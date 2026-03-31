---
work_package_id: WP11
title: Reconnection & Game Resume
lane: "doing"
dependencies:
- WP03
requirement_refs:
- FR-005
- FR-013
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this feature were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
base_branch: 005-frontend-game-integration-layer-WP03
base_commit: 4c22703786ff7c9f6f7e8e9ea26cfc37f60c8e29
created_at: '2026-03-31T17:09:36.788841+00:00'
subtasks: [T051, T052, T053, T054, T055]
phase: Phase 3 - Polish
assignee: ''
agent: headless-impl
shell_pid: "89103"
review_status: ''
reviewed_by: ''
history:
- timestamp: '2026-03-31T07:30:22Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
---

# Work Package Prompt: WP11 – Reconnection & Game Resume

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

- Build `ReconnectionOverlay` that appears on WebSocket disconnect and auto-dismisses on reconnect.
- Implement app startup game detection: check for active game on launch, redirect to game screen.
- Handle reconnection state restoration: re-fetch game state, sync timer, restore correct phase/sub-view.
- Performance target: <5s reconnection recovery (SC-003).
- Widget tests verify overlay behavior and game resume scenarios.

## Context & Constraints

- **Spec**: `spec.md` — Reconnection overlay description, User Story 7 (reconnection during night phase).
- **Existing infrastructure**: `ReconnectingWebSocket` (WP03) provides `connectionState` stream with `WebSocketConnectionState` enum. Auth redirect guard (WP04) provides the integration point for startup game detection.
- **API contracts**: `contracts/api-contracts.md` — `GET /api/onuw/me/current-game/` for startup detection, `GET /onuw/games/<id>/me/` for state restoration (returns full `GameMeResponse`).
- **Constitution**: Server-authoritative (re-fetch state from server, don't reconstruct from cached WS events).
- **Governance directive**: TEST_FIRST.
- **Dependencies**: WP03 (`WebSocketConnectionState` stream), WP07 (`GameNotifier` for state restoration).

**Implementation command**: `spec-kitty implement WP11 --base WP07`

## Subtasks & Detailed Guidance

### Subtask T051 – Build `ReconnectionOverlay`

- **Purpose**: Visual feedback during WebSocket disconnection without blocking state updates (FR-013).
- **Steps**:
  1. Create `frontend/lib/features/game/presentation/reconnection_overlay.dart`.
  2. Design: Semi-transparent overlay (`ColoredBox` with opacity or `BackdropFilter`).
  3. Content: `MvLoading` spinner + "Reconnecting..." text using `AppTokens` typography.
  4. Positioning: `Positioned.fill` overlay on top of the game container — does NOT replace the screen. Underlying widgets continue to receive state updates from re-fetched data.
  5. The overlay is a presentational widget that takes a `bool isVisible` prop. It does NOT manage its own WebSocket state.
- **Files**: `frontend/lib/features/game/presentation/reconnection_overlay.dart` (new, ~40 lines)
- **Parallel?**: Yes — independent from T052.
- **Notes**: Keep the overlay simple — it's a visual cue, not a state manager. The parent (`GameContainerScreen`) decides when to show/hide it based on `WebSocketConnectionState`. The underlying game view should still be partially visible through the semi-transparent overlay.

### Subtask T052 – Implement app startup game detection

- **Purpose**: Resume an in-progress game on app launch (FR-005).
- **Steps**:
  1. Integrate with the auth redirect guard from WP04 (T016).
  2. On successful authentication (stored session restore or fresh login):
     - Call `GET /api/onuw/me/current-game/`.
     - If response has `game_id`: navigate to `/game/:id`.
     - If response has `"game": null`: continue to home screen.
  3. This check should happen once on auth state change (not on every navigation).
  4. Use `AuthenticatedClient` for the API call.
- **Files**: `frontend/lib/core/router/app_router.dart` (modify redirect guard, ~15 lines)
- **Parallel?**: Yes — independent from T051.
- **Notes**: This extends the auth redirect guard from WP04. The `current-game` check was already planned in T016 — this subtask ensures it's fully implemented and tested. Cache the result to avoid repeated API calls.

### Subtask T053 – Handle reconnection state restoration

- **Purpose**: After WS reconnects, restore the correct game state from the server (SC-003).
- **Steps**:
  1. In `GameNotifier`, when WebSocket reconnects (`connectionState` transitions to `connected` after `disconnected`/`reconnecting`):
     - Re-fetch full game state via `GameService.getGameState(gameId)` — `GET /onuw/games/<id>/me/`.
     - The `GameMeResponse` contains everything needed: `phase`, `current_wave`, `deadline`, `your_role`, `action_prompt`, `players`, `has_voted`.
     - Rebuild `GameSessionState` from this response.
  2. Timer sync: `deadline` from the response is the server's authoritative deadline. `TimerProvider` will automatically compute the correct remaining time.
  3. Correct phase/sub-view restoration:
     - `phase` determines which phase view.
     - Night phase: if `has_acted: true` and no `action_prompt` → `nightSubView = waiting` (already acted).
     - Night phase: if `action_prompt` present → `nightSubView = actionPrompt` (action pending).
     - Voting phase: if `has_voted: true` → show locked `VoteSubmission` with progress from player list.
  4. Performance: Target <5s total recovery time (reconnection + state fetch + render).
- **Files**: `frontend/lib/features/game/presentation/game_notifier.dart` (add reconnection handler, ~30 lines)
- **Parallel?**: Depends on WP07 `GameNotifier` structure.
- **Notes**: Re-fetching full state is intentional — it's more reliable than trying to reconstruct from missed WS events. The server state is always authoritative. One-time `action_result` events that were missed during disconnect cannot be replayed — the player sees the current state (waiting or next phase) instead.

### Subtask T054 – Wire reconnection overlay to `WebSocketConnectionState`

- **Purpose**: Show/hide the overlay based on connection state (FR-013).
- **Steps**:
  1. In `GameContainerScreen`:
     - Watch the `WebSocketConnectionState` from the game's `ReconnectingWebSocket` instance.
     - Show `ReconnectionOverlay(isVisible: true)` when state is `disconnected` or `reconnecting`.
     - Hide overlay (`isVisible: false`) when state is `connected`.
  2. Use a `Stack` to layer the overlay on top of the game content.
  3. If phase changed during disconnect, the overlay dismisses into the new phase view (state was re-fetched in T053).
- **Files**: `frontend/lib/features/game/presentation/game_container_screen.dart` (modify ~15 lines)
- **Parallel?**: Depends on T051 (overlay widget), T053 (state restoration).
- **Notes**: The overlay and the state restoration are independent concerns that work together. The overlay provides visual feedback. The state restoration ensures the game is correct when the overlay dismisses.

### Subtask T055 – Tests

- **Purpose**: Verify reconnection behavior and game resume (TEST_FIRST directive).
- **Steps**:
  1. Create `frontend/test/features/game/presentation/reconnection_overlay_test.dart`:
     - Overlay visible when `isVisible: true`.
     - Overlay hidden when `isVisible: false`.
     - Shows spinner and "Reconnecting..." text.
     - Overlay does not block tap events on underlying content (optional — depends on design).
  2. Create `frontend/test/features/game/presentation/game_resume_test.dart`:
     - **Startup detection**: Mock `current-game` endpoint returning active game. Verify navigation to `/game/:id`.
     - **Startup no game**: Mock `current-game` returning null. Verify stays on home.
     - **Reconnection state restore**: Mock WS reconnection. Verify `getGameState` called after reconnect. Verify state updated from response.
     - **Already acted**: Mock reconnected state with `has_acted: true`, no `action_prompt`. Verify `nightSubView = waiting`.
     - **Already voted**: Mock reconnected state with `has_voted: true`. Verify locked `VoteSubmission`.
     - **Phase changed during disconnect**: Mock state with different phase than before disconnect. Verify correct new phase rendered.
- **Files**: `frontend/test/features/game/presentation/reconnection_overlay_test.dart`, `frontend/test/features/game/presentation/game_resume_test.dart` (new, ~180 lines total)
- **Parallel?**: Can scaffold before implementation.
- **Notes**: Reconnection state restore tests are the most critical — they verify the app handles the most fragile user scenario (lost connection mid-game).

## Test Strategy

**Directive**: TEST_FIRST.

**Commands**:
```bash
cd frontend && just test
cd frontend && just check
```

**Order**: Overlay tests first (simple widget), then game resume tests (more complex state).

## Risks & Mitigations

- **Risk**: Reconnection during phase transition causes stale display.
  **Mitigation**: Re-fetch full state on reconnect. Server state is authoritative.
- **Risk**: Multiple reconnection attempts flood the server.
  **Mitigation**: Exponential backoff in `ReconnectingWebSocket` (WP03).
- **Risk**: Missed one-time events (action_result) during disconnect.
  **Mitigation**: Accept that some events are lost. Re-fetched state shows the current reality. Player sees their current state, not a replay.

## Review Guidance

- Verify overlay is a positioned layer, not a screen replacement.
- Verify state restoration re-fetches from server (not cached/reconstructed).
- Verify `has_acted` + no `action_prompt` → waiting sub-view (not re-prompting).
- Verify `has_voted` → locked vote submission.
- Verify startup game detection integrates with auth redirect guard.
- Verify <5s recovery time target is achievable with the implementation.
- Run `just check && just test` from `frontend/`.

## Activity Log

> **CRITICAL**: Chronological order (oldest first, newest last).

### Updating Lane Status

1. **Edit directly**: Change `lane:` in frontmatter AND append activity log entry
2. **Use CLI**: `spec-kitty agent tasks move-task WP11 --to <lane> --note "message"`

**Valid lanes**: `planned`, `doing`, `for_review`, `done`

- 2026-03-31T07:30:22Z – system – lane=planned – Prompt created.
- 2026-03-31T14:40:18Z – headless-impl – shell_pid=99269 – lane=doing – Assigned agent via workflow command
