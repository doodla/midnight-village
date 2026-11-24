#!/usr/bin/env node
// The audio layer in a real browser: `node frontend/tool/audio_proof/run.cjs`.
// Not in CI. Compiles proof_main.dart (the app's own SoundEngine and
// WebAudioBackend) with `dart compile js`, serves it with two of the owner's
// candidate mp3s as stand-ins (copied at run time, never bundled), and drives
// headless Chromium with Playwright. Prints what it measured as JSON.
//
// (a) no AudioContext before a gesture, running after;
// (b) pointerdown to the cue's source.start() call, and the context's
//     baseLatency / outputLatency (what the device adds after start());
// (c) the theme rendered offline through the engine across two loop ends
//     and a variant switch, compared sample by sample with the file, once
//     looping the whole file and once over loop points cut to its sound;
// (d) the context suspended while the page is hidden, running when shown.
const { execFileSync } = require('child_process');
const fs = require('fs');
const http = require('http');
const path = require('path');
const { chromium } = require('playwright');

const here = __dirname;
const frontend = path.resolve(here, '../..');
const candidates = path.resolve(frontend, '../docs/dev/owner-board/sounds-candidates');
const out = path.join(frontend, 'build/audio_proof');

const loopFile = process.env.LOOP || 'dawn-a.mp3';
const cueFile = process.env.CUE || 'knock-a.mp3';

function build() {
  fs.mkdirSync(out, { recursive: true });
  execFileSync('dart', ['compile', 'js', '-O2', '-o', path.join(out, 'proof.js'),
    path.join(here, 'proof_main.dart')], { cwd: frontend, stdio: 'ignore' });
  fs.copyFileSync(path.join(candidates, loopFile), path.join(out, 'loop.mp3'));
  fs.copyFileSync(path.join(candidates, cueFile), path.join(out, 'knock.mp3'));
  fs.writeFileSync(path.join(out, 'index.html'), `<!doctype html><html><body>
<div id="pad" style="width:100vw;height:100vh"></div>
<script>
  window.__created = 0; window.__starts = []; window.__downs = [];
  const Real = window.AudioContext;
  window.AudioContext = class extends Real {
    constructor(...a) { super(...a); window.__created++; window.__ctx = this; }
  };
  const realStart = AudioBufferSourceNode.prototype.start;
  AudioBufferSourceNode.prototype.start = function (...a) {
    if (this.context === window.__ctx) {
      window.__starts.push({ t: performance.now(), loop: this.loop });
    }
    return realStart.apply(this, a);
  };
  window.addEventListener('pointerdown', () => {
    if (window.__createdAtFirstDown === undefined) {
      window.__createdAtFirstDown = window.__created;
    }
    window.__downs.push(performance.now());
  }, { capture: true });
</script>
<script src="proof.js"></script>
<script>
  // The stage asks for the theme before any gesture, from the page itself
  // (Playwright's evaluate runs as a user gesture, so it must not).
  (function ask() {
    if (window.mvProof) { window.__asked = performance.now(); mvProof.theme('table'); }
    else setTimeout(ask, 10);
  })();
</script></body></html>`);
  fs.writeFileSync(path.join(out, 'policy.html'), `<!doctype html><script>
  window.__policy = new AudioContext().state;
  setTimeout(() => { window.__policyLater = window.__policyCtx.state; }, 300);
  window.__policyCtx = new AudioContext();
</script>`);
}

function serve() {
  const types = { '.html': 'text/html', '.js': 'text/javascript', '.mp3': 'audio/mpeg' };
  const server = http.createServer((req, res) => {
    const file = path.join(out, req.url === '/' ? 'index.html' : req.url.slice(1));
    if (!file.startsWith(out) || !fs.existsSync(file)) { res.writeHead(404); return res.end(); }
    res.writeHead(200, { 'content-type': types[path.extname(file)] || 'application/octet-stream' });
    fs.createReadStream(file).pipe(res);
  });
  return new Promise((ok) => server.listen(0, '127.0.0.1', () => ok(server)));
}

const until = async (page, fn, ms = 5000) => {
  await page.waitForFunction(fn, null, { timeout: ms });
};

(async () => {
  build();
  const server = await serve();
  const url = `http://127.0.0.1:${server.address().port}/`;
  // The real autoplay rule: headless Chromium lets any page play unless told.
  const browser = await chromium.launch({
    args: ['--autoplay-policy=user-gesture-required'],
    ignoreDefaultArgs: ['--autoplay-policy=no-user-gesture-required'],
  });
  const context = await browser.newContext();
  const page = await context.newPage();
  page.on('console', (m) => process.stderr.write('[page] ' + m.text() + '\n'));
  page.on('pageerror', (e) => process.stderr.write('[page error] ' + e + '\n'));
  const report = { browser: browser.version(), loopFile, cueFile };
  try {
    // What this headless browser does with a context made with no gesture
    // at all (whether it enforces the autoplay rule), on a blank page.
    // A page that makes a context on load, with no gesture: the rule this
    // browser enforces.
    const blank = await context.newPage();
    await blank.goto(url + 'policy.html');
    await blank.waitForTimeout(500);
    report.policyWithoutGesture = await blank.evaluate(() => [window.__policy, window.__policyLater]);
    await blank.close();

    // No evaluate on this page before the click: it would count as a gesture.
    await page.goto(url);
    await page.waitForTimeout(800);
    await page.mouse.click(100, 100);
    await until(page, () => window.mvProof.playing() === 'table');
    report.a = {
      themeAskedBeforeGesture: await page.evaluate(() => window.__asked !== undefined),
      contextsBeforeGesture: await page.evaluate(() => window.__createdAtFirstDown),
    };
    if (report.policyWithoutGesture[0] === 'running') {
      report.a.note = 'this headless browser does not enforce the autoplay rule (a context made on load runs), so running after the gesture shows the unlock path ran, not that the gesture is what allowed it; what is shown is that no context exists before the first pointerdown';
    }
    report.a.contextsAfterGesture = await page.evaluate(() => window.__created);
    report.a.stateAfterGesture = await page.evaluate(() => window.mvProof.state());
    report.a.themePlayingAfterGesture = await page.evaluate(() => window.mvProof.playing());

    // (b) 20 taps, each a pointerdown the page's handler answers with the cue.
    await page.evaluate(() => { window.__downs = []; window.__starts = []; });
    for (let i = 0; i < 20; i++) {
      await page.mouse.click(120 + i, 140);
      await page.waitForTimeout(60);
    }
    const timing = await page.evaluate(() => ({
      downs: window.__downs,
      starts: window.__starts.filter((s) => !s.loop).map((s) => s.t),
    }));
    const deltas = timing.downs.map((d, i) => timing.starts[i] - d).filter((x) => x >= 0);
    deltas.sort((x, y) => x - y);
    const [base, output, rate] = await page.evaluate(() => window.mvProof.latency());
    report.b = {
      taps: timing.downs.length,
      cueStarts: timing.starts.length,
      pointerdownToStartMs: {
        median: deltas[Math.floor(deltas.length / 2)],
        max: deltas[deltas.length - 1],
      },
      baseLatencyMs: base * 1000,
      outputLatencyMs: output * 1000,
      sampleRate: rate,
    };

    // (d) the page hidden behind another tab, then shown again.
    const other = await context.newPage();
    await other.goto(url + 'policy.html');
    await other.bringToFront();
    await page.waitForTimeout(400);
    report.d = {
      visibilityWhenBehind: await page.evaluate(() => document.visibilityState),
      stateWhenBehind: await page.evaluate(() => window.__ctx.state),
    };
    if (report.d.visibilityWhenBehind === 'visible') {
      // Headless did not hide it: say so, then hide it by hand (the
      // browser's own event, with the page's visibility overridden).
      report.d.note = 'headless kept the page visible; hidden simulated by overriding visibilityState and dispatching visibilitychange';
      await page.evaluate(() => {
        Object.defineProperty(document, 'visibilityState', { configurable: true, get: () => 'hidden' });
        document.dispatchEvent(new Event('visibilitychange'));
      });
      await page.waitForTimeout(200);
      report.d.stateWhenHiddenSimulated = await page.evaluate(() => window.__ctx.state);
      const t1 = await page.evaluate(() => window.__ctx.currentTime);
      await page.waitForTimeout(300);
      report.d.clockAdvancedWhileHiddenMs = (await page.evaluate(() => window.__ctx.currentTime) - t1) * 1000;
      await page.evaluate(() => {
        Object.defineProperty(document, 'visibilityState', { configurable: true, get: () => 'visible' });
        document.dispatchEvent(new Event('visibilitychange'));
      });
    } else {
      await page.bringToFront();
    }
    await page.waitForTimeout(300);
    report.d.stateWhenShown = await page.evaluate(() => window.__ctx.state);
    report.d.themeAfterShown = await page.evaluate(() => window.mvProof.playing());
    const t2 = await page.evaluate(() => window.__ctx.currentTime);
    await page.waitForTimeout(300);
    report.d.clockAdvancedAfterShownMs = (await page.evaluate(() => window.__ctx.currentTime) - t2) * 1000;

    // (c) the theme offline, every sample.
    report.c = JSON.parse(await page.evaluate(() => window.mvProof.offline(false)));
    report.cTrimmed = JSON.parse(await page.evaluate(() => window.mvProof.offline(true)));
  } finally {
    await browser.close();
    server.close();
  }
  console.log(JSON.stringify(report, null, 2));
})().catch((e) => { console.error(e); process.exit(1); });
