---
work_package_id: WP06
title: Lobby Screen
lane: "doing"
dependencies: [WP05]
requirement_refs:
- FR-008
- FR-020
- FR-029
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this feature were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
base_branch: 005-frontend-game-integration-layer-WP05
base_commit: 0b5eb30163d00a7b466d5d4a3a38e50ba4116f68
created_at: '2026-04-01T01:12:34.541175+00:00'
subtasks: [T023, T024, T025, T026, T027]
phase: Phase 2 - Feature UIs
assignee: ''
agent: ''
shell_pid: "26409"
review_status: ''
reviewed_by: ''
history:
- timestamp: '2026-03-31T07:30:22Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
---

# Work Package Prompt: WP06 – Lobby Screen

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

- Build the lobby screen: lobby code display, player list with ready indicators, role configuration controls, host-only start button.
- Wire all interactions to `LobbyNotifier` from WP05.
- All UI uses `AppTokens` via `activeThemeProvider` — no hardcoded colors, spacing, or typography (SC-007).
- Widget tests verify all interactive states.

## Context & Constraints

- **Spec**: `spec.md` — "Lobby screen" in New Screens to Build. Design direction: "candlelit waiting room — warm, anticipatory."
- **Existing components**: `AtmosphericBackground` (lobby phase), `VillageAppBar` (brand variant), `PlayerAvatar`, `RoleTokenList`, `PrimaryButton`, `MvTextInput`.
- **Design constraints**: Firelit Gothic aesthetic, phone-sized screens primary, `AppTokens` design token system.
- **Constitution**: Server-authoritative (UI displays server state, sends actions), no game logic client-side.
- **Governance directive**: TEST_FIRST.
- **Dependency**: WP05 (`LobbyNotifier`, `LobbyState`, `RoleConfig`).

**Implementation command**: `spec-kitty implement WP06 --base WP05`

## Subtasks & Detailed Guidance

### Subtask T023 – Build lobby screen layout

- **Purpose**: Create the main lobby screen composing existing design system components (FR-008).
- **Steps**:
  1. Create `frontend/lib/features/lobby/presentation/lobby_screen.dart`.
  2. Layout structure:
     - `MvScaffold` with `VillageAppBar` (brand variant) and `AtmosphericBackground` (lobby phase).
     - Lobby code section: Large, prominent display of `lobbyState.code` for sharing. Consider a copy-to-clipboard tap action.
     - Player list: Scrollable list of `PlayerAvatar` widgets with ready-state indicators (checkmark badge or similar). Show each player's `displayName` and `isReady` status.
     - `RoleTokenList` showing current role configuration summary.
     - Leave button: `PrimaryButton` that calls `lobbyNotifier.leave()` and navigates to home.
  3. Use `AppTokens` for all colors, spacing, typography.
- **Files**: `frontend/lib/features/lobby/presentation/lobby_screen.dart` (new, ~120 lines)
- **Parallel?**: Yes — can develop alongside T024 (role config is a separate section/widget).
- **Notes**: The lobby code must be highly visible — it's the primary way players join. Consider using `AppTokens` heading typography. The player list should feel like a candlelit gathering — warm tones, atmospheric.

### Subtask T024 – Build role configuration UI section

- **Purpose**: Allow the host to configure which roles are in the game with +/- controls and presets (FR-020, FR-029).
- **Steps**:
  1. Build as a widget/section within the lobby screen (or extract as a separate widget for clarity).
  2. Per-role row: Role name, current count, `-` button, `+` button.
     - Use `RoleConfig.stepSize(role)` for increment/decrement (Mason jumps by 2).
     - Use `RoleConfig.maxCount(role)` to disable `+` at max.
     - Disable `-` at 0.
  3. Preset selector: Dropdown or chip selector showing presets from `RoleConfig.presetsForPlayerCount(playerCount)`.
     - Selecting a preset auto-populates all role counts.
  4. Validation display: Show total card count vs required (playerCount + 3). Use `RoleConfig.validationError()` for error text. Highlight in red/warning when invalid.
  5. This section is only visible to the host (non-host players see the `RoleTokenList` summary only).
- **Files**: Part of `lobby_screen.dart` or extracted widget (~80 lines)
- **Parallel?**: Yes — can be developed as a separate component from T023.
- **Notes**: With 12 roles on a phone screen, consider a scrollable list. Presets should be the primary UX path — manual adjustment is for advanced users. The validation message should be clear: "Need 8 cards for 5 players (have 7)".

### Subtask T025 – Wire lobby screen to `LobbyNotifier`

- **Purpose**: Connect UI interactions to the state management layer.
- **Steps**:
  1. Use `ref.watch(lobbyNotifierProvider(code))` for reactive state.
  2. Handle `AsyncValue` states: loading (show `MvLoading`), error (show `MvError` with retry), data (render lobby UI).
  3. Wire actions:
     - Ready toggle → `lobbyNotifier.toggleReady()`
     - Leave → `lobbyNotifier.leave()` then `context.go('/')`
     - Role config change → `lobbyNotifier.updateRoleConfig(newRoles)`
     - Preset selection → `lobbyNotifier.updateRoleConfig(presetRoles)`
     - Start game → `lobbyNotifier.startGame()` (navigation handled by `game_started` WS event in notifier)
- **Files**: `frontend/lib/features/lobby/presentation/lobby_screen.dart` (modify)
- **Parallel?**: Depends on T023 (layout exists).
- **Notes**: The `game_started` navigation is handled by the notifier (WP05 T021), not the screen. The screen just calls `startGame()` and the notifier handles the WS event → navigation flow.

### Subtask T026 – Implement host-only controls

- **Purpose**: Only the host can start the game and configure roles. Non-host players see a read-only view.
- **Steps**:
  1. Detect host: Compare current user ID (from `authNotifierProvider`) with `lobbyState.hostId`.
  2. Host sees:
     - Start button (disabled until: all players ready AND valid role config AND player count 3-10).
     - Role configuration section (T024).
  3. Non-host sees:
     - `RoleTokenList` summary (read-only view of roles).
     - No start button, no role config controls.
     - "Waiting for host to start..." message.
  4. Start button disabled state: Use `RoleConfig.isValid()` and check all players `isReady`.
- **Files**: Part of `lobby_screen.dart` (modify ~20 lines)
- **Parallel?**: Depends on T023 and T024.
- **Notes**: Three conditions for start button enabled: (1) all players `isReady`, (2) `RoleConfig.isValid(roles, playerCount)`, (3) player count between 3 and 10. All three must be true. The validation is UI convenience — the server re-validates on start.

### Subtask T027 – Widget tests

- **Purpose**: Verify all lobby screen interactions (TEST_FIRST directive, SC-007).
- **Steps**:
  1. Create `frontend/test/features/lobby/presentation/lobby_screen_test.dart`.
  2. Use `pumpAuthenticated` test harness (or equivalent) with mock `LobbyNotifier`.
  3. **Tests**:
     - Lobby code displayed prominently.
     - Player list shows all players with correct ready indicators.
     - Ready toggle calls notifier method.
     - Role config +/- buttons increment/decrement correctly (Mason by 2).
     - Preset selection populates role counts.
     - Start button disabled when: not all ready, invalid config, player count out of range.
     - Start button enabled when all conditions met.
     - Non-host: no start button, no role config controls visible.
     - Leave button calls notifier and navigates.
     - Design token compliance: no hardcoded colors or spacing (SC-007).
  4. Override providers to inject mock state with various configurations.
- **Files**: `frontend/test/features/lobby/presentation/lobby_screen_test.dart` (new, ~200 lines)
- **Parallel?**: Can be scaffolded before implementation.
- **Notes**: Use `mocktail` to mock `LobbyNotifier`. Create factory functions for test `LobbyState` with different configurations. Test both host and non-host views.

## Test Strategy

**Directive**: TEST_FIRST.

**Commands**:
```bash
cd frontend && just test
cd frontend && just check
cd frontend && just gen
```

**Test files**:
- `frontend/test/features/lobby/presentation/lobby_screen_test.dart`

## Risks & Mitigations

- **Risk**: Role config UI complexity with 12 roles on phone screen.
  **Mitigation**: Scrollable list, presets as primary UX path.
- **Risk**: Design token coverage gaps in new widgets.
  **Mitigation**: Widget tests assert no hardcoded colors/spacing.

## Review Guidance

- Verify all UI uses `AppTokens` — no hardcoded colors, spacing, or typography.
- Verify host-only controls are properly gated.
- Verify start button validation combines all three conditions.
- Verify Mason +/- steps by 2.
- Verify lobby code is prominent and easily shareable.
- Run `just check && just test` from `frontend/`.

## Activity Log

> **CRITICAL**: Chronological order (oldest first, newest last).

### Updating Lane Status

1. **Edit directly**: Change `lane:` in frontmatter AND append activity log entry
2. **Use CLI**: `spec-kitty agent tasks move-task WP06 --to <lane> --note "message"`

**Valid lanes**: `planned`, `doing`, `for_review`, `done`

- 2026-03-31T07:30:22Z – system – lane=planned – Prompt created.
