---
work_package_id: WP04
title: Reusable Test Harnesses
lane: "doing"
dependencies: [WP01, WP02]
requirement_refs: [FR-007, FR-017]
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this feature were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
base_branch: 002-flutter-ui-test-infrastructure-WP04-merge-base
base_commit: 3f008453aba83782e288a777d41d1e8a405583a3
created_at: '2026-03-26T01:27:48.218351+00:00'
subtasks:
- T016
- T017
- T018
- T019
- T020
phase: Phase 1 - Core Layers
assignee: ''
agent: ''
shell_pid: "83324"
review_status: ''
reviewed_by: ''
history:
- timestamp: '2026-03-25T23:55:37Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
---

# Work Package Prompt: WP04 – Reusable Test Harnesses

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

Build builder-pattern test harnesses that reduce per-test setup to 5 lines or fewer for common scenarios: authenticated user, game phase state, and full-app bootstrap with mocks.

**Success criteria**:
- `pumpAuthenticated(widget)` renders a widget requiring auth state in 3-5 lines of setup
- `pumpWithGameState(widget, phase:, players:)` simulates a voting phase with 5 players
- `pumpApp()` boots the full app with mock HTTP, mock WebSocket, and configurable routes
- All harnesses compose on top of `pumpWithTokens` (not replace it)
- Example tests demonstrate each harness in action

**Implementation command**: `spec-kitty implement WP04 --base WP02`

## Context & Constraints

- **Spec**: `kitty-specs/002-flutter-ui-test-infrastructure/spec.md` — User Story 3; FR-007, FR-017
- **Plan**: `kitty-specs/002-flutter-ui-test-infrastructure/plan.md` — Decisions #6, #10
- **Depends on WP01**: Deterministic rendering foundation (`flutter_test_config.dart`, `pumpWithTokens` golden extensions)
- **Depends on WP02**: Mock HTTP (`MockHttpClient`), Mock WebSocket (`MockWebSocketChannel`), Timer control (`TimerControl`)
- **Existing helper**: `frontend/test/design_system/test_helpers/pump_with_tokens.dart` — harnesses COMPOSE on top of this, not replace
- **Riverpod pattern**: Use `ProviderScope(overrides: [...])` following the established `pumpWithTokens` pattern
- **Constraint**: Provider override API follows Riverpod 2.x/3.x `overrideWithValue` or `overrideWith` patterns
- **Constraint**: Game state types may not exist in the frontend yet — use minimal placeholder types or adapt to whatever types exist

## Subtasks & Detailed Guidance

### Subtask T016 – Create `pump_app.dart` (full-app pump)

- **Purpose**: Provide a single-call extension for integration-style widget tests that need the full app with routing, mock HTTP, mock WebSocket, and all providers.
- **Steps**:
  1. Create `frontend/test/helpers/pump_app.dart`
  2. Define `extension PumpAppExtension on WidgetTester`:
     ```dart
     Future<void> pumpApp({
       MockHttpClient? httpClient,
       MockWebSocketChannel? webSocket,
       String? initialRoute,
       List<Override>? overrides,
     }) async {
       final mockHttp = httpClient ?? MockHttpClient();
       final mockWs = webSocket ?? MockWebSocketChannel();

       await pumpWidget(
         ProviderScope(
           overrides: [
             httpClientProvider.overrideWithValue(mockHttp.dio),
             webSocketProvider.overrideWithValue(mockWs),
             ...?overrides,
           ],
           child: MidnightVillageApp(
             initialRoute: initialRoute,
           ),
         ),
       );
       await pumpAndSettle();
     }
     ```
  3. Check `frontend/lib/` for:
     - The main app widget name (likely `MidnightVillageApp` or similar)
     - Provider names for HTTP client and WebSocket
     - Router configuration (GoRouter setup)
  4. Accept optional `overrides` for test-specific customization
- **Files**: `frontend/test/helpers/pump_app.dart` (new, ~60 lines)
- **Parallel?**: Yes — can proceed in parallel with T017
- **Notes**: This is the heaviest harness — it boots the entire app. Most tests should prefer `pumpAuthenticated` or `pumpWithGameState` for speed. `pumpApp` is for tests that need routing and full DI context. Check if the app widget accepts an `initialRoute` parameter; if not, use `GoRouter.overrideWith`.

### Subtask T017 – Create `test_harness.dart` (auth + game state harnesses)

- **Purpose**: Provide lightweight harness extensions for the two most common test scenarios: authenticated user and game phase state.
- **Steps**:
  1. Create `frontend/test/helpers/test_harness.dart`
  2. Define `pumpAuthenticated` extension:
     ```dart
     extension TestHarnessExtension on WidgetTester {
       Future<void> pumpAuthenticated(
         Widget widget, {
         String playerName = 'TestPlayer',
         String token = 'test-jwt-token',
         List<Override>? overrides,
       }) async {
         await pumpWithTokens(
           widget,
           overrides: [
             tokenStorageProvider.overrideWithValue(FakeTokenStorage(token)),
             currentUserProvider.overrideWithValue(
               AsyncData(User(name: playerName, id: 'test-user-id')),
             ),
             ...?overrides,
           ],
         );
       }
     ```
  3. Define `pumpWithGameState` extension:
     ```dart
       Future<void> pumpWithGameState(
         Widget widget, {
         required GamePhase phase,
         required List<Player> players,
         MockWebSocketChannel? webSocket,
         List<Override>? overrides,
       }) async {
         final mockWs = webSocket ?? MockWebSocketChannel();
         await pumpAuthenticated(
           widget,
           overrides: [
             gameStateProvider.overrideWithValue(
               AsyncData(GameState(phase: phase, players: players)),
             ),
             webSocketProvider.overrideWithValue(mockWs),
             ...?overrides,
           ],
         );
       }
     ```
  4. Check `frontend/lib/` for actual provider names, user model, and game state types
  5. If game state types don't exist yet, create minimal placeholder types:
     ```dart
     // Placeholder until real types exist
     enum GamePhase { lobby, night, discussion, voting, results }
     class Player { final String name; final String id; Player({required this.name, required this.id}); }
     ```
- **Files**: `frontend/test/helpers/test_harness.dart` (new, ~100 lines)
- **Parallel?**: Yes — can proceed in parallel with T016
- **Notes**: The key design principle is composition: `pumpWithGameState` calls `pumpAuthenticated` which calls `pumpWithTokens`. Each layer adds its overrides. The `overrides` parameter allows test-specific customization without breaking the composition chain.

### Subtask T018 – Harness example: authenticated state

- **Purpose**: Demonstrate the `pumpAuthenticated` harness with a working example test that other developers can copy.
- **Steps**:
  1. Create `frontend/test/helpers/examples/authenticated_harness_test.dart`
  2. Write a test that:
     - Uses `pumpAuthenticated` with a widget that displays the user's name
     - Asserts the user name is rendered
     - Demonstrates that auth state is pre-configured in 3-5 lines of setup
     ```dart
     testWidgets('pumpAuthenticated provides logged-in user state', (tester) async {
       await tester.pumpAuthenticated(
         const UserProfileWidget(), // or whatever widget shows user info
         playerName: 'TestHero',
       );

       expect(find.text('TestHero'), findsOneWidget);
     });
     ```
  3. Include descriptive comments explaining the harness pattern for copy-paste reuse
- **Files**: `frontend/test/helpers/examples/authenticated_harness_test.dart` (new, ~40 lines)
- **Parallel?**: No — depends on T017
- **Notes**: The example widget should be something that already exists and requires auth state. If no such widget exists, create a minimal test widget inline.

### Subtask T019 – Harness example: game phase state

- **Purpose**: Demonstrate the `pumpWithGameState` harness with a working example test for a game scenario.
- **Steps**:
  1. Create `frontend/test/helpers/examples/game_state_harness_test.dart`
  2. Write a test that:
     - Configures voting phase with 5 players using `pumpWithGameState`
     - Renders a game widget (or minimal test widget showing player names and phase)
     - Asserts player names appear and phase indicator matches
     ```dart
     testWidgets('pumpWithGameState provides game phase and players', (tester) async {
       final players = List.generate(5, (i) => Player(name: 'Player $i', id: 'id-$i'));

       await tester.pumpWithGameState(
         const GamePhaseWidget(), // or test widget
         phase: GamePhase.voting,
         players: players,
       );

       expect(find.text('Player 0'), findsOneWidget);
       expect(find.text('Voting'), findsOneWidget);
     });
     ```
  3. Include comments explaining how to customize the harness for different phases
- **Files**: `frontend/test/helpers/examples/game_state_harness_test.dart` (new, ~50 lines)
- **Parallel?**: No — depends on T017
- **Notes**: If game widgets don't exist yet, create a minimal test widget that reads from the game state provider and displays the phase and player names. The example should demonstrate the harness API, not test a real widget.

### Subtask T020 – Harness example: WebSocket event updates UI

- **Purpose**: Demonstrate how to use the mock WebSocket via the harness to emit events and verify UI updates.
- **Steps**:
  1. Create `frontend/test/helpers/examples/websocket_harness_test.dart`
  2. Write a test that:
     - Creates a `MockWebSocketChannel`
     - Uses `pumpWithGameState` with the mock WebSocket
     - Emits a `phase_change` event via `mockWs.addServerEvent(...)`
     - Pumps the widget tree to process the event
     - Asserts the UI reflects the phase change
     ```dart
     testWidgets('WebSocket phase_change event updates UI', (tester) async {
       final mockWs = MockWebSocketChannel();

       await tester.pumpWithGameState(
         const GamePhaseWidget(),
         phase: GamePhase.discussion,
         players: testPlayers,
         webSocket: mockWs,
       );

       // Simulate server event
       mockWs.addServerEvent(jsonEncode({'type': 'phase_change', 'phase': 'voting'}));
       await tester.pumpAndSettle();

       expect(find.text('Voting'), findsOneWidget);
     });
     ```
  3. Include comments explaining the event injection pattern
- **Files**: `frontend/test/helpers/examples/websocket_harness_test.dart` (new, ~50 lines)
- **Parallel?**: No — depends on T016, T017
- **Notes**: The event format should match the backend's WebSocket contract. If the event format is not yet defined on the frontend, use a reasonable JSON structure. The test may need to mock the state management layer that processes WebSocket events.

## Test Strategy

The example tests ARE the test strategy — they validate the harnesses by using them:

1. **T018**: Authenticated harness works (user state pre-loaded, widget renders correctly)
2. **T019**: Game state harness works (phase and players configured, UI reflects state)
3. **T020**: WebSocket event injection works (event emitted, UI updates)
4. **Regression**: Run `just flutter-test` to verify harnesses don't break existing tests

## Risks & Mitigations

- **Provider override API may change with Riverpod 3.x**: Follow the existing `pumpWithTokens` override pattern as the proven approach. If Riverpod updates, the harnesses are the single point of change.
- **Game state types may not exist**: Create minimal placeholder types for testing. When real types are added later, update the harnesses to use them.
- **Provider names may differ from examples**: The code snippets above use hypothetical provider names. Check `frontend/lib/` for actual provider definitions and adapt accordingly.

## Review Guidance

- Verify harnesses compose on `pumpWithTokens` (not bypass it)
- Verify `pumpAuthenticated` reduces setup to 5 lines or fewer
- Verify `pumpWithGameState` accepts configurable phase and player list
- Verify all harnesses accept optional `overrides` for extensibility
- Verify example tests are self-documenting with comments explaining the pattern
- Verify existing tests still pass after harness additions

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
2. **Use CLI**: `spec-kitty agent tasks move-task WP04 --to <lane> --note "message"` (recommended)

The CLI command updates both frontmatter and activity log automatically.

**Valid lanes**: `planned`, `doing`, `for_review`, `done`
