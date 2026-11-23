// Judges frontend/vercel.json as Vercel will act on it (routes.cjs compiles it
// with Vercel's own `@vercel/routing-utils`). `node --test tool/web_smoke/`;
// run by `just web-smoke` before the build, in the "Web page smoke" job.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const { compile, resolve } = require('./routes.cjs');

const routes = compile();
// The files a build has: the shell, the code, a picture, the commit.
const files = new Set([
  '/index.html', '/main.dart.js', '/commit.txt', '/flutter_bootstrap.js', '/favicon.png',
  '/manifest.json', '/assets/AssetManifest.bin.json',
  '/assets/assets/skins/shadow_paper/roles/werewolf_lunge.webp',
  '/canvaskit/canvaskit.wasm', '/.well-known/assetlinks.json',
]);
const get = (url) => resolve(routes, url, (p) => files.has(p === '/' ? '/index.html' : p));

test('every app route the app opens at is served the app', () => {
  for (const url of ['/join/ABCD', '/join/K7QX4M', '/join/ABCD/', '/lobby/K7QX4M', '/game/12', '/debug', '/app/x']) {
    assert.deepStrictEqual(get(url).file, '/index.html', url);
  }
  assert.strictEqual(get('/').file, '/', 'the front page is the file index.html itself');
});

test('a file that is not there is a 404, never the app (a removed picture)', () => {
  for (const url of [
    '/assets/assets/skins/shadow_paper/roles/werewolf.webp',
    '/assets/anything',
    '/assets/nope.webp',
    '/somewhere/else.png',
    '/main.dart.js.map',
    '/canvaskit/gone.wasm',
  ]) {
    assert.strictEqual(get(url).notFound, true, url);
  }
});

test('files that are there are served as they are', () => {
  for (const url of ['/main.dart.js', '/commit.txt', '/assets/assets/skins/shadow_paper/roles/werewolf_lunge.webp']) {
    assert.strictEqual(get(url).file, url, url);
  }
});

test('/app redirects to the Android download, before anything else', () => {
  const { redirect } = get('/app');
  assert.strictEqual(redirect.status, 307);
  assert.match(redirect.location, /^https:\/\/github\.com\/.*\/android-latest\/midnight-village\.apk$/);
});

test('the shell and the code are revalidated on every load; pictures are not', () => {
  for (const url of ['/', '/index.html', '/join/ABCD', '/main.dart.js', '/commit.txt', '/flutter_bootstrap.js']) {
    assert.strictEqual(get(url).headers['Cache-Control'], 'no-cache', url);
  }
  for (const url of ['/assets/AssetManifest.bin.json', '/canvaskit/canvaskit.wasm']) {
    assert.strictEqual(get(url).headers['Cache-Control'], undefined, url);
  }
});

test('the Android link file is served as JSON', () => {
  const answer = get('/.well-known/assetlinks.json');
  assert.strictEqual(answer.file, '/.well-known/assetlinks.json');
  assert.strictEqual(answer.headers['Content-Type'], 'application/json');
});
