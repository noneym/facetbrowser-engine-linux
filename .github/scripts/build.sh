#!/bin/bash
set -euxo pipefail

clone=false
use_gentoo_source_tar=false
if [[ "${1:-}" == "-c" ]]; then
    clone=true
elif [[ "${1:-}" == "-g" ]]; then
    use_gentoo_source_tar=true
fi

. "/repo/scripts/shared.sh"

setup_paths

if [ "$_prepare_only" = true ]; then
    fetch_sources "$clone" "$use_gentoo_source_tar"
    apply_patches
    apply_domsub
    write_gn_args
    fix_tool_downloading
    setup_toolchain
    gn_gen
else
    # one budget for everything this job compiles
    _deadline=$(( $(date +%s) + 18000 ))
    remaining_time() {
        echo $(( _deadline - $(date +%s) ))
    }

    cd "$_src_dir"

    # Hotfixes: a patch in hotfix/ of this repository is applied once to a tree
    # that is already partly built, so that a late compile error can be fixed in
    # a run that continues from another one instead of starting over.
    for _hotfix in "${_root}"/hotfix/*.patch; do
        if [ ! -f "$_hotfix" ]; then
            continue
        fi
        _hotfix_marker="out/Default/facet_hotfix_$(basename "$_hotfix").done"
        if [ ! -f "$_hotfix_marker" ]; then
            echo "Hotfix: applying $(basename "$_hotfix")"
            patch -p1 --forward --batch --no-backup-if-mismatch -i "$_hotfix"
            touch "$_hotfix_marker"
        fi
    done

    # Preflight: compile the files changed by the FacetBrowser Engine patches
    # before anything else, all of them (-k 0), so that a compile error in a
    # patch shows up in the first job instead of days into the build. Nothing
    # is built twice: the objects are part of the normal build.
    _preflight_marker="out/Default/facet_preflight.done"
    if [ ! -f "$_preflight_marker" ]; then
        if ninja -C out/Default -t inputs chrome chromedriver > /tmp/facet_preflight_inputs.txt; then
            python3 "${_root}/.github/scripts/facet_preflight.py" "${_main_repo}/patches" \
                /tmp/facet_preflight_inputs.txt > /tmp/facet_preflight_targets.txt
            echo "Preflight: compiling $(wc -l < /tmp/facet_preflight_targets.txt) patched files first"

            set +e
            timeout -k 5m -s INT "$(remaining_time)"s \
                xargs ninja -C out/Default -k 0 < /tmp/facet_preflight_targets.txt
            rc=$?
            set -e

            if [ "$rc" -eq 124 ]; then
                echo "Preflight ran out of time; continuing in next run."
                echo "status=running" >> "$GITHUB_OUTPUT"
                exit 0
            fi
            if [ "$rc" -ne 0 ]; then
                echo "Preflight: patched files do not compile"
                exit "$rc"
            fi
            cp /tmp/facet_preflight_targets.txt "$_preflight_marker"
            echo "Preflight: all patched files compile"
        else
            echo "Preflight: skipped, could not list the inputs of chrome"
        fi
    fi

    if [ "${FACET_PREFLIGHT_ONLY:-false}" = true ]; then
        echo "Preflight only: stopping before the full build."
        echo "status=preflight" >> "$GITHUB_OUTPUT"
        exit 0
    fi

    _task_timeout="$(remaining_time)"
    if [ "$_task_timeout" -lt 60 ]; then
        echo "status=running" >> "$GITHUB_OUTPUT"
        exit 0
    fi

    set +e
    timeout -k 5m -s INT "${_task_timeout}"s ninja -C out/Default chrome chromedriver
    rc=$?
    set -e

    if [ "${_gha_final}" != "true" ] && [ "$rc" -eq 124 ]; then
        echo "Task timed out after ${_task_timeout}s; continuing in next run."
        echo "status=running" >> "$GITHUB_OUTPUT"
        exit 0
    elif [ "$rc" -eq 0 ] && [ -x "${_out_dir}/chrome" ] && [ -x "${_out_dir}/chromedriver" ]; then
        echo "status=completed" >> "$GITHUB_OUTPUT"
    fi

    exit "$rc"
fi
