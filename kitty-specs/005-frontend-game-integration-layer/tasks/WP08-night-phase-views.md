---
work_package_id: WP08
title: Night Phase Views
lane: done
dependencies: [WP07]
requirement_refs: [FR-010, FR-011, FR-021, FR-022, FR-023, FR-026]
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this feature were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
base_branch: 005-frontend-game-integration-layer-WP07
base_commit: 79976d3d3a2e2d4758e9ba041d57052947d6c577
created_at: '2026-04-01T01:14:35.139737+00:00'
subtasks: [T034, T035, T036, T037, T038, T039, T040]
phase: Phase 2 - Feature UIs
assignee: ''
agent: headless-reviewer
shell_pid: '31817'
review_status: approved
reviewed_by: Sridhar Vadlamani
review_feedback: feedback://005-frontend-game-integration-layer/WP08/20260401T021047Z-a6c6c7cc.md
history:
- timestamp: '2026-03-31T07:30:22Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
---

# Work Package Prompt: WP08 – Night Phase Views

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

- Build all 5 night phase sub-views: role reveal, night waiting, Seer choice, night action result, lone Werewolf peek.
- Wire night sub-views to `GameContainerScreen` via the `NightSubView` state machine.
- Wire `NightActionPrompt` (existing widget) to `GameNotifier.submitAction`.
- Widget tests verify each view's display and interaction behavior.
- All UI uses `AppTokens` — no hardcoded values.

## Context & Constraints

- **Spec**: `spec.md` — Night phase views in New Screens to Build.
- **Existing components**: `RoleCard` (face-down/face-up), `GameTimer`, `CenterCards` (tap-to-select, supports maxSelections:1), `NightActionPrompt` (action submission), `AtmosphericBackground` (night), `PrimaryButton`, `PlayerAvatar`.
- **Existing widget limitations** (from spec):
  - `NightActionPrompt` has no result display — result is a separate view (T037).
  - `_SeeTeamAction` shows misleading text for empty Mason/Minion — night result view must handle empty-state messages correctly.
  - `_PeekCenterAction` hardcodes "Choose 2 center cards" — lone Werewolf uses `CenterCards` directly with maxSelections:1 (T038).
- **Constitution**: Server-authoritative, no game logic client-side, design token system.
- **Governance directive**: TEST_FIRST.
- **Dependency**: WP07 (`GameNotifier`, `NightSubView` state machine, `GameContainerScreen`).

**Implementation command**: `spec-kitty implement WP08 --base WP07`

## Subtasks & Detailed Guidance

### Subtask T034 – Build `RoleRevealView`

- **Purpose**: Dramatic reveal of the player's assigned role at game start (FR-010).
- **Steps**:
  1. Create `frontend/lib/features/game/presentation/role_reveal_view.dart`.
  2. Show a `RoleCard` animating from face-down (roleId: null) to face-up (roleId: assigned role).
  3. Animation: Use `AnimatedBuilder` or `TweenAnimationController` for a flip/fade transition. Keep it simple — opacity + scale transform. Avoid 3D transforms (web compatibility).
  4. Typography: "You are the **[Role Name]**" using `AppTokens` heading style. Serif for dramatic moments.
  5. Auto-advance timer: After 3-5 seconds, transition to next `NightSubView` (waiting or actionPrompt depending on first wave).
  6. `AtmosphericBackground` with night phase.
- **Files**: `frontend/lib/features/game/presentation/role_reveal_view.dart` (new, ~70 lines)
- **Parallel?**: Yes — independent from T035, T036, T038.
- **Notes**: The auto-advance timer is local (not server-driven). If the player backgrounds the app, they should skip directly to the current state on return (handled by reconnection in WP11). Keep the animation tasteful — this sets the tone for the game.

### Subtask T035 – Build `NightWaitingView`

- **Purpose**: Atmospheric waiting screen for players with no action in the current wave (FR-011).
- **Steps**:
  1. Create `frontend/lib/features/game/presentation/night_waiting_view.dart`.
  2. Display "The village sleeps..." atmospheric text using `AppTokens` typography.
  3. `GameTimer` countdown showing time remaining in current wave (from `gameState.deadline`).
  4. Subtle breathing/pulse animation on the text or background. Use `AnimatedOpacity` or `TweenSequence` for a slow pulse effect.
  5. `AtmosphericBackground` with night/deep void variant.
- **Files**: `frontend/lib/features/game/presentation/night_waiting_view.dart` (new, ~50 lines)
- **Parallel?**: Yes — independent from T034, T036, T038.
- **Notes**: This view is shown when the player has no action in the current wave or is waiting for their wave. Immersive feel — "eyes closed." The timer uses `TimerProvider` from WP07.

### Subtask T036 – Build `SeerChoiceView`

- **Purpose**: Pre-action choice for Seer (and Doppelganger-as-Seer) between peek_player and peek_center (FR-021).
- **Steps**:
  1. Create `frontend/lib/features/game/presentation/seer_choice_view.dart`.
  2. Display role identity strip (role name + small `RoleCard`) — follow the `_RoleIdentityStrip` pattern from `NightActionPrompt`. Use `actionPrompt.roleActingAs` for the role label.
  3. Two choice buttons:
     - "Look at one player's card" → sets action type to `peek_player`.
     - "Look at two center cards" → sets action type to `peek_center`.
  4. On button tap: Call a callback or update state so `GameContainerScreen` transitions to `NightActionPrompt` with the selected action type.
  5. `AtmosphericBackground` (night).
- **Files**: `frontend/lib/features/game/presentation/seer_choice_view.dart` (new, ~60 lines)
- **Parallel?**: Yes — independent from T034, T035, T038.
- **Notes**: Both Seer and Doppelganger-as-Seer use this view. The `roleActingAs` field drives the display — "Seer" or "Doppelganger (acting as Seer)". After choosing, the `GameNotifier` should update state to render `NightActionPrompt` with the chosen single action type.

### Subtask T037 – Build `NightResultView`

- **Purpose**: Display the result of a player's night action (FR-022).
- **Steps**:
  1. Create `frontend/lib/features/game/presentation/night_result_view.dart`.
  2. Display varies by `actionResult.actionType`:
     - **peek_player**: "You looked at [target name]'s card" + `RoleCard` showing the revealed role.
     - **peek_center**: "You looked at center card(s)" + `RoleCard`(s) showing revealed role(s).
     - **swap_with_player** (Robber): "You swapped with [target name]. You are now the **[new role]**" + `RoleCard`.
     - **swap_with_center** (Drunk): "You swapped your card with center card [index]. Your card may have changed." Confirmation text only.
     - **swap_others** (Troublemaker): "You swapped [player1 name] and [player2 name]'s cards." Confirmation with names.
     - **see_team** (Werewolf, Mason, Minion):
       - Werewolves: "Your fellow werewolves are: [names]" or "You are the lone Werewolf! You may peek at one center card."
       - Masons: "Your fellow Mason is: [name]" or "You are the only Mason."
       - Minion: "The werewolves are: [names]" or "There are no werewolves. Good luck!"
     - **Insomniac**: "Your card is now: **[role]**" + `RoleCard` (even if unchanged).
  3. Parse `actionResult.revealedInfo` map for the relevant data.
  4. `AtmosphericBackground` (night).
- **Files**: `frontend/lib/features/game/presentation/night_result_view.dart` (new, ~100 lines)
- **Parallel?**: Can be developed once action types are clear from T028 models.
- **Notes**: The empty-state messages are critical: lone Werewolf → triggers transition to `LoneWerewolfPeekView` (T038). Lone Mason → "You are the only Mason" (comforting). Minion with no werewolves → "There are no werewolves. Good luck!" (panic-inducing). The result data comes from `actionResult.revealedInfo` which is a Map populated by the server.

### Subtask T038 – Build `LoneWerewolfPeekView`

- **Purpose**: Allow the lone Werewolf to optionally peek at one center card (FR-026).
- **Steps**:
  1. Create `frontend/lib/features/game/presentation/lone_werewolf_peek_view.dart`.
  2. Display "You are the lone Werewolf. You may look at one center card." text.
  3. `CenterCards` widget with `maxSelections: 1` (existing widget supports this).
  4. "Peek" button: Submits `see_team` action with `{"center_index": selectedIndex}` target.
  5. "Skip" button: Submits `see_team` action with empty targets `{}` (skips the peek).
  6. After submission, `action_result` WS event arrives showing the peeked card (or nothing if skipped).
- **Files**: `frontend/lib/features/game/presentation/lone_werewolf_peek_view.dart` (new, ~60 lines)
- **Parallel?**: Yes — independent specialized view.
- **Notes**: The transition to this view happens after the Werewolf's `see_team` result shows an empty teammate list. The `NightResultView` (T037) should detect this and the `GameNotifier` should transition `nightSubView` to `loneWerewolfPeek`. The peek action is optional — the "Skip" button is important UX.

### Subtask T039 – Wire night sub-views to `GameContainerScreen`

- **Purpose**: Connect all night views to the container's phase switching logic.
- **Steps**:
  1. Open `frontend/lib/features/game/presentation/game_container_screen.dart` (from WP07 T032).
  2. Replace night phase placeholder with a switch on `gameState.nightSubView`:
     - `NightSubView.roleReveal` → `RoleRevealView`
     - `NightSubView.waiting` → `NightWaitingView`
     - `NightSubView.seerChoice` → `SeerChoiceView`
     - `NightSubView.actionPrompt` → `NightActionPrompt` (existing widget, wired below)
     - `NightSubView.actionResult` → `NightResultView`
     - `NightSubView.loneWerewolfPeek` → `LoneWerewolfPeekView`
  3. Wire `NightActionPrompt`'s `onActionSubmitted(NightActionSelection)` callback:
     - Translate `NightActionSelection` to `GameNotifier.submitAction(actionType, targets)`.
     - Map the selection's action type and target data to the API contract format.
  4. Pass relevant state to each view (deadline, actionPrompt, actionResult, yourRole, etc.).
- **Files**: `frontend/lib/features/game/presentation/game_container_screen.dart` (modify ~40 lines)
- **Parallel?**: Depends on T034-T038 (views exist), T032 (container exists).
- **Notes**: The `NightActionPrompt` existing widget fires `onActionSubmitted(NightActionSelection)`. The translation to API format: `NightActionSelection.actionType` → string, `NightActionSelection.targets` → Map matching `ActionRequest` format in api-contracts.md.

### Subtask T040 – Widget tests

- **Purpose**: Verify each night view's display and interaction (TEST_FIRST directive).
- **Steps**:
  1. Create one test file per view in `frontend/test/features/game/presentation/`:
     - `role_reveal_view_test.dart`: Verify card flip animation triggers, role name displayed, auto-advance timer fires after delay.
     - `night_waiting_view_test.dart`: Verify atmospheric text, timer displays countdown.
     - `seer_choice_view_test.dart`: Verify two choice buttons, tapping each calls the correct callback with the right action type.
     - `night_result_view_test.dart`: Test display for each action type (peek_player, peek_center, swap_with_player, swap_with_center, swap_others, see_team with teammates, see_team empty for each role).
     - `lone_werewolf_peek_view_test.dart`: Verify CenterCards with maxSelections:1, peek button submits with center_index, skip button submits without.
  2. Use `pumpAuthenticated` or equivalent test harness with mock `GameNotifier`.
  3. Use `fake_async` for timer-dependent tests (role reveal auto-advance).
- **Files**: 5 test files in `frontend/test/features/game/presentation/` (new, ~300 lines total)
- **Parallel?**: Can scaffold tests before implementing views.
- **Notes**: Night result view tests need multiple test cases — one per action type. Empty-state messages for lone Werewolf, lone Mason, and Minion-without-werewolves are important edge cases.

## Test Strategy

**Directive**: TEST_FIRST.

**Commands**:
```bash
cd frontend && just test
cd frontend && just check
cd frontend && just gen
```

**Order**: Widget test scaffolds first (per view), then implement views, then integration wiring test.

## Risks & Mitigations

- **Risk**: Card flip animation complexity on web platform.
  **Mitigation**: Use simple opacity/scale transform. Avoid 3D transforms.
- **Risk**: Doppelganger multi-step flow creates confusing UX.
  **Mitigation**: `roleActingAs` field from server clearly labels which role is acting.
- **Risk**: Empty-state messages for team roles need careful wording.
  **Mitigation**: Test each empty-state variant explicitly.

## Review Guidance

- Verify each night sub-view maps to a `NightSubView` enum value.
- Verify `NightActionPrompt` wiring translates selection to correct API format.
- Verify empty-state messages for lone Werewolf, lone Mason, Minion-without-werewolves.
- Verify role reveal auto-advance timer works.
- Verify all views use `AppTokens` — no hardcoded values.
- Run `just check && just test` from `frontend/`.

## Activity Log

> **CRITICAL**: Chronological order (oldest first, newest last).

### Updating Lane Status

1. **Edit directly**: Change `lane:` in frontmatter AND append activity log entry
2. **Use CLI**: `spec-kitty agent tasks move-task WP08 --to <lane> --note "message"`

**Valid lanes**: `planned`, `doing`, `for_review`, `done`

- 2026-03-31T07:30:22Z – system – lane=planned – Prompt created.
- 2026-04-01T01:14:35Z – headless-impl – shell_pid=29155 – lane=doing – Assigned agent via workflow command
- 2026-04-01T01:43:16Z – headless-impl – shell_pid=29155 – lane=for_review – All 5 night phase views implemented and wired: RoleRevealView (4s auto-advance), NightWaitingView (atmospheric), SeerChoiceView (peek_player/peek_center choice), NightResultView (8 action-type variants with empty-state messages), LoneWerewolfPeekView (optional center card peek). NightActionPrompt wired via _handleActionSubmitted. 486 tests pass, analyzer clean.
- 2026-04-01T01:48:38Z – headless-reviewer – shell_pid=88440 – lane=doing – Started review via workflow command
- 2026-04-01T01:52:26Z – headless-reviewer – shell_pid=88440 – lane=planned – Moved to planned
- 2026-04-01T02:05:27Z – headless-reviewer – shell_pid=88440 – lane=for_review – Re-review after lost verdict
- 2026-04-01T02:05:41Z – headless-reviewer – shell_pid=10412 – lane=doing – Started review via workflow command
- 2026-04-01T02:10:47Z – headless-reviewer – shell_pid=10412 – lane=planned – Moved to planned
- 2026-04-01T02:11:32Z – headless-impl – shell_pid=19015 – lane=doing – Started implementation via workflow command
- 2026-04-01T02:18:19Z – headless-impl – shell_pid=19015 – lane=for_review – Addressed review feedback: added RoleCard to SeerChoiceView identity strip, replaced hardcoded icon size 64 with tokens.spacing.xxxl, added NightSubView.actionPrompt container test. 488 tests pass, analyzer clean.
- 2026-04-01T02:18:53Z – headless-reviewer – shell_pid=31817 – lane=doing – Started review via workflow command
- 2026-04-01T02:23:26Z – headless-reviewer – shell_pid=31817 – lane=approved – Review passed: all 5 night phase views implemented with tests; 488 tests pass, analyzer clean; spec requirements FR-010/011/021/022/023/026 satisfied
