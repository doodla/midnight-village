---
work_package_id: WP02
title: Game Domain Models
lane: "doing"
dependencies: [WP01]
base_branch: 001-frontend-design-system-and-architecture-WP01
base_commit: 935942f5cd141c469c185ab7eaaf02e89a12078f
created_at: '2026-03-25T03:53:23.017796+00:00'
subtasks:
- T008
- T009
- T010
- T011
- T012
- T013
phase: Phase A - Foundation
assignee: ''
agent: "headless-impl"
shell_pid: "35942"
review_status: ''
reviewed_by: ''
history:
- timestamp: '2026-03-25T01:34:57Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
requirement_refs:
- FR-006
- FR-007
- FR-008
---

# Work Package Prompt: WP02 – Game Domain Models

## ⚠️ IMPORTANT: Review Feedback Status

**Read this first if you are implementing this task!**

- **Has review feedback?**: Check the `review_status` field above. If it says `has_feedback`, scroll to the **Review Feedback** section immediately.
- **You must address all feedback** before your work is complete.

---

## Review Feedback

*[This section is empty initially.]*

---

## Objectives & Success Criteria

Create all game-specific enums, data models, and asset abstractions used by game UI components:

1. **RoleId + TeamId** — Enum for all 12 v1 roles with team affiliation and derived properties.
2. **GamePhase** — Enum for the 5 game phases.
3. **NightActionType + NightActionSelection** — Enum for action types + sealed class for selection variants.
4. **Player/Vote/Result models** — Freezed data classes for component inputs.
5. **ThemeAssets** — Abstract asset resolver with placeholder icon mapping.

**Success criteria**:
- All 12 v1 roles mapped to correct teams
- `RoleId.teamColor(AppColorTokens)` returns correct team color
- `NightActionSelection` sealed class has 4 variants matching all action response shapes
- All data models instantiable with mock data
- `just flutter-analyze` passes

**Implementation command**: `spec-kitty implement WP02 --base WP01`

## Context & Constraints

**Key documents**:
- Data model: `kitty-specs/001-frontend-design-system-and-architecture/data-model.md`
- Component APIs: `kitty-specs/001-frontend-design-system-and-architecture/contracts/component-api.md`

**Constraints**:
- These are **UI display models**, not API deserialization DTOs. Mapping from API responses to these models happens in the data layer (built later).
- Use Freezed for data classes that need `copyWith`, `==`, and `toString`.
- Enums are plain Dart `enum` with extension methods or enhanced enums.
- All models live under `frontend/lib/design_system/models/`.

## Subtasks & Detailed Guidance

### Subtask T008 – Create RoleId + TeamId enums

- **Purpose**: Define the type-safe vocabulary for all 12 v1 roles and their team affiliations. Used by RoleCard, RoleTokenList, NightActionPrompt, GameResults.
- **File**: `frontend/lib/design_system/models/role.dart`
- **Steps**:
  1. Create `enum TeamId` with values: `werewolf`, `village`, `independent`
  2. Create `enum RoleId` with all 12 v1 roles:
     ```dart
     enum RoleId {
       werewolf,
       minion,
       villager,
       seer,
       robber,
       troublemaker,
       drunk,
       insomniac,
       mason,
       hunter,
       tanner,
       doppelganger,
     }
     ```
  3. Add derived properties via extension or enhanced enum:
     - `TeamId get team` — maps each role to its team:
       - Werewolf team: `werewolf`, `minion`
       - Village team: `villager`, `seer`, `robber`, `troublemaker`, `drunk`, `insomniac`, `mason`, `hunter`, `doppelganger`
       - Independent: `tanner`
     - `String get displayName` — human-readable name (e.g., `troublemaker` → `"Troublemaker"`)
     - `Color teamColor(AppColorTokens colors)` — returns `colors.werewolfTeam`, `colors.villageTeam`, or `colors.independentTeam` based on team
     - `IconData get placeholderIcon` — Material Icon for placeholder rendering:
       - werewolf → `Icons.pets`
       - minion → `Icons.sentiment_very_dissatisfied`
       - villager → `Icons.person`
       - seer → `Icons.visibility`
       - robber → `Icons.swap_horiz`
       - troublemaker → `Icons.shuffle`
       - drunk → `Icons.local_bar`
       - insomniac → `Icons.nightlight_round`
       - mason → `Icons.handshake`
       - hunter → `Icons.gps_fixed`
       - tanner → `Icons.work`
       - doppelganger → `Icons.content_copy`
- **Validation**:
  - [ ] All 12 roles defined
  - [ ] Team mapping is correct (check doppelganger → village)
  - [ ] `displayName` returns properly capitalized names
  - [ ] `teamColor()` returns the correct color token for each team
  - [ ] `placeholderIcon` returns a distinct icon per role

### Subtask T009 – Create GamePhase enum

- **Purpose**: Define game phases for the PhaseIndicator component. Drives navigation and UI state.
- **File**: `frontend/lib/design_system/models/game_phase.dart`
- **Steps**:
  1. Create `enum GamePhase`:
     ```dart
     enum GamePhase {
       lobby('Lobby'),
       night('Night'),
       discussion('Discussion'),
       voting('Voting'),
       results('Results');

       const GamePhase(this.displayName);
       final String displayName;
     }
     ```
- **Parallel?**: Yes — independent of other subtasks.
- **Validation**:
  - [ ] All 5 phases defined with display names

### Subtask T010 – Create NightActionType + NightActionSelection

- **Purpose**: Define the action type vocabulary and selection data shapes for the NightActionPrompt component.
- **File**: `frontend/lib/design_system/models/night_action.dart`
- **Steps**:
  1. Create `enum NightActionType`:
     ```dart
     enum NightActionType {
       peekPlayer,      // Seer option A
       peekCenter,      // Seer option B, lone werewolf
       swapWithPlayer,  // Robber
       swapWithCenter,  // Drunk
       swapOthers,      // Troublemaker
       seeTeam,         // Werewolf, Mason, Minion
       none,            // Villager, Tanner, Hunter (no action / waiting)
     }
     ```
  2. Create `sealed class NightActionSelection`:
     ```dart
     sealed class NightActionSelection {}

     class PlayerTarget extends NightActionSelection {
       final String playerId;
       PlayerTarget(this.playerId);
     }

     class CenterTargets extends NightActionSelection {
       final List<int> indices;
       CenterTargets(this.indices);
     }

     class TwoPlayerTargets extends NightActionSelection {
       final String player1Id;
       final String player2Id;
       TwoPlayerTargets(this.player1Id, this.player2Id);
     }

     class NoAction extends NightActionSelection {}
     ```
  3. Consider using Freezed for the sealed class variants if it simplifies equality/toString, but plain classes are fine since these are simple data holders.
- **Parallel?**: Yes — independent of other subtasks.
- **Validation**:
  - [ ] All 7 action types defined
  - [ ] Sealed class has 4 variants covering all selection shapes
  - [ ] `switch` on `NightActionSelection` is exhaustive (Dart sealed class guarantee)

### Subtask T011 – Create PlayerDisplay + PlayerStatus models

- **Purpose**: Data structures for rendering players in PlayerCircle and other components.
- **File**: `frontend/lib/design_system/models/player_display.dart`
- **Steps**:
  1. Create `enum PlayerStatus`:
     ```dart
     enum PlayerStatus { active, eliminated, disconnected }
     ```
  2. Create `PlayerDisplay` as a Freezed class:
     ```dart
     @freezed
     class PlayerDisplay with _$PlayerDisplay {
       const factory PlayerDisplay({
         required String id,
         required String displayName,
         @Default(false) bool isCurrentPlayer,
         @Default(true) bool isSelectable,
         @Default(false) bool isSelected,
         @Default(PlayerStatus.active) PlayerStatus status,
       }) = _PlayerDisplay;
     }
     ```
  3. Run `dart run build_runner build` to generate Freezed code.
- **Parallel?**: Yes — independent of T012.
- **Validation**:
  - [ ] `PlayerDisplay` has `copyWith` for updating selection state
  - [ ] `PlayerStatus` has all 3 states
  - [ ] Default values are sensible (active, selectable, not selected)

### Subtask T012 – Create VoteResult, GameResult, PlayerResult models

- **Purpose**: Data structures for rendering vote reveal and game results screens.
- **File**: `frontend/lib/design_system/models/game_result.dart`
- **Steps**:
  1. Create `VoteResult` as a Freezed class:
     ```dart
     @freezed
     class VoteResult with _$VoteResult {
       const factory VoteResult({
         required String voterId,
         required String voterName,
         required String targetId,
         required String targetName,
       }) = _VoteResult;
     }
     ```
  2. Create `PlayerResult` as a Freezed class:
     ```dart
     @freezed
     class PlayerResult with _$PlayerResult {
       const factory PlayerResult({
         required String id,
         required String displayName,
         required RoleId originalRole,
         required RoleId finalRole,
         required TeamId team,
         required bool isEliminated,
         required bool isWinner,
       }) = _PlayerResult;
     }
     ```
  3. Create `GameResult` as a Freezed class:
     ```dart
     @freezed
     class GameResult with _$GameResult {
       const factory GameResult({
         required List<TeamId> winningTeams,
         required List<PlayerResult> players,
       }) = _GameResult;
     }
     ```
  4. Run `dart run build_runner build`.
- **Parallel?**: Yes — independent of T011.
- **Validation**:
  - [ ] `GameResult.winningTeams` supports multiple winners (Tanner + Village)
  - [ ] `PlayerResult` tracks both original and final role (for swap display)
  - [ ] All classes generate correctly with Freezed

### Subtask T013 – Create ThemeAssets abstraction + placeholder mapping

- **Purpose**: Abstract asset path resolution per theme. Placeholder implementation maps roles to Material Icons.
- **File**: `frontend/lib/design_system/tokens/theme_assets.dart`
- **Steps**:
  1. Create `abstract class ThemeAssets`:
     ```dart
     abstract class ThemeAssets {
       String get themeId;
       String roleCardPath(RoleId role);
       String get cardBackPath;
     }
     ```
  2. Create `class MidnightVillageAssets implements ThemeAssets`:
     ```dart
     class MidnightVillageAssets implements ThemeAssets {
       const MidnightVillageAssets();

       @override
       String get themeId => 'midnight-village';

       @override
       String roleCardPath(RoleId role) =>
         'assets/themes/midnight-village/roles/${role.name}.svg';

       @override
       String get cardBackPath =>
         'assets/themes/midnight-village/card-back.svg';
     }
     ```
  3. Note: The RoleCard component handles fallback to Material Icons when SVG files don't exist yet. This is by design — SVG illustrations are added later.
- **Notes**: ThemeAssets is provided alongside AppTokens but kept as a separate abstraction since asset paths are not visual tokens.
- **Validation**:
  - [ ] `MidnightVillageAssets` returns correct asset paths
  - [ ] Path format matches pubspec.yaml asset declarations from WP01

## Risks & Mitigations

- **Model bloat**: Keep models minimal — only fields needed for UI rendering. No business logic.
- **Freezed codegen**: Ensure `build_runner` generates all `.freezed.dart` and `.g.dart` files. Run with `--delete-conflicting-outputs` if needed.
- **Icon choices**: Placeholder icons are subjective. Focus on distinctiveness — each role should have a visually different icon.

## Review Guidance

- Verify all 12 roles map to correct teams (check data-model.md).
- Verify NightActionSelection sealed class covers all action response shapes from component-api.md.
- Verify PlayerDisplay has all fields needed by PlayerCircle component API.
- Verify GameResult.winningTeams is `List<TeamId>` (not single TeamId) to support multi-winner.
- Check that Freezed codegen runs without errors.

## Activity Log

- 2026-03-25T01:34:57Z – system – lane=planned – Prompt created.
- 2026-03-25T03:53:23Z – headless-impl – shell_pid=35942 – lane=doing – Assigned agent via workflow command
