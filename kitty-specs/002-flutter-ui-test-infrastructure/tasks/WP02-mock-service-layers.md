---
work_package_id: WP02
title: Mock HTTP & WebSocket Layers
lane: "doing"
dependencies: []
requirement_refs: [FR-005, FR-006, FR-008]
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this feature were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
base_branch: main
base_commit: 21653006791718e234164f7be306de21bc74eabd
created_at: '2026-03-26T00:57:43.015478+00:00'
subtasks:
- T006
- T007
- T008
- T009
- T010
phase: Phase 0 - Foundation
assignee: ''
agent: "headless-reviewer"
shell_pid: "70477"
review_status: ''
reviewed_by: ''
history:
- timestamp: '2026-03-25T23:55:37Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
---

# Work Package Prompt: WP02 – Mock HTTP & WebSocket Layers

## IMPORTANT: Review Feedback Status

**Read this first if you are implementing this task!**

- **Has review feedback?**: Check the `review_status` field above. If it says `has_feedback`, scroll to the **Review Feedback** section immediately (right below this notice).
- **You must address all feedback** before your work is complete. Feedback items are your implementation TODO list.
- **Mark as acknowledged**: When you understand the feedback and begin addressing it, update `review_status: acknowledged` in the frontmatter.
- **Report progress**: As you address each feedback item, update the Activity Log explaining what you changed.

---

## Review Feedback

> **Populated by `/spec-kitty.review`** – Reviewers add detailed feedback here when work needs changes. Implementation must address every item listed below before returning for re-review.

*[This section is empty initially. Reviewers will populate it if the work is returned from review. If you see feedback here, treat each item as a must-do before completion.]*

---

## Markdown Formatting
Wrap HTML/XML tags in backticks: `` `<div>` ``, `` `<script>` ``
Use language identifiers in code blocks: ````python`, ````bash`

---

## Objectives & Success Criteria

Build the shared mock service infrastructure that both integration tests and interaction harnesses depend on — a mock Dio HTTP layer that fails loud on unmocked endpoints, a fake WebSocket channel for game event simulation, and a timer control utility for countdown testing.

**Success criteria**:
- Mock HTTP returns canned responses for configured endpoints and throws `UnmockedEndpointException` on unconfigured ones
- Mock WebSocket can inject server events and capture client-sent messages
- Timer control can fast-forward time without real delays
- All mock layers have comprehensive tests

**Implementation command**: `spec-kitty implement WP02`

## Context & Constraints

- **Spec**: `kitty-specs/002-flutter-ui-test-infrastructure/spec.md` — User Stories 2, 3; FR-005, FR-006, FR-008
- **Plan**: `kitty-specs/002-flutter-ui-test-infrastructure/plan.md` — Decisions #4-5
- **Dio version**: 5.9.x (check `frontend/pubspec.yaml` for exact version — pin to it)
- **WebSocket interface**: Check `frontend/lib/core/` for the app's WebSocket channel abstraction; the mock must implement the same interface
- **Constraint**: Mock HTTP must fail loud on unmocked endpoints (throw, not return empty) per spec edge cases
- **Constraint**: Timer control must work with both `Timer` and `Stream.periodic` patterns used in game countdown widgets

## Subtasks & Detailed Guidance

### Subtask T006 – Create `mock_http_client.dart` (Dio interceptor)

- **Purpose**: Provide a deterministic HTTP mock layer for tests that returns canned responses for registered endpoints and throws on any unregistered request, preventing silent test failures.
- **Steps**:
  1. Create `frontend/test/helpers/mock_http_client.dart`
  2. Define `UnmockedEndpointException` class:
     ```dart
     class UnmockedEndpointException implements Exception {
       final String method;
       final String path;
       UnmockedEndpointException(this.method, this.path);
       @override
       String toString() => 'UnmockedEndpointException: $method $path has no registered mock response';
     }
     ```
  3. Define `MockHttpClient` class that wraps a `Dio` instance with a custom interceptor:
     ```dart
     class MockHttpClient {
       final Dio dio;
       final Map<String, Response> _registry = {};

       MockHttpClient() : dio = Dio() {
         dio.interceptors.add(_MockInterceptor(_registry));
       }

       MockHttpClient when({required String method, required String path}) { ... }
       void thenReturn(Response response) { ... }
     }
     ```
  4. The interceptor should:
     - Build a registry key from `${method.toUpperCase()}:${path}`
     - On request, look up the key; if found, resolve with the canned response
     - If not found, reject with `DioException` wrapping `UnmockedEndpointException`
  5. Support response status codes, headers, and body data
- **Files**: `frontend/test/helpers/mock_http_client.dart` (new, ~80 lines)
- **Parallel?**: Yes — fully independent of T007 and T008
- **Notes**: The interceptor pattern uses `handler.resolve(response)` for matched requests and `handler.reject(DioException(...))` for unmatched. Consider supporting regex path matching for parameterized routes (e.g., `/api/v1/games/:id/`).

### Subtask T007 – Create `mock_websocket.dart` (fake channel)

- **Purpose**: Provide a fake WebSocket channel that allows tests to simulate server-sent events and capture client-sent messages without a real WebSocket connection.
- **Steps**:
  1. Check `frontend/lib/core/` for the app's WebSocket channel abstraction/interface
  2. Create `frontend/test/helpers/mock_websocket.dart`
  3. Define `MockWebSocketChannel`:
     ```dart
     class MockWebSocketChannel {
       final StreamController<dynamic> _serverToClient = StreamController.broadcast();
       final List<dynamic> sentMessages = [];
       bool _isClosed = false;

       Stream<dynamic> get stream => _serverToClient.stream;
       bool get isClosed => _isClosed;

       void addServerEvent(dynamic data) {
         if (!_isClosed) _serverToClient.add(data);
       }

       void send(dynamic data) {
         sentMessages.add(data);
       }

       Future<void> close([int? code, String? reason]) async {
         _isClosed = true;
         await _serverToClient.close();
       }
     }
     ```
  4. If the app uses `WebSocketChannel` from `package:web_socket_channel`, implement/extend that interface
  5. Ensure the mock supports:
     - Injecting server events via `addServerEvent()`
     - Capturing client-sent messages via `sentMessages` list
     - Close lifecycle (closing prevents further events)
     - Error simulation via `addServerError(Object error)`
- **Files**: `frontend/test/helpers/mock_websocket.dart` (new, ~70 lines)
- **Parallel?**: Yes — fully independent of T006 and T008
- **Notes**: Use `StreamController.broadcast()` so multiple listeners can subscribe. The `sentMessages` list is a simple capture mechanism — tests assert on its contents. If the app's WebSocket abstraction is not yet fully defined, create a minimal interface that the mock implements.

### Subtask T008 – Create `timer_control.dart` (FakeAsync wrapper)

- **Purpose**: Allow tests to advance time programmatically for testing countdowns and auto-transitions without real delays.
- **Steps**:
  1. Create `frontend/test/helpers/timer_control.dart`
  2. Check if `package:fake_async` is in `pubspec.yaml` dev dependencies; if not, add it
  3. Define `TimerControl` utility:
     ```dart
     class TimerControl {
       final FakeAsync _fakeAsync;

       TimerControl(this._fakeAsync);

       void advanceBy(Duration duration) {
         _fakeAsync.elapse(duration);
       }

       void advanceBySeconds(int seconds) {
         advanceBy(Duration(seconds: seconds));
       }

       void flushMicrotasks() {
         _fakeAsync.flushMicrotasks();
       }

       void flushTimers() {
         _fakeAsync.flushTimers();
       }
     }
     ```
  4. Provide a convenience function:
     ```dart
     void testWithTimerControl(String description, Future<void> Function(TimerControl control) body) {
       test(description, () {
         fakeAsync((async) {
           body(TimerControl(async));
         });
       });
     }
     ```
  5. Ensure compatibility with both `Timer.periodic` and `Stream.periodic` patterns
- **Files**: `frontend/test/helpers/timer_control.dart` (new, ~50 lines)
- **Parallel?**: Yes — fully independent of T006 and T007
- **Notes**: `FakeAsync` from `package:fake_async` (or `package:quiver/testing/async.dart`) intercepts all timer-based operations. The wrapper makes the API more discoverable for test authors. Consider whether `flutter_test` already provides `fakeAsync` — if so, use that instead of adding a new dependency.

### Subtask T009 – Write tests for mock HTTP client

- **Purpose**: Verify the mock HTTP layer works correctly before other WPs depend on it.
- **Steps**:
  1. Create `frontend/test/helpers/mock_http_client_test.dart`
  2. Write tests for:
     - **Canned response return**: Register a GET /api/v1/me/ response, make the request, verify the response data and status code
     - **Throw on unmocked endpoint**: Make a GET request to an unregistered path, verify `UnmockedEndpointException` is thrown
     - **Path + method matching**: Register GET /api/v1/games/ and POST /api/v1/games/ separately, verify each returns the correct response
     - **Multiple endpoints**: Register several endpoints, verify each returns its own response
  3. Use descriptive test names: `test('returns canned response for registered GET endpoint', ...)`
- **Files**: `frontend/test/helpers/mock_http_client_test.dart` (new, ~80 lines)
- **Parallel?**: No — depends on T006
- **Notes**: These tests validate the mock itself, not app behavior. Keep them focused on the mock's contract.

### Subtask T010 – Write tests for mock WebSocket

- **Purpose**: Verify the mock WebSocket channel works correctly before other WPs depend on it.
- **Steps**:
  1. Create `frontend/test/helpers/mock_websocket_test.dart`
  2. Write tests for:
     - **Event injection reaches listeners**: Call `addServerEvent()`, verify the stream listener receives the event
     - **Sent message capture**: Call `send()` with data, verify `sentMessages` contains the data
     - **Close lifecycle**: Call `close()`, verify `isClosed` is true and no further events are emitted
     - **Multiple events**: Inject several events, verify all are received in order
     - **Error simulation**: Call `addServerError()`, verify the stream listener receives the error
  3. Use descriptive test names
- **Files**: `frontend/test/helpers/mock_websocket_test.dart` (new, ~80 lines)
- **Parallel?**: No — depends on T007
- **Notes**: Use `expectAsync1` or `completer` patterns for async stream assertions.

## Test Strategy

This WP produces test infrastructure with its own validation tests:

1. **T009**: Mock HTTP client tests (canned response, throw on unmocked, path+method matching)
2. **T010**: Mock WebSocket tests (event injection, message capture, close lifecycle)
3. **Timer control**: Validated by usage in WP04 harness tests; consider a minimal smoke test here if time permits

Run all tests: `flutter test test/helpers/`

## Risks & Mitigations

- **Dio interceptor API may change**: Pin to Dio 5.9.x as already in pubspec. Check interceptor handler API (`resolve`, `reject`, `next`).
- **WebSocket channel interface may not be abstracted yet**: If `frontend/lib/core/` doesn't have a WebSocket abstraction, create a minimal interface that the mock implements. The real implementation can adopt it later.
- **`fake_async` may conflict with `flutter_test`**: Flutter's test framework includes its own `fakeAsync`. Check if the built-in version is sufficient before adding a new dependency.

## Review Guidance

- Verify `UnmockedEndpointException` includes method and path for debugging
- Verify mock HTTP fails loud (throws, not returns empty)
- Verify mock WebSocket uses broadcast StreamController (supports multiple listeners)
- Verify timer control works with both `Timer` and `Stream.periodic`
- Verify all tests are descriptive and test the mock contract, not implementation details

## Activity Log

> **CRITICAL**: Activity log entries MUST be in chronological order (oldest first, newest last).

### How to Add Activity Log Entries

**When adding an entry**:
1. Scroll to the bottom of this file (Activity Log section below "Valid lanes")
2. **APPEND the new entry at the END** (do NOT prepend or insert in middle)
3. Use exact format: `- YYYY-MM-DDTHH:MM:SSZ – agent_id – lane=<lane> – <action>`
4. Timestamp MUST be current time in UTC (ISO-8601 `YYYY-MM-DDTHH:MM:SSZ`) and should be generated without shell commands (prefer `NOW_UTC_ISO` from `check-prerequisites --json --paths-only`)
5. Lane MUST match the frontmatter `lane:` field exactly
6. Agent ID should identify who made the change (claude-sonnet-4-5, codex, etc.)

**Format**:
```
- YYYY-MM-DDTHH:MM:SSZ – <agent_id> – lane=<lane> – <brief action description>
```

**Initial entry**:
- 2026-03-25T23:55:37Z – system – lane=planned – Prompt created.

---

### Updating Lane Status

To change a work package's lane, either:

1. **Edit directly**: Change the `lane:` field in frontmatter AND append activity log entry (at the end)
2. **Use CLI**: `spec-kitty agent tasks move-task WP02 --to <lane> --note "message"` (recommended)

The CLI command updates both frontmatter and activity log automatically.

**Valid lanes**: `planned`, `doing`, `for_review`, `done`
- 2026-03-26T00:57:43Z – headless-impl – shell_pid=53081 – lane=doing – Assigned agent via workflow command
- 2026-03-26T01:05:15Z – headless-impl – shell_pid=53081 – lane=for_review – Ready for review: Mock HTTP client (UnmockedEndpointException on unmocked endpoints), MockWebSocketChannel (sync broadcast stream, event injection, message capture, close lifecycle), TimerControl/testWithTimerControl (fakeAsync wrapper). 21 tests all passing, flutter analyze clean on new files.
- 2026-03-26T01:16:18Z – headless-reviewer – shell_pid=70477 – lane=doing – Started review via workflow command
