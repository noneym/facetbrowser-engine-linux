#!/usr/bin/env node
// Starts chromedriver, opens a headless session with the given chrome, loads
// a page and reads a few values back. Exits non-zero if any step fails.
//
//   node chromedriver_smoke.mjs <chrome> <chromedriver>
//
// Needs Node 18 or newer (global fetch). No dependencies.

import { spawn } from 'node:child_process'

const [chrome, chromedriver] = process.argv.slice(2)
if (!chrome || !chromedriver) {
  console.error('usage: chromedriver_smoke.mjs <chrome> <chromedriver>')
  process.exit(2)
}

const port = 9515
const base = `http://127.0.0.1:${port}`
const driver = spawn(chromedriver, [`--port=${port}`], { stdio: ['ignore', 'inherit', 'inherit'] })
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms))

async function call(method, path, body) {
  const response = await fetch(base + path, {
    method,
    headers: { 'content-type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body)
  })
  const json = await response.json()
  if (!response.ok) throw new Error(`${method} ${path}: ${JSON.stringify(json.value)}`)
  return json.value
}

let exitCode = 0
let sessionId
try {
  for (let i = 0; ; i++) {
    try {
      if ((await call('GET', '/status')).ready) break
    } catch (e) {
      if (i >= 50) throw new Error('chromedriver did not start: ' + e.message)
    }
    await sleep(200)
  }

  const session = await call('POST', '/session', {
    capabilities: {
      alwaysMatch: {
        'goog:chromeOptions': {
          binary: chrome,
          args: ['--headless=new', '--no-sandbox', '--disable-dev-shm-usage', '--disable-gpu']
        }
      }
    }
  })
  sessionId = session.sessionId
  console.log('chromedriver session: browserVersion ' + session.capabilities.browserVersion)

  const page = '<title>engine</title><p id="p">ok</p>'
  await call('POST', `/session/${sessionId}/url`, { url: 'data:text/html,' + encodeURIComponent(page) })
  const title = await call('GET', `/session/${sessionId}/title`)
  const values = await call('POST', `/session/${sessionId}/execute/sync`, {
    script:
      'return { text: document.getElementById("p").textContent, userAgent: navigator.userAgent, ' +
      'webdriver: navigator.webdriver, cdc: Object.keys(window).filter((k) => k.includes("cdc_")).length }',
    args: []
  })
  console.log('chromedriver session: title ' + JSON.stringify(title) + ', page ' + JSON.stringify(values))
  if (title !== 'engine' || values.text !== 'ok') throw new Error('the page did not load as expected')
} catch (e) {
  console.error('chromedriver session FAILED: ' + e.message)
  exitCode = 1
} finally {
  if (sessionId) await call('DELETE', `/session/${sessionId}`).catch(() => {})
  driver.kill()
}
process.exit(exitCode)
