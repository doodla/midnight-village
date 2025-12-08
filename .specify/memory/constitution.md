<!--
  Sync Impact Report
  ===================
  Version change: 1.1.0 → 1.2.0 (MINOR: type checker tool change)

  Modified principles:
    - III. Type Safety: Changed Python type checker from mypy to Pyrefly

  Added sections: None

  Removed sections: None

  Templates requiring updates:
    - All templates remain compatible (no mypy-specific references)

  Follow-up TODOs: None

  ---
  Previous: 1.0.0 → 1.1.0 (MINOR: expanded testing, added UX and performance principles)
  - I. Test-First Development → I. Test-First Development & Quality Gates (expanded)
  - V. Platform Parity → V. Platform Parity & UX Consistency (expanded)
  - Added VIII. Performance Budgets, Technical Decision Governance
-->

# Midnight Village Constitution

## Core Principles

### I. Test-First Development & Quality Gates (NON-NEGOTIABLE)

All production code MUST be written using Test-Driven Development with explicit quality gates:

**TDD Cycle**:
- Tests MUST be written before implementation code
- Tests MUST fail before implementation begins (Red phase)
- Implementation MUST be minimal to pass tests (Green phase)
- Refactoring MUST NOT change test behavior (Refactor phase)
- No feature is complete until tests pass

**Quality Gates**:
- Unit test coverage MUST be at least 80% for new code
- Critical game logic (role resolution, voting, night actions) MUST have 100% branch coverage
- Integration tests MUST cover all API endpoints
- Contract tests MUST validate WebSocket message formats
- All tests MUST pass in CI before merge

**Test Organization**:
- `tests/unit/` - Isolated component tests (no I/O, mocked dependencies)
- `tests/integration/` - Tests with real database and external services
- `tests/contract/` - API and WebSocket contract validation
- Test files MUST mirror source structure (e.g., `src/game/roles.py` → `tests/unit/game/test_roles.py`)

**Rationale**: A real-time multiplayer game requires high reliability. TDD ensures
game logic (roles, night actions, voting) is correct and regression-free. Explicit
coverage gates prevent quality erosion over time.

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

- Python: Type hints required; Pyrefly MUST pass with strict mode
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

### V. Platform Parity & UX Consistency

All platforms (web, iOS, Android) MUST provide equivalent and consistent user experience:

**Gameplay Parity**:
- Core game mechanics MUST behave identically across platforms
- Features MUST NOT be platform-exclusive without explicit justification
- Cross-platform play MUST be supported from day one

**UX Consistency**:
- Game flow (lobby → role reveal → night → day → voting) MUST follow identical steps
- Visual hierarchy and information architecture MUST be consistent across platforms
- Touch targets MUST be minimum 44x44 points on mobile, equivalent click areas on web
- Animation timing and feedback patterns MUST be synchronized across clients
- Error messages and help text MUST use identical wording

**Accessibility**:
- Color choices MUST meet WCAG 2.1 AA contrast requirements
- Interactive elements MUST be keyboard/switch accessible on web
- VoiceOver (iOS) and TalkBack (Android) MUST be supported for critical game actions

**Rationale**: Players on any device should be able to join the same game
session with identical experience. UX inconsistencies create confusion and unfair
advantages for platform-familiar players.

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

### VIII. Performance Budgets

All components MUST meet explicit performance requirements:

**Backend Performance**:
- API response time MUST be <100ms p95 for game actions
- WebSocket message delivery MUST be <50ms p95 within region
- Game state updates MUST be broadcast to all players within 100ms
- Server MUST support 100 concurrent games (800 players) per instance

**Frontend Performance**:
- Initial page load MUST be <3 seconds on 3G connection
- Time to interactive MUST be <5 seconds on mid-range devices
- UI interactions MUST provide feedback within 100ms
- Animation frame rate MUST maintain 60fps during game play

**Mobile Performance**:
- App cold start MUST be <2 seconds
- Memory usage MUST stay below 150MB during active gameplay
- Battery drain MUST not exceed 5% per 30-minute game session
- App size MUST be <50MB (excluding on-demand resources)

**Measurement**:
- Performance MUST be measured in CI using synthetic benchmarks
- Real user metrics MUST be collected and reviewed weekly
- Performance regressions MUST block deployment

**Rationale**: A real-time social game depends on snappy interactions. Slow
responses break immersion and cause players to miss time-sensitive actions.

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
- Reviewers MUST verify adherence to Performance Budgets (Principle VIII)

**Quality Gates**:
- All tests MUST pass
- Type checking MUST pass (mypy, tsc, Swift/Kotlin compilers)
- No security vulnerabilities in dependencies (automated scanning)
- Game logic changes require manual playtest verification
- Performance benchmarks MUST not regress beyond defined budgets

**Deployment Policy**:
- Staging environment MUST mirror production
- Game-breaking changes require feature flags or phased rollout
- Rollback plan MUST exist for every deployment

## Governance

This constitution supersedes all other development practices for Midnight Village.

### Amendment Process

1. Propose change with rationale in writing
2. Review impact on existing principles and codebase
3. Update constitution with version increment
4. Propagate changes to all dependent templates and documentation

### Versioning Policy

- MAJOR: Principle removal, redefinition, or backward-incompatible governance change
- MINOR: New principle added or existing principle materially expanded
- PATCH: Clarifications, wording improvements, typo fixes

### Compliance Review

- All PRs MUST verify alignment with constitutional principles
- Violations require explicit justification or principle amendment
- Regular architecture reviews SHOULD reference this constitution

### Technical Decision Governance

When making technical decisions, the following hierarchy applies:

1. **Constitutional Principles First**: Any decision that conflicts with a
   constitutional principle requires either principle amendment or explicit
   waiver with documented justification.

2. **Decision Documentation**: Significant technical decisions MUST be documented
   in the relevant plan.md or as Architecture Decision Records (ADRs) including:
   - Context and problem statement
   - Options considered with trade-offs
   - Which constitutional principles influenced the decision
   - The chosen approach and rationale

3. **Principle Conflict Resolution**: When principles conflict, apply in order:
   - Privacy & Fair Play (VI) - player trust is paramount
   - Real-Time State Consistency (IV) - game integrity
   - Test-First Development (I) - quality assurance
   - Performance Budgets (VIII) - user experience
   - Platform Parity (V) - reach and accessibility
   - Simplicity (II) - maintainability
   - Type Safety (III) - developer experience
   - Offline-Resilient Design (VII) - edge case handling

4. **Implementation Choices**: When the constitution does not dictate a specific
   approach, prefer solutions that:
   - Align with existing codebase patterns
   - Minimize new dependencies
   - Are easily testable
   - Have clear performance characteristics

**Version**: 1.2.0 | **Ratified**: 2025-12-06 | **Last Amended**: 2025-12-07
