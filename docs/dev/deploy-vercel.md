# Running the backend on Vercel

Status: **deployed and played end to end on 19 November 2026** (Vercel project
`midnight-village`, a preview of the working branch). See "Verified by the first deploy" and
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
| `ALLOWED_HOSTS` | comma-separated; `VERCEL_URL` and `VERCEL_PROJECT_PRODUCTION_URL` are added automatically |
| `CORS_ALLOWED_ORIGINS` | comma-separated origins of the app |
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
   entry itself (`vercel.json` `crons`) is not in the repo.
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
* The Flutter app is not deployed anywhere yet, and `CORS_ALLOWED_ORIGINS` is empty.
