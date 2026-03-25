---
work_package_id: WP05
title: Game Components – Player Interaction
lane: done
dependencies: [WP04]
requirement_refs:
- FR-006
- FR-008
- FR-009
- FR-010
- FR-011
- FR-017
base_branch: 001-frontend-design-system-and-architecture-WP04
base_commit: 935942f5cd141c469c185ab7eaaf02e89a12078f
created_at: '2026-03-25T03:53:26.743980+00:00'
subtasks:
- T026
- T027
- T028
- T029
- T030
phase: Phase C - Game Components
assignee: ''
agent: headless-reviewer
shell_pid: '7784'
review_status: has_feedback
reviewed_by: Sridhar Vadlamani
history:
- timestamp: '2026-03-25T01:34:57Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
review_feedback_file: /private/var/folders/h1/g68scqh939n8kgw31xxqvq6r0000gn/T/tmp.Ow1Mk9LkUC
---

# Work Package Prompt: WP05 – Game Components – Player Interaction

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

Build all player-facing interaction components — the heart of the game UI:

1. **PlayerCircle** — Adaptive player display for 3-10 players with selection modes and status indicators.
2. **NightActionPrompt** — Composite component handling all 7 night action types with appropriate UI per type.
3. **VoteSubmission** — Vote target selection with privacy protection from nearby players.
4. **VoteReveal** — Simultaneous display of all votes with tallies and elimination outcome.
5. **GameResults** — Win/loss display handling all team combinations and role reveals.

**Success criteria**:
- PlayerCircle renders correctly for 3, 5, 8, and 10 players on 360dp width
- NightActionPrompt handles all 7 action types with correct target selection UI
- VoteSubmission hides vote choice from casual observation
- VoteReveal displays all votes simultaneously with accurate tallies
- GameResults handles all win conditions: village-only, werewolf-only, tanner-only, tanner+village dual, no-winner
- Zero hardcoded visual values

**Implementation command**: `spec-kitty implement WP05 --base WP04`

## Context & Constraints

**Key documents**:
- Component APIs: `kitty-specs/001-frontend-design-system-and-architecture/contracts/component-api.md`
- Data model: `kitty-specs/001-frontend-design-system-and-architecture/data-model.md`
- Spec (acceptance scenarios): `kitty-specs/001-frontend-design-system-and-architecture/spec.md` (User Stories 3, 4, 5)

**Prerequisite code (from WP01-WP04)**:
- Token system: `frontend/lib/design_system/tokens/`
- Domain models: `frontend/lib/design_system/models/` (RoleId, NightActionType, NightActionSelection, PlayerDisplay, VoteResult, GameResult)
- Game components: `frontend/lib/design_system/components/game/` (RoleCard, CenterCards, GameTimer)

**Constraints**:
- Components are pure display/input widgets — no game logic, no API calls
- Server-authoritative: Components render what they're told. NightActionPrompt doesn't decide which action a role gets — it receives `NightActionType` from the parent.
- Vote privacy (FR-009): After vote submission, the confirmed state must NOT prominently display who was voted for. Nearby players glancing at the screen should not see the vote target.

## Subtasks & Detailed Guidance

### Subtask T026 – Create PlayerCircle component

- **Purpose**: Display players in a selectable layout. Used for night action target selection, voting, and status display. Must scale from 3 to 10 players.
- **File**: `frontend/lib/design_system/components/game/player_circle.dart`
- **Steps**:
  1. Create `PlayerCircle` widget:
     ```dart
     class PlayerCircle extends ConsumerWidget {
       final List<PlayerDisplay> players;
       final ValueChanged<String>? onPlayerSelected;  // callback with player ID
       final int? maxSelections;  // 1 for vote/peek, 2 for troublemaker/seer-center
       final bool showStatus;  // show eliminated/disconnected indicators

       const PlayerCircle({
         super.key,
         required this.players,
         this.onPlayerSelected,
         this.maxSelections,
         this.showStatus = false,
       });
     }
     ```
  2. **Layout strategy**: Use a grid or wrapped list layout that adapts to player count:
     - 3-4 players: Single row
     - 5-6 players: 2 rows of 3
     - 7-8 players: 2 rows of 4
     - 9-10 players: 2 rows of 5 or 3 rows
     - Each player slot: circular avatar area with name below
     - Use `Wrap` or `GridView` for automatic flow
  3. **Player rendering**:
     - Avatar circle: `tokens.colors.surface` background, `tokens.colors.onSurface` initials or icon
     - Name: `tokens.typography.caption` below avatar, truncated with ellipsis for long names
     - Current player: Distinct border (e.g., `tokens.colors.primary` ring) and marked as non-selectable
  4. **Selection state**:
     - **Selectable** (`isSelectable && onPlayerSelected != null`): Tappable, subtle border/highlight on hover
     - **Selected** (`isSelected`): `tokens.colors.primary` border/highlight, check indicator
     - **Not selectable** (`!isSelectable` or current player): Dimmed, no tap response
     - When `maxSelections` is reached, remaining unselected players become dimmed
  5. **Status display** (when `showStatus` is true):
     - Active: Normal rendering
     - Eliminated: Crossed-out or red overlay, `tokens.colors.error` indicator
     - Disconnected: Greyed out with disconnect icon
  6. **Self-exclusion**: Player where `isCurrentPlayer == true` is visually distinct and cannot be selected (cannot vote for self, cannot target self).
- **Validation**:
  - [ ] 3 players: renders in single row, all visible
  - [ ] 5 players: wraps to 2 rows
  - [ ] 10 players: all visible on 360dp width
  - [ ] Current player is visually marked and non-selectable
  - [ ] Selected player shows primary color highlight
  - [ ] Long names truncate without layout breakage
  - [ ] Eliminated status shows crossed-out indicator
  - [ ] maxSelections=1: only one player can be selected at a time
  - [ ] maxSelections=2: exactly two players can be selected

### Subtask T027 – Create NightActionPrompt component

- **Purpose**: The most complex UI component. Renders the appropriate interaction for each of 7 night action types. Composite component using PlayerCircle, CenterCards, GameTimer, and RoleCard.
- **File**: `frontend/lib/design_system/components/game/night_action_prompt.dart`
- **Steps**:
  1. Create `NightActionPrompt` widget:
     ```dart
     class NightActionPrompt extends ConsumerWidget {
       final NightActionType actionType;
       final RoleId playerRole;
       final List<PlayerDisplay> players;
       final int centerCardCount;
       final Duration timeRemaining;
       final ValueChanged<NightActionSelection> onActionSubmitted;
       final VoidCallback? onSkip;

       const NightActionPrompt({
         super.key,
         required this.actionType,
         required this.playerRole,
         required this.players,
         required this.centerCardCount,
         required this.timeRemaining,
         required this.onActionSubmitted,
         this.onSkip,
       });
     }
     ```
  2. **Structure**: Column layout:
     - Top: Role identity display — show the player's role card (small) + role name
     - Middle: Action-specific UI (switches based on `actionType`)
     - Bottom: `GameTimer` showing `timeRemaining`
  3. **Action-type UIs** (build as private helper widgets within the file):

     **`peekPlayer`** (Seer option A):
     - Prompt: "Choose a player to look at their card"
     - UI: `PlayerCircle` with `maxSelections: 1`
     - On selection: Confirm button → `onActionSubmitted(PlayerTarget(playerId))`

     **`peekCenter`** (Seer option B, lone werewolf):
     - Prompt: "Choose 2 center cards to look at"
     - UI: `CenterCards` with tappable cards, `maxSelections: 2`
     - On selection: Confirm button → `onActionSubmitted(CenterTargets(indices))`

     **`swapWithPlayer`** (Robber):
     - Prompt: "Choose a player to swap cards with"
     - UI: `PlayerCircle` with `maxSelections: 1`
     - On selection: Confirm button → `onActionSubmitted(PlayerTarget(playerId))`

     **`swapWithCenter`** (Drunk):
     - Prompt: "Choose a center card to swap your card with"
     - UI: `CenterCards` with tappable cards, `maxSelections: 1`
     - On selection: Confirm button → `onActionSubmitted(CenterTargets([index]))`

     **`swapOthers`** (Troublemaker):
     - Prompt: "Choose 2 players to swap their cards"
     - UI: `PlayerCircle` with `maxSelections: 2`
     - On selection of 2: Confirm button → `onActionSubmitted(TwoPlayerTargets(p1, p2))`

     **`seeTeam`** (Werewolf, Mason, Minion):
     - Prompt: Varies by role:
       - Werewolf: "These are your fellow werewolves" (or "You are the lone werewolf" if no other werewolves)
       - Mason: "These are your fellow masons"
       - Minion: "These are the werewolves (they don't know you)"
     - UI: List of revealed player names (the teammates), or special lone wolf message
     - Action: Acknowledge button → `onActionSubmitted(NoAction())`

     **`none`** (Villager, Tanner, Hunter):
     - Prompt: "The night is in progress. Close your eyes and wait."
     - UI: Atmospheric waiting screen — themed with night imagery text
     - No interaction needed. Timer runs. Auto-completes or skip button.
     - `onActionSubmitted(NoAction())` on timer expiry or acknowledge

  4. **Confirm flow**: After target selection, show a confirm button (`MvButton` primary variant) before submitting. This prevents accidental taps.
  5. **Skip**: If `onSkip` is provided, show a secondary "Skip" button for optional actions.
- **Edge cases**:
  - Seer has two options (peek player OR peek center). Consider showing both options initially and letting the player choose, then showing the appropriate selection UI. Or: pass the specific action type from the parent (the server decides which option the Seer chose via a prior selection step).
  - Lone werewolf during `seeTeam`: Display "You are the lone werewolf" message instead of empty teammate list.
- **Validation**:
  - [ ] `peekPlayer`: Shows player circle, selection works, confirm submits `PlayerTarget`
  - [ ] `peekCenter`: Shows center cards, 2-card selection works, confirm submits `CenterTargets`
  - [ ] `swapWithPlayer`: Shows player circle, single selection, confirm submits `PlayerTarget`
  - [ ] `swapWithCenter`: Shows center cards, single selection, confirm submits `CenterTargets`
  - [ ] `swapOthers`: Shows player circle, 2-player selection, confirm submits `TwoPlayerTargets`
  - [ ] `seeTeam`: Shows teammate list, acknowledge button submits `NoAction`
  - [ ] `none`: Shows waiting message, no interaction required
  - [ ] Timer displays remaining time with urgency color shift
  - [ ] Player role card visible at top of prompt

### Subtask T028 – Create VoteSubmission component

- **Purpose**: Vote target selection with privacy from nearby players. Players vote for who they think is a werewolf.
- **File**: `frontend/lib/design_system/components/game/vote_submission.dart`
- **Steps**:
  1. Create `VoteSubmission` widget:
     ```dart
     class VoteSubmission extends ConsumerWidget {
       final List<PlayerDisplay> players;
       final Duration timeRemaining;
       final ValueChanged<String> onVoteSubmitted;  // player ID
       final bool isLocked;

       const VoteSubmission({
         super.key,
         required this.players,
         required this.timeRemaining,
         required this.onVoteSubmitted,
         this.isLocked = false,
       });
     }
     ```
  2. **Pre-vote state** (`isLocked == false`):
     - Header: "Vote for who you think is a werewolf"
     - `PlayerCircle` with `maxSelections: 1`
     - `GameTimer` showing remaining time
     - On selection + confirm: Call `onVoteSubmitted(playerId)`
  3. **Post-vote state** (`isLocked == true`):
     - **PRIVACY**: Show a generic "Your vote has been submitted" message
     - Do NOT display the target player's name in large text
     - Use a simple check icon + small confirmation text
     - Timer continues running (other players may still be voting)
     - **Why**: Players sit together. Someone glancing at your phone should NOT see who you voted for.
  4. Confirm button before submitting: "Lock in your vote" with a warning that it cannot be changed.
- **Validation**:
  - [ ] Player circle shows all players except self
  - [ ] Selection highlights the chosen target
  - [ ] Confirm button submits the vote
  - [ ] After submission: generic "Vote submitted" message, no target name visible
  - [ ] Timer continues showing remaining time
  - [ ] Privacy: nearby player cannot determine vote target from glancing at the screen

### Subtask T029 – Create VoteReveal component

- **Purpose**: Simultaneous display of all votes after voting concludes. Shows who voted for whom, tallies per player, and who (if anyone) is eliminated.
- **File**: `frontend/lib/design_system/components/game/vote_reveal.dart`
- **Steps**:
  1. Create `VoteReveal` widget:
     ```dart
     class VoteReveal extends ConsumerWidget {
       final List<VoteResult> votes;
       final Map<String, int> tally;  // player ID → vote count
       final List<String> eliminatedPlayerIds;

       const VoteReveal({
         super.key,
         required this.votes,
         required this.tally,
         required this.eliminatedPlayerIds,
       });
     }
     ```
  2. Build:
     - **Vote list**: Each voter → target displayed as "{VoterName} voted for {TargetName}"
     - Use `tokens.typography.body` for text
     - **Tally section**: Show each player who received votes with their count
     - Sort by vote count descending
     - Highlight the most-voted player(s)
     - **Elimination outcome**:
       - If `eliminatedPlayerIds` is not empty: "Eliminated: {PlayerName(s)}" in `tokens.colors.error`
       - If empty: "No one was eliminated!" — all votes tied or other no-elimination scenario
     - Use `tokens.typography.heading` for the outcome announcement
  3. Layout: Scrollable column since vote lists can be long for 10-player games.
- **Parallel?**: Yes — independent of T030.
- **Validation**:
  - [ ] All votes displayed with correct voter → target mapping
  - [ ] Tally shows accurate counts
  - [ ] Most-voted player highlighted
  - [ ] Elimination shown in error color
  - [ ] "No one eliminated" message when `eliminatedPlayerIds` is empty
  - [ ] Scrollable for 10-player games

### Subtask T030 – Create GameResults component

- **Purpose**: End-of-game display showing which teams won, all role reveals, and player outcomes. Must handle all win condition combinations.
- **File**: `frontend/lib/design_system/components/game/game_results.dart`
- **Steps**:
  1. Create `GameResults` widget:
     ```dart
     class GameResults extends ConsumerWidget {
       final GameResult result;
       final VoidCallback? onPlayAgain;
       final VoidCallback? onReturnToLobby;

       const GameResults({
         super.key,
         required this.result,
         this.onPlayAgain,
         this.onReturnToLobby,
       });
     }
     ```
  2. **Win announcement**:
     - Display winning team(s) prominently using `tokens.typography.displayHeading`
     - Color the announcement in the winning team's color: `tokens.colors.werewolfTeam`, `tokens.colors.villageTeam`, or `tokens.colors.independentTeam`
     - Handle multi-winner: "Tanner Wins! Village Wins!" — each in their team color
     - Handle no winner: "Nobody wins!" in neutral color
  3. **Player reveal section**: List each player showing:
     - Player name
     - Original role → Final role (if different, show arrow: "Seer → Drunk")
     - If same: Just show the role
     - Team color indicator
     - Win/loss status: Winner gets `tokens.colors.primary` highlight, loser gets muted
     - Eliminated indicator if `isEliminated` is true
     - Use `RoleCard` (small, face-up) next to each player for visual role identification
  4. **Action buttons** at bottom:
     - "Play Again" (`MvButton` primary) if `onPlayAgain` provided
     - "Return to Lobby" (`MvButton` secondary) if `onReturnToLobby` provided
  5. Layout: Scrollable for large player counts.
- **Parallel?**: Yes — independent of T029.
- **Edge cases**:
  - Tanner + Village dual win: Both teams shown as winners, both team colors
  - No werewolves in game and village voted to kill someone: Village loses
  - Doppelganger display: Show "Doppelganger (as Seer)" if the Doppelganger copied a role
- **Validation**:
  - [ ] Village win: Blue-themed announcement
  - [ ] Werewolf win: Red-themed announcement
  - [ ] Tanner win: Gold-themed announcement
  - [ ] Tanner + Village dual: Both colors shown
  - [ ] No winner: Neutral announcement
  - [ ] Role reveals show all 12 role types correctly
  - [ ] Swapped roles show original → final
  - [ ] Eliminated players marked
  - [ ] Play Again and Return to Lobby buttons functional
  - [ ] Scrollable for 10-player games

## Risks & Mitigations

- **NightActionPrompt complexity**: 7 action types is substantial. Break into private helper widgets — one per action type. Keep the main widget as a switch/when dispatcher.
- **PlayerCircle scaling**: 10 players on a narrow screen is tight. Use compact avatars (40dp diameter) and small text. Test on 360dp width.
- **Vote privacy assumption**: The spec says "hide from casual observation." This means: small confirmation text, no large target name display. It does NOT mean encryption or obfuscation — just reasonable visual privacy.
- **GameResults with Doppelganger**: The data model has `originalRole` and `finalRole`. Display logic: if originalRole == doppelganger AND finalRole != doppelganger, show "Doppelganger (as FinalRole)".

## Review Guidance

- **NightActionPrompt coverage**: Test each of the 7 action types individually. Verify correct prompt text, correct selection UI, and correct `NightActionSelection` variant on submit.
- **Vote privacy**: After vote submission, look at the `isLocked` state. Is the target name hidden? Could a nearby person tell who was voted for?
- **GameResults win conditions**: Test all 5 scenarios: village-only, werewolf-only, tanner-only, tanner+village, no-winner.
- **PlayerCircle at extremes**: Test with 3 players and 10 players. Verify layout doesn't overflow.
- **No hardcoded values**: All colors, spacing, typography from tokens.

## Activity Log

- 2026-03-25T01:34:57Z – system – lane=planned – Prompt created.
- 2026-03-25T03:53:26Z – headless-impl – shell_pid=36491 – lane=doing – Assigned agent via workflow command
- 2026-03-25T04:01:32Z – headless-impl – shell_pid=36491 – lane=planned – Reset for re-run
- 2026-03-25T04:24:27Z – headless-impl – shell_pid=66410 – lane=doing – Started implementation via workflow command
- 2026-03-25T05:05:49Z – headless-impl – shell_pid=66410 – lane=for_review – Committed by orchestrator fallback, rebased onto WP04
- 2026-03-25T05:10:24Z – headless-reviewer – shell_pid=7784 – lane=doing – Started review via workflow command
- 2026-03-25T05:13:45Z – headless-reviewer – shell_pid=7784 – lane=done – Review passed: All 5 components (PlayerCircle, NightActionPrompt, VoteSubmission, VoteReveal, GameResults) implemented correctly. All 7 night action types, all 5 win conditions, vote privacy, token-based styling verified. 152/152 tests pass, flutter analyze clean.
