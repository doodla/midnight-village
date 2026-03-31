---
work_package_id: WP04
title: Routing & Navigation
lane: done
dependencies: [WP02]
requirement_refs: [FR-018, FR-019]
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this feature were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
base_branch: 005-frontend-game-integration-layer-WP02
base_commit: cafb0c799c5e735ea80dcec8d4cd1a16e42d9114
created_at: '2026-03-31T14:34:15.619502+00:00'
subtasks: [T015, T016, T017]
phase: Phase 0.5
assignee: ''
agent: headless-reviewer
shell_pid: '18606'
review_status: approved
reviewed_by: Sridhar Vadlamani
history:
- timestamp: '2026-03-31T07:30:22Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
---

# Work Package Prompt: WP04 – Routing & Navigation

## IMPORTANT: Review Feedback Status

**Read this first if you are implementing this task!**

- **Has review feedback?**: Check the `review_status` field above. If it says `has_feedback`, scroll to the **Review Feedback** section immediately.
- **You must address all feedback** before your work is complete.
- **Mark as acknowledged**: Update `review_status: acknowledged` when you begin addressing feedback.

---

## Review Feedback

> **Populated by `/spec-kitty.review`**

*[This section is empty initially.]*

---

## Markdown Formatting
Wrap HTML/XML tags in backticks: `` `<div>` ``, `` `<script>` ``
Use language identifiers in code blocks: ````dart`, ````bash`

---

## Objectives & Success Criteria

- Add `LobbyRoute` (path: `/lobby/:code`) and `GameRoute` (path: `/game/:gameId`) to GoRouter using `@TypedGoRoute` pattern.
- Add auth redirect guard: unauthenticated users redirected to `/`, authenticated users with an active game redirected to `/game/:id`.
- Route definitions exist and resolve correctly.
- Widget tests verify route resolution and auth redirect behavior.

## Context & Constraints

- **Research decision R4**: TypedGoRoute pattern matches existing `HomeRoute` in `routes.dart`. See `research.md` R4.
- **Existing code**: `frontend/lib/core/router/routes.dart` (existing `HomeRoute` with `@TypedGoRoute`), `frontend/lib/core/router/app_router.dart` (existing router setup).
- **Constitution**: Server-authoritative (redirect based on server state), Riverpod code-gen patterns.
- **Governance directive**: TEST_FIRST.
- **Dependency**: WP02 (`authenticatedClientProvider` for auth state in redirect guard).

**Implementation command**: `spec-kitty implement WP04 --base WP02`

## Subtasks & Detailed Guidance

### Subtask T015 – Add `LobbyRoute` and `GameRoute` definitions

- **Purpose**: Define typed routes for lobby and game screens matching the existing GoRouter pattern (FR-018).
- **Steps**:
  1. Open `frontend/lib/core/router/routes.dart`.
  2. Add `@TypedGoRoute<LobbyRoute>(path: '/lobby/:code')` with a `LobbyRoute` class taking `String code` parameter.
  3. Add `@TypedGoRoute<GameRoute>(path: '/game/:gameId')` with a `GameRoute` class taking `String gameId` parameter.
  4. Each route's `build` method returns a placeholder widget initially — real screens are built in WP06 (lobby) and WP07 (game container).
  5. Run `just gen` to regenerate `routes.g.dart`.
- **Files**: `frontend/lib/core/router/routes.dart` (modify ~30 lines)
- **Parallel?**: Yes — different concern from T016 (can develop route definitions while guard is separate).
- **Notes**: Follow the exact pattern of the existing `HomeRoute`. The placeholder widgets should be simple `Scaffold` with a `Text` showing the route parameter — just enough to verify routing works.

### Subtask T016 – Add auth redirect guard

- **Purpose**: Protect routes and handle active game resumption on app startup (FR-018, FR-019).
- **Steps**:
  1. Open `frontend/lib/core/router/app_router.dart`.
  2. Add a `redirect` callback to the `GoRouter` configuration.
  3. Redirect logic:
     - Read auth state from `authNotifierProvider`.
     - If user is **unauthenticated** and navigating to a protected route (`/lobby/*`, `/game/*`): redirect to `/`.
     - If user is **authenticated** and navigating to `/`: check for active game via `GET /api/onuw/me/current-game/` (cache the result — don't call on every navigation). If active game exists, redirect to `/game/:id`.
     - Otherwise: no redirect (return `null`).
  4. The active-game check uses `AuthenticatedClient` from WP02.
- **Files**: `frontend/lib/core/router/app_router.dart` (modify ~25 lines)
- **Parallel?**: Yes — different file from T015.
- **Notes**: The active-game redirect is for app startup/resume only — it's called when the user first authenticates or when the app cold-starts with stored credentials. Cache the result to avoid repeated API calls on every navigation event. Clear the cache when navigating away from a game.

### Subtask T017 – Routing tests

- **Purpose**: Verify route resolution and auth redirect behavior (TEST_FIRST directive).
- **Steps**:
  1. Create `frontend/test/core/router/routes_test.dart`.
  2. **Route resolution tests**:
     - Verify `/lobby/ABC123` resolves to `LobbyRoute(code: 'ABC123')`.
     - Verify `/game/550e8400-uuid` resolves to `GameRoute(gameId: '550e8400-uuid')`.
     - Verify `/` resolves to `HomeRoute()`.
  3. **Auth redirect tests**:
     - Mock `authNotifierProvider` as unauthenticated. Navigate to `/lobby/ABC`. Verify redirect to `/`.
     - Mock `authNotifierProvider` as authenticated, no active game. Navigate to `/`. Verify stays on `/`.
     - Mock `authNotifierProvider` as authenticated, active game `game-123`. Navigate to `/`. Verify redirect to `/game/game-123`.
  4. Use `pumpWidget` with a `ProviderScope` and override providers for mocking.
- **Files**: `frontend/test/core/router/routes_test.dart` (new, ~80 lines)
- **Parallel?**: Can be scaffolded before implementation.
- **Notes**: Use the test harness pattern from existing tests. GoRouter testing may require `pumpAndSettle` for async redirects.

## Test Strategy

**Directive**: TEST_FIRST.

**Commands**:
```bash
cd frontend && just test
cd frontend && just check
cd frontend && just gen      # After adding route annotations
```

**Test files**:
- `frontend/test/core/router/routes_test.dart` — Route resolution and auth redirect

## Risks & Mitigations

- **Risk**: Code generation out of sync after adding route annotations.
  **Mitigation**: Run `just gen` as part of implementation.
- **Risk**: Active-game check adds latency to every navigation.
  **Mitigation**: Cache the result; only check on authentication state changes.

## Review Guidance

- Verify routes use `@TypedGoRoute` code-gen pattern (not manual route registration).
- Verify auth guard handles all three cases: unauthenticated redirect, active game redirect, no redirect.
- Verify active-game check result is cached.
- Verify `just gen` was run and `routes.g.dart` is up to date.
- Run `just check && just test` from `frontend/`.

## Activity Log

> **CRITICAL**: Chronological order (oldest first, newest last).

### Updating Lane Status

1. **Edit directly**: Change `lane:` in frontmatter AND append activity log entry
2. **Use CLI**: `spec-kitty agent tasks move-task WP04 --to <lane> --note "message"`

**Valid lanes**: `planned`, `doing`, `for_review`, `done`

- 2026-03-31T07:30:22Z – system – lane=planned – Prompt created.
- 2026-03-31T14:34:15Z – headless-impl – shell_pid=91469 – lane=doing – Assigned agent via workflow command
- 2026-03-31T14:53:41Z – headless-impl – shell_pid=91469 – lane=for_review – Ready for review: LobbyRoute + GameRoute typed routes with code-gen, appRouterProvider Riverpod provider with async auth redirect guard (unauthenticated protection + active game resume), 7 passing tests
- 2026-03-31T14:54:25Z – headless-reviewer – shell_pid=18606 – lane=doing – Started review via workflow command
- 2026-03-31T14:57:42Z – headless-reviewer – shell_pid=18606 – lane=approved – Review passed: TypedGoRoute definitions for LobbyRoute+GameRoute, 3-case auth redirect guard with caching, 386 tests pass, analysis clean
