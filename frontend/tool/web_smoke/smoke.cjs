// The built web page in a real browser, served as Vercel serves it: the
// routing is read from frontend/vercel.json itself (redirects, then files,
// then rewrites, else 404; its headers on top of Vercel's default of
// revalidating every file). A first visit loads, a return loads (from
// Flutter's service worker), and a second build served in the first one's
// place (a deploy) runs on its first open; a table's link
// (`/join/<code>`) opens the app, as a return and as a first visit that
// registers the whole site's worker; a made-up picture is a 404 and
// `/commit.txt` is the commit built; and an app left open on the old build
// reloads itself for the new one when it is resumed (once, never in a loop,
// even when the shell it reloads into is still the old one).
//
// usage: node tool/web_smoke/smoke.cjs <release build/web>
// Needs the `playwright` package (NODE_PATH, or installed beside this file)
// and its Chromium. No backend: the app opens on 01 with nothing signed in.
// The build must have been made with BUILD_COMMIT=<40 times "a"> (run.sh).
'use strict';
const crypto = require('crypto');
const fs = require('fs');
const http = require('http');
const os = require('os');
const path = require('path');
const { chromium } = require('playwright');

// The commits of the deploys. The build under test was made with
// BUILD_COMMIT=<COMMIT_A> (tool/web_smoke/run.sh); the deploys carry their own.
const COMMIT_A = 'a'.repeat(40);
const COMMIT_B = 'b'.repeat(40);
const vercel = JSON.parse(fs.readFileSync(path.join(__dirname, '../../vercel.json'), 'utf8'));
const whole = (source) => new RegExp(`^${source}$`);

const build = path.resolve(process.argv[2] || 'build/web');
if (!fs.existsSync(path.join(build, 'main.dart.js'))) {
  console.error(`web-smoke: no build at ${build}`);
  process.exit(2);
}
if (!fs.readFileSync(path.join(build, 'main.dart.js'), 'utf8').includes(COMMIT_A)) {
  console.error(`web-smoke: the build was not made with BUILD_COMMIT=${COMMIT_A} (tool/web_smoke/run.sh)`);
  process.exit(2);
}

// Deploys of the same build, told apart by a line at the end of main.dart.js
// (`window.mvBuild`) and the commit compiled into it. B's service worker lists
// its main.dart.js with the new hash and its page a new worker version, as a
// real deploy that changed the app would: the worker updates and drops the
// old copy. `commit` is what /commit.txt says; `appCommit` the build id inside
// the app (C: a shell that is still the old build's under the new commit.txt).
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'web-smoke-'));
const md5 = (file) => crypto.createHash('md5').update(fs.readFileSync(file)).digest('hex');
function deploy(name, version, commit, appCommit = commit) {
  const dir = path.join(root, name);
  fs.cpSync(build, dir, { recursive: true });
  const main = path.join(dir, 'main.dart.js');
  fs.writeFileSync(main, fs.readFileSync(main, 'utf8').split(COMMIT_A).join(appCommit));
  fs.appendFileSync(main, `\n;window.mvBuild=${JSON.stringify(name)};\n`);
  fs.writeFileSync(path.join(dir, 'commit.txt'), `${commit}\n`);
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
deploy('A', '1111', COMMIT_A);
deploy('B', '2222', COMMIT_B);
deploy('C', '3333', COMMIT_B, COMMIT_A);

let current = 'A';
const documents = [];
const types = {
  '.js': 'text/javascript', '.mjs': 'text/javascript', '.html': 'text/html',
  '.json': 'application/json', '.wasm': 'application/wasm', '.webp': 'image/webp',
  '.png': 'image/png', '.ttf': 'font/ttf', '.otf': 'font/otf', '.txt': 'text/plain',
};
const server = http.createServer((req, res) => {
  const url = decodeURIComponent(req.url.split('?')[0]);
  const headers = { 'Cache-Control': 'public, max-age=0, must-revalidate' };
  for (const rule of vercel.headers || []) {
    if (whole(rule.source).test(url)) {
      for (const h of rule.headers) headers[h.key] = h.value;
    }
  }
  const redirect = (vercel.redirects || []).find((r) => whole(r.source).test(url));
  if (redirect) {
    res.writeHead(redirect.permanent ? 308 : 307, { Location: redirect.destination });
    return res.end();
  }
  const dir = path.join(root, current);
  let file = path.join(dir, url === '/' ? 'index.html' : url);
  const real = file.startsWith(dir) && fs.existsSync(file) && fs.statSync(file).isFile();
  if (!real) {
    const rewrite = (vercel.rewrites || []).find((r) => whole(r.source).test(url));
    if (!rewrite) {
      res.writeHead(404, { 'Content-Type': 'text/plain' });
      return res.end('NOT_FOUND');
    }
    file = path.join(dir, rewrite.destination);
  }
  if (path.basename(file) === 'index.html') documents.push(url);
  const body = fs.readFileSync(file);
  const etag = `"${crypto.createHash('md5').update(body).digest('hex')}"`;
  headers.ETag = etag;
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

// The tab comes back to the foreground: what Flutter turns into the app's
// resume (the page's visibility goes hidden, then visible).
async function resume(page) {
  await page.evaluate(() => {
    const set = (v) => {
      Object.defineProperty(document, 'visibilityState', { configurable: true, get: () => v });
      Object.defineProperty(document, 'hidden', { configurable: true, get: () => v === 'hidden' });
      document.dispatchEvent(new Event('visibilitychange'));
    };
    set('hidden');
    set('visible');
  });
}

async function liveBuild(page, want, ms = 30000) {
  return page.waitForFunction((b) => window.mvBuild === b, want, { timeout: ms }).then(
    () => true,
    () => false,
  );
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

    // 5b. A file that is not there looks missing; commit.txt names the build;
    // /app still redirects and app routes still get the page.
    const status = async (p, init) => (await fetch(`${url}${p}`, { redirect: 'manual', ...init }));
    const missing = await status('assets/assets/skins/shadow_paper/roles/werewolf.webp');
    check(missing.status === 404, `a made-up picture is a 404, not the page (${missing.status})`);
    const missingFile = await status('somewhere/else.png');
    check(missingFile.status === 404, `any made-up file with an extension is a 404 (${missingFile.status})`);
    const commit = await status('commit.txt');
    check(commit.status === 200 && (await commit.text()).trim() === COMMIT_B, '/commit.txt is the commit built');
    check(commit.headers.get('cache-control') === 'no-cache', '/commit.txt is never kept without asking');
    const route = await status('join/ABCD');
    check(route.status === 200 && (await route.text()).includes('flutter'), 'an app route still gets the app');
    const app = await status('app');
    check(app.status === 307 && /android-latest/.test(app.headers.get('location') || ''), '/app still redirects');
    const links = await status('.well-known/assetlinks.json');
    check(links.status === 200 && links.headers.get('content-type') === 'application/json', 'assetlinks.json is still served as JSON');

    // 7. A tab left open on A while B goes live (its worker registered, as an
    // old tab's is): resumed, it reloads itself for B (nothing typed, nothing
    // in flight, on 01), and the reload gets B, not the old worker's copy of A.
    const open1 = await browser.newContext();
    current = 'A';
    const tab = await open(open1, url, 'a tab left open on A');
    let held = false;
    for (let i = 0; i < 120 && !held; i++) {
      held = await tab.page.evaluate(async () => (await navigator.serviceWorker.getRegistration())?.active?.state === 'activated');
      if (!held) await tab.page.waitForTimeout(500);
    }
    check(held && tab.build === 'A', 'a tab on A, its worker registered');
    const before = documents.length;
    current = 'B';
    // (a resume asks again no sooner than 10 s after the last look)
    await tab.page.waitForTimeout(11000);
    await resume(tab.page);
    check(await liveBuild(tab.page, 'B'), 'an open tab on the old build reloads itself for the new one when resumed');
    check(documents.length - before === 1, `...with one reload (${documents.length - before} page requests)`);
    await open1.close();

    // 7b. No loop: a deploy whose commit.txt names a new build but whose shell
    // is still the old build (C). The tab reloads once and then leaves it.
    const stale = await browser.newContext();
    current = 'A';
    const old = await open(stale, url, 'open on A');
    check(old.build === 'A', 'a fresh tab on A');
    current = 'C';
    const mark = documents.length;
    await old.page.waitForTimeout(11000);
    await resume(old.page);
    await old.page.waitForTimeout(11000);
    await resume(old.page);
    await old.page.waitForTimeout(3000);
    const loads = documents.length - mark;
    check(loads >= 1 && loads <= 2, `a shell that stays old is reloaded for once, never in a loop (${loads} page requests)`);
    await stale.close();
    current = 'B';

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
