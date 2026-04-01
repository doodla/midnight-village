---
work_package_id: WP07
title: Game Core — Domain, Service & Container
lane: done
dependencies:
- WP02
requirement_refs: [FR-007, FR-009, FR-014, FR-017, FR-023]
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this feature were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
base_branch: 005-frontend-game-integration-layer-WP02
base_commit: cafb0c799c5e735ea80dcec8d4cd1a16e42d9114
created_at: '2026-03-31T17:09:35.424030+00:00'
subtasks: [T028, T029, T030, T031, T032, T033]
phase: Phase 1 - Feature Data Layers
assignee: ''
agent: headless-reviewer
shell_pid: '13289'
review_status: approved
reviewed_by: Sridhar Vadlamani
review_feedback: feedback://005-frontend-game-integration-layer/WP07/20260331T173702Z-005af141.md
history:
- timestamp: '2026-03-31T07:30:22Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
---

# Work Package Prompt: WP07 – Game Core — Domain, Service & Container

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

- Create all game domain Freezed models: `GameSessionState`, `YourRole`, `GamePlayer`, `ActionPrompt`, `ActionResult`, `NightSubView`, `VoteProgress`, `VoteRevealData`.
- Create `GameService` for all game HTTP operations.
- Create `GameNotifier` as `@riverpod` `AsyncNotifier` handling all 9+ WebSocket event types and the `NightSubView` state machine.
- Create `TimerProvider` — deadline-driven countdown stream.
- Build `GameContainerScreen` — phase-switching shell that renders correct sub-view based on game phase.
- Thorough unit tests for each component.

## Context & Constraints

- **Research decisions**: R3 (AsyncNotifier), R6 (night sub-view state machine, not URL routing), R7 (extend existing Freezed models).
- **Data models**: `data-model.md` — all game domain model definitions.
- **API contracts**: `contracts/api-contracts.md` — Game REST + WS endpoints, all event schemas.
- **Constitution**: Server-authoritative (no game logic client-side), state machine transitions server-driven, dispose resources.
- **Governance directive**: TEST_FIRST.
- **Dependencies**: WP02 (`AuthenticatedClient`), WP03 (`ReconnectingWebSocket`, `WebSocketEvent`).

**Implementation command**: `spec-kitty implement WP07 --base WP02`

## Subtasks & Detailed Guidance

### Subtask T028 – Create game domain models

- **Purpose**: Define all Freezed models for game state management (FR-007).
- **Steps**:
  1. Create `frontend/lib/features/game/domain/game_session_state.dart`:
     ```dart
     @freezed
     abstract class GamePlayer with _$GamePlayer {
       const factory GamePlayer({
         required int playerId,
         required String displayName,
         @Default(false) bool hasVoted,
       }) = _GamePlayer;
       factory GamePlayer.fromJson(Map<String, dynamic> json) =>
           _$GamePlayerFromJson(json);
     }

     @freezed
     abstract class YourRole with _$YourRole {
       const factory YourRole({
         required String originalRole,
         required bool hasActed,
         String? currentRole,
       }) = _YourRole;
       factory YourRole.fromJson(Map<String, dynamic> json) =>
           _$YourRoleFromJson(json);
     }

     @freezed
     abstract class GameSessionState with _$GameSessionState {
       const factory GameSessionState({
         required String gameId,
         required String phase,
         int? currentWave,
         DateTime? deadline,
         required YourRole yourRole,
         required bool hasVoted,
         required List<GamePlayer> players,
         ActionPrompt? actionPrompt,
         ActionResult? lastActionResult,
         required NightSubView nightSubView,
         required List<RoleInGame> rolesInGame,
       }) = _GameSessionState;
       factory GameSessionState.fromJson(Map<String, dynamic> json) =>
           _$GameSessionStateFromJson(json);
     }
     ```
  2. Create `frontend/lib/features/game/domain/night_state.dart`:
     - `NightSubView` enum: `roleReveal`, `waiting`, `actionPrompt`, `seerChoice`, `actionResult`, `loneWerewolfPeek`
     - `ActionPrompt` Freezed: `roleActingAs` (String), `actionTypes` (List), `validTargets` (Map)
     - `ActionResult` Freezed: `actionType` (String), `revealedInfo` (Map)
     - `RoleInGame` Freezed: `role` (String), `count` (int)
  3. Create `frontend/lib/features/game/domain/voting_state.dart`:
     - `VoteProgress` Freezed: `playerVoted` (Map<int, bool>), `totalPlayers` (int)
     - `VoteRevealData` Freezed: `votes` (Map<String, int?> — voter ID → target ID, null for abstain)
  4. Run `just gen`.
- **Files**: `frontend/lib/features/game/domain/game_session_state.dart`, `night_state.dart`, `voting_state.dart` (new, ~120 lines total)
- **Parallel?**: Yes — independent from T031 (timer).
- **Notes**: Field names must align with the JSON from `GameMeResponse` in `contracts/api-contracts.md`. The `NightSubView` enum is frontend-only — it's derived from WS events, not from the server response directly.

### Subtask T029 – Create `GameService`

- **Purpose**: HTTP calls for all game actions (FR-014).
- **Steps**:
  1. Create `frontend/lib/features/game/data/game_service.dart`.
  2. Constructor takes `AuthenticatedClient`.
  3. Methods per API contracts:
     - `getGameState(String gameId)` → GET `/onuw/games/<id>/me/` → returns `GameSessionState`
     - `submitAction(String gameId, String actionType, Map<String, dynamic> targets)` → POST `/onuw/games/<id>/action/` with `ActionRequest` body. Handle 409 as success (already acted).
     - `submitVote(String gameId, int targetPlayerId)` → POST `/onuw/games/<id>/vote/` with `{"target_player_id": targetPlayerId}`. Handle 409 as success (already voted).
     - `endDiscussion(String gameId)` → POST `/onuw/games/<id>/end-discussion/`
     - `fetchResults(String gameId)` → GET `/onuw/games/<id>/results/` → returns `ResultsResponse`
  4. Create `@riverpod` provider.
- **Files**: `frontend/lib/features/game/data/game_service.dart` (new, ~60 lines)
- **Parallel?**: Depends on T028 (uses model types).
- **Notes**: 409 responses on `submitAction` and `submitVote` should be treated as success (idempotent — player already acted). Error 400 on `submitAction` means invalid action for current state — surface to user.

### Subtask T030 – Create `GameNotifier`

- **Purpose**: The core game state machine handling all WebSocket events and exposing action methods (FR-007, FR-023).
- **Steps**:
  1. Create `frontend/lib/features/game/presentation/game_notifier.dart`.
  2. `@riverpod` `AsyncNotifier` family keyed by game ID:
     ```dart
     @riverpod
     class GameNotifier extends _$GameNotifier {
       @override
       Future<GameSessionState> build(String gameId) async {
         // 1. Fetch initial state via GameService.getGameState(gameId)
         // 2. Connect game WebSocket
         // 3. Listen to WS events
         // 4. ref.onDispose to close WS
       }
     }
     ```
  3. **WebSocket event handlers** (each is a discrete method):
     - `_handleWaveStart(data)` → update `currentWave`, `deadline`. If player has action this wave, `action_prompt` event follows. If not, `wave_waiting` sets `nightSubView = waiting`.
     - `_handleActionPrompt(data)` → If `actionTypes.length > 1`: set `nightSubView = seerChoice`. If single type: set `nightSubView = actionPrompt`. Update `actionPrompt` state. Set `roleActingAs` for Doppelganger display.
     - `_handleActionResult(data)` → set `nightSubView = actionResult`, store `lastActionResult`.
     - `_handleWaveComplete(data)` → clear prompt/result, set `nightSubView = waiting`.
     - `_handleWaveWaiting(data)` → set `nightSubView = waiting` (player has no action this wave).
     - `_handlePhaseChange(data)` → update `phase`, `deadline`. Container transitions to new view.
     - `_handleVoteSubmitted(data)` → mark `player_id` as voted in `VoteProgress`.
     - `_handleVoteReveal(data)` → store vote mapping, start 5s timeout for `game_results`. If timeout fires, fallback to `fetchResults()` via REST.
     - `_handleGameResults(data)` → cancel timeout, fetch full results via `GameService.fetchResults(gameId)`.
  4. **Exposed methods**:
     - `submitAction(String actionType, Map<String, dynamic> targets)` → calls `GameService.submitAction()`
     - `submitVote(int targetPlayerId)` → calls `GameService.submitVote()`
     - `endDiscussion()` → calls `GameService.endDiscussion()`
  5. **Doppelganger multi-step** (FR-023): After first `action_result` for Doppelganger, if the copied role has an immediate follow-up, the server sends another `action_prompt` in the same wave. The handler processes this naturally — each `action_prompt` event triggers the same state machine transition.
- **Files**: `frontend/lib/features/game/presentation/game_notifier.dart` (new, ~200 lines)
- **Parallel?**: Depends on T028 (models), T029 (service).
- **Notes**: This is the most complex piece. Each event handler should be a discrete, testable method. The `NightSubView` state machine is display-only — it determines which view the `GameContainerScreen` renders. The 5s timeout on `vote_reveal` → `game_results` ensures progress if the WebSocket event is missed.

### Subtask T031 – Create `TimerProvider`

- **Purpose**: Deadline-driven countdown for game phase timers (FR-017).
- **Steps**:
  1. Create `frontend/lib/features/game/presentation/timer_provider.dart`.
  2. `@riverpod` stream provider:
     ```dart
     @riverpod
     Stream<Duration> gameTimer(GameTimerRef ref, DateTime? deadline) async* {
       if (deadline == null) return;
       while (true) {
         final remaining = deadline.difference(DateTime.now());
         if (remaining <= Duration.zero) {
           yield Duration.zero;
           return;
         }
         yield remaining;
         await Future.delayed(const Duration(seconds: 1));
       }
     }
     ```
  3. Returns `Duration.zero` when expired. Returns nothing (empty stream) when deadline is null.
- **Files**: `frontend/lib/features/game/presentation/timer_provider.dart` (new, ~25 lines)
- **Parallel?**: Yes — independent from all other subtasks.
- **Notes**: The `GameTimer` existing widget expects a `Duration` — this provider supplies it. Consumers use `ref.watch(gameTimerProvider(deadline))`. The timer ticks every second, computing `deadline - now`. Uses `Stream.periodic` or manual `Future.delayed` loop.

### Subtask T032 – Build `GameContainerScreen`

- **Purpose**: Phase-switching shell that renders the correct sub-view based on current game phase and night sub-view state (FR-009).
- **Steps**:
  1. Create `frontend/lib/features/game/presentation/game_container_screen.dart`.
  2. Layout:
     - `MvScaffold` with `VillageAppBar` (phase variant) and `AtmosphericBackground` (current phase).
     - `PhaseIndicator` at top showing game progress.
     - Body: Switch on `gameState.phase`:
       - `"night"` → switch on `gameState.nightSubView` (roleReveal, waiting, actionPrompt, seerChoice, actionResult, loneWerewolfPeek) → render corresponding view widget.
       - `"discussion"` → render `DiscussionView`.
       - `"voting"` → render `VoteSubmission` (wired in WP09).
       - `"results"` → render `GameResults` (wired in WP10).
     - Animated transitions between phases (use `AnimatedSwitcher` or similar).
  3. Use `ref.watch(gameNotifierProvider(gameId))` for state.
  4. Handle `AsyncValue` loading/error states.
  5. **Initially**: Render placeholder widgets for views not yet built (WP08, WP09, WP10). Use `Center(child: Text('Night Waiting'))` etc.
- **Files**: `frontend/lib/features/game/presentation/game_container_screen.dart` (new, ~100 lines)
- **Parallel?**: Depends on T030 (GameNotifier state shape).
- **Notes**: This is the game's "router" — but it's a widget, not a URL router (R6). Phase transitions are driven by WebSocket events via `GameNotifier`. The `nightSubView` enum gives fine-grained control over which night view to show. Update the route placeholder from WP04 to render this screen.

### Subtask T033 – Tests

- **Purpose**: Thorough unit tests for all game core components (TEST_FIRST directive).
- **Steps**:
  1. **Model tests** in `frontend/test/features/game/domain/game_models_test.dart`:
     - JSON serialization roundtrip for `GameSessionState`, `YourRole`, `GamePlayer`, `ActionPrompt`, `ActionResult`, `VoteProgress`.
     - Verify `fromJson` handles `GameMeResponse` format.
  2. **Service tests** in `frontend/test/features/game/data/game_service_test.dart`:
     - Mock `AuthenticatedClient`. Verify each method calls correct endpoint.
     - Verify 409 on `submitAction` treated as success.
     - Verify 409 on `submitVote` treated as success.
  3. **Notifier tests** in `frontend/test/features/game/presentation/game_notifier_test.dart`:
     - **Per-event tests**: Each WS event type in isolation. Verify state mutation.
     - `wave_start` → updates `currentWave`, `deadline`.
     - `action_prompt` with 2 action types → `nightSubView = seerChoice`.
     - `action_prompt` with 1 action type → `nightSubView = actionPrompt`.
     - `action_result` → `nightSubView = actionResult`, stores result.
     - `wave_complete` → clears prompt/result, `nightSubView = waiting`.
     - `phase_change` to discussion → updates `phase`, `deadline`.
     - `vote_submitted` → marks player as voted.
     - `vote_reveal` → stores vote mapping.
     - `game_results` → triggers results fetch.
     - **Sequence tests**: `wave_start` → `action_prompt` → `action_result` → `wave_complete` (full wave cycle).
     - **Doppelganger multi-step**: `action_result` followed by another `action_prompt` in same wave.
  4. **Timer tests** in `frontend/test/features/game/presentation/timer_provider_test.dart`:
     - Use `fake_async`. Set deadline 10s in future. Verify stream ticks down 10, 9, 8... 0.
     - Null deadline returns empty stream.
     - Past deadline yields `Duration.zero` immediately.
  5. **Container tests** in `frontend/test/features/game/presentation/game_container_screen_test.dart`:
     - Mock `GameNotifier` with different phases. Verify correct placeholder view rendered.
     - Verify `PhaseIndicator` shown.
- **Files**: 5 test files (new, ~400 lines total)
- **Parallel?**: Model tests and timer tests can be written immediately. Others as implementation scaffolds.
- **Notes**: GameNotifier tests are the most critical — test each event handler in isolation, then test sequences. Use `mocktail` for mocking WS events. Use `fake_async` for timer tests.

## Test Strategy

**Directive**: TEST_FIRST.

**Commands**:
```bash
cd frontend && just test
cd frontend && just check
cd frontend && just gen
```

**Order**: Model tests first (pure data), timer tests (pure stream logic), then service tests (mock HTTP), then notifier tests (mock service + WS, most complex), then container screen tests (widget tests).

## Risks & Mitigations

- **Risk**: GameNotifier complexity — many event types and state transitions.
  **Mitigation**: Thorough per-event unit tests. Each handler is a discrete method.
- **Risk**: Race condition between `vote_reveal` and `game_results` events.
  **Mitigation**: 5-second timeout with REST fallback per spec.
- **Risk**: Doppelganger multi-step flow creates state machine edge cases.
  **Mitigation**: Each `action_prompt` event triggers the same handler regardless of context. Test the sequence explicitly.

## Review Guidance

- Verify `GameNotifier` handles all 9 WS event types with correct state mutations.
- Verify `NightSubView` state machine transitions are driven by WS events, not by widget logic.
- Verify `TimerProvider` computes from server deadline (not local countdown).
- Verify `GameContainerScreen` switches on both `phase` and `nightSubView`.
- Verify 409 responses on action/vote submissions treated as success.
- Verify `vote_reveal` → `game_results` 5s timeout with REST fallback.
- Run `just check && just test` from `frontend/`.

## Activity Log

> **CRITICAL**: Chronological order (oldest first, newest last).

### Updating Lane Status

1. **Edit directly**: Change `lane:` in frontmatter AND append activity log entry
2. **Use CLI**: `spec-kitty agent tasks move-task WP07 --to <lane> --note "message"`

**Valid lanes**: `planned`, `doing`, `for_review`, `done`

- 2026-03-31T07:30:22Z – system – lane=planned – Prompt created.
- 2026-03-31T14:38:17Z – headless-impl – shell_pid=95895 – lane=doing – Assigned agent via workflow command
- 2026-03-31T17:30:12Z – headless-impl – shell_pid=89103 – lane=for_review – Ready for review: All 6 subtasks complete. Domain models with snake_case JSON, GameService with 409 idempotency, GameNotifier handling all 9 WS events, TimerProvider, GameContainerScreen with phase switching. 67 tests passing, zero analysis issues.
- 2026-03-31T17:33:32Z – headless-reviewer – shell_pid=16462 – lane=doing – Started review via workflow command
- 2026-03-31T17:37:03Z – headless-reviewer – shell_pid=16462 – lane=planned – Moved to planned
- 2026-04-01T00:59:34Z – headless-reviewer – shell_pid=16462 – lane=for_review – Addressed review: added roleReveal, has_voted, fixed analyzer
- 2026-04-01T01:02:15Z – headless-reviewer – shell_pid=13289 – lane=doing – Started review via workflow command
- 2026-04-01T01:06:26Z – headless-reviewer – shell_pid=13289 – lane=approved – Review passed: all 446 tests pass, analyzer clean, all 9 WS event types handled, 409 idempotency correct, vote_reveal timeout+fallback implemented, GameContainerScreen switches on phase+nightSubView.
