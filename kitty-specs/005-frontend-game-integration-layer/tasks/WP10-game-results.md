---
work_package_id: WP10
title: Game Results
lane: "approved"
dependencies: [WP07]
requirement_refs:
- FR-024
- FR-028
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this feature were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
base_branch: 005-frontend-game-integration-layer-WP07
base_commit: 79976d3d3a2e2d4758e9ba041d57052947d6c577
created_at: '2026-04-01T01:18:36.122623+00:00'
subtasks: [T046, T047, T048, T049, T050]
phase: Phase 2 - Feature UIs
assignee: ''
agent: headless-reviewer
shell_pid: '92125'
review_status: "approved"
reviewed_by: "Sridhar Vadlamani"
history:
- timestamp: '2026-03-31T07:30:22Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
---

# Work Package Prompt: WP10 – Game Results

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

- Update existing Freezed models (`VoteResult`, `PlayerResult`, `GameResult`) with new nullable fields and additional data.
- Wire `GameResults` widget to real results endpoint data via `GameNotifier`.
- Implement results data mapping: elimination reason enum, center card role mapping, vote target display names.
- Handle all win condition edge cases per game specs.
- Existing widget tests updated for new fields; new tests for data mapping and win conditions.

## Context & Constraints

- **Research decision R7**: Extend existing Freezed models in-place. Use `@Default([])` for backward compatibility.
- **Data models**: `data-model.md` — Updated `VoteResult`, `PlayerResult`, `GameResult` definitions.
- **API contracts**: `contracts/api-contracts.md` — `ResultsResponse` shape with `elimination_reason`, `vote_target_id`, `center_cards`.
- **Existing components**: `GameResults` widget (`design_system/`), `VoteReveal` widget.
- **Game specs**: `docs/specs/onuw/voting-and-resolution.md` — win conditions, Hunter chain, Tanner.
- **Governance directive**: TEST_FIRST.
- **Dependencies**: WP07 (`GameNotifier`, `GameContainerScreen` results phase). WP01 (backend FR-033 `elimination_reason`) needed for full integration testing.

**Implementation command**: `spec-kitty implement WP10 --base WP07`

## Subtasks & Detailed Guidance

### Subtask T046 – Update existing Freezed models

- **Purpose**: Add new fields to existing game result models (FR-028).
- **Steps**:
  1. Open `frontend/lib/design_system/models/game_result.dart`.
  2. **`VoteResult`**: Make `targetId` and `targetName` nullable (`String?`). These are `null` for abstainers.
  3. **`PlayerResult`**: Add fields:
     - `String? voteTargetId` — who this player voted for (null for abstainers)
     - `String? voteTargetName` — display name of vote target
     - `EliminationReason? eliminationReason` — null if not eliminated
  4. Add `EliminationReason` enum:
     ```dart
     enum EliminationReason { vote, hunterChain }
     ```
  5. **`GameResult`**: Add fields:
     - `@Default([]) List<VoteResult> votes` — per-player vote pairs
     - `@Default([]) List<RoleId> centerCards` — final center card identities
  6. Use `@Default([])` for new list fields to maintain backward compat with existing test factories.
  7. Run `just gen` to regenerate Freezed code.
- **Files**: `frontend/lib/design_system/models/game_result.dart` (modify ~30 lines)
- **Parallel?**: Yes — can proceed independently of T047-T049.
- **Notes**: Using `@Default([])` for `votes` and `centerCards` means existing code creating `GameResult` without these fields continues to work. Nullable fields (`String?`) also maintain compatibility. Existing widget tests should still pass after this change.

### Subtask T047 – Wire `GameResults` widget to results endpoint

- **Purpose**: Fetch and display real results data from the server (FR-024).
- **Steps**:
  1. In `GameNotifier` results handling (or a derived provider):
     - When results phase is reached, `GameNotifier` has fetched results via `GET /onuw/games/<id>/results/`.
     - Map the `ResultsResponse` to the `GameResult` model.
  2. In `GameContainerScreen` results phase:
     - Render the existing `GameResults` widget with the mapped `GameResult`.
     - Add "Return to Home" navigation: `context.go('/')` button after results.
  3. Map `vote_target_id` (int) to display names using `gameState.players` list.
- **Files**: `game_container_screen.dart` (modify results section, ~20 lines), potentially `game_notifier.dart` (add results mapping logic, ~30 lines)
- **Parallel?**: Depends on T046 (model fields exist).
- **Notes**: The `GameResults` widget already exists and handles display. The new work is: (a) fetching real data instead of placeholder, (b) mapping server response to the model, (c) adding return-to-home navigation.

### Subtask T048 – Implement results data mapping

- **Purpose**: Transform server response format to frontend model format.
- **Steps**:
  1. Create mapping logic (in a utility or within the notifier/service):
     - `elimination_reason` string → `EliminationReason` enum: `"vote"` → `.vote`, `"hunter_chain"` → `.hunterChain`.
     - Center card role strings → `RoleId` enum values: `"seer"` → `RoleId.seer`, etc.
     - `vote_target_id` (int) → display name lookup from player list. `null` → abstainer.
     - Per-player `outcome` string → `isWinner` boolean: `"win"` → true, `"loss"` → false.
  2. Handle Doppelganger display: If `original_role` is `"doppelganger"`, the `_buildRoleLabel` in `GameResults` already handles "Doppelganger (as [role])". Ensure `finalRole` is populated correctly.
- **Files**: Mapping logic in service or notifier (~30 lines)
- **Parallel?**: Depends on T046 (model types).
- **Notes**: The `ResultsResponse` from the server uses snake_case strings and integer IDs. The frontend models use Dart enums and display names. This mapping layer bridges the two. Check `contracts/api-contracts.md` for the exact response shape.

### Subtask T049 – Handle win condition edge cases

- **Purpose**: Ensure all win conditions display correctly per game rules.
- **Steps**:
  1. Review win conditions from `docs/specs/onuw/voting-and-resolution.md`.
  2. Verify/implement display for each scenario:
     - **Standard village win**: Werewolf eliminated by vote. `winningTeams: ["village"]`.
     - **Werewolf team win**: No werewolf eliminated. `winningTeams: ["werewolf"]`.
     - **No werewolves + no elimination**: Village wins. `winningTeams: ["village"]`. Special message.
     - **No werewolves + non-Minion eliminated**: Nobody wins. `winningTeams: []`.
     - **Minion-only werewolf team**: Minion not eliminated. `winningTeams: ["werewolf"]`.
     - **Tanner self-elimination**: Tanner also wins. `winningTeams: ["village", "tanner"]` or `["tanner"]` depending on if werewolves were also eliminated.
     - **Multiple winners**: Both Tanner and Village can win simultaneously.
     - **Hunter chain**: Eliminated by Hunter shows "Eliminated by Hunter" label (use `eliminationReason: .hunterChain`).
  3. The `_WinAnnouncement` widget in `GameResults` already handles empty teams ("Nobody wins!") and multiple winners. Verify it works with the new data.
  4. Add "Eliminated by Hunter" label for `hunterChain` elimination reason in `_PlayerResultRow`.
- **Files**: `game_result.dart` widget area or data mapping (~20 lines)
- **Parallel?**: Depends on T047/T048 (basic wiring complete).
- **Notes**: Server computes win conditions — frontend just displays. The main work is ensuring the display handles all variants correctly. Focus on the edge cases that existing widgets don't currently handle (Hunter chain label, no-werewolves scenario).

### Subtask T050 – Tests

- **Purpose**: Update existing tests and add new ones (TEST_FIRST directive, SC-007).
- **Steps**:
  1. **Update existing tests** in `frontend/test/design_system/components/game/game_results_test.dart`:
     - Add nullable `targetId`/`targetName` to `VoteResult` test factories.
     - Add new fields to `PlayerResult` test factories.
     - Add `votes` and `centerCards` to `GameResult` test factories.
     - Verify existing test assertions still pass.
  2. **Update existing tests** in `frontend/test/design_system/components/game/vote_reveal_test.dart`:
     - Test with nullable targets (abstainers show "Abstained").
  3. **New tests** for results data mapping:
     - `elimination_reason` string → enum mapping.
     - Center card string → `RoleId` mapping.
     - `vote_target_id` → display name lookup.
     - Abstainer (null target) handling.
  4. **New tests** for win condition edge cases:
     - Standard village/werewolf win renders correctly.
     - No werewolves + no elimination renders village win message.
     - Nobody wins renders correct message.
     - Tanner win displays correctly.
     - Hunter chain elimination labeled distinctly.
     - Multiple winners rendered.
- **Files**: Update `game_results_test.dart`, `vote_reveal_test.dart`; new mapping/edge case tests (~150 lines total)
- **Parallel?**: Existing test updates (T046 compat) can be done first.
- **Notes**: Backward compatibility is critical — existing tests should pass after model changes with no modifications (thanks to `@Default([])` and nullable fields). New tests cover the new functionality.

## Test Strategy

**Directive**: TEST_FIRST.

**Commands**:
```bash
cd frontend && just test
cd frontend && just check
cd frontend && just gen
```

**Order**: Update existing model tests first (backward compat), then mapping tests, then win condition scenario tests.

## Risks & Mitigations

- **Risk**: Model field additions break existing widget tests.
  **Mitigation**: `@Default([])` for lists, nullable for optionals. Run existing tests first.
- **Risk**: Win condition logic is complex.
  **Mitigation**: Per-scenario tests matching spec. Server computes wins — frontend just displays.

## Review Guidance

- Verify `@Default([])` used for new list fields (backward compat).
- Verify existing tests pass without modification after model changes.
- Verify `elimination_reason` mapping handles all values including null.
- Verify abstainer display ("Abstained") in vote results.
- Verify Hunter chain elimination labeled distinctly from vote elimination.
- Verify center cards displayed in results.
- Run `just check && just test` from `frontend/`.

## Activity Log

> **CRITICAL**: Chronological order (oldest first, newest last).

### Updating Lane Status

1. **Edit directly**: Change `lane:` in frontmatter AND append activity log entry
2. **Use CLI**: `spec-kitty agent tasks move-task WP10 --to <lane> --note "message"`

**Valid lanes**: `planned`, `doing`, `for_review`, `done`

- 2026-03-31T07:30:22Z – system – lane=planned – Prompt created.
- 2026-04-01T01:18:36Z – headless-impl – shell_pid=34379 – lane=doing – Assigned agent via workflow command
- 2026-04-01T01:42:16Z – headless-impl – shell_pid=34379 – lane=for_review – Ready for review: GameResult models extended with EliminationReason, nullable vote targets, votes/centerCards lists; _parseGameResult maps ResultsResponse JSON to models; GameContainerScreen renders GameResults on results phase with Return to Home nav; Hunter chain elimination label; abstainer display in VoteReveal; 463 tests passing including 13 new results mapping tests
- 2026-04-01T01:43:53Z – headless-impl – shell_pid=81504 – lane=doing – Started implementation via workflow command
- 2026-04-01T01:45:37Z – headless-impl – shell_pid=81504 – lane=for_review – Ready for review: GameResult models extended with EliminationReason enum, nullable vote targets, votes/centerCards lists; _parseGameResult maps ResultsResponse to models; GameContainerScreen renders GameResults with Return to Home nav; Hunter chain elimination label; abstainer display in VoteReveal; 463 tests passing including 13 results mapping tests and 18 GameResults tests
- 2026-04-01T01:50:39Z – headless-reviewer – shell_pid=92125 – lane=doing – Started review via workflow command
- 2026-04-01T01:52:43Z – headless-reviewer – shell_pid=92125 – lane=approved – Review passed: 463 tests green, analysis clean; all 5 subtasks implemented — extended Freezed models, _parseGameResult mapping, GameContainerScreen results view with Return to Home, hunter chain label, abstainer display, comprehensive test suite
