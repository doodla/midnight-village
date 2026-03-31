---
work_package_id: WP01
title: Backend Additions
lane: "doing"
dependencies: []
requirement_refs:
- FR-030
- FR-031
- FR-032
- FR-033
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this feature were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
base_branch: main
base_commit: 346ead182d862980b68ffbba264d784d83d3141d
created_at: '2026-03-31T07:54:10.651157+00:00'
subtasks: [T001, T002, T003, T004, T005]
phase: Phase 0 - Foundation
assignee: ''
agent: "headless-impl"
shell_pid: "56648"
review_status: ''
reviewed_by: ''
history:
- timestamp: '2026-03-31T07:30:22Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
---

# Work Package Prompt: WP01 – Backend Additions

## IMPORTANT: Review Feedback Status

**Read this first if you are implementing this task!**

- **Has review feedback?**: Check the `review_status` field above. If it says `has_feedback`, scroll to the **Review Feedback** section immediately.
- **You must address all feedback** before your work is complete.
- **Mark as acknowledged**: When you understand the feedback and begin addressing it, update `review_status: acknowledged` in the frontmatter.
- **Report progress**: As you address each feedback item, update the Activity Log.

---

## Review Feedback

> **Populated by `/spec-kitty.review`** – Reviewers add detailed feedback here when work needs changes.

*[This section is empty initially.]*

---

## Markdown Formatting
Wrap HTML/XML tags in backticks: `` `<div>` ``, `` `<script>` ``
Use language identifiers in code blocks: ````python`, ````bash`

---

## Objectives & Success Criteria

- Add four targeted backend endpoints/fields required by the frontend integration layer.
- All four changes are additive — no modifications to existing fields or behavior.
- `just test` from `backend/` passes with new tests covering PATCH lobby, `game_started` handler, `roles_in_game` serialization, and `elimination_reason` in results.
- `just check` passes (lint, format, typecheck).
- 80% coverage maintained.

## Context & Constraints

- **Spec**: `kitty-specs/005-frontend-game-integration-layer/spec.md`
- **Plan**: `kitty-specs/005-frontend-game-integration-layer/plan.md` — see "Key Research Decisions" R9
- **API contracts**: `kitty-specs/005-frontend-game-integration-layer/contracts/api-contracts.md` — defines the expected request/response shapes
- **Constitution**: Server-authoritative, atomicity via `@atomic`, hidden information (responses are player-scoped)
- **Governance directive**: TEST_FIRST — write tests before implementation
- **No dependencies** — this is a starting package. All changes are additive to existing backend code.

**Implementation command**: `spec-kitty implement WP01`

## Subtasks & Detailed Guidance

### Subtask T001 – Add PATCH method to `LobbyDetailView`

- **Purpose**: Allow the host to update lobby settings (role configuration) before starting the game (FR-030).
- **Steps**:
  1. Open `backend/apps/core/views.py` — find `LobbyDetailView`.
  2. Add a `partial_update` method (PATCH handler).
  3. Accept request body: `{"settings": {"roles": {"werewolf": 2, "seer": 1, ...}}}`.
  4. Validate caller is the host (compare `request.user` with `lobby.host`). Return 403 for non-host.
  5. Validate the role configuration using the same validation logic that `GameStartView` uses — total cards must equal player count + 3, Mason count must be 0 or 2, etc.
  6. Update `lobby.settings` and save.
  7. Broadcast a `lobby_update` WebSocket event via `async_to_sync(channel_layer.group_send)` to the lobby group.
  8. Return the updated `LobbyResponse`.
- **Files**: `backend/apps/core/views.py` (modify ~30 lines)
- **Parallel?**: Yes — different file from T002–T004.
- **Notes**: Reuse `get_object()` pattern already on `LobbyDetailView`. The broadcast pattern matches existing `player_joined`/`player_left` broadcasts. If validation logic is currently inline in `GameStartView`, consider extracting to a shared utility or calling the same validator.

### Subtask T002 – Add `game_started` handler to `LobbyConsumer`

- **Purpose**: Forward `game.started` channel layer event to all connected WebSocket clients so the frontend can navigate to the game screen (FR-031).
- **Steps**:
  1. Open `backend/apps/core/consumers.py` — find `LobbyConsumer`.
  2. Add a handler method `game_started(self, event)` following the pattern of existing `player_joined`/`player_left` handlers.
  3. Send to WebSocket: `{"type": "game_started", "game_id": event["game_id"]}`.
  4. This is approximately 5 lines of code.
- **Files**: `backend/apps/core/consumers.py` (modify ~5 lines)
- **Parallel?**: Yes — different concern from T001, T003, T004.
- **Notes**: The channel layer event type should be `game.started` (dots become underscores for the method name per Django Channels convention). The `GameStartView` or game creation logic must already be sending this event to the lobby group — verify this, and add the send if missing.

### Subtask T003 – Add `roles_in_game` to `GameMeSerializer`

- **Purpose**: Expose which roles are in the current game so the frontend can display `RoleTokenList` during discussion phase (FR-032).
- **Steps**:
  1. Open `backend/apps/onuw/serializers.py` — find `GameMeSerializer`.
  2. Add a `SerializerMethodField` named `roles_in_game`.
  3. Implement `get_roles_in_game(self, obj)`: read `self.context['game'].settings['roles']` and return as `[{"role": "werewolf", "count": 2}, ...]`.
  4. Add `roles_in_game` to the serializer's `Meta.fields`.
- **Files**: `backend/apps/onuw/serializers.py` (modify ~10 lines)
- **Parallel?**: Yes — different serializer file from T001, T002.
- **Notes**: The `game` object is available in serializer context per existing patterns. Verify the settings dict key structure before implementing.

### Subtask T004 – Add `elimination_reason` to results endpoint

- **Purpose**: Distinguish vote-based elimination from Hunter chain kills in the results response so the frontend can label them correctly (FR-033).
- **Steps**:
  1. Open `backend/apps/onuw/views.py` — find the results endpoint view.
  2. In the `eliminated_players` section of the response, add an `elimination_reason` field per player.
  3. Value is `"vote"` for players eliminated by vote threshold, `"hunter_chain"` for players killed by the Hunter's chain reaction.
  4. The game resolution data already tracks which elimination mechanism was used — serialize this into the response.
- **Files**: `backend/apps/onuw/views.py` (modify ~10 lines)
- **Parallel?**: Yes — different view/concern from T001–T003.
- **Notes**: Check the game resolution model to find where elimination cause is stored. The API contract specifies the response shape — see `contracts/api-contracts.md` ResultsResponse.

### Subtask T005 – Tests for all four changes

- **Purpose**: Ensure all new endpoints/fields work correctly and edge cases are covered (SC-008, TEST_FIRST directive).
- **Steps**:
  1. **FR-030 tests** in `backend/tests/unit/core/`:
     - Test PATCH returns updated lobby with new settings.
     - Test 403 when non-host PATCHes.
     - Test 400 when role config is invalid (wrong total, odd Mason count).
     - Test `lobby_update` WebSocket event is broadcast after successful PATCH.
  2. **FR-031 tests** in `backend/tests/unit/core/`:
     - Test `game_started` event is forwarded to all lobby WebSocket clients.
     - Test event contains `game_id`.
  3. **FR-032 tests** in `backend/tests/unit/onuw/`:
     - Test `roles_in_game` field present in `GET /onuw/games/<id>/me/` response.
     - Test serialization matches expected format: `[{"role": "werewolf", "count": 2}, ...]`.
  4. **FR-033 tests** in `backend/tests/unit/onuw/`:
     - Test `elimination_reason` is `"vote"` for vote-eliminated players.
     - Test `elimination_reason` is `"hunter_chain"` for Hunter chain kills.
     - Test non-eliminated players have no `elimination_reason` (null or absent).
- **Files**: `backend/tests/unit/core/` (new test files), `backend/tests/unit/onuw/` (new test files)
- **Parallel?**: T005 tests can be split per-feature for parallelism — core tests and onuw tests are independent.
- **Notes**: TEST_FIRST — write these tests before implementing T001–T004. Seed all randomness in game setup fixtures per project convention. Use existing test factories and fixtures.

## Test Strategy

**Directive**: TEST_FIRST — all tests written before implementation code.

**Commands**:
```bash
just test              # Run all backend tests (from backend/)
just check             # Lint + format-check + typecheck
just test-cov          # Verify 80% coverage maintained
```

**Test structure**:
- `backend/tests/unit/core/test_lobby_patch.py` — FR-030 PATCH tests
- `backend/tests/unit/core/test_game_started_handler.py` — FR-031 WS handler tests
- `backend/tests/unit/onuw/test_roles_in_game.py` — FR-032 serializer tests
- `backend/tests/unit/onuw/test_elimination_reason.py` — FR-033 results tests

**Fixtures**: Use existing test factories for Lobby, Game, Player creation. Seed randomness per project convention.

## Risks & Mitigations

- **Risk**: Existing backend tests break from model changes.
  **Mitigation**: Changes are additive fields/methods, not modifications. Run `just test` before and after.
- **Risk**: PATCH validation differs from `GameStartView` validation.
  **Mitigation**: Extract shared validation logic or call the same validator. Test both paths with the same edge cases.
- **Risk**: `game_started` channel event not being sent from game creation code.
  **Mitigation**: Verify the game start flow sends the channel event to the lobby group. Add if missing.

## Review Guidance

- Verify all four changes are tested with both happy path and error cases.
- Confirm PATCH endpoint reuses existing validation (not duplicated logic).
- Check that `lobby_update` broadcast uses the correct channel group name.
- Verify `roles_in_game` reads from the correct settings path.
- Verify `elimination_reason` handles the case where a player is not eliminated (null/absent).
- Run `just check && just test` — must pass clean.

## Activity Log

> **CRITICAL**: Activity log entries MUST be in chronological order (oldest first, newest last).

### How to Add Activity Log Entries

**When adding an entry**:
1. Scroll to the bottom of this file (Activity Log section below "Valid lanes")
2. **APPEND the new entry at the END** (do NOT prepend or insert in middle)
3. Use exact format: `- YYYY-MM-DDTHH:MM:SSZ – agent_id – lane=<lane> – <action>`

**Format**:
```
- YYYY-MM-DDTHH:MM:SSZ – <agent_id> – lane=<lane> – <brief action description>
```

### Updating Lane Status

To change a work package's lane, either:

1. **Edit directly**: Change the `lane:` field in frontmatter AND append activity log entry (at the end)
2. **Use CLI**: `spec-kitty agent tasks move-task WP01 --to <lane> --note "message"` (recommended)

**Valid lanes**: `planned`, `doing`, `for_review`, `done`

- 2026-03-31T07:30:22Z – system – lane=planned – Prompt created.
- 2026-03-31T07:54:10Z – headless-impl – shell_pid=56648 – lane=doing – Assigned agent via workflow command
