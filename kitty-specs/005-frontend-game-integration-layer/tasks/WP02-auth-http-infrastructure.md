---
work_package_id: WP02
title: Auth & HTTP Infrastructure
lane: "doing"
dependencies: []
requirement_refs:
- FR-001
- FR-002
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this feature were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
base_branch: main
base_commit: c3720b001a02ccd65be982cbf757f51c821bbe20
created_at: '2026-03-31T07:54:12.337072+00:00'
subtasks: [T006, T007, T008, T009]
phase: Phase 0 - Foundation
assignee: ''
agent: "headless-impl"
shell_pid: "56820"
review_status: ''
reviewed_by: ''
history:
- timestamp: '2026-03-31T07:30:22Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
---

# Work Package Prompt: WP02 – Auth & HTTP Infrastructure

## IMPORTANT: Review Feedback Status

**Read this first if you are implementing this task!**

- **Has review feedback?**: Check the `review_status` field above. If it says `has_feedback`, scroll to the **Review Feedback** section immediately.
- **You must address all feedback** before your work is complete.
- **Mark as acknowledged**: When you understand the feedback and begin addressing it, update `review_status: acknowledged` in the frontmatter.
- **Report progress**: As you address each feedback item, update the Activity Log.

---

## Review Feedback

> **Populated by `/spec-kitty.review`** – Reviewers add detailed feedback here when work needs changes.

*[This section is empty initially.]*

---

## Markdown Formatting
Wrap HTML/XML tags in backticks: `` `<div>` ``, `` `<script>` ``
Use language identifiers in code blocks: ````dart`, ````bash`

---

## Objectives & Success Criteria

- Create `AuthInterceptor` that adds JWT bearer tokens to all authenticated HTTP requests.
- Create `AuthenticatedClient` wrapping Dio with the interceptor attached.
- Wire `authenticatedClientProvider` into the Riverpod provider tree.
- Unit tests verify: bearer token injection, 401 triggers token refresh then retries, concurrent request queueing during refresh, refresh failure clears tokens and signals auth state change.
- `just test` from `frontend/` passes. `just check` passes.

## Context & Constraints

- **Research decision R1**: Separate `AuthenticatedClient` avoids circular dependency with unauthenticated `ApiClient` used for token refresh. See `kitty-specs/005-frontend-game-integration-layer/research.md` R1.
- **Existing patterns**: `frontend/lib/core/api/api_client.dart:12-29` (Dio setup), `frontend/lib/features/auth/data/auth_service.dart:81-110` (refresh call pattern), `frontend/lib/features/auth/presentation/auth_notifier.dart:41-47` (auth state management).
- **Constitution**: Server-authoritative, Riverpod code-gen patterns, dispose resources via `ref.onDispose`.
- **Governance directive**: TEST_FIRST — write tests before implementation.
- **No dependencies** — uses existing `ApiClient`, `TokenStorage`, `AuthService` providers.

**Implementation command**: `spec-kitty implement WP02`

## Subtasks & Detailed Guidance

### Subtask T006 – Create `AuthInterceptor`

- **Purpose**: Intercept all authenticated HTTP requests to add JWT bearer token, handle 401 responses with automatic token refresh (FR-001, FR-002).
- **Steps**:
  1. Create `frontend/lib/core/api/auth_interceptor.dart`.
  2. Implement `AuthInterceptor` extending `QueuedInterceptorsWrapper` (not plain `Interceptor` — serializes concurrent requests during refresh).
  3. Constructor takes: `TokenStorage tokenStorage`, `ApiClient unauthenticatedClient` (for refresh calls), `void Function() onAuthFailure` callback.
  4. `onRequest`: Read access token from `tokenStorage.getAccessToken()`. Add `Authorization: Bearer <token>` header. If no token, pass through (let server return 401).
  5. `onError` (for 401 responses):
     - Read refresh token from `tokenStorage.getRefreshToken()`.
     - If no refresh token, call `onAuthFailure()` and reject.
     - Call `POST /auth/token/refresh/` via the unauthenticated `ApiClient` with the refresh token.
     - On success: save new tokens to `tokenStorage`, retry the original request with the new access token.
     - On refresh failure (401): clear all tokens via `tokenStorage`, call `onAuthFailure()`, reject the original error.
  6. `QueuedInterceptorsWrapper` ensures that while one request triggers a refresh, all other concurrent requests queue behind it and retry with the new token.
- **Files**: `frontend/lib/core/api/auth_interceptor.dart` (new, ~80 lines)
- **Parallel?**: Can be developed alongside T007 (same concern).
- **Notes**: The unauthenticated `ApiClient` is passed in to avoid circular dependency — it handles the refresh call without going through this interceptor. The `onAuthFailure` callback will be wired to clear auth state in T008.

### Subtask T007 – Create `AuthenticatedClient`

- **Purpose**: Provide a Dio wrapper with `AuthInterceptor` attached that exposes the same HTTP surface as `ApiClient` (FR-001).
- **Steps**:
  1. Create `frontend/lib/core/api/authenticated_client.dart`.
  2. Create `AuthenticatedClient` class with its own `Dio` instance.
  3. Constructor takes: `String baseUrl`, `AuthInterceptor interceptor`.
  4. Configure Dio with the same base options as `ApiClient` (base URL, content type, timeouts) — reference `api_client.dart:12-29`.
  5. Attach the `AuthInterceptor` to the Dio instance.
  6. Expose methods: `get`, `post`, `patch`, `delete` matching the `ApiClient` surface.
- **Files**: `frontend/lib/core/api/authenticated_client.dart` (new, ~40 lines)
- **Parallel?**: Develop alongside T006.
- **Notes**: This is a thin wrapper. The interceptor does the heavy lifting. Keep the API surface consistent with `ApiClient` so callers can swap between them if needed.

### Subtask T008 – Create `authenticatedClientProvider`

- **Purpose**: Wire `AuthenticatedClient` into the Riverpod provider tree so feature services can depend on it (FR-001).
- **Steps**:
  1. Add the provider in `frontend/lib/features/auth/presentation/auth_notifier.dart` (or a nearby provider file — follow existing file organization).
  2. Create `@Riverpod(keepAlive: true)` provider: `authenticatedClientProvider`.
  3. Construct `AuthInterceptor` with:
     - `tokenStorage` from existing `tokenStorageProvider`
     - `unauthenticatedClient` from existing `apiClientProvider`
     - `onAuthFailure` callback that invalidates `authNotifierProvider` / sets state to unauthenticated
  4. Construct `AuthenticatedClient` with `Env.apiUrl` and the interceptor.
  5. Return the client. `keepAlive: true` ensures a single instance shared across the app.
  6. Run `just gen` to regenerate Riverpod code.
- **Files**: `frontend/lib/features/auth/presentation/auth_notifier.dart` or nearby (modify ~20 lines)
- **Parallel?**: Depends on T006 and T007 being structurally defined.
- **Notes**: The `onAuthFailure` callback wiring is critical — it bridges the HTTP layer to the auth state layer. Follow the existing `AuthNotifier` pattern for state transitions. The GoRouter auth guard (WP04) will handle the actual redirect.

### Subtask T009 – Tests for auth interceptor

- **Purpose**: Verify the complete auth interceptor flow (SC-004, TEST_FIRST directive).
- **Steps**:
  1. Create `frontend/test/core/api/auth_interceptor_test.dart`.
  2. **Bearer token injection test**: Mock `TokenStorage` to return a token. Verify outgoing request has `Authorization: Bearer <token>` header.
  3. **401 refresh flow test**: Mock a 401 response, mock successful refresh call. Verify: refresh called with correct token, new tokens saved, original request retried with new token.
  4. **Concurrent request queueing test**: Trigger two requests that both get 401. Verify only one refresh call is made (not two). Both requests retry with the new token.
  5. **Refresh failure redirect test**: Mock 401 response, mock refresh returning 401. Verify: tokens cleared, `onAuthFailure` callback invoked, original request rejected.
  6. **No token test**: Mock `TokenStorage` returning null. Verify request sent without Authorization header.
- **Files**: `frontend/test/core/api/auth_interceptor_test.dart` (new, ~150 lines)
- **Parallel?**: Tests can be scaffolded before implementation (test-first).
- **Notes**: Use `mocktail` for mocking (project standard). Mock `Dio` responses using `DioAdapter` or mock `RequestInterceptorHandler`/`ErrorInterceptorHandler`. Reference existing test patterns in `frontend/test/`.

## Test Strategy

**Directive**: TEST_FIRST — write tests before implementation code.

**Commands**:
```bash
cd frontend && just test     # Run all frontend tests
cd frontend && just check    # Lint + format-check + typecheck
cd frontend && just gen      # Regenerate Riverpod/Freezed code after adding providers
```

**Test files**:
- `frontend/test/core/api/auth_interceptor_test.dart` — All T009 scenarios

**Key test scenarios**:
1. Bearer token added to every request
2. 401 response triggers refresh + retry
3. Concurrent requests queue behind a single refresh
4. Failed refresh clears tokens and signals auth failure
5. Missing token sends request without auth header

## Risks & Mitigations

- **Risk**: Concurrent refresh race condition — multiple requests trigger simultaneous refresh calls.
  **Mitigation**: `QueuedInterceptorsWrapper` serializes interceptor execution. Test this explicitly in T009.
- **Risk**: Token storage async access timing in interceptor.
  **Mitigation**: `QueuedInterceptorsWrapper.onRequest` supports async handlers natively.
- **Risk**: Circular dependency if `AuthenticatedClient` is used for token refresh.
  **Mitigation**: Architecture explicitly uses unauthenticated `ApiClient` for refresh (R1). Tests verify this path.

## Review Guidance

- Verify `QueuedInterceptorsWrapper` is used (not plain `Interceptor`) to prevent concurrent refresh.
- Verify the unauthenticated client is used for refresh calls (no circular dependency).
- Verify `onAuthFailure` callback clears tokens AND signals auth state change.
- Verify the provider is `keepAlive: true` for singleton behavior.
- Run `just check && just test` from `frontend/` — must pass clean.

## Activity Log

> **CRITICAL**: Activity log entries MUST be in chronological order (oldest first, newest last).

### How to Add Activity Log Entries

**When adding an entry**:
1. Scroll to the bottom of this file
2. **APPEND the new entry at the END**
3. Use exact format: `- YYYY-MM-DDTHH:MM:SSZ – agent_id – lane=<lane> – <action>`

### Updating Lane Status

To change a work package's lane, either:
1. **Edit directly**: Change the `lane:` field in frontmatter AND append activity log entry
2. **Use CLI**: `spec-kitty agent tasks move-task WP02 --to <lane> --note "message"` (recommended)

**Valid lanes**: `planned`, `doing`, `for_review`, `done`

- 2026-03-31T07:30:22Z – system – lane=planned – Prompt created.
- 2026-03-31T07:54:12Z – headless-impl – shell_pid=56820 – lane=doing – Assigned agent via workflow command
