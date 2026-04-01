---
work_package_id: WP09
title: Discussion & Voting
lane: "doing"
dependencies: [WP07]
requirement_refs: [FR-012, FR-015, FR-025]
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this feature were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
base_branch: 005-frontend-game-integration-layer-WP07
base_commit: 79976d3d3a2e2d4758e9ba041d57052947d6c577
created_at: '2026-04-01T01:16:35.542049+00:00'
subtasks: [T041, T042, T043, T044, T045]
phase: Phase 2 - Feature UIs
assignee: ''
agent: "headless-reviewer"
shell_pid: "51844"
review_status: has_feedback
reviewed_by: Sridhar Vadlamani
review_feedback: feedback://005-frontend-game-integration-layer/WP09/20260401T022709Z-0f55de6e.md
history:
- timestamp: '2026-03-31T07:30:22Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
---

# Work Package Prompt: WP09 – Discussion & Voting

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

- Build the discussion phase view with timer, roles summary, and host "End Discussion" control.
- Wire `VoteSubmission` (existing widget) to `GameNotifier.submitVote`.
- Implement vote progress display showing "X of Y voted" with per-player indicators.
- Implement vote reveal flow: intermediate tally display, then full results on `game_results` event (or 5s REST fallback).
- Widget tests verify all interactive states.

## Context & Constraints

- **Spec**: `spec.md` — Discussion phase view description, voting flow in User Story 5.
- **API contracts**: `contracts/api-contracts.md` — vote endpoint, `vote_submitted` WS event, `vote_reveal` WS event schema.
- **Existing components**: `GameTimer`, `RoleTokenList`, `VoteSubmission` (selection + locked state), `VoteReveal` (tally + elimination), `PhaseIndicator`, `AtmosphericBackground`, `PrimaryButton`, `MvDialog`, `PlayerCircle`.
- **Existing limitations** (from spec):
  - `VoteSubmission` has no vote progress indicator — must add "X of Y voted" display.
  - `VoteReveal` shows "No one was eliminated!" when `eliminatedPlayerIds` is empty — don't render until elimination data arrives.
- **Constitution**: Server-authoritative, design token system.
- **Governance directive**: TEST_FIRST.
- **Dependency**: WP07 (`GameNotifier`, `GameContainerScreen`).

**Implementation command**: `spec-kitty implement WP09 --base WP07`

## Subtasks & Detailed Guidance

### Subtask T041 – Build `DiscussionView`

- **Purpose**: The most social screen — context for in-person discussion (FR-012).
- **Steps**:
  1. Create `frontend/lib/features/game/presentation/discussion_view.dart`.
  2. Layout:
     - `AtmosphericBackground` (discussion phase — warm, light tones).
     - Prominent `GameTimer` countdown from server deadline via `TimerProvider`.
     - `RoleTokenList` showing roles in play from `gameState.rolesInGame` (public info — helps discussion).
     - Host-only "End Discussion" `PrimaryButton`:
       - On tap: Show `MvDialog` confirmation: "End discussion early? Players are still talking."
       - Confirm → POST `/onuw/games/<id>/end-discussion/` via `gameNotifier.endDiscussion()`.
       - Cancel → no-op.
     - Detect host: compare current user ID with game host (from game state or lobby context).
  3. Use `AppTokens` for all styling. Warm-lit aesthetic per spec.
- **Files**: `frontend/lib/features/game/presentation/discussion_view.dart` (new, ~80 lines)
- **Parallel?**: Yes — different phase from T042/T043 (voting).
- **Notes**: This screen is mostly informational — players are talking in person. The phone provides context (timer, roles in play). The host "End Discussion" button is a convenience for shorter games. The confirmation dialog prevents accidental taps.

### Subtask T042 – Wire `VoteSubmission` to `GameNotifier`

- **Purpose**: Connect the existing vote selection widget to the game state (FR-015).
- **Steps**:
  1. In `GameContainerScreen` voting phase view, render `VoteSubmission` widget.
  2. Pass props:
     - `players`: from `gameState.players` mapped to the format `VoteSubmission` expects.
     - `timeRemaining`: from `TimerProvider(gameState.deadline)`.
     - `onVoteSubmitted: (targetPlayerId) => gameNotifier.submitVote(targetPlayerId)`.
     - `isLocked`: `gameState.hasVoted` — shows locked state after submission.
  3. `GameNotifier.submitVote` calls `GameService.submitVote()`. Handle 409 as success (already voted).
  4. After successful submission, optimistically set `hasVoted = true` in local state (server confirms via `vote_submitted` WS event).
- **Files**: `frontend/lib/features/game/presentation/game_container_screen.dart` (modify voting phase section, ~15 lines)
- **Parallel?**: Can develop alongside T041 (different phase).
- **Notes**: The `VoteSubmission` widget is existing — don't rebuild it. Just wire the callbacks and pass the right data. The locked state prevents double-submission.

### Subtask T043 – Implement vote progress display

- **Purpose**: Show how many players have voted without revealing who voted for whom (FR-025).
- **Steps**:
  1. Build a vote progress section in the voting phase view (alongside or above `VoteSubmission`).
  2. Display: "X of Y voted" text derived from `VoteProgress.playerVoted` map.
  3. Per-player voted indicators: Show `PlayerCircle` or `PlayerAvatar` widgets with a checkmark badge for players who have voted. No vote targets revealed.
  4. State updates come from `vote_submitted` WS events — `GameNotifier` marks `player_id` as voted.
  5. Use `AppTokens` for badge styling.
- **Files**: Part of the voting phase view in `game_container_screen.dart` or extracted widget (~40 lines)
- **Parallel?**: Depends on T042 structurally (same voting phase view).
- **Notes**: The progress display must not leak who voted for whom — only show that a player has voted (boolean). The server only sends `player_id` in `vote_submitted`, not the target.

### Subtask T044 – Implement vote reveal flow

- **Purpose**: Two-step vote reveal: intermediate tally, then full results with elimination data (spec US5 AS6).
- **Steps**:
  1. On `vote_reveal` WS event:
     - Event data: `{"votes": {"1": 3, "2": 3, "4": 1, "5": null}}` (voter_id → target_id, null = abstain).
     - Map voter/target IDs to display names using `gameState.players`.
     - Compute tally: count votes per target.
     - Display intermediate state: show votes and tally (who voted for whom, vote counts). Do NOT render `VoteReveal` widget yet — it needs elimination data.
     - Start 5-second timeout waiting for `game_results` WS event.
  2. On `game_results` WS event (or 5s timeout):
     - If `game_results` arrives: Cancel timeout. `GameNotifier` fetches full results via `GET /onuw/games/<id>/results/`.
     - If timeout fires: Fallback to `GameNotifier.fetchResults(gameId)` via REST.
     - Transition to results phase.
  3. Handle abstainers: `null` target → display "Abstained" in vote reveal.
- **Files**: Part of `GameNotifier` event handling (some in WP07 T030), plus voting phase view updates (~50 lines of view code)
- **Parallel?**: Depends on T042/T043 (voting phase view structure).
- **Notes**: The two-step reveal creates dramatic tension. First: "Here's how everyone voted." Brief pause. Then: "Here's who was eliminated." The 5s timeout is a safety net — if the WS event is missed, REST fetches the same data. Abstainers have `null` in the votes map — map to display text "Abstained".

### Subtask T045 – Widget tests

- **Purpose**: Verify discussion and voting UI behavior (TEST_FIRST directive).
- **Steps**:
  1. Create `frontend/test/features/game/presentation/discussion_view_test.dart`:
     - Timer counts down from server deadline.
     - `RoleTokenList` shows roles in game.
     - Host sees "End Discussion" button; non-host does not.
     - End Discussion button shows confirmation dialog.
     - Confirming dialog calls `endDiscussion()`.
  2. Create `frontend/test/features/game/presentation/voting_flow_test.dart`:
     - `VoteSubmission` renders with correct player list.
     - Tapping a player and confirming calls `submitVote(targetId)`.
     - After voting, `isLocked` shows locked state.
     - Vote progress shows correct count "X of Y voted".
     - Vote progress updates on `vote_submitted` events.
     - Vote reveal maps IDs to names correctly.
     - Abstainers show "Abstained".
  3. Use test harness with mock `GameNotifier`.
- **Files**: `frontend/test/features/game/presentation/discussion_view_test.dart`, `frontend/test/features/game/presentation/voting_flow_test.dart` (new, ~200 lines total)
- **Parallel?**: Can scaffold before implementation.
- **Notes**: Use `fake_async` for timer tests and the 5s vote_reveal timeout test.

## Test Strategy

**Directive**: TEST_FIRST.

**Commands**:
```bash
cd frontend && just test
cd frontend && just check
```

**Order**: Discussion view tests first (simpler), then voting flow tests (more complex state).

## Risks & Mitigations

- **Risk**: `vote_reveal` → `game_results` timing gap confuses users.
  **Mitigation**: Show intermediate "calculating results..." state. 5s timeout ensures progress.
- **Risk**: Host accidentally ends discussion.
  **Mitigation**: Confirmation dialog per spec.
- **Risk**: Abstainer display not handled.
  **Mitigation**: Explicit test for null target → "Abstained".

## Review Guidance

- Verify discussion timer uses `TimerProvider` (server deadline, not local countdown).
- Verify End Discussion has confirmation dialog and is host-only.
- Verify vote progress shows count without revealing targets.
- Verify vote reveal handles abstainers (null target).
- Verify 5s timeout fallback to REST for results.
- Verify `VoteReveal` widget not rendered until elimination data is available.
- Run `just check && just test` from `frontend/`.

## Activity Log

> **CRITICAL**: Chronological order (oldest first, newest last).

### Updating Lane Status

1. **Edit directly**: Change `lane:` in frontmatter AND append activity log entry
2. **Use CLI**: `spec-kitty agent tasks move-task WP09 --to <lane> --note "message"`

**Valid lanes**: `planned`, `doing`, `for_review`, `done`

- 2026-03-31T07:30:22Z – system – lane=planned – Prompt created.
- 2026-04-01T01:16:35Z – headless-impl – shell_pid=31797 – lane=doing – Assigned agent via workflow command
- 2026-04-01T01:31:11Z – headless-impl – shell_pid=31797 – lane=for_review – Ready for review: DiscussionView with timer/roles/host controls, voting phase wiring with VoteSubmission, vote progress display, intermediate vote tally, 5-second fallback. 463 tests pass, no analyzer warnings.
- 2026-04-01T01:32:33Z – headless-reviewer – shell_pid=60179 – lane=doing – Started review via workflow command
- 2026-04-01T01:38:47Z – headless-reviewer – shell_pid=60179 – lane=planned – Moved to planned
- 2026-04-01T01:41:52Z – headless-impl – shell_pid=77691 – lane=doing – Started implementation via workflow command
- 2026-04-01T02:14:18Z – headless-impl – shell_pid=23135 – lane=doing – Started implementation via workflow command
- 2026-04-01T02:20:49Z – headless-impl – shell_pid=23135 – lane=for_review – Addressed all review feedback: (1) added container-level isHost wiring tests to GameContainerScreen and JSON parsing tests to game_models_test.dart to prove the full GameSessionState.isHost→DiscussionView path (backend serializer fix was already in place); (2) vote_submitted WS event test already present; (3) fake_async 5-second timeout test already present. 470 tests pass, no analyzer warnings.
- 2026-04-01T02:23:40Z – headless-reviewer – shell_pid=40094 – lane=doing – Started review via workflow command
- 2026-04-01T02:27:09Z – headless-reviewer – shell_pid=40094 – lane=planned – Moved to planned
- 2026-04-01T02:27:44Z – headless-impl – shell_pid=45485 – lane=doing – Started implementation via workflow command
- 2026-04-01T02:32:30Z – headless-impl – shell_pid=45485 – lane=for_review – Addressed review feedback: added per-player PlayerAvatar voted indicators with checkmark sigil to _VotingActiveView; Semantics labels enable WS integration test verifying indicator appears for voted player but not others. 471 tests pass, no analyzer warnings.
- 2026-04-01T02:33:42Z – headless-reviewer – shell_pid=51844 – lane=doing – Started review via workflow command
