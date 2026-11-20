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
(`git config core.hooksPath .claude/hooks/git`, shared by every worktree of the clone), then
runs `just install` in `backend/` and `flutter pub get` in `frontend/`.

- **One database per checkout.** Parallel agents each work in their own worktree with their
  own `DB_NAME` (pytest creates `test_<DB_NAME>`); two checkouts on one name break each
  other's runs.
- **`DJANGO_SETTINGS_MODULE` never goes in `backend/.env`**: it makes the tests run under the
  development settings.
- **Port 8001 is shared**: `just test-harness` and `just harness-serve` bind
  `127.0.0.1:8001` and the database `midnight_village_harness`. Check nothing else is
  listening before you start one.
- **Timing tests fail falsely under load** (for example
  `test_a_scheduled_job_runs_after_the_delay_with_its_params` in the timers tests): re-run on a
  quiet machine before believing the failure.
