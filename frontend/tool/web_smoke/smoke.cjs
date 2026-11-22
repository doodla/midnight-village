// The built web page in a real browser, served as Vercel serves it (every
// file revalidated, unknown paths answered with index.html): a first visit
// loads, a return loads (from Flutter's service worker), and a second build
// served in the first one's place (a deploy) runs on its first open; a
// table's link (`/join/<code>`) opens the app, as a return and as a first
// visit that registers the whole site's worker.
//
// usage: node tool/web_smoke/smoke.cjs <release build/web>
// Needs the `playwright` package (NODE_PATH, or installed beside this file)
// and its Chromium. No backend: the app opens on 01 with nothing signed in.
'use strict';
const crypto = require('crypto');
const fs = require('fs');
const http = require('http');
const os = require('os');
const path = require('path');
const { chromium } = require('playwright');

const build = path.resolve(process.argv[2] || 'build/web');
if (!fs.existsSync(path.join(build, 'main.dart.js'))) {
  console.error(`web-smoke: no build at ${build}`);
  process.exit(2);
}

// Two deploys of the same build, told apart by a line at the end of
// main.dart.js (`window.mvBuild`). B's service worker lists its main.dart.js
// with the new hash and its page a new worker version, as a real deploy that
// changed the app would: the worker updates and drops the old copy.
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'web-smoke-'));
const md5 = (file) => crypto.createHash('md5').update(fs.readFileSync(file)).digest('hex');
function deploy(name, version) {
  const dir = path.join(root, name);
  fs.cpSync(build, dir, { recursive: true });
  const main = path.join(dir, 'main.dart.js');
  fs.appendFileSync(main, `\n;window.mvBuild=${JSON.stringify(name)};\n`);
  const worker = path.join(dir, 'flutter_service_worker.js');
  const text = fs.readFileSync(worker, 'utf8').replace(
    /"main\.dart\.js": "[0-9a-f]+"/,
    `"main.dart.js": "${md5(main)}"`,
  );
  fs.writeFileSync(worker, text);
  const index = path.join(dir, 'index.html');
  fs.writeFileSync(
    index,
    fs.readFileSync(index, 'utf8').replace(/var version = "\d+"/, `var version = "${version}"`),
  );
}
deploy('A', '1111');
deploy('B', '2222');

let current = 'A';
const types = {
  '.js': 'text/javascript', '.mjs': 'text/javascript', '.html': 'text/html',
  '.json': 'application/json', '.wasm': 'application/wasm', '.webp': 'image/webp',
  '.png': 'image/png', '.ttf': 'font/ttf', '.otf': 'font/otf', '.txt': 'text/plain',
};
const server = http.createServer((req, res) => {
  let url = decodeURIComponent(req.url.split('?')[0]);
  if (url === '/') url = '/index.html';
  let file = path.join(root, current, url);
  if (!file.startsWith(path.join(root, current)) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
    file = path.join(root, current, 'index.html');
  }
  const body = fs.readFileSync(file);
  const etag = `"${crypto.createHash('md5').update(body).digest('hex')}"`;
  const headers = { 'Cache-Control': 'public, max-age=0, must-revalidate', ETag: etag };
  if (req.headers['if-none-match'] === etag) {
    res.writeHead(304, headers);
    return res.end();
  }
  res.writeHead(200, { ...headers, 'Content-Type': types[path.extname(file)] || 'application/octet-stream' });
  res.end(body);
});

const failures = [];
function check(ok, what) {
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${what}`);
  if (!ok) failures.push(what);
}

async function open(context, url, label) {
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message.slice(0, 200)));
  const logs = [];
  page.on('console', (m) => logs.push(m.text().slice(0, 120)));
  const started = Date.now();
  await page.goto(url);
  // The launch mark goes on Flutter's first frame (web/flutter_bootstrap.js).
  const painted = await page
    .waitForFunction(() => document.getElementById('launch') === null, null, { timeout: 30000 })
    .then(() => true, () => false);
  const state = await page.evaluate(async () => {
    const r = await navigator.serviceWorker.getRegistration();
    return {
      build: window.mvBuild ?? null,
      controlled: navigator.serviceWorker.controller != null,
      worker: r?.active?.scriptURL?.split('/').pop() ?? null,
    };
  });
  if (process.env.WEB_SMOKE_DEBUG) console.log(JSON.stringify(state), logs.join(' | '));
  console.log(`     ${label}: ${painted ? `first frame in ${Date.now() - started} ms` : 'no first frame'}, ` +
    `build ${state.build}, served by the worker: ${state.controlled}`);
  return { page, painted, errors, ...state };
}

(async () => {
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  const url = `http://localhost:${server.address().port}/`;
  const browser = await chromium.launch();
  const context = await browser.newContext();
  try {
    // 1. A first visit: the app paints, nothing waited for.
    const first = await open(context, url, 'first visit');
    check(first.painted && first.build === 'A', 'a first visit loads the app');
    check(!first.controlled, 'a first visit is not held by a service worker');
    // The worker is registered once the app's own start is in.
    let registered = false;
    for (let i = 0; i < 120 && !registered; i++) {
      registered = await first.page.evaluate(async () => {
        const r = await navigator.serviceWorker.getRegistration();
        return r?.active?.state === 'activated';
      });
      if (!registered) await first.page.waitForTimeout(500);
    }
    check(registered, 'the first visit then registers the service worker');
    check(first.errors.length === 0, `no page errors on the first visit ${first.errors.join(' | ')}`);
    await first.page.close();

    // 2. A return: the worker serves it.
    const back = await open(context, url, 'return');
    check(back.painted && back.build === 'A', 'a return loads the app');
    check(back.controlled, 'a return is served by the service worker');
    check(back.errors.length === 0, `no page errors on the return ${back.errors.join(' | ')}`);
    await back.page.close();

    // 3. A deploy: B served in A's place. Its first open runs B.
    current = 'B';
    const deployed = await open(context, url, 'first open after a deploy');
    check(deployed.painted && deployed.build === 'B', 'the first open after a deploy runs the new build');
    check(deployed.errors.length === 0, `no page errors after the deploy ${deployed.errors.join(' | ')}`);
    await deployed.page.close();

    // 4. And it stays the new build, served by the new worker.
    const again = await open(context, url, 'return after the deploy');
    check(again.painted && again.build === 'B', 'a return after the deploy runs the new build');
    check(again.controlled, 'the new build is served by the service worker');
    await again.page.close();

    // 5. A table's link (`/join/<code>`, a path) is the app too.
    const link = await open(context, `${url}join/ABCD`, 'a join link');
    check(link.painted && link.build === 'B', "a table's link opens the app");
    check(link.controlled, "a table's link is served by the service worker");
    await link.page.close();

    // 6. A phone whose first visit is a table's link: the worker it then
    // registers is the whole site's, not the link's folder.
    const fresh = await browser.newContext();
    const linked = await open(fresh, `${url}join/ABCD`, 'a first visit by a join link');
    check(linked.painted && linked.build === 'B', "a first visit by a table's link loads the app");
    let scope = null;
    for (let i = 0; i < 120 && scope == null; i++) {
      scope = await linked.page.evaluate(async () => {
        const r = await navigator.serviceWorker.getRegistration();
        return r?.active?.state === 'activated' ? r.scope : null;
      });
      if (scope == null) await linked.page.waitForTimeout(500);
    }
    check(scope === url, `that visit registers the site's service worker (scope ${scope})`);
    check(linked.errors.length === 0, `no page errors on that visit ${linked.errors.join(' | ')}`);
    await fresh.close();
  } finally {
    await browser.close();
    server.close();
    fs.rmSync(root, { recursive: true, force: true });
  }
  if (failures.length) {
    console.error(`web-smoke: ${failures.length} failed`);
    process.exit(1);
  }
  console.log('web-smoke: all passed');
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
