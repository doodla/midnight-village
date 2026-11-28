# Vercel's two scripts, as the live app's host served them

`speed-insights.js` is `/_vercel/speed-insights/script.js` (Speed Insights, script
version 0.1.3) and `insights.js` is `/_vercel/insights/script.js` (Web Analytics, 0.1.3),
fetched from the web app's production host on 27 November 2026. They are built from
Vercel's MIT-licensed packages `@vercel/speed-insights` and `@vercel/analytics`.

`frontend/tool/web_smoke/smoke.cjs` serves them at those paths so the smoke can check, in a real
browser, what they send for a table's link: the route pattern (`/join/[code]`), never the
code (`frontend/lib/core/perf/vercel_insights_web.dart`). When Vercel changes its scripts, fetch
them again from the live host and run `just web-smoke`.
