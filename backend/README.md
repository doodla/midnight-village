# Midnight Village: the server

Django, DRF and Channels. Start at `CLAUDE.md` in this folder (commands, rules that have
bitten, adding a role); each part is described where it lives:

- `backend/apps/core/README.md`: shared infrastructure (accounts, lobbies, presence, timers).
- `backend/apps/onuw/README.md`: One Night Ultimate Werewolf (the engine, the night, the vote).
- `backend/apps/observe/README.md`: how the live app measures itself (speed summaries, the owner's report).
- `backend/tests/README.md`: the tests.

Setup: `tool/setup_env.sh <db_name>` from the repo root (`docs/dev/environment.md`); never
`.env.example` copied as is. Then `just dev`, `just check`, `just test`.
