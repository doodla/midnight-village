# Backend: Midnight Village

Django 5, DRF, Channels, Postgres, managed with `uv`. Game rules: `docs/specs/onuw/`. What
the code does, endpoint by endpoint: `apps/onuw/README.md` (the night, voting,
look stage, results, decks) and `apps/core/README.md` (timers, presence, host handover, play
again, tokens, where am I). Tests: `tests/README.md`. Read the README of the part you change,
and keep it true.

## Commands

```bash
just test                       # pytest, then the migration tests (second pass)
just test tests/onuw/test_x.py  # one file (first pass only)
just test tests/onuw/test_x.py -v  # with each test's name (the run is quiet by default)
just check                      # ruff lint + format-check, pyrefly, makemigrations --check
just fix                        # auto-fix lint and format
just samples                    # re-record contract_samples/ after a payload change
just harness-serve              # DEBUG backend for the e2e harness ($HARNESS_PORT, else a free port)
```

Set up with `tool/setup_env.sh <db_name>` (or `just install`): never `uv sync --all-extras`,
never `.env.example` copied as is. `backend/.env` holds your own `DB_NAME` and never
`DJANGO_SETTINGS_MODULE` (it makes the tests run under dev settings). `docs/dev/environment.md`.

## Deploy-safe changes

The server is live: every push migrates the shared database while the previous code still
serves. Full rules: `docs/dev/deploy-vercel.md`, "Deploy-safe changes". In one line each:

- Never edit a pushed migration; add a new one. `just check` fails a model change without one.
- No `from apps...` in a migration; copy what it needs.
- `SET LOCAL lock_timeout = '5s'` is the first operation of every migration from 0010 on.
- Every new NOT NULL column has a `db_default` and a Python `default`.
- GitHub proves it: when a change has a migration, "Backend Checks" runs the previous
  build's tests on the migrated database (`just previous-build-check`).
- A column is removed in two pushes: first the model stops naming it and the database gets a
  default (state-only removal), then a later push drops it.
- Every migration gets a case in `tests/test_migrations.py`; never add columns to the old
  code's INSERTs in `tests/old_code.py`; a backfill touches only what it must.
- Socket consumers extend `TolerantJsonWebsocketConsumer`, so old instances drop a new event type.

## Rules that have bitten

- **Hidden information in errors.** A refusal never depends on the role: generic messages and
  codes (`bad_request`, `wrong_stage`, ...), never "Seer cannot do that". Targets are plain
  JSON integers; anything else is 400, never coerced.
- **Lock before you check.** Every state change locks the Game row (`select_for_update()`),
  then re-checks phase and stage, then the PlayerRole. Lock order: Game, PlayerRole, Lobby,
  LobbyMember.
- **Side effects after commit.** Socket sends and timer schedule/cancel go through
  `transaction.on_commit`; build payloads inside the transaction. Tests must capture
  on-commit callbacks (`tests/README.md`).
- **Dealt card decides who wakes**, the held card decides who wins.
- **A sample diff is a behaviour change.** Review every changed contract sample after
  `just samples`; a change the task did not ask for is a bug to fix, not to regenerate.
- **No waits beyond the table's settings.** The night's minimum window and the Doppelganger's
  fixed window are the table's own settings; add no other delay, minimum or assumed default
  length. A stage ends once everyone present has done their part; at night that is
  every phone with a choice (a sleeper is never waited for; a dropped actor holds the window
  through its grace period); window 1 keeps the table's fixed length.
- **Database clock.** Due times, heartbeats and freshness use `Now()`, never an instance clock.
- **WebSocket tests need an authenticated scope**; unauthenticated sockets are rejected
  silently.
- **Throttle rates live in test settings**; without them guest sign-up tests fail with 429s.
- **One process for the memory timer backend** (dev, tests, harness): its timers are threads.
- **Timers in tests**: an autouse fixture makes `timers.schedule` a no-op; `make_night`
  records callbacks you call to run the job; real rows and threads need
  `@pytest.mark.uses_timers` (`tests/README.md`).

## Contract samples

`contract_samples/` is recorded from the real API by `tests/contract/scenarios.py`; the suite
fails while the committed files differ. A new endpoint or situation is a `table.record(...)`
line there, then `just samples`; review the diff. Detail: `tests/README.md`.

## Adding things

- **A role** touches `apps/onuw/engine/roles.py`, `behaviors.py`, `night.py`,
  `win_conditions.py` if it changes the win, `apps/onuw/serializers.py` if it displays
  differently, and tests for each: the type checker will not catch a missed one.
- **A Django app**: `name = "apps.myapp"` in its `AppConfig` (the prefix is easy to forget),
  add it to `INSTALLED_APPS` in `config/settings/base.py`, tests under `tests/<app>/`. A game
  plugs into core through `apps/core/games.py` (`GameHooks`); core imports no game app.

## Debug harness

DEBUG-only endpoints (forced deal, `debug-state` oracle, `debug-fire-timer`; 403 in
production) live in `apps/onuw/debug.py` and `debug_views.py`. `tools/game_driver.py` drives a
whole game through them. Docs: `docs/dev/debug-harness/`.

The commit gate is git's own hooks in
`.claude/hooks/git/` (`docs/claude-architecture.md`). For backend changes it runs `just check`
only (seconds). GitHub runs `just check` and `just test` (coverage floor, contract samples
current, migration tests) on every pull request and merges nothing on red; `just gate-full` runs
them locally.
