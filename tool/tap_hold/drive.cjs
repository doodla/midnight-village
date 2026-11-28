// A first step of the tap/hold browser check: serves a built stage (frontend/test_screens/tap_hold/), touches one part through CDP at each CPU speed and prints what each touch did, with its own times. usage: node drive.cjs <build> <part> <cpus> <sem> <touches> <quick ms,...>
'use strict';
const { chromium } = require('playwright');
const [dir, part, cpuList, semList, touches, quickMs] = process.argv.slice(2);

const http = require('http'); const fs = require('fs'); const path = require('path');
const TYPES = { '.js': 'text/javascript', '.mjs': 'text/javascript', '.wasm': 'application/wasm', '.json': 'application/json', '.html': 'text/html', '.css': 'text/css', '.png': 'image/png', '.webp': 'image/webp', '.ttf': 'font/ttf', '.otf': 'font/otf' };
function serve(root) {
  const server = http.createServer((req, res) => {
    let file = path.join(root, decodeURIComponent(new URL(req.url, 'http://x').pathname));
    if (!file.startsWith(root) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) file = path.join(root, 'index.html');
    res.writeHead(200, { 'content-type': TYPES[path.extname(file)] || 'application/octet-stream' });
    fs.createReadStream(file).pipe(res);
  });
  return new Promise((r) => server.listen(0, '127.0.0.1', () => r(server)));
}
async function run() {
  const server = await serve(path.resolve(dir));
  const url = `http://127.0.0.1:${server.address().port}/`;
  const browser = await chromium.launch({
    executablePath: process.env.CHROME || undefined,
    args: ['--no-sandbox', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'],
  });
  const tally = [];
  for (const sem of semList.split(',')) {
    const ctx = await browser.newContext({ viewport: { width: 412, height: 915 }, deviceScaleFactor: 2.625, isMobile: true, hasTouch: true });
    const page = await ctx.newPage();
    await page.addInitScript(() => {
      const L = (window.__ev = []);
      for (const k of ['pointerdown', 'pointerup']) window.addEventListener(k, (e) => L.push([k, e.timeStamp, performance.now()]), true);
      const F = (window.__fr = []);
      const tick = (t) => { F.push(t); requestAnimationFrame(tick); };
      requestAnimationFrame(tick);
    });
    const said = [];
    let wake = null;
    page.on('console', (m) => {
      const t = m.text();
      if (!t.startsWith('tap-hold: ')) return;
      said.push(t.slice(10));
      if (wake) wake();
    });
    const until = (test, ms = 30000) => new Promise((res, rej) => {
      const check = () => { const hit = test(); if (hit) { wake = null; clearTimeout(timer); res(hit); } };
      const timer = setTimeout(() => { wake = null; rej(new Error('timed out; said: ' + said.slice(-5).join(' | '))); }, ms);
      wake = check; check();
    });
    await page.goto(`${url}?part=${part}&sem=${sem}`);
    const ready = await until(() => said.find((s) => s.startsWith('ready ')), 90000);
    const [, x, y] = ready.split(' ').map(Number);
    const cdp = await ctx.newCDPSession(page);
    for (const cpu of cpuList.split(',').map(Number)) {
      await cdp.send('Emulation.setCPUThrottlingRate', { rate: cpu });
      for (const [kind, ms] of [...quickMs.split(',').map((q) => ['quick', Number(q)]), ['long', 500]]) {
        const got = [];
        const n = kind === 'long' ? 6 : Number(touches);
        const lens = [];
        for (let i = 0; i < n; i++) {
          said.length = 0;
          await page.evaluate(() => { window.__ev.length = 0; window.__fr.length = 0; });
          const point = [{ x, y, radiusX: 6, radiusY: 6, force: 1 }];
          // not waiting for the landing to be handled: a finger lifts when it lifts
          const landed = cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: point });
          await new Promise((r) => setTimeout(r, ms));
          await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
          await landed;
          await until(() => said.includes('settled'));
          const verdict = said.filter((s) => s === 'tap' || s === 'hold').join('+') || 'nothing';
          const [ev, fr] = await page.evaluate(() => [window.__ev, window.__fr]);
          const d = ev.find((e) => e[0] === 'pointerdown'), u = ev.find((e) => e[0] === 'pointerup');
          const t0 = d ? d[1] : 0;
          const gaps = fr.map((f, j) => j ? Math.round(f - fr[j - 1]) : 0).slice(1, 6);
          lens.push([verdict, u && d ? u[1] - d[1] : 9999]);
          got.push(`${verdict}[len ${u && d ? Math.round(u[1] - d[1]) : '?'} upAt ${u ? Math.round(u[2] - t0) : '?'} fr ${gaps.join(',')}]`);
        }
        const under = lens.filter((l) => l[1] < 300);
        const line = `SUMMARY ${part} sem=${sem} cpu=${cpu}x ${kind} ${ms}ms: holds ${lens.filter((l) => l[0] === 'hold').length}/${n}; finger under 300ms: ${under.length}, of which held ${under.filter((l) => l[0] === 'hold').length}\n   ${got.join('\n   ')}`;
        console.log(line);
        tally.push(line);
      }
    }
    await ctx.close();
  }
  await browser.close();
  server.close();
}
run().catch((e) => { console.error(e); process.exit(2); });
