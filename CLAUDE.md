# Midnight Village

## What This Is

A multiplayer social deduction game platform. Players sit together in person and use their phones for secret role actions and voting. The app handles role assignment, night phases, timers, and simultaneous reveals.

**First game:** One Night Ultimate Werewolf (ONUW) — a single-night variant where roles may swap during the night, then players discuss and vote to find the werewolf.

## Core Principles

IMPORTANT: These principles are non-negotiable and apply to ALL code in this project.

1. **Server-authoritative** — ALL game logic runs on the server. Clients send actions, server validates and broadcasts results. NEVER compute game logic client-side.
2. **Hidden information** — Server knows everything, but API responses are player-scoped. A player ONLY sees what their role allows. NEVER leak another player's secret info through API responses, WebSocket events, or error messages.
3. **State machine** — Games have phases (lobby → night → discussion → voting → results) with explicitly defined valid transitions. Invalid transitions MUST be rejected.
4. **Atomicity** — Game state changes are all-or-nothing. Use `@atomic` for state transitions. No partial updates.
5. **Determinism** — Same inputs produce same outputs. ALL randomness is seeded and logged for replay/debugging.
6. **Separate game apps** — `apps.core` has shared infrastructure (auth, lobbies, WebSockets). Each game type is its own Django app (`apps.onuw`). No premature abstraction across games.
7. **HTTP for state changes, WebSockets for events** — Clients submit actions and queries via REST. The server broadcasts state changes via WebSocket. Never use WebSocket messages as the primary way to submit player actions.

## Commands

```bash
just check             # Lint + format-check + typecheck (MUST pass before commit)
just test              # All backend tests (MUST pass before commit)
just fix               # Auto-fix lint + format
just test-cov          # Tests with coverage report
```

All root commands delegate to `backend/justfile` or `frontend/justfile`. Run `just --list` for the full set. See `backend/CLAUDE.md` and `frontend/CLAUDE.md` for component-specific commands.

## Dev & Test Harness

Beyond `just check`/`test` (which mock the HTTP/WS seam), there is a deterministic harness for driving the **whole ONUW multiplayer flow against a real backend**, plus a single-agent game driver. Full docs: `docs/dev/debug-harness/` (`contract.md`, `game-driver.md`).

- `cd backend && just harness-serve` — boot a throwaway DEBUG backend on `127.0.0.1:8001` (forced role assignment, a full-state oracle, fire-timer hook — all `DEBUG`-only, 403 in prod).
- `cd frontend && just test-harness` — deterministic e2e integration harness: real widget tree ↔ real backend, per-player PNG filmstrips (`frontend/test_e2e/`; not part of `just test`).
- `backend/tools/game_driver.py` — one agent drives an entire game via the real player API + oracle and verifies outcomes against the rules.
- `/debug` route (dev-only, gated by `Env.isDev`) — debug toolbar: spin up a table, switch player perspectives, god panel, auto-drive.

## Code Style

- **Tests:** Descriptive names (`test_seer_can_view_one_center_card`), seed ALL randomness, test multi-player scenarios not just single player.
- **Commits:** `type(scope): description` — types: feat, fix, test, refactor, docs, chore
- **Coverage:** 80% minimum, enforced.

## Quality Gates

Design constraints (verified by tests):
- Game logic is unit-testable independent of HTTP/Django
- API responses are player-scoped — never return another player's hidden info
- No hidden information leaks in error messages, WebSocket events, or validation responses

## Game Specs

The authoritative ONUW game rules live in `docs/specs/onuw/`. Read these before implementing or reviewing any game mechanic:

- `overview.md` — Setup, game flow, phases, teams, information architecture
- `roles.md` — All 12 v1 roles (team, wave, action, special rules)
- `night-phase.md` — Wake order, wave system, action types, timer model, optionality
- `voting-and-resolution.md` — Discussion, voting, death threshold, Hunter chain, win conditions
- `doppelganger.md` — Complete Doppelganger interaction matrix for all 12 copied roles
- `recommended-setups.md` — Curated role combinations by player count

## Autonomous Development

If you modify anything in `.claude/` (agents, skills, hooks, settings), you MUST update `docs/claude-architecture.md` in the same commit.
