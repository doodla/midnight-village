# Development environment

What a checkout needs before `just check` and `just test` pass. The cloud container has no
setup script (the proposal was declined), so a fresh container is set up by hand.

## Tools (once per container)

- `just`: `uv tool install rust-just`.
- Flutter **3.38.10**, unpacked to `/opt/flutter` and linked into `/usr/local/bin`.
- Postgres 16 with user and password `postgres`/`postgres`. After a container restart it is
  down: `service postgresql start`.
- `java` only to run the TLA+ models (`docs/dev/models/`; TLC is not in the repository).

## Each checkout or worktree

```bash
tool/setup_env.sh <db_name>
```

It starts Postgres, writes `backend/.env` from `backend/.env.example` (or fixes the existing
one) with that `DB_NAME` and without `DJANGO_SETTINGS_MODULE`, turns on the commit gate
(`.claude/hooks/session-start.sh`: `core.hooksPath` = `.claude/hooks/git`, shared by every
worktree of the clone; the same script runs at the start of every Claude session), then runs
`just install` in `backend/` and `flutter pub get` in `frontend/`.

- **One database per checkout.** Parallel agents each work in their own worktree with their
  own `DB_NAME` (pytest creates `test_<DB_NAME>`); two checkouts on one name break each
  other's runs.
- **`DJANGO_SETTINGS_MODULE` never goes in `backend/.env`**: it makes the tests run under the
  development settings.
- **Harness runs go side by side**: `just test-harness` and `just harness-serve` each take
  `HARNESS_PORT`, or a free port they pick (harness-serve prints it), and the test-harness run
  stops only the backend it started (its own process group, a hard kill after 5 s). They share
  the database `midnight_village_harness`; one migrates it at a time.
- **Timing tests fail falsely under load** (for example
  `test_a_scheduled_job_runs_after_the_delay_with_its_params` in the timers tests): re-run on a
  quiet machine before believing the failure.

## The web integration test in the cloud container

`just test-integration-ci` (in `frontend/`) drives `integration_test/auth_flow_test.dart` in headless Chrome through `flutter drive`, which needs a
chromedriver of Chrome's own version listening on port 4444. CI installs both
(`.github/workflows/flutter-tests.yml`). In the cloud container (20 November 2026) Chrome
is Chrome for Testing 153.0.8010.12 (`/opt/pw-browsers/chromium-1243/chrome-linux64/chrome`,
also `/usr/bin/google-chrome`) but the only chromedriver is 147.0.7727.24
(`/opt/node-tools/node_modules/chromedriver/`), which refuses it. The matching driver is
`https://storage.googleapis.com/chrome-for-testing-public/153.0.8010.12/linux64/chromedriver-linux64.zip`
(it downloads); with it: start `chromedriver --port=4444`, then
`CHROME_EXECUTABLE=/opt/pw-browsers/chromium-1243/chrome-linux64/chrome just test-integration-ci`.
An agent session may not run a downloaded binary, so it is not run there.
