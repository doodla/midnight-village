<!--
  Sync Impact Report
  ===================
  Version change: N/A → 1.0.0 (Initial ratification)

  Modified principles: None (initial creation)

  Added sections:
    - Core Principles (7 principles)
    - Technology Stack
    - Development Workflow
    - Governance

  Removed sections: None

  Templates requiring updates:
    - .specify/templates/plan-template.md: ✅ Compatible (no updates needed)
    - .specify/templates/spec-template.md: ✅ Compatible (no updates needed)
    - .specify/templates/tasks-template.md: ✅ Compatible (no updates needed)
    - .specify/templates/checklist-template.md: ✅ Compatible (no updates needed)
    - .specify/templates/agent-file-template.md: ✅ Compatible (no updates needed)

  Follow-up TODOs: None
-->

# Midnight Village Constitution

## Core Principles

### I. Test-First Development (NON-NEGOTIABLE)

All production code MUST be written using Test-Driven Development:

- Tests MUST be written before implementation code
- Tests MUST fail before implementation begins (Red phase)
- Implementation MUST be minimal to pass tests (Green phase)
- Refactoring MUST NOT change test behavior (Refactor phase)
- No feature is complete until tests pass

**Rationale**: A real-time multiplayer game requires high reliability. TDD ensures
game logic (roles, night actions, voting) is correct and regression-free.

### II. Simplicity & YAGNI

Start with the simplest solution that works:

- MUST NOT add features, abstractions, or infrastructure "for later"
- MUST implement only what the current user story requires
- MUST choose boring technology over clever solutions
- Three similar lines of code are preferable to a premature abstraction
- Delete unused code rather than commenting it out

**Rationale**: Game development scope creep is common. Simplicity keeps the MVP
deliverable and allows the game design to evolve based on playtesting.

### III. Type Safety

All code MUST be statically typed where the language supports it:

- Python: Type hints required; mypy MUST pass with strict mode
- TypeScript: strict mode enabled; no `any` types without explicit justification
- Mobile: Swift/Kotlin native typing enforced
- API contracts MUST be defined with explicit schemas (OpenAPI, Pydantic)

**Rationale**: Game state is complex (roles, night actions, votes). Type safety
catches logic errors at compile time rather than during gameplay.

### IV. Real-Time State Consistency

Game state MUST remain synchronized across all clients:

- Server is the single source of truth for all game state
- Clients MUST NOT trust local state for game-critical decisions
- State transitions MUST be atomic and validated server-side
- Network failures MUST be handled gracefully with reconnection support

**Rationale**: One Night Ultimate Werewolf involves hidden information. Any
desync could reveal roles or corrupt game integrity.

### V. Platform Parity

All platforms (web, iOS, Android) MUST provide equivalent gameplay:

- Core game mechanics MUST behave identically across platforms
- UI may adapt to platform conventions but game logic is shared
- Features MUST NOT be platform-exclusive without explicit justification
- Cross-platform play MUST be supported from day one

**Rationale**: Players on any device should be able to join the same game
session with identical experience.

### VI. Privacy & Fair Play

Player information MUST be protected and gameplay MUST be fair:

- Role information MUST NOT leak through API responses, logs, or timing
- Players MUST NOT be able to gain unfair advantage through technical means
- Randomization MUST use cryptographically secure sources
- Game logs for debugging MUST be stripped of sensitive role data

**Rationale**: The game depends on hidden information. Any leak ruins the
experience and trust.

### VII. Offline-Resilient Design

The system MUST handle disconnections gracefully:

- Players MUST be able to rejoin games after brief disconnections
- Game state MUST be recoverable if server restarts mid-game
- Turn timers MUST account for network latency
- Mobile apps MUST handle backgrounding without losing game context

**Rationale**: Mobile games frequently experience network interruptions. Players
should not lose their game due to a brief signal loss.

## Technology Stack

**Backend**: Django (Python 3.11+) with Django Channels for WebSocket support
**Frontend Web**: TypeScript with strict mode
**Mobile**: Native iOS (Swift) and Android (Kotlin)
**Database**: PostgreSQL for persistent data, Redis for real-time game state
**API**: REST for non-realtime operations, WebSocket for game events
**Testing**: pytest (backend), Jest (web), XCTest (iOS), JUnit (Android)

All technology choices MUST align with the core principles above. New
dependencies require justification against Simplicity (Principle II).

## Development Workflow

**Code Review Requirements**:
- All changes MUST be reviewed before merge
- Reviewers MUST verify TDD compliance (tests exist and test the right things)
- Type checking MUST pass in CI before merge

**Quality Gates**:
- All tests MUST pass
- Type checking MUST pass (mypy, tsc, Swift/Kotlin compilers)
- No security vulnerabilities in dependencies (automated scanning)
- Game logic changes require manual playtest verification

**Deployment Policy**:
- Staging environment MUST mirror production
- Game-breaking changes require feature flags or phased rollout
- Rollback plan MUST exist for every deployment

## Governance

This constitution supersedes all other development practices for Midnight Village.

**Amendment Process**:
1. Propose change with rationale in writing
2. Review impact on existing principles and codebase
3. Update constitution with version increment
4. Propagate changes to all dependent templates and documentation

**Versioning Policy**:
- MAJOR: Principle removal, redefinition, or backward-incompatible governance change
- MINOR: New principle added or existing principle materially expanded
- PATCH: Clarifications, wording improvements, typo fixes

**Compliance Review**:
- All PRs MUST verify alignment with constitutional principles
- Violations require explicit justification or principle amendment
- Regular architecture reviews SHOULD reference this constitution

**Version**: 1.0.0 | **Ratified**: 2025-12-06 | **Last Amended**: 2025-12-06
