# Midnight Village

A party game: friends at one table use their phones for secret roles, night actions and
votes; the server runs the game. First game: One Night Ultimate Werewolf (ONUW). Where the
work stands: `docs/dev/status.md`.

## Core principles (all code)

1. **Server-authoritative**: all game logic on the server; clients send actions and show results.
2. **Hidden information**: responses, socket events and errors are player-scoped; never leak another player's secret.
3. **State machine**: phases (lobby, night, discussion, voting, results) with explicit transitions; reject invalid ones.
4. **Atomicity**: state changes are all-or-nothing (`@atomic`). Game logic is unit-testable without HTTP or Django.
5. **Determinism**: all randomness seeded and logged.
6. **Separate game apps**: `apps.core` is shared infrastructure; each game is its own app (`apps.onuw`); no premature abstraction.
7. **HTTP for actions, WebSockets for events**: never submit a player action over a socket.

## How we work

- The owner is not an engineer: report in plain words, short. Decide and carry on; do not stop to ask.
- Fun first: a friendly game at a table. Do not over-index on secrecy or peeking. No added waits, minimum response times or assumed timer lengths: every length is the table's setting. Test: would friends notice the protection, or only the friction?
- Few words on screen; elements do the job; teach a gesture once by doing it, then never again. A player's name is never truncated.
- A look ("skin") is a complete design with its own layouts and original art, never a recolour or filter. One look today: Shadow paper.
- Every screen change gets a "does it look good" review by eye, and before/after pictures go to the owner before it merges.
- Every change is reviewed once by a fresh agent that was not given the author's conclusions; the author fixes, the orchestrator checks the fixes. A second review only for a serious finding in the server or the rules. Fix the cause as a mechanism, not the instance.
- Ship in chunks: each finished piece is its own pull request, merged when its checks are green (the owner has asked for this standing). Never merge unfinished work; never one giant change.
- Work in this session with subagents, one heavy piece at a time (they share one machine); no extra cloud sessions.
- The owner tests on the live app. What they report is in `docs/dev/owner-feedback.md`: read it before touching a screen.
- Subagents: one worktree and one `DB_NAME` each. `just test-harness` takes its own free port and stops only its own backend, so runs go side by side. Timer tests wait on the timer itself (`backend/tests/timer_threads.py`), never on a sleep.
- Test fixtures come only from `contract_samples/`; after a payload change, and after merging a branch that changes payloads, run `just samples` and review the diff.
- The server is LIVE: every push migrates the shared database (rules: `backend/CLAUDE.md`, "Deploy-safe changes"). Do not touch the owner's Vercel, Neon or Redis accounts; ask before generating large batches of art. Fetch and merge before pushing; after pushing server changes, tell the deployment session (id in `docs/dev/status.md`).
- Never open or read https://github.com/mankidev/antialgorithm in a main session; only subagents may, and they must not reproduce it.
- Ordering and concurrency logic (server stage handling, the phone's outbox) is model-checked in focused slices: `docs/dev/models/README.md`.

## Subagents: model and effort

A hook blocks any Agent or workflow `agent()` call that is not on an allowed model. Set `model` and `effort` on every call, or use a `.claude/agents/` type that pins them.

- Only `opus` or `sonnet`, never the main session's model, never `haiku`.
- Opus for design-heavy or tricky work and for reviews. Sonnet for well-specified work and lookups.
- Effort: `low` for lookups, `medium` for routine edits, `high` for design and review.
- Forks are not allowed (they inherit the main model). Spawn a fresh agent with the context in its prompt.
- Change the allowed list in `.claude/guardrails/config.toml`.

## Commands (repo root)

```bash
just check            # backend lint, format, types, migrations + instruction links
just test             # backend tests + guardrail and gate-routing tests
just flutter-test     # frontend tests (frontend: just analyze, just format-check)
just samples          # re-record contract_samples/
just test-harness     # end-to-end harness against its own real backend (a free port)
just screens          # every screen as a PNG beside its mock
```

More: `backend/CLAUDE.md`, `frontend/CLAUDE.md`, `just --list`. Setup: `docs/dev/environment.md`.

## Commits

- `type(scope): description`; types feat, fix, test, refactor, docs, chore. Tests: descriptive names, seeded, several players; coverage 80% minimum.
- Git's own hooks (`.claude/hooks/git/`, switched on by `.claude/hooks/session-start.sh` at every session start) run the checks for what you commit; never `--no-verify` or any other bypass. Give a committing Bash call `timeout` 600000 or run it in the background: the suites take minutes.
- A change under `.claude/` updates `docs/claude-architecture.md` in the same commit.

## Pointers

- Game rules (read before touching a mechanic): `docs/specs/onuw/index.md`. Server API v2: `docs/specs/onuw/api-contract-v2.md`.
- Screens and copy: `docs/specs/frontend/first-time-play.md` (sections 7 and 8 win); the look: `docs/design/`.
- Harness and oracle: `docs/dev/debug-harness/`. Running on Vercel: `docs/dev/deploy-vercel.md`.
- Hooks, guardrails, agents, skills: `docs/claude-architecture.md`.
