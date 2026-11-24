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

- Write plainly and briefly: the owner is not an engineer. Decide and carry on.
- Fun first: a friendly game at a table. Do not over-index on secrecy or peeking. No added waits, minimum response times or assumed timer lengths: every length is the table's setting. Test: would friends notice the protection, or only the friction?
- Few words on screen; elements do the job; teach a gesture once by doing it, then never again. A player's name is never truncated.
- A look ("skin") is a complete design with its own layouts and original art, never a recolour or filter. One look today: Shadow paper.
- A screen is judged by eye: render it (`just screens`), look at every picture, and hand over before and after.
- The owner plays the live app. What they hit is in `docs/dev/owner-feedback.md`: read it before touching a screen.
- Fix the cause as a mechanism, not the instance.
- A source file stays under 600 lines (`tool/check_file_sizes.py`, in `just check` and the commit gate); one already over may shrink but never grow (the check compares with main; there is no list).
- Every test run builds its own database (`test_<DB_NAME>_<process id>`), so runs side by side never collide. `just test-harness` takes its own free port and stops only its own backend. Timer tests wait on the timer itself (`backend/tests/timer_threads.py`), never on a sleep.
- Test fixtures come only from `contract_samples/`; after a payload change run `just samples` and review the diff.
- The server is LIVE: every push migrates the shared database (rules: `backend/CLAUDE.md`, "Deploy-safe changes"). Do not touch the owner's Vercel, Neon or Redis accounts; ask before generating large batches of art.
- Ordering and concurrency logic (server stage handling, the phone's outbox) is model-checked in focused slices: `docs/dev/models/README.md`.

## Commands (repo root)

```bash
just check            # backend lint, format, types, migrations + instruction links
just brief 09         # FIRST on a screen: its spec and the owner's words as written, states, files, who else is in them
just piece-check      # while building: fast checks + only the tests this change reaches (a minute or two)
just handover <file>  # LAST, the only way to hand over: refuses unpushed work, runs the checks, draws it beside main
just test             # backend tests (on every core) + guardrail and gate-routing tests
just flutter-test     # frontend tests (frontend: just analyze, just format-check)
just samples          # re-record contract_samples/
just test-harness     # end-to-end harness against its own real backend (a free port)
just gate-full        # the whole local suite on demand (GitHub runs it all, and the browser jobs)
just screens          # every screen as a PNG beside its mock
```

Every recipe runs from the repo root, and from `frontend/` and `backend/` too. More:
`backend/CLAUDE.md`, `frontend/CLAUDE.md`, `just --list`. Setup: `docs/dev/environment.md`.

## Commits

- `type(scope): description`; types feat, fix, test, refactor, docs, chore. Tests: descriptive names, seeded, several players; coverage 80% minimum.
- Git's own hooks (`.claude/hooks/git/`, switched on by `.claude/hooks/session-start.sh` at every session start) run the fast checks for what you commit (format, lint, types, analyze: seconds); never `--no-verify` or any other bypass.
- GitHub is the wall: it runs every check on every pull request, and nothing merges to main except by pull request with every check green. Run `just piece-check` while you work; `just gate-full` runs the whole local suite on demand (minutes).
- A change under `.claude/` updates `docs/claude-architecture.md` in the same commit.

## Pointers

- Game rules (read before touching a mechanic): `docs/specs/onuw/index.md`. Server API v2: `docs/specs/onuw/api-contract-v2.md`.
- Screens and copy: `docs/specs/frontend/first-time-play.md` (sections 7 and 8 win); the look: `docs/design/`.
- Harness and oracle: `docs/dev/debug-harness/`. Running on Vercel: `docs/dev/deploy-vercel.md`.
- Hooks, guardrails, agents, skills: `docs/claude-architecture.md`.
- Running the work (who builds, who reviews, pull requests, models): `docs/dev/running-the-work.md`.
