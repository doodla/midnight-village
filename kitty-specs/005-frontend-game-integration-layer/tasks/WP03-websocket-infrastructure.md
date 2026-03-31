---
work_package_id: WP03
title: WebSocket Infrastructure
lane: "doing"
dependencies: []
requirement_refs: [FR-003, FR-004]
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this feature were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
base_branch: main
base_commit: ea9875f4bdaf7d92a9e33259489e82d1561ba311
created_at: '2026-03-31T07:54:14.006315+00:00'
subtasks: [T010, T011, T012, T013, T014]
phase: Phase 0 - Foundation
assignee: ''
agent: ''
shell_pid: "56963"
review_status: ''
reviewed_by: ''
history:
- timestamp: '2026-03-31T07:30:22Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
---

# Work Package Prompt: WP03 – WebSocket Infrastructure

## IMPORTANT: Review Feedback Status

**Read this first if you are implementing this task!**

- **Has review feedback?**: Check the `review_status` field above. If it says `has_feedback`, scroll to the **Review Feedback** section immediately.
- **You must address all feedback** before your work is complete.
- **Mark as acknowledged**: When you understand the feedback and begin addressing it, update `review_status: acknowledged` in the frontmatter.

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

- Promote `WebSocketChannelInterface` from test helpers to `lib/core/websocket/`.
- Create `ReconnectingWebSocket` with automatic reconnection and exponential backoff.
- Add `wsUrl` getter to `Env` configuration.
- Create Riverpod provider for WebSocket connection lifecycle.
- Unit tests verify: connection with JWT query param, reconnection after disconnect with exponential backoff (1s->2s->4s->8s->max 30s), connection state stream reports all states, dispose stops reconnection.

## Context & Constraints

- **Research decision R2**: `WebSocketChannelInterface` is the canonical interface. See `research.md` R2.
- **Research decision R5**: JWT passed as URL query parameter (browser WebSocket API doesn't support custom headers).
- **Research decision R8**: Add `web_socket_channel ^3.0.0` as only new dependency.
- **Existing code**: `frontend/test/helpers/mock_websocket.dart:8-20` (interface to promote), `frontend/test/helpers/test_harness.dart:52-59` (provider shape), `frontend/lib/core/config/env.dart:12-23` (URL pattern).
- **Constitution**: Dispose resources via `ref.onDispose`.
- **Governance directive**: TEST_FIRST.
- **No dependencies** — pure infrastructure, depends only on existing `TokenStorage`.

**Implementation command**: `spec-kitty implement WP03`

## Subtasks & Detailed Guidance

### Subtask T010 – Promote `WebSocketChannelInterface` to lib

- **Purpose**: Make the WebSocket interface the canonical contract in `lib/` so both production and test code implement the same interface (R2).
- **Steps**:
  1. Read `frontend/test/helpers/mock_websocket.dart` to understand the current interface definition.
  2. Create `frontend/lib/core/websocket/websocket_channel.dart`.
  3. Move `WebSocketChannelInterface` to this new file.
  4. Add `WebSocketConnectionState` enum: `connecting`, `connected`, `disconnected`, `reconnecting`.
  5. Add `WebSocketEvent` Freezed model for typed event handling:
     ```dart
     @freezed
     abstract class WebSocketEvent with _$WebSocketEvent {
       const factory WebSocketEvent({
         required String type,
         required Map<String, dynamic> data,
       }) = _WebSocketEvent;
       factory WebSocketEvent.fromJson(Map<String, dynamic> json) =>
           _$WebSocketEventFromJson(json);
     }
     ```
  6. Update `frontend/test/helpers/mock_websocket.dart` to import from `lib/` instead of defining locally. Keep `MockWebSocketChannel` in test.
  7. Run `just gen` to generate Freezed code for `WebSocketEvent`.
- **Files**: `frontend/lib/core/websocket/websocket_channel.dart` (new, ~50 lines), `frontend/test/helpers/mock_websocket.dart` (modify imports)
- **Parallel?**: Yes — independent from T011, T012.
- **Notes**: Ensure backward compatibility — `MockWebSocketChannel` in tests should still work with the promoted interface. The mock file should re-export or import from `lib/`.

### Subtask T011 – Create `ReconnectingWebSocket`

- **Purpose**: Production WebSocket client with automatic reconnection and exponential backoff (FR-003, FR-004).
- **Steps**:
  1. Create `frontend/lib/core/websocket/reconnecting_websocket.dart`.
  2. Implement `ReconnectingWebSocket` implementing `WebSocketChannelInterface`.
  3. Constructor takes: `String url`, `TokenStorage tokenStorage`, `Duration initialBackoff = const Duration(seconds: 1)`, `Duration maxBackoff = const Duration(seconds: 30)`.
  4. `connect()`:
     - Read JWT from `tokenStorage.getAccessToken()`.
     - Append token as query parameter: `ws://host/ws/game/123/?token=<jwt>`.
     - Create `WebSocketChannel.connect(uri)` from `web_socket_channel` package.
     - Emit `WebSocketConnectionState.connected` on success.
     - Listen to the channel's stream, forwarding messages.
     - On close/error: emit `disconnected`, start reconnection.
  5. Reconnection loop:
     - Emit `WebSocketConnectionState.reconnecting`.
     - Wait `backoff` duration (exponential: 1s, 2s, 4s, 8s, 16s, max 30s).
     - Re-read JWT from `tokenStorage` on each attempt (picks up refreshed tokens).
     - Attempt `connect()` again.
     - On success: reset backoff to initial value.
     - On failure: double backoff (capped at max).
  6. `connectionState` stream: `StreamController<WebSocketConnectionState>` exposed as a broadcast stream.
  7. `dispose()`: Cancel reconnection timer, close WebSocket channel, close stream controller.
- **Files**: `frontend/lib/core/websocket/reconnecting_websocket.dart` (new, ~100 lines)
- **Parallel?**: Depends on T010 (interface definition).
- **Notes**: Re-reading the JWT on each reconnection attempt is intentional — the token may have been refreshed by `AuthInterceptor` during the disconnect period. The `web_socket_channel` package must be added to `pubspec.yaml` (see T012 notes). Approximately 80-100 lines of implementation.

### Subtask T012 – Add `wsUrl` getter to `Env`

- **Purpose**: Provide WebSocket base URL derived from the existing HTTP API URL.
- **Steps**:
  1. Open `frontend/lib/core/config/env.dart`.
  2. Add a `wsUrl` getter that derives from `apiUrl`:
     - `http://` → `ws://`
     - `https://` → `wss://`
     - Strip `/api` suffix if present (WebSocket endpoints are at root, e.g., `/ws/lobby/ABC/`).
  3. Add `web_socket_channel: ^3.0.0` to `frontend/pubspec.yaml` dependencies.
  4. Run `flutter pub get`.
- **Files**: `frontend/lib/core/config/env.dart` (modify ~5 lines), `frontend/pubspec.yaml` (add dependency)
- **Parallel?**: Yes — independent from T010 and T011.
- **Notes**: Reference existing `apiUrl` pattern in `env.dart:12-23`. The URL transformation should handle both dev (`http://localhost:8000/api`) and potential production (`https://api.example.com/api`) patterns.

### Subtask T013 – Create `webSocketConnectionProvider`

- **Purpose**: Riverpod provider managing WebSocket connection lifecycle with proper disposal (R2, constitution: dispose resources).
- **Steps**:
  1. Create a provider file in `frontend/lib/core/websocket/` (or add to the websocket_channel.dart file if small).
  2. Create `@riverpod` function provider: `webSocketConnection(ref, {required String url})`.
  3. Construct `ReconnectingWebSocket` with the URL and `tokenStorage` from existing provider.
  4. Call `connect()`.
  5. `ref.onDispose(() => socket.dispose())` — ensures cleanup on navigation away.
  6. Return the `ReconnectingWebSocket` instance.
  7. Run `just gen` to regenerate Riverpod code.
- **Files**: `frontend/lib/core/websocket/` (new or modify, ~20 lines)
- **Parallel?**: Depends on T011 (needs `ReconnectingWebSocket`).
- **Notes**: This provider is consumed by `LobbyNotifier` (WP05) and `GameNotifier` (WP07) to get a WebSocket connection for their respective channels.

### Subtask T014 – Tests for WebSocket connection

- **Purpose**: Verify connection lifecycle, backoff timing, state transitions, JWT injection (TEST_FIRST directive).
- **Steps**:
  1. Create `frontend/test/core/websocket/reconnecting_websocket_test.dart`.
  2. **Connection test**: Mock `web_socket_channel`. Verify connection URL includes `?token=<jwt>`.
  3. **Reconnection backoff test**: Use `fake_async` (existing `timer_control.dart` pattern). Simulate disconnect, verify reconnection attempts at 1s, 2s, 4s, 8s intervals. Verify backoff caps at 30s.
  4. **State stream test**: Verify `connectionState` emits: `connecting` → `connected` → (simulate disconnect) → `disconnected` → `reconnecting` → `connected` (simulate reconnect success).
  5. **JWT re-read test**: Mock `TokenStorage` to return different tokens on successive calls. Verify reconnection uses the new token.
  6. **Dispose test**: Call `dispose()`. Verify reconnection timer is cancelled, no further reconnection attempts.
  7. **Backoff reset test**: After successful reconnection, simulate another disconnect. Verify backoff resets to 1s.
- **Files**: `frontend/test/core/websocket/reconnecting_websocket_test.dart` (new, ~180 lines)
- **Parallel?**: Tests can be scaffolded before implementation.
- **Notes**: Use `fake_async` for time-dependent tests. Mock `WebSocketChannel` from `web_socket_channel` package. Reference existing timer test patterns in the codebase.

## Test Strategy

**Directive**: TEST_FIRST.

**Commands**:
```bash
cd frontend && just test     # Run all frontend tests
cd frontend && just check    # Lint + format-check + typecheck
cd frontend && just gen      # Regenerate code after Freezed/Riverpod changes
flutter pub get              # After adding web_socket_channel dependency
```

**Test files**:
- `frontend/test/core/websocket/reconnecting_websocket_test.dart` — All T014 scenarios
- Existing tests in `frontend/test/helpers/` must still pass after interface promotion (T010).

## Risks & Mitigations

- **Risk**: `web_socket_channel` web platform quirks.
  **Mitigation**: Package is well-tested for web; mock in unit tests, verify with integration tests.
- **Risk**: Promoting interface breaks existing test imports.
  **Mitigation**: Update `mock_websocket.dart` to import from `lib/`, keeping backward compatibility. Run existing tests.
- **Risk**: Reconnection flooding server during outage.
  **Mitigation**: Exponential backoff with 30s cap. Dispose on navigation away.

## Review Guidance

- Verify `WebSocketChannelInterface` is properly promoted (not duplicated).
- Verify existing test imports still work after promotion.
- Verify exponential backoff timing: 1s, 2s, 4s, 8s, 16s, 30s (capped).
- Verify JWT is re-read from `TokenStorage` on each reconnection (not cached).
- Verify `dispose()` stops all reconnection activity.
- Verify `ref.onDispose` is used in the provider.
- Run `just check && just test` from `frontend/`.

## Activity Log

> **CRITICAL**: Chronological order (oldest first, newest last).

### Updating Lane Status

1. **Edit directly**: Change `lane:` in frontmatter AND append activity log entry
2. **Use CLI**: `spec-kitty agent tasks move-task WP03 --to <lane> --note "message"`

**Valid lanes**: `planned`, `doing`, `for_review`, `done`

- 2026-03-31T07:30:22Z – system – lane=planned – Prompt created.
