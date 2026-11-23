# Development environment

What a checkout needs before `just check` and `just test` pass.

## A fresh cloud container: one command

```bash
tool/bootstrap_container.sh
```

It installs the tools below, starts Postgres, sets its password and runs `tool/setup_env.sh`
(about three minutes; safe to run again). Without it a fresh container cannot build or test
the app, and the commit gate refuses any commit that needs the frontend checks. The cloud
environment has no setup script of its own yet: the owner can only approve one at a computer
(asked 22 and 23 November 2026). At every session start `.claude/hooks/session-start.sh`
starts Postgres if it is installed and down.

## Tools (what the command installs)

- `just`: `uv tool install rust-just`.
- Flutter **3.38.10**, unpacked to `/opt/flutter` and linked into `/usr/local/bin`.
- Postgres 16 with user and password `postgres`/`postgres` (the image has Postgres; the
  password is set by the command). After a container restart it is down: the session-start
  hook starts it, or `service postgresql start`.
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

- **Every test run has its own database**: pytest builds `test_<DB_NAME>_<process id>`
  (`backend/config/test_database.py`), so two runs side by side, in one checkout or in two,
  never share one (on one machine: the process id is what tells them apart). A run that was killed leaves its database behind; the next run drops it.
  `DB_NAME` itself is only the development database (`just dev`, `just migrate`): give a
  worktree its own when its migrations differ.
- **`DJANGO_SETTINGS_MODULE` never goes in `backend/.env`**: it makes the tests run under the
  development settings.
- **Harness runs go side by side**: `just test-harness` and `just harness-serve` each take
  `HARNESS_PORT`, or a free port they pick (harness-serve prints it), and the test-harness run
  stops only the backend it started (its own process group, a hard kill after 5 s). They share
  the database `midnight_village_harness`; one migrates it at a time.
- **Timer tests are not timing-dependent**: they wait for the timer itself to finish
  (`backend/tests/timer_threads.py`). A failure under load is a real failure.

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
On 21 November 2026 an agent session downloaded that driver to its scratchpad, ran it there and the test passed; if a session is refused running a downloaded binary, it does not work around that.
