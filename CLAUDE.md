# Midnight Village

## What This Is

A multiplayer social deduction game platform. Players sit together in person and use their phones for secret role actions and voting. The app handles role assignment, night phases, timers, and simultaneous reveals.

**First game:** One Night Ultimate Werewolf (ONUW) — a single-night variant where roles may swap during the night, then players discuss and vote to find the werewolf.

## Architecture

- **Backend:** Python 3.12, Django 5.x, Django REST Framework, Django Channels (WebSockets), PostgreSQL, Redis
- **Frontend:** Flutter (web, iOS, Android), Riverpod (state management), GoRouter (navigation), Dio (HTTP)
- **Real-time:** WebSockets for game events, HTTP for CRUD operations

### Core Principles

IMPORTANT: These principles are non-negotiable and apply to ALL code in this project.

1. **Server-authoritative** — ALL game logic runs on the server. Clients send actions, server validates and broadcasts results. NEVER compute game logic client-side.
2. **Hidden information** — Server knows everything, but API responses are player-scoped. A player ONLY sees what their role allows. NEVER leak another player's secret info through API responses, WebSocket events, or error messages.
3. **State machine** — Games have phases (lobby → night → discussion → voting → results) with explicitly defined valid transitions. Invalid transitions MUST be rejected.
4. **Atomicity** — Game state changes are all-or-nothing. Use `@atomic` for state transitions. No partial updates.
5. **Determinism** — Same inputs produce same outputs. ALL randomness is seeded and logged for replay/debugging.
6. **Separate game apps** — `apps.core` has shared infrastructure (auth, lobbies, WebSockets). Each game type is its own Django app (`apps.onuw`). No premature abstraction across games.

### Project Structure

```text
backend/
  config/settings/     # Split settings: base, development, staging, production, test
  apps/core/           # Users, auth, lobbies, WebSockets (generic)
  apps/onuw/           # ONUW game logic (to be built)
  tests/               # pytest: unit/integration/contract markers
frontend/
  lib/core/            # API client, config, router, storage
  lib/features/        # Feature modules (auth, lobby, game)
docs/                  # Architecture, API patterns, contributing, game design plans
```

## ONUW Game Domain

YOU MUST understand these mechanics before implementing any game feature.

**Game flow:** Lobby → Night → Discussion → Voting → Results

**Night phase runs in waves:**
1. **Doppelganger** — copies a player's role, may act again in that role's wave
2. **Werewolves, Minion, Masons** — see each other (no state changes)
3. **Seer, Robber, Troublemaker, Drunk** — independent actions, resolve simultaneously
4. **Insomniac, Doppelganger-as-Insomniac** — see own final role after all swaps

**Action types:** `peek_player`, `peek_center`, `swap_with_player`, `swap_with_center`, `swap_others`, `see_team`, `none`

**v1 roles (12):** Werewolf, Villager, Seer, Robber, Troublemaker, Drunk, Insomniac, Minion, Tanner, Hunter, Mason, Doppelganger

**Win conditions:**
- Village wins if a Werewolf is eliminated
- Werewolves win if no Werewolf is eliminated
- Tanner wins if Tanner is eliminated (overrides village win)
- Hunter kills the player they voted for if Hunter dies
- No werewolves in play → village must NOT vote to kill anyone to win

**Critical edge cases to always consider:**
- Player disconnects mid-action → action skipped after timer
- Timer expires with no submission → action skipped
- Doppelganger copies a role with a night action → acts again in that wave
- All votes tied → no one dies
- Robber swaps then Troublemaker swaps the same player → order matters (wave ordering resolves this)

## Commands

```bash
# Root (delegates to backend/frontend)
just test              # Run all backend tests
just check             # Lint + format-check + typecheck
just dev               # Run dev server
just fix               # Auto-fix lint + format

# Backend (from backend/)
just test              # pytest
just test-cov          # pytest with coverage
just test-unit         # Unit tests only
just lint              # Ruff check
just format            # Ruff format
just typecheck         # Pyrefly

# Frontend (from frontend/)
just flutter-run       # Run on web (chrome, port 3000)
just flutter-test      # Run tests
just flutter-analyze   # Dart analysis
just flutter-build-runner  # Code generation
```

## Code Style

- **Python:** Standard conventions. Ruff for lint/format, Pyrefly for types.
- **Dart/Flutter:** Standard analysis_options.yaml. Riverpod with code generation.
- **Tests:** Descriptive names (`test_seer_can_view_one_center_card`), seed randomness, test multi-player scenarios not just single player.
- **Commits:** `type(scope): [TASK-XXX] description` — types: feat, fix, test, refactor, docs, chore
- **Coverage:** 80% minimum, enforced.

## Quality Gates

IMPORTANT: You MUST pass these before considering any work complete:
1. `just check` passes (lint + format + typecheck)
2. `just test` passes (all tests green)
3. Game logic is unit-testable independent of HTTP/Django
4. API responses are player-scoped — verified by test
5. No hidden information leaks — verified by test

## Autonomous Development

This project uses an orchestration system with mechanical enforcement. Key documents:
- `docs/claude-architecture.md` — How the system works and why (MUST be updated when .claude/ changes)
- `docs/user-guide.md` — How the user interacts with the system

Use `/orchestrate` to start or resume orchestrated development.

State is tracked in `.plan/` directory (STATUS.yaml, plan.yaml per milestone, BACKLOG.yaml).

IMPORTANT: If you modify anything in `.claude/` (agents, skills, hooks, settings), you MUST update `docs/claude-architecture.md` in the same commit. This is not optional.
