# FacetBrowser Engine: Linux packaging

This is a fork of [ungoogled-chromium-portablelinux](https://github.com/ungoogled-software/ungoogled-chromium-portablelinux)
that builds [FacetBrowser Engine](https://github.com/noneym/facetbrowser-engine) for Linux x86_64
on GitHub's own runner. The engine repository is the `ungoogled-chromium` submodule.

What differs from upstream:

- The build is started by hand (`Build Linux binaries of FacetBrowser Engine` workflow). It can
  continue from the build cache of another run (`resume_run_id`), build another revision of the
  engine (`engine_ref`), and stop after compiling the files the engine patches change (`preflight_only`).
- The files changed by the engine patches are compiled first, so that an error in a patch shows
  up in the first job.
- Only the `tar.xz` is produced, not the AppImage. It contains `chrome` and `chromedriver`.
- The `tar.xz` is tested in a Debian bookworm container (`Test a Linux build of FacetBrowser Engine` workflow).
- No release is created by the workflow.

The upstream README follows.

---

# ungoogled-chromium-portablelinux
Portable Linux (`.AppImage`) packaging for [ungoogled-chromium](https://github.com/ungoogled-software/ungoogled-chromium).

## Downloads
- [Download binaries from GitHub Releases](https://github.com/ungoogled-software/ungoogled-chromium-portablelinux/releases).
- [Download binaries from the Contributor Binaries website](https://ungoogled-software.github.io/ungoogled-chromium-binaries/).

## Building
To build the binary, run `scripts/docker-build.sh` from the repo root.

The `scripts/docker-build.sh` script will:
1. Create a Docker image of a Debian-based building environment with all required packages (llvm, nodejs and distro packages) included.
2. Run `scripts/build.sh` inside the Docker image to build ungoogled-chromium.

Running `scripts/build.sh` directly will not work unless you're running a Debian-based distro and have all necessary dependencies installed. This repo is designed to avoid having to configure the building environment on your Linux installation.

### Packaging
After building, run `scripts/package.sh`. Alternatively, you can run `package/docker-package.sh` to build inside a Docker image.

Either of these scripts will create `tar.xz` and `AppImage` files under `build/`.

### Development
By default, the build script uses tarball. If you need to use a source tree clone, you can run `scripts/docker-build.sh -c` instead. This may be useful if a tarball for a release isn't available yet.

## License
BSD-3-Clause. See [LICENSE](LICENSE)
