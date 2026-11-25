#!/usr/bin/env node
// The audio layer in a real browser: `node frontend/tool/audio_proof/run.cjs`.
// Not in CI. Compiles proof_main.dart (the app's own SoundEngine and
// WebAudioBackend) with `dart compile js`, serves it with two of the owner's
// candidate mp3s as stand-ins (copied at run time, never bundled), and drives
// headless Chromium with Playwright, as an Android phone: a touch context
// (hasTouch, isMobile, the Pixel 7's 412-wide profile) and
// page.touchscreen.tap, so a tap is pointerdown, pointerup, touchend, then a
// compatibility mousedown and click, with no mouse. Prints what it measured as JSON and writes it to
// result.json beside this script.
//
// (a) no AudioContext on the first touch's pointerdown (not an activation
//     on a touch); made on its pointerup, running, the theme playing;
// (b) "the call": pointerup (the event Flutter's onTap fires on) to the
//     cue's source.start() call, and separately the context's baseLatency /
//     outputLatency (what the device adds after start());
// (e) the context suspended by the browser: the next tap resumes it and
//     that tap's own cue starts; whether microtasks run between the engine's
//     capture listener and the page's handler of the same pointerup (why the
//     engine's "this gesture asked for the resume" flag lasts a task);
// (c) the theme rendered offline through the engine across two loop ends
//     and a variant switch, compared sample by sample with the file, once
//     looping the whole file and once over loop points cut to its sound;
// (d) the context suspended while the page is hidden, running when shown.
const { execFileSync } = require('child_process');
const fs = require('fs');
const http = require('http');
const path = require('path');
const { chromium, devices } = require('playwright');

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
  window.__created = 0; window.__starts = []; window.__downs = []; window.__ups = [];
  window.__events = [];
  const Real = window.AudioContext;
  window.AudioContext = class extends Real {
    constructor(...a) {
      super(...a); window.__created++; window.__ctx = this;
      window.__madeOn = window.__current; window.__stateWhenMade = this.state;
    }
  };
  const active = () => navigator.userActivation ? navigator.userActivation.isActive : null;
  const realStart = AudioBufferSourceNode.prototype.start;
  AudioBufferSourceNode.prototype.start = function (...a) {
    if (this.context === window.__ctx) {
      window.__starts.push({ t: performance.now(), loop: this.loop });
    }
    return realStart.apply(this, a);
  };
  // Registered before the engine's own capture listeners, so these run
  // first: what the event is, before the engine sees it.
  for (const type of ['pointerdown', 'touchend', 'pointerup', 'click', 'mousedown']) {
    window.addEventListener(type, (e) => {
      window.__current = type + (e.pointerType ? ':' + e.pointerType : '');
      if (window.__events.length < 12) window.__events.push({ type: window.__current, activeAtEvent: active() });
    }, { capture: true });
  }
  window.addEventListener('pointerdown', () => {
    window.__downs.push(performance.now());
  }, { capture: true });
  window.addEventListener('pointerup', () => {
    if (window.__createdAtFirstUp === undefined) window.__createdAtFirstUp = window.__created;
    window.__ups.push(performance.now());
    window.__micro = false;
    queueMicrotask(() => { window.__micro = true; });
  }, { capture: true });
  document.addEventListener('pointerup', () => {
    window.__microRanBetweenListeners = window.__micro;
  });
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
  // What the old engine did: a context made, and resumed, on a touch's
  // pointerdown. Does this browser leave it suspended there?
  fs.writeFileSync(path.join(out, 'down.html'), `<!doctype html><body style="height:100vh"><script>
  window.__probe = {};
  addEventListener('pointerdown', () => {
    const c = window.__c = new AudioContext();
    __probe.stateWhenMadeOnPointerdown = c.state;
    c.resume().then(() => { __probe.resumeFromPointerdownSettledAt = __probe.at || 'before pointerup'; });
  }, { capture: true });
  addEventListener('pointerup', () => {
    __probe.at = 'after pointerup';
    __probe.stateAtPointerup = window.__c.state;
  }, { capture: true });
  addEventListener('click', () => {
    setTimeout(() => { __probe.stateAfterClick = window.__c.state; }, 100);
  });
</script></body>`);
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
  const policy = '--autoplay-policy=document-user-activation-required';
  const browser = await chromium.launch({
    args: [policy],
    ignoreDefaultArgs: ['--autoplay-policy=no-user-gesture-required'],
  });
  // An Android phone: touch only, 412 wide.
  const phone = devices['Pixel 7'];
  const context = await browser.newContext({ ...phone, hasTouch: true, isMobile: true });
  const page = await context.newPage();
  page.on('console', (m) => process.stderr.write('[page] ' + m.text() + '\n'));
  page.on('pageerror', (e) => process.stderr.write('[page error] ' + e + '\n'));
  const report = {
    browser: browser.version(), launchedWith: policy,
    profile: { viewport: phone.viewport, isMobile: true, hasTouch: true, userAgent: phone.userAgent },
    input: 'page.touchscreen.tap', loopFile, cueFile,
  };
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

    // A touch's pointerdown alone: what the old engine relied on.
    const down = await context.newPage();
    await down.goto(url + 'down.html');
    await down.waitForTimeout(300);
    await down.touchscreen.tap(50, 50);
    await down.waitForTimeout(400);
    report.contextMadeOnTouchPointerdown = await down.evaluate(() => window.__probe);
    await down.close();

    // No evaluate on this page before the tap: it would count as a gesture.
    await page.goto(url);
    await page.waitForTimeout(800);
    await page.touchscreen.tap(100, 100);
    await until(page, () => window.mvProof.playing() === 'table');
    report.a = await page.evaluate(() => ({
      themeAskedBeforeGesture: window.__asked !== undefined,
      firstTapEvents: window.__events,
      contextsAfterFirstPointerdown: window.__createdAtFirstUp,
      contextMadeOn: window.__madeOn,
      stateWhenMade: window.__stateWhenMade,
      contextsAfterGesture: window.__created,
      stateAfterGesture: window.mvProof.state(),
      themePlayingAfterGesture: window.mvProof.playing(),
    }));

    // (b) 20 taps; the page answers each pointerup with the cue.
    await page.evaluate(() => { window.__ups = []; window.__starts = []; });
    for (let i = 0; i < 20; i++) {
      await page.touchscreen.tap(120 + i, 140);
      await page.waitForTimeout(60);
    }
    const timing = await page.evaluate(() => ({
      ups: window.__ups,
      starts: window.__starts.filter((s) => !s.loop).map((s) => s.t),
    }));
    const deltas = timing.ups.map((d, i) => timing.starts[i] - d).filter((x) => x >= 0);
    deltas.sort((x, y) => x - y);
    const [base, output, rate] = await page.evaluate(() => window.mvProof.latency());
    report.b = {
      taps: timing.ups.length,
      cueStarts: timing.starts.length,
      theCall_pointerupToStartMs: {
        median: deltas[Math.floor(deltas.length / 2)],
        max: deltas[deltas.length - 1],
      },
      outputLatency: {
        baseLatencyMs: base * 1000,
        outputLatencyMs: output * 1000,
        sampleRate: rate,
        note: 'what the device adds after start(), apart from the call; headless renders to no real device',
      },
    };

    // (e) the browser suspends the context on its own (as Chrome on Android
    // does); the next tap must resume it and sound its own cue.
    await page.evaluate(() => window.__ctx.suspend());
    await page.waitForTimeout(200);
    const startsBefore = await page.evaluate(() => window.__starts.filter((s) => !s.loop).length);
    const stateBefore = await page.evaluate(() => window.__ctx.state);
    await page.touchscreen.tap(200, 200);
    await page.waitForTimeout(200);
    report.e = await page.evaluate(([n, before]) => ({
      stateBeforeTap: before,
      stateAfterTap: window.__ctx.state,
      cueStartedOnThatTap: window.__starts.filter((s) => !s.loop).length > n,
      microtasksRanBetweenEngineAndPageListeners: window.__microRanBetweenListeners,
    }), [startsBefore, stateBefore]);

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
  const json = JSON.stringify(report, null, 2);
  fs.writeFileSync(path.join(here, 'result.json'), json + '\n');
  console.log(json);
})().catch((e) => { console.error(e); process.exit(1); });
