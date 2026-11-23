// What Vercel does with a request, read from frontend/vercel.json the way
// Vercel reads it: the file is compiled by Vercel's own `@vercel/routing-utils`
// (`getTransformedRoutes`, the step its build runs), and the compiled routes are
// walked in its order: the redirects and headers that come first, then the
// files, then the rewrite (checked against the files again), else a 404.
// Used by the smoke test's server and by routes.test.cjs, so what they judge is
// what Vercel will do, never a hand-read of the `source` patterns.
'use strict';
const fs = require('fs');
const path = require('path');
const { getTransformedRoutes } = require('@vercel/routing-utils');

function compile(file = path.join(__dirname, '../../vercel.json')) {
  const config = JSON.parse(fs.readFileSync(file, 'utf8'));
  const { routes, error } = getTransformedRoutes({
    redirects: config.redirects,
    rewrites: config.rewrites,
    headers: config.headers,
  });
  if (error) throw new Error(`vercel.json does not compile: ${JSON.stringify(error)}`);
  return routes;
}

/// The answer to a GET of [url]: `{ redirect: {status, location} }`, or
/// `{ file }` (a path of the build, served as it is, or the page the rewrite
/// names), or `{ notFound: true }`; always with the `headers` the routes add.
/// [exists] says whether a path is a file of the build.
function resolve(routes, url, exists) {
  const headers = {};
  let at = url;
  for (const route of routes) {
    if (route.handle === 'filesystem') {
      if (exists(at)) return { file: at, headers };
      continue;
    }
    if (route.handle) continue;
    const match = new RegExp(route.src).exec(at);
    if (!match) continue;
    Object.assign(headers, route.status ? {} : route.headers || {});
    if (route.status && route.headers && route.headers.Location) {
      return { redirect: { status: route.status, location: route.headers.Location }, headers };
    }
    if (route.dest) {
      at = route.dest;
      if (!route.check || exists(at)) return { file: at, headers };
      return { notFound: true, headers };
    }
    if (!route.continue) break;
  }
  return { notFound: true, headers };
}

module.exports = { compile, resolve };
