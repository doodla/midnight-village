---
work_package_id: WP06
title: Architecture Playbook & Testing Strategy
lane: "planned"
dependencies: [WP03]
base_branch: 001-frontend-design-system-and-architecture-WP03
base_commit: 935942f5cd141c469c185ab7eaaf02e89a12078f
created_at: '2026-03-25T03:53:24.953311+00:00'
subtasks:
- T031
- T032
- T033
- T034
- T035
phase: Phase D - Documentation
assignee: ''
agent: "headless-impl"
shell_pid: "36168"
review_status: "has_feedback"
reviewed_by: "Sridhar Vadlamani"
review_feedback_file: "/private/var/folders/h1/g68scqh939n8kgw31xxqvq6r0000gn/T/tmp.Ow1Mk9LkUC"
history:
- timestamp: '2026-03-25T01:34:57Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
requirement_refs:
- FR-012
- FR-013
- FR-014
- FR-015
- FR-016
---

# Work Package Prompt: WP06 – Architecture Playbook & Testing Strategy

## ⚠️ IMPORTANT: Review Feedback Status

**Read this first if you are implementing this task!**

- **Has review feedback?**: Check the `review_status` field above. If it says `has_feedback`, scroll to the **Review Feedback** section immediately.
- **You must address all feedback** before your work is complete.

---

## Review Feedback

**Reviewed by**: Sridhar Vadlamani
**Status**: ❌ Changes Requested
**Date**: 2026-03-25
**Feedback file**: `/private/var/folders/h1/g68scqh939n8kgw31xxqvq6r0000gn/T/tmp.Ow1Mk9LkUC`

Reset from stuck doing state for orchestration re-run.


## Objectives & Success Criteria

Create two documentation deliverables that enable developers to build new features without guessing:

1. **Frontend Architecture Playbook** — How to structure features, how WebSocket events flow, how phases drive navigation, how to handle reconnection.
2. **Testing Strategy** — Patterns for unit, widget, and theme tests with runnable examples.

**Success criteria**:
- A developer unfamiliar with the codebase can read the architecture doc and correctly structure a new feature module
- The architecture doc answers "where does this code go?" for any piece of frontend code
- WebSocket event flow is documented end-to-end for at least 3 representative scenarios
- Testing doc provides copy-paste-able patterns for unit, widget, and theme tests
- Example tests actually compile and pass
- No game logic computed client-side (server-authority verified)

**Implementation command**: `spec-kitty implement WP06 --base WP03`

## Context & Constraints

**Key documents**:
- Spec (US6, US7): `kitty-specs/001-frontend-design-system-and-architecture/spec.md`
- Quickstart: `kitty-specs/001-frontend-design-system-and-architecture/quickstart.md`
- Existing architecture: `docs/` directory in repository root

**Prerequisite code to reference**:
- Token system: `frontend/lib/design_system/tokens/` (patterns for provider + bridge)
- Core components: `frontend/lib/design_system/components/core/` (widget patterns)
- Auth feature: `frontend/lib/features/auth/` (existing feature module structure)
- Test helpers: `frontend/test/design_system/test_helpers/` (pumpWithTokens pattern)

**Constraints**:
- Document PATTERNS, not exhaustive implementation details. The code is the source of truth.
- Reference actual file paths and class names from the codebase.
- Architecture must enforce server-authority: client NEVER computes game logic.
- Reconnection pattern must handle mid-game disconnect gracefully.

## Subtasks & Detailed Guidance

### Subtask T031 – Document feature module structure

- **Purpose**: Define how any new game feature (e.g., night phase screen, voting screen) should be structured in the codebase.
- **File**: `frontend/docs/architecture.md`
- **Steps**:
  1. Create the architecture document with a "Feature Module Structure" section.
  2. Document the three-layer architecture:
     - **Domain layer** (`lib/features/<feature>/domain/`):
       - Pure Dart models (no Flutter dependencies)
       - State classes (using Freezed)
       - No imports from `data/` or `presentation/`
       - Example: `GameState`, `NightActionState`, `VoteState`
     - **Data layer** (`lib/features/<feature>/data/`):
       - Services (HTTP API calls via Dio)
       - Repositories (WebSocket event subscription)
       - Bridge between domain models and external services
       - Imports: `domain/` models, `core/api/` client, `core/storage/`
       - Example: `GameService`, `GameRepository`
     - **Presentation layer** (`lib/features/<feature>/presentation/`):
       - Riverpod notifiers (state management, codegen)
       - Screen widgets (ConsumerWidget)
       - Imports: `domain/` models, `data/` services, `design_system/` components
       - Example: `NightPhaseNotifier`, `NightPhaseScreen`
  3. Document the dependency rules:
     ```
     presentation → domain, data, design_system
     data → domain, core
     domain → (nothing — pure Dart)
     design_system → (nothing — independent component library)
     ```
  4. Provide a concrete "new feature checklist":
     - [ ] Create `lib/features/<name>/domain/` with state models
     - [ ] Create `lib/features/<name>/data/` with service(s)
     - [ ] Create `lib/features/<name>/presentation/` with notifier + screen
     - [ ] Add route to `lib/core/router/routes.dart`
     - [ ] Use design system components in the screen (MvScaffold, MvButton, etc.)
  5. Reference the existing auth feature as an example of this structure.
- **Validation**:
  - [ ] Three layers clearly defined with responsibilities
  - [ ] Dependency rules stated explicitly
  - [ ] New feature checklist is actionable
  - [ ] References actual code paths in the project

### Subtask T032 – Document WebSocket event flow pattern

- **Purpose**: Define the exact data path for real-time game events from server to UI update.
- **File**: `frontend/docs/architecture.md` (add section)
- **Steps**:
  1. Add "Real-Time Event Flow" section to the architecture document.
  2. Document the end-to-end flow:
     ```
     Server → WebSocket message (JSON)
       → WebSocket connection (core/api/)
       → Event deserialization (data layer)
       → Riverpod state update (notifier)
       → Widget rebuild (presentation)
       → Design system component renders new state
     ```
  3. Document 3 representative scenarios:
     **Scenario 1: Night action result received**
     - Server sends: `{"type": "night_action_result", "role": "seer", "target": "player_3", "revealed_role": "werewolf"}`
     - WebSocket handler deserializes to domain model
     - Notifier updates state: `NightPhaseState(result: PeekResult(...))`
     - Screen widget rebuilds: Shows RoleCard face-up with revealed role

     **Scenario 2: Phase transition**
     - Server sends: `{"type": "phase_change", "phase": "voting"}`
     - Handler updates game state
     - Router guard detects phase change → navigates to voting screen

     **Scenario 3: Vote submitted by another player**
     - Server sends: `{"type": "vote_update", "votes_submitted": 4, "total_players": 6}`
     - Notifier updates waiting state: "4 of 6 votes in"
     - Screen shows progress without revealing any votes

  4. Document the WebSocket connection lifecycle:
     - Connect on game join
     - Heartbeat/ping-pong for connection health
     - Reconnect on disconnect (see T033)
     - Disconnect on game leave
  5. Emphasize: The client NEVER computes game outcomes from WebSocket data. It displays what the server tells it.
- **Validation**:
  - [ ] Data path is complete: server → widget
  - [ ] 3 scenarios documented with concrete event payloads
  - [ ] Server-authority principle is explicit
  - [ ] WebSocket lifecycle documented

### Subtask T033 – Document phase navigation and reconnection patterns

- **Purpose**: Define how game phases drive screen navigation and how players reconnect after a disconnect.
- **File**: `frontend/docs/architecture.md` (add section)
- **Steps**:
  1. Add "Phase-Driven Navigation" section:
     - Game phases (lobby, night, discussion, voting, results) map to routes
     - Phase changes come from the server (never client-decided)
     - GoRouter redirect guard checks current game phase → redirects to correct screen
     - Phase transition flow:
       ```
       Server sends phase_change event
         → Game state notifier updates currentPhase
         → Router guard fires on next navigation
         → Player navigated to corresponding screen
       ```
  2. Add "Reconnection Pattern" section:
     - Detect disconnect: WebSocket `onDone` / `onError` handler
     - Show reconnecting UI (MvLoading with "Reconnecting..." message)
     - Reconnection strategy:
       1. Re-establish WebSocket connection (with exponential backoff)
       2. Fetch current game state via HTTP GET `/api/games/current/`
       3. Update all Riverpod state from fetched state
       4. Router guard navigates to correct phase screen
     - Edge cases:
       - Game ended while disconnected → navigate to results
       - Player was eliminated while disconnected → show results with elimination
       - No active game → navigate to lobby
  3. Reference the existing `auth_notifier.dart` pattern for how notifiers handle state restoration.
- **Validation**:
  - [ ] Phase → route mapping is explicit
  - [ ] Router guard pattern is documented
  - [ ] Reconnection steps are ordered and complete
  - [ ] Edge cases (game ended, player eliminated) are covered
  - [ ] Server-authority: client doesn't decide which phase to show

### Subtask T034 – Document testing patterns

- **Purpose**: Define testing strategy so developers know how to test any frontend code they write.
- **File**: `frontend/docs/testing-strategy.md`
- **Steps**:
  1. Create the testing strategy document with sections:

  2. **Unit Tests** (domain + notifiers):
     - Domain models: Pure Dart tests, no Flutter dependency
     - Riverpod notifiers: Create `ProviderContainer`, override dependencies, test state transitions
     - Pattern:
       ```dart
       test('notifier updates state on event', () {
         final container = ProviderContainer(overrides: [
           gameServiceProvider.overrideWithValue(mockService),
         ]);
         final notifier = container.read(gameNotifierProvider.notifier);
         notifier.handleEvent(someEvent);
         expect(container.read(gameNotifierProvider), expectedState);
       });
       ```

  3. **Widget Tests** (components + screens):
     - Use `pumpWithTokens` helper from test_helpers
     - Pattern:
       ```dart
       testWidgets('button shows primary style', (tester) async {
         await tester.pumpWithTokens(
           MvButton(label: 'Test', onPressed: () {}),
         );
         // Find and assert
       });
       ```

  4. **Theme Compatibility Tests**:
     - Render with default theme AND test theme
     - Verify no exceptions or layout overflow
     - Pattern:
       ```dart
       for (final theme in [MidnightVillageTheme(), TestThemeTokens()]) {
         testWidgets('renders with ${theme.name}', (tester) async {
           await tester.pumpWithTokens(widget, theme: theme);
           expect(tester.takeException(), isNull);
         });
       }
       ```

  5. **What to mock**:
     - YES: HTTP services, WebSocket connections, storage
     - NO: Domain models, Riverpod state logic, widget rendering, design system components
     - Use `mocktail` for mocking (already in dev_dependencies)

  6. **Coverage target**: 80% minimum for all design system code.

  7. **File organization**: Tests mirror source tree:
     ```
     test/design_system/tokens/ → tests for token system
     test/design_system/components/core/ → tests for core components
     test/design_system/components/game/ → tests for game components
     ```
- **Validation**:
  - [ ] Unit test pattern is copy-paste-able
  - [ ] Widget test pattern includes pumpWithTokens
  - [ ] Theme test pattern covers multiple themes
  - [ ] What-to-mock guidance is clear
  - [ ] Coverage target stated

### Subtask T035 – Create runnable example tests

- **Purpose**: Provide actual, runnable test files demonstrating each testing pattern. Developers can copy and adapt these.
- **Files**:
  - `frontend/test/design_system/examples/unit_test_example.dart`
  - `frontend/test/design_system/examples/widget_test_example.dart`
  - `frontend/test/design_system/examples/theme_test_example.dart`
- **Steps**:
  1. **Unit test example**: Test a domain model or enum:
     ```dart
     import 'package:flutter_test/flutter_test.dart';
     import 'package:midnight_village/design_system/models/role.dart';

     void main() {
       group('RoleId', () {
         test('werewolf maps to werewolf team', () {
           expect(RoleId.werewolf.team, TeamId.werewolf);
         });

         test('seer maps to village team', () {
           expect(RoleId.seer.team, TeamId.village);
         });

         test('tanner maps to independent team', () {
           expect(RoleId.tanner.team, TeamId.independent);
         });

         test('displayName returns capitalized name', () {
           expect(RoleId.troublemaker.displayName, 'Troublemaker');
         });
       });
     }
     ```
  2. **Widget test example**: Test a core component with theme:
     ```dart
     import 'package:flutter/material.dart';
     import 'package:flutter_test/flutter_test.dart';
     import 'package:midnight_village/design_system/components/core/mv_button.dart';
     import '../test_helpers/pump_with_tokens.dart';

     void main() {
       testWidgets('MvButton primary renders with primary color', (tester) async {
         await tester.pumpWithTokens(
           MvButton(label: 'Test', onPressed: () {}),
         );
         expect(find.text('Test'), findsOneWidget);
         expect(find.byType(ElevatedButton), findsOneWidget);
       });

       testWidgets('MvButton disabled when onPressed is null', (tester) async {
         await tester.pumpWithTokens(
           MvButton(label: 'Disabled', onPressed: null),
         );
         final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
         expect(button.onPressed, isNull);
       });
     }
     ```
  3. **Theme test example**: Test component with multiple themes:
     ```dart
     import 'package:flutter_test/flutter_test.dart';
     import 'package:midnight_village/design_system/components/core/mv_card.dart';
     import 'package:midnight_village/design_system/tokens/midnight_village_theme.dart';
     import '../test_helpers/pump_with_tokens.dart';
     import '../test_helpers/test_theme.dart';

     void main() {
       final themes = [
         const MidnightVillageTheme(),
         const TestThemeTokens(),
       ];

       for (final theme in themes) {
         testWidgets('MvCard renders without error with ${theme.name}', (tester) async {
           await tester.pumpWithTokens(
             MvCard(child: Text('Content')),
             theme: theme,
           );
           expect(tester.takeException(), isNull);
           expect(find.text('Content'), findsOneWidget);
         });
       }
     }
     ```
  4. These files must compile and run successfully with `just flutter-test`.
- **Validation**:
  - [ ] All 3 example files exist and have correct import paths
  - [ ] Examples compile without errors
  - [ ] Examples demonstrate distinct testing patterns
  - [ ] A developer can copy an example and adapt it for a new component

## Risks & Mitigations

- **Docs becoming stale**: Focus on patterns and principles, not specific implementation details. Reference the design system directory structure and existing examples rather than line-by-line code.
- **Example tests breaking**: Example tests depend on actual components from WP01-WP03. Ensure imports are correct. If component APIs change, examples may need updating.
- **WebSocket patterns are speculative**: The WebSocket infrastructure isn't built yet. Document the intended pattern based on Django Channels contract. Mark as "planned pattern" where implementation doesn't exist yet.

## Review Guidance

- **Developer test**: Can a new developer read the architecture doc and correctly answer: "Where should I put the voting screen's state management?" (Answer: `lib/features/game/presentation/` as a notifier)
- **Server authority**: Does any pattern suggest computing game logic client-side? If so, flag it.
- **Example tests**: Do they actually pass? Run `just flutter-test` to verify.
- **Reconnection completeness**: Are all disconnect scenarios covered? (Game ended, player eliminated, mid-action disconnect)

## Activity Log

- 2026-03-25T01:34:57Z – system – lane=planned – Prompt created.
- 2026-03-25T03:53:25Z – headless-impl – shell_pid=36168 – lane=doing – Assigned agent via workflow command
- 2026-03-25T04:01:33Z – headless-impl – shell_pid=36168 – lane=planned – Reset for re-run
