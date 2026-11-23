# Running the backend on Vercel

Status: **deployed and played end to end on 19 November 2026** (Vercel project
`midnight-village`, a preview deployment). See "Verified by the first deploy" and
"Still unverified" below. Everything here follows the facts measured on a throwaway
FastAPI project and Vercel's docs (Django ASGI + Channels WebSockets are supported).

## Why this needed changes

On Vercel the backend runs as short-lived function instances, several at once, started
and stopped at any time. Three things assumed one long-lived process and were replaced:

| Was | Is now |
|---|---|
| `threading.Timer`s in memory (`timers.py`) | **Durable timers**: a `ScheduledTimer` row per timer, fired by a Vercel Queue message |
| Socket **counts** zeroed at every process start | **Socket rows** with heartbeats; nothing is reset at start-up |
| `config/asgi.py` ran start-up recovery on import | Skipped for the queue backend (and `ONUW_RECOVER_TIMERS_ON_START = False`) |

Local development, the tests and the debug harness keep the `memory` backend
(`ONUW_TIMER_BACKEND = "memory"`, the default) and need no Vercel account.

## Which pushes deploy (and the daily cap)

Both projects build **only `main`**. `backend/vercel.json` and `frontend/vercel.json` carry
`"git": {"deploymentEnabled": {"main": true, "**": false}}`, so Vercel creates no deployment
for a push to any other branch (a branch matching several rules deploys if one is `true`, so
`main` still deploys). Each file sits in its project's Root Directory (`backend`, `frontend`).
`backend/vercel.json` holds nothing else: the backend's build still comes from
`pyproject.toml` and the dashboard.

* **Daily cap**: Vercel's Limits page lists 100 deployments created per day on Hobby (a
  86400 s window; once hit, wait for it to pass). Every deployment created counts, preview or
  production, on each project. Vercel's monorepo docs say builds canceled by an Ignored Build
  Step still count, which is why this uses `git.deploymentEnabled`, not `ignoreCommand`.
* **Going live** is a merge to `main`: one deployment per project.
* **A one-off preview** of a branch: run `vercel deploy` from a checkout linked to the project
  (the CLI creates the deployment itself). It still counts toward the cap, and the backend
  needs the new address in `ALLOWED_HOSTS`, so only when a preview is really wanted.

## Resources to create

1. **Postgres** (any provider; use the **pooled** connection string).
2. **Redis** for the Channels layer (`channels_redis`), e.g. Upstash / Vercel Marketplace.
3. **Vercel Queues** (the topic `onuw-timers` is created by publishing; subscriber below).

## Environment variables

| Variable | Notes |
|---|---|
| `DJANGO_SETTINGS_MODULE` | `config.settings.vercel` (the queue subscriber defaults to it; the ASGI app needs it set) |
| `SECRET_KEY` | required |
| `DATABASE_URL` | required, `postgres://user:pass@host:port/db` (pooled) |
| `REDIS_URL` | required (`rediss://...`) |
| `ALLOWED_HOSTS` | comma-separated. The settings add `VERCEL_URL` (the per-build address) and `VERCEL_PROJECT_PRODUCTION_URL` (one production domain) themselves; every OTHER address people use must be listed here, or Django answers "Bad Request (400)". Currently set on the project: `midnight-village-anthelion.vercel.app`, `midnight-village-api.vercel.app`, `midnight-village-git-main-anthelion.vercel.app` and the app's own host `midnight-village-app-anthelion.vercel.app` (it must stay: the socket origin check uses this list); a dead working-branch alias, `midnight-village-git-ccr-2435dc07-33z3jn-anthelion.vercel.app`, is still set and is to be removed. A custom domain needs adding, and the change only applies to the next build. |
| `CORS_ALLOWED_ORIGINS` | comma-separated origins of the app (answers to them expose the `Date` header: `CORS_EXPOSE_HEADERS` in the base settings, not an env var) |
| `CSRF_TRUSTED_ORIGINS` | comma-separated (admin only) |
| `DB_CONN_MAX_AGE` | optional, default `0` (do not hold connections between requests) |
| `DB_SSLMODE` | optional, default `require` |
| `ONUW_TIMER_QUEUE_TOPIC` | optional, default `onuw-timers` |
| `CRON_SECRET` | shared secret of the timer sweep endpoint (`Authorization: Bearer ...`); unset = the endpoint refuses everything |

No secrets live in the repo. `DEBUG` is forced off, so the debug harness endpoints
(forced assignment, oracle, fire-timer) answer 403.

## Files

* `backend/config/settings/vercel.py`: the settings above, `ONUW_TIMER_BACKEND = "vercel_queue"`.
* `backend/pyproject.toml`: `vercel-queue` is a normal dependency, so the build installs it;
  `[tool.vercel.scripts] build` runs `migrate` on every build; and
  `[[tool.vercel.subscribers]] entrypoint = "apps.core.queue_worker"`.
* `backend/apps/core/queue_worker.py`: the subscriber (`@subscribe(topic="onuw-timers*")`).
* Migrations to run on deploy: `python manage.py migrate --noinput` (core 0006, 0007;
  onuw 0004, 0005, 0006, 0007).

## How timers work

A timer is a named job with JSON params (`night_window`, `discussion_deadline`,
`voting_deadline`, `grace_expired`, `host_handover`, `presence_check`) due at a time.

1. `timers.schedule(key, delay, job, params)` (always after the DB commit) upserts the
   `ScheduledTimer` row with a **fresh random token** and publishes `{key, token}` with
   `delay` (rounded up to whole seconds, so a message is never early).
2. When a message arrives, `timers.fire(key, token)` locks the row and runs the job only if
   the row still exists **with that token** and is due (2 s of clock skew tolerated). It
   deletes the row in the same transaction. So: a **stale token** (the timer was
   rescheduled), a **cancelled key** (row deleted; a queued message cannot be cancelled), or
   a **duplicate delivery** (at-least-once) does nothing, and two instances cannot both run
   it. The job's own phase / window checks are a second guard.
3. A message that arrives early beyond the skew tolerance is re-sent with the remaining
   delay instead of running early.
4. **A failing job keeps its timer.** Every job logs and re-raises, so `fire` rolls back
   and the row survives. The worker then raises the SDK's `RetryAfter(15)` (up to 5
   deliveries, by `message.metadata.delivery_count`); after that it drops the message and
   the row waits for the sweep. (Memory backend: retried after 5 s, at most 5 attempts.)
5. **Lost publications.** The row stores `published_at`, set only after the send returned.
   A row unpublished for more than 5 s (the instance died between the row and the send, or
   the send failed) does not count as scheduled, so the lazy repair re-publishes it
   (`GET /me/` calls `ensure_timers` and then `timers.sweep` for that game's keys). The sweep
   also re-sends, with the SAME token (a duplicate is harmless: only one claim runs), rows
   more than 5 s past due whose message evidently never ran, at most every 30 s per row.
6. **Cron.** `GET` or `POST /api/onuw/internal/sweep-timers/` sweeps every timer. It
   answers 403 unless `Authorization: Bearer <CRON_SECRET>` matches the `CRON_SECRET`
   environment variable (Vercel Cron sends exactly that header on its GET); with no secret
   configured it always refuses. Vercel Cron's minimum interval depends on the plan (hobby
   plans are limited to daily runs), so the lazy repair on `GET /me/` is the primary
   repair and the cron is a backstop for games nobody is polling. NOTE (open): the cron
   entry itself (the `crons` of a vercel.json) is not in the repo.
7. **One clock.** `due_at`, `last_seen`, the staleness cutoff and every due / freshness
   comparison use the database clock, so instances with skewed clocks agree on who is
   connected and what is due.
8. A night that was committed but never opened (instance died between creating the game
   and opening its first window) cannot happen on start any more: the first window opens
   in the same transaction as the game. A legacy / crashed one is opened by the next
   `GET /me/` once it is 15 s old.

Nothing stays in the process, nothing is re-armed at import, and `recover_timers` /
`run_startup_recovery` are never run under this backend.

### Measured queue lateness

Measured on a throwaway FastAPI project: 30 messages with delays of 1 to 30 s arrived
**0.18 to 0.30 s late when warm and up to 1.0 s late on a cold start**. Effects:

* Deadlines close up to ~1 s after the stored `phase_deadline` (clients show the stored
  deadline). The lateness is the same for every player; no player's action changes it.
* The Doppelganger window is one message of exactly `night_doppelganger_window_seconds`
  whatever she did (one `night_window` message per window; her look and follow-up never
  reschedule it), so its length still says nothing about her under either backend.
* The deferred minimum-length close is a message too; it re-checks readiness when it fires.

## How presence works

One row per open socket (`SocketPresence` for a game socket, `LobbySocket` for a lobby socket: user, game or lobby, unique `channel_name`,
`connected_at`, `last_seen`). The consumer inserts it on connect, deletes it on a clean
disconnect, and refreshes `last_seen` every 15 s (`ONUW_PRESENCE_HEARTBEAT_SECONDS`; each
beat is a short DB call that releases its connection). A user is **connected** while a row
was seen within 40 s (`ONUW_PRESENCE_STALE_SECONDS`).

**Silent deaths** (an instance is killed and never runs `disconnect`): when a row is created
or refreshed a durable `presence_check` timer is ensured for that user and scope, due at
`last_seen + 40 s`. A heartbeat does not write it; when it fires early it re-arms itself, so
about one timer write per 40 s per socket. When it fires and the user has no fresh row it
deletes the stale rows and runs exactly the clean-disconnect code path (the
`player_presence` event, the grace timer, the host handover clock). The grace period and the
handover period count from the moment the death is noticed (so up to ~40 s after the last
heartbeat, then the usual 25 s / 60 s).

WebSocket connections close when the function reaches its max duration; the app already
reconnects, which is a normal disconnect + connect to the presence rows.

## Single process still assumed anywhere?

Under `vercel_queue`: nothing. Under `memory` (dev, tests, harness, `just dev`): exactly one
process, because its timers are threads in that process.

## Verified by the first deploy

A three-player game was played against a preview deployment over the real API and
WebSockets (guests, lobby, deal, night, talk, vote, results, play again):

* Vercel finds the ASGI app from `ASGI_APPLICATION` with the Django framework preset and
  `backend` as the root directory; no `[tool.vercel] entrypoint` is needed.
* The subscriber is found from `[[tool.vercel.subscribers]]`. Its handler must take an
  UNTYPED message (`Message[Any]`): a bare `dict` is rejected at build time and a typed
  payload needs pydantic.
* `vercel-queue` must be a normal dependency (the build does not install extras).
* `[tool.vercel.scripts] build = "python manage.py migrate --noinput"` runs at build time
  with database access; the build then runs `collectstatic` itself.
* The Marketplace stores set `DATABASE_URL` (pooled Neon) and `REDIS_URL` (Upstash) under
  exactly those names.
* Timers through the queue: a 12 s night window closed 12.5 s after the deal and a 15 s
  talk ended 15.5 s later; the topic name matches the `onuw-timers*` pattern.
* Lobby and game sockets connect (JWT in the query string), presence events arrive, and
  events fan out to every player through Redis.

Deployment Protection is on for every non-custom domain, so phones cannot reach a preview
URL without signing in to Vercel. A custom domain, or changing that setting, is needed
before real players can use it.

## Still unverified

* Behaviour at the function's maximum duration (a socket being closed and reconnecting
  mid-game), and a silent socket death noticed through the presence check.
* A deck with the Doppelganger (the fixed first window) and a dropped player's grace period.
* The maximum queue delay (the longest timer is the 3600 s phase limit).
* The timer sweep cron: no `crons` entry exists yet, and the minimum interval depends on
  the plan.
* Cold-start cost after a long idle period, and many tables at once.
* The app on a real phone and in a real browser against the live server (the server side is played end to end; the app screens are not yet).

## The app (web and Android)

* **Web**: its own Vercel project `midnight-village-app` (root `frontend`, build `bash tool/vercel_build.sh`, output `build/web`, `frontend/vercel.json` sends every path to `index.html`, so a table's link, `<origin>/join/<code>`, opens the app on a cold load; the app uses the path URL strategy, no `#`). Vercel's builders have no Flutter, so the script fetches the pinned version and builds with `--dart-define=ENV=prod --dart-define=API_ORIGIN=<server origin>`. Flutter's service worker (offline-first, Flutter 3.38's default) serves repeat visits from its cache. `web/flutter_bootstrap.js` is inlined in `index.html`, which the worker always fetches from the network first, so the page always knows the deployed build. A first visit loads at once and registers the worker only once the app's own start is in (01's picture and the secrets' art, `lib/core/web/start_done_web.dart`), never waiting for it; that visit is not cached by it, so the first return still revalidates its files. A returning phone after a deploy has Flutter's loader update the worker before the app loads, for at most 4 s: if the new worker is in within that, the phone runs the new build on that first open; if not (a slow line), the old worker still serves the cached app for that one open, and the next open runs the new build. `just web-smoke` (`frontend/tool/web_smoke/`, CI job "Web page smoke") builds the page twice and checks a first visit, a return and a deploy in Chrome. **Upgrading Flutter.** From 3.41 Flutter drops this worker (flutter/flutter#156910): the page then needs long cache headers on hashed files (`--web-content-hash`) in `frontend/vercel.json` instead. Any upgrade that changes the engine has one more risk: a phone whose worker update misses the 4 s runs the NEW inlined bootstrap (new engine revision, new CanvasKit) with the OLD cached `main.dart.js` for that one open, which can fail to start; the next open is the new build. Check that case with `just web-smoke` and a slow `main.dart.js` before shipping an engine change. `API_ORIGIN` is a project environment variable (currently `https://midnight-village-anthelion.vercel.app`). Production address: `https://midnight-village-app-anthelion.vercel.app`; production branch `main`.
* **The server must know the app's address**: add its host to `ALLOWED_HOSTS` (the socket origin check uses it) and its origin to `CORS_ALLOWED_ORIGINS` on the server project; both are set for the address above. A new app address needs both, then a server redeploy.
* **The toolbar**: a build with no `ENV` is prod and has no `/debug` toolbar; dev is explicit (`--dart-define=ENV=dev`, which the just recipes, the harness and CI pass). `tool/vercel_build.sh` also runs `tool/check_release_has_no_debug.sh` on `build/web` and fails the deploy if the toolbar is in it.
* **Android** (sideloaded APK): `API_ORIGIN=<server origin> PUBLIC_ORIGIN=<web app origin> tool/build_android.sh` (`just build-android` in `frontend/`), which runs `flutter build apk --release --split-per-abi --dart-define=ENV=prod --dart-define=API_ORIGIN=... --dart-define=PUBLIC_ORIGIN=...` with the Android SDK (platform 36, build-tools 36.0.0) installed and `ANDROID_HOME` set. The web app's production origin is `https://midnight-village-app-anthelion.vercel.app` (above). The main manifest declares INTERNET (Flutter adds it only to the debug manifest); the scanner's plugin adds CAMERA.
  * **Which file to hand out:** the workflow publishes the arm64 one ("Android app download", below); by hand it is `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (nearly every phone since 2017). `app-armeabi-v7a-release.apk` is for old 32-bit phones and `app-x86_64-release.apk` for emulators. They are split by processor because one universal APK holds all three and is about 72 MB (sizes of each: see the build's own listing; the script prints them).
  * **`PUBLIC_ORIGIN` is required for a release build.** Without a public https origin the app would draw no QR code and share no link, so the build stops, saying what to pass: the script checks both origins first (`PUBLIC_ORIGIN` is an origin only, no path, query or fragment: the manifest opens `<host>/join/` links, which a path would put out of reach), and `android/app/build.gradle.kts` stops any release task whose `--dart-define=PUBLIC_ORIGIN` is missing, not https or has a path (debug builds and tests are not affected: they need none).
  * **The signing key is public, on purpose** (owner's decision, 22 November 2026: "Just put it in the repo ... App is not being sent to the play store yet. Custom installs only. We'll rotate it when publishing"): `frontend/android/release-key/` (keystore, `key.properties`, README). Release builds sign with it; anyone can sign an app with it; **replace it with a private key kept as a build secret before any store release.** The app id is unchanged (`com.midnightvillage.midnight_village`). An APK signed with the old debug key does not update in place (Android refuses a new key over an old one), so anyone with an older APK **uninstalls once**.
  * **Table links open the installed app** (Android App Links): the manifest's `https://<PUBLIC_ORIGIN host>/join/` intent filter (`autoVerify`; the host comes from the same `PUBLIC_ORIGIN`, never written in the manifest) and the web app's `/.well-known/assetlinks.json` (`frontend/web/.well-known/`, served as application/json by `vercel.json`) naming the package and the key's SHA-256 (`09:0C:3F:15:6B:0D:B8:95:43:A1:FB:8C:80:AD:45:07:27:34:C5:2B:CB:B6:7B:89:68:A6:4D:2F:F7:E6:3B:A7`; a test fails if the file and the key disagree). The file holds no origin: it is the same for any host that serves it. Android checks it when the app is installed; with the app not installed (or not verified) the link opens in the browser, which is the web app. A new web origin needs an APK built with its `PUBLIC_ORIGIN`.
  * **The scan action** (01 "Join a table") uses the camera inside the app: Android through CameraX and ML Kit (the `mobile_scanner` package, BSD-3; the barcode model is bundled in the APK, so no Play services download), the web through the browser's `getUserMedia`, which needs https (localhost counts) and the player's permission. Browsers with a built-in barcode detector (Chrome on Android, Safari 17 and later) decode natively. The others (Firefox, Safari before 17, desktop Chrome on Windows and Linux) load a decoder, zxing-wasm 3.1.6 (MIT; about 40 KB of script and a 947 KB .wasm), **from the app's own files** `web/zxing/` the first time the scanner opens: nothing from a CDN, no third-party request. The pin, the licence and how it was made: `frontend/tool/zxing_wasm.sh` (`--check` verifies it). The web app's own `main.dart.js` grows by 93 KB (27 KB gzipped) for the scanner. Refused, no camera or an insecure page: one line and typing.
* **Deployment Protection is off on both projects** so phones need no Vercel login.

## Android app download

Friends get the app from one stable address; nobody builds or hands out a file by hand any more.

* **How it is built:** the workflow `.github/workflows/android-download.yml` ("Android App Download") runs on every push to `main` that touches `frontend/**` and on manual dispatch ("Run workflow"). It runs `frontend/tool/build_android.sh` with `API_ORIGIN=https://midnight-village-anthelion.vercel.app` and `PUBLIC_ORIGIN=https://midnight-village-app-anthelion.vercel.app` (Flutter 3.38.10, Java 17, the runner's Android SDK), signed with the public key in `frontend/android/release-key/`.
* **Where it goes:** the arm64 APK (nearly every phone since 2017; the script builds one APK per processor, so no universal one) is uploaded as `midnight-village.apk` to one rolling GitHub release, tag `android-latest`, replacing the previous file (uploaded under a temporary name, retried, then the old asset is deleted and the new one renamed through the REST API, so the release is never without a file; only from `main`; the release notes name the commit it was built from). The release is created on the first run, marked not "latest".
* **The address:** `https://github.com/doodla/midnight-village/releases/download/android-latest/midnight-village.apk` (the repository is public). The web app's short address `https://midnight-village-app-anthelion.vercel.app/app` redirects there (`redirects` in `frontend/vercel.json`, a temporary 307, answered before the single-page rewrite; the app's router has no `/app`). The web app's first screen (01) shows a quiet "Get the app" link that opens `/app`, only in an Android browser.
* **First merge:** the link on 01 exists about ten minutes before the first file does (the build has to finish); until then it leads to a not-found page.
* **Not a check:** it never runs on pull requests and is not in `docs/dev/main-ruleset.json`; it has `contents: write` on its one job only. A failed build does not block anything; the previous file stays. `guardrails/tests/test_workflows.py` holds it to those rules.
* **Untested until the first run on `main`:** the workflow itself (it cannot run off GitHub); check the Actions tab after the first merge that touches `frontend/`, and that the asset downloads. Anyone with an older APK signed with another key uninstalls once (above).

## The check after each merge

Nobody watches deployments by hand. After every merge to `main` the workflow
`.github/workflows/deployed-check.yml` ("Deployed Check") runs `tool/deployed_check.py`
against the two live addresses, from outside, with no account and no secret:

1. **Waits for the merged commit** (up to 15 minutes): the server's `/api/health/` names the
   commit its build was made from (`commit`, Vercel's `VERCEL_GIT_COMMIT_SHA`) and the app
   serves `/commit.txt` (written by `frontend/tool/vercel_build.sh`). Until both name the
   merged commit, the previous build is still live and there is nothing to prove yet.
2. **Health** answers JSON.
3. **The app and its server**: the page loads, its bundle names the server origin, and the
   server lets the app's origin call it (a CORS preflight).
4. **A real Start and Join**: guest A is made, opens a table, guest B joins by its code, both
   read the table and see two players. Every answer must be JSON with the expected status.
5. **Both leave, always**, also when a step failed or its answer was lost: each guest asks the
   server where it sits and leaves that table; the last one out deletes it.

**What it leaves in the live database**: two guest accounts per run, named `Deploy check A`
and `Deploy check B`. They open no socket, so they never count in "N at tables". Nothing
prunes them yet (to do with the server cleanups: guests with those names older than a day).

**When it fails**: the run "Deployed Check" is red on `main` (the Actions tab; GitHub emails
whoever's merge started the failed run). The log has one line per step, `ok` or `FAIL`
with what answered. A failure means players may be looking at a broken game: read the line,
and roll back in Vercel (the owner's account) or revert the merge. A newer merge cancels an
older run that is still waiting. By hand: "Run workflow" on `main`, or locally
`python3 tool/deployed_check.py --api <server origin> --app <app origin>`.

**What it proves that "Web page smoke" does not.** "Web page smoke" builds the page and opens
it in Chrome against no server: it never makes a request through Vercel's own routing. On 22
November 2026 a routing change (#66) passed every check and broke the live app for about
half an hour, because API calls got the app's page back. No check that runs before the merge
can see the deployed routing; this one makes real requests through it, minutes after.

**What it does not prove**: a whole game (the deal, the night, timers through the queue,
sockets through Redis). Start and Join only.

`backend/tests/core/test_deployed_check.py` runs the same script against a local server on
every pull request, so a change to the guest, table, join or leave answers that would break
the check fails before the merge.

## Deploy-safe changes

The previous code serves while `migrate` runs on every deploy (every deployment of `main` builds and migrates the shared database). Checked by tests and `just check`, not by habit:
- **Migrations are frozen once pushed.** Every push migrates the live database; to change the schema again, add a NEW migration, never edit a pushed one. `just check` runs `makemigrations --check --dry-run` (a model change without its migration fails the gate and CI).
- **No application code in a migration** (no `from apps...`): copy what it needs, frozen. `tests/test_migration_rules.py` scans every migration file.
- **`SET LOCAL lock_timeout = '5s'` is the first operation** of every migration from 0010 on (same test), so an ALTER that cannot get its lock fails the build instead of blocking the live site behind it.
- **Every new NOT NULL column has a `db_default`** (and a Python `default`), because the old code's INSERTs omit it. A backfill touches only what it must (finished tables stay blank) and new code treats a blank value as "not backfilled yet" (a blank token is filled at the deal).
- **A column is removed in two pushes.** The previous code's model still has the field, so every INSERT it makes names the column: drop it in one push and those INSERTs fail from the migration until the new build is promoted (every join, for `LobbyMember`). Push 1: take the field out of the model with `SeparateDatabaseAndState` (state only) and give the column a database default, so both builds can write (`core/migrations/0011_lobbymember_is_ready_left_to_the_database.py` is the pattern, with its test). Push 2, once push 1 is live: drop the column. After push 2 a rollback to a build from before push 1 cannot write that table: roll forward instead.
- **The migration test gains a case per migration.** `tests/test_migrations.py` (marker `migration`) applies the REAL migrations (the rest of the suite uses `--nomigrations`, where these tests skip), seeds old-shape rows through the historical models, migrates forward, asserts, runs the old code's INSERTs (`tests/old_code.py`, never add columns to them), then back and forward again. `just test` runs it as a second pass (`just test-migrations`, about 5 s); CI runs `just test`.
- **A new socket event type reaches instances that have no handler:** consumers extend `core.consumers.TolerantJsonWebsocketConsumer`, which logs an unknown type at WARNING and drops it (and raises when `ONUW_STRICT_SOCKET_EVENTS` is true: test, development and harness settings, so a misspelled type in new code still fails the suite).
- **Rolling back past practice players** (code without `apps/core/practice.py`) while practice tables exist: the old handover and owner-leaving code does not skip them, so it could hand a table to a practice account (and the old app would show them as people). Before such a rollback, close those tables (every `LobbyMember` whose username starts with `practice-`).
