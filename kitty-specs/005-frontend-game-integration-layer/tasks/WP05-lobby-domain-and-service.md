---
work_package_id: WP05
title: Lobby Domain & Service
lane: "doing"
dependencies:
- WP02
requirement_refs: [FR-006, FR-016, FR-020, FR-027, FR-029]
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this feature were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
base_branch: 005-frontend-game-integration-layer-WP02
base_commit: cafb0c799c5e735ea80dcec8d4cd1a16e42d9114
created_at: '2026-03-31T15:44:32.775347+00:00'
subtasks: [T018, T019, T020, T021, T022]
phase: Phase 1 - Feature Data Layers
assignee: ''
agent: headless-impl
shell_pid: "67159"
review_status: ''
reviewed_by: ''
history:
- timestamp: '2026-03-31T07:30:22Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
---

# Work Package Prompt: WP05 – Lobby Domain & Service

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

- Create `LobbyPlayer` and `LobbyState` Freezed models with JSON serialization.
- Create `RoleConfig` utility with validation logic (total = players + 3, Mason step=2, player count 3-10) and recommended presets.
- Create `LobbyService` for all lobby HTTP operations.
- Create `LobbyNotifier` as `@riverpod` `AsyncNotifier` handling HTTP + WebSocket coordination.
- Unit tests verify: model serialization roundtrip, RoleConfig validation, LobbyService HTTP calls, LobbyNotifier WS event handling.

## Context & Constraints

- **Research decision R3**: AsyncNotifier pattern matching `AuthNotifier`. See `research.md` R3.
- **Data models**: `kitty-specs/005-frontend-game-integration-layer/data-model.md` — LobbyPlayer, LobbyState definitions.
- **API contracts**: `kitty-specs/005-frontend-game-integration-layer/contracts/api-contracts.md` — Lobby REST + WS endpoints.
- **Game specs**: `docs/specs/onuw/recommended-setups.md` — preset role combinations by player count.
- **Existing patterns**: `frontend/lib/features/auth/` (data-domain-presentation structure), `frontend/lib/features/auth/presentation/auth_notifier.dart` (Riverpod AsyncNotifier pattern).
- **Constitution**: Server-authoritative (lobby state comes from server), dispose resources via `ref.onDispose`.
- **Governance directive**: TEST_FIRST.
- **Dependencies**: WP02 (`AuthenticatedClient`), WP03 (`ReconnectingWebSocket`).

**Implementation command**: `spec-kitty implement WP05 --base WP02`

## Subtasks & Detailed Guidance

### Subtask T018 – Create `LobbyPlayer` and `LobbyState` Freezed models

- **Purpose**: Define the domain models for lobby state management (FR-006).
- **Steps**:
  1. Create `frontend/lib/features/lobby/domain/lobby_state.dart`.
  2. Define `LobbyPlayer` Freezed class per `data-model.md`:
     ```dart
     @freezed
     abstract class LobbyPlayer with _$LobbyPlayer {
       const factory LobbyPlayer({
         required int id,
         required String displayName,
         required bool isReady,
         required DateTime joinedAt,
       }) = _LobbyPlayer;
       factory LobbyPlayer.fromJson(Map<String, dynamic> json) =>
           _$LobbyPlayerFromJson(json);
     }
     ```
  3. Define `LobbyState` Freezed class per `data-model.md`:
     - Fields: `code` (String), `hostId` (int), `gameType` (String), `status` (String), `maxPlayers` (int), `settings` (Map with roles), `players` (List of LobbyPlayer), `createdAt` (DateTime).
     - Include `fromJson` factory.
  4. Run `just gen` to generate Freezed code.
- **Files**: `frontend/lib/features/lobby/domain/lobby_state.dart` (new, ~50 lines)
- **Parallel?**: Yes — independent from T019.
- **Notes**: Field names must match the JSON response from the backend (snake_case → camelCase via Freezed's `@JsonKey` or default conversion). Reference `data-model.md` for exact field definitions.

### Subtask T019 – Create `RoleConfig` utility class

- **Purpose**: Validate role configuration and provide recommended presets for the lobby UI (FR-020, FR-029).
- **Steps**:
  1. Create `frontend/lib/features/lobby/domain/role_config.dart`.
  2. Implement static methods:
     - `isValid(Map<RoleId, int> roles, int playerCount)` → `bool`: Total cards must equal `playerCount + 3`. Each role count >= 0. Mason count must be 0 or 2. Player count must be 3-10.
     - `stepSize(RoleId role)` → `int`: Returns 2 for `mason`, 1 for all others.
     - `maxCount(RoleId role)` → `int`: Maximum count per role (e.g., Villager up to 3, Werewolf up to 2, most roles max 1).
     - `presetsForPlayerCount(int count)` → `Map<String, Map<RoleId, int>>`: Named presets ("Basic", "Intermediate", "Advanced") populated from `docs/specs/onuw/recommended-setups.md`.
     - `totalCards(Map<RoleId, int> roles)` → `int`: Sum of all role counts.
     - `validationError(Map<RoleId, int> roles, int playerCount)` → `String?`: Human-readable error message or null if valid.
  3. Read `docs/specs/onuw/recommended-setups.md` for the preset data.
- **Files**: `frontend/lib/features/lobby/domain/role_config.dart` (new, ~80 lines)
- **Parallel?**: Yes — independent from T018.
- **Notes**: This is pure logic with no dependencies — easy to test first. Mason step size = 2 is a game rule (Masons must come in pairs). The `RoleId` enum should already exist in the design system.

### Subtask T020 – Create `LobbyService`

- **Purpose**: HTTP calls for all lobby CRUD operations (FR-016).
- **Steps**:
  1. Create `frontend/lib/features/lobby/data/lobby_service.dart`.
  2. Constructor takes `AuthenticatedClient` (from WP02).
  3. Implement methods per API contracts:
     - `createLobby()` → POST `/lobbies/` with `{"game_type": "onuw"}` → returns `LobbyState`
     - `joinLobby(String code)` → POST `/lobbies/<code>/join/` → returns `LobbyState`
     - `leaveLobby(String code)` → POST `/lobbies/<code>/leave/`
     - `toggleReady(String code)` → POST `/lobbies/<code>/ready/`
     - `updateRoleConfig(String code, Map<RoleId, int> roles)` → PATCH `/lobbies/<code>/` with `{"settings": {"roles": {...}}}` → returns `LobbyState`
     - `startGame(String code)` → POST `/onuw/lobbies/<code>/start/` → returns `{"game_id": "uuid"}`
     - `fetchLobby(String code)` → GET `/lobbies/<code>/` → returns `LobbyState`
  4. Create a `@riverpod` provider for `LobbyService`.
- **Files**: `frontend/lib/features/lobby/data/lobby_service.dart` (new, ~70 lines)
- **Parallel?**: Depends on T018 (uses `LobbyState` model).
- **Notes**: Each method maps directly to one API endpoint. Parse responses into `LobbyState.fromJson()`. Handle errors via Dio exceptions (the `AuthInterceptor` handles 401s automatically).

### Subtask T021 – Create `LobbyNotifier`

- **Purpose**: Riverpod `AsyncNotifier` coordinating HTTP state with WebSocket real-time events (FR-006, FR-027).
- **Steps**:
  1. Create `frontend/lib/features/lobby/presentation/lobby_notifier.dart`.
  2. Implement `@riverpod` `AsyncNotifier` family provider keyed by lobby code:
     ```dart
     @riverpod
     class LobbyNotifier extends _$LobbyNotifier {
       @override
       Future<LobbyState> build(String code) async {
         // 1. Fetch initial lobby state via LobbyService
         // 2. Connect lobby WebSocket via ReconnectingWebSocket
         // 3. Listen to WS events and update state
         // 4. ref.onDispose to close WS
       }
     }
     ```
  3. WebSocket event handling per `contracts/api-contracts.md`:
     - `player_joined` → re-fetch full lobby state via `lobbyService.fetchLobby(code)` (event has only username, insufficient for player list)
     - `player_left` → re-fetch full lobby state (same reason)
     - `player_ready` → update matching player's `isReady` flag in local state (event has complete data)
     - `lobby_update` → update `settings` in local state (role configuration changed by host)
     - `game_started` → extract `game_id`, navigate to `/game/<gameId>` (WS provider auto-disposes)
  4. Expose methods: `toggleReady()`, `startGame()`, `leave()`, `updateRoleConfig(Map<RoleId, int> roles)`.
  5. `ref.onDispose` closes the WebSocket connection.
- **Files**: `frontend/lib/features/lobby/presentation/lobby_notifier.dart` (new, ~120 lines)
- **Parallel?**: Depends on T018 (models), T020 (service).
- **Notes**: The `game_started` handling (FR-027) is critical — it bridges lobby to game. Extract `game_id` from the WS event, then navigate. The WS connection is automatically closed via `ref.onDispose` when the provider is invalidated by navigation. For `player_joined`/`player_left`, re-fetching is preferred over constructing from partial WS data to stay consistent with server truth (spec US3 AS7).

### Subtask T022 – Tests

- **Purpose**: Verify all lobby domain, service, and notifier behavior (TEST_FIRST directive).
- **Steps**:
  1. **Model tests** in `frontend/test/features/lobby/domain/lobby_state_test.dart`:
     - JSON serialization roundtrip for `LobbyPlayer` and `LobbyState`.
     - Verify `fromJson` handles the backend response format.
  2. **RoleConfig tests** in `frontend/test/features/lobby/domain/role_config_test.dart`:
     - Valid config (total = players + 3) returns true.
     - Invalid total returns false with descriptive error.
     - Mason count 1 returns false.
     - Mason count 0 and 2 return true.
     - Player count outside 3-10 returns false.
     - Step size returns 2 for Mason, 1 for others.
     - Presets match `recommended-setups.md` data.
  3. **Service tests** in `frontend/test/features/lobby/data/lobby_service_test.dart`:
     - Mock `AuthenticatedClient`. Verify each method calls the correct endpoint with correct HTTP method and body.
     - Verify response parsing into `LobbyState`.
  4. **Notifier tests** in `frontend/test/features/lobby/presentation/lobby_notifier_test.dart`:
     - Mock `LobbyService` and `ReconnectingWebSocket`.
     - `build()` fetches initial state and connects WS.
     - `player_joined` WS event triggers re-fetch.
     - `player_ready` WS event updates player in-place.
     - `lobby_update` WS event updates settings.
     - `game_started` WS event extracts game_id (verify via navigation mock or state).
- **Files**: `frontend/test/features/lobby/domain/lobby_state_test.dart`, `frontend/test/features/lobby/domain/role_config_test.dart`, `frontend/test/features/lobby/data/lobby_service_test.dart`, `frontend/test/features/lobby/presentation/lobby_notifier_test.dart` (new, ~250 lines total)
- **Parallel?**: RoleConfig tests (pure logic) can be written immediately. Others as implementation is scaffolded.
- **Notes**: Use `mocktail` for mocking. Use existing test harness patterns from `frontend/test/helpers/`.

## Test Strategy

**Directive**: TEST_FIRST.

**Commands**:
```bash
cd frontend && just test
cd frontend && just check
cd frontend && just gen
```

**Order**: RoleConfig tests first (pure logic, no mocks), then model tests, then service tests (mock HTTP), then notifier tests (mock service + WS).

## Risks & Mitigations

- **Risk**: Recommended presets change with game rules.
  **Mitigation**: Read from const map populated from game spec; easy to update.
- **Risk**: Re-fetching on `player_joined`/`player_left` increases API load.
  **Mitigation**: Events are infrequent (lobby joins). Alternative (constructing from partial WS data) would diverge from server truth.
- **Risk**: Navigation from `game_started` event races with WS dispose.
  **Mitigation**: Navigation triggers provider invalidation, which triggers `ref.onDispose`, which closes WS. Order is deterministic.

## Review Guidance

- Verify `LobbyNotifier` re-fetches on `player_joined`/`player_left` (not in-place update).
- Verify `player_ready` updates in-place (no re-fetch — event has complete data).
- Verify RoleConfig validation matches game rules (Mason step=2, total=players+3, count 3-10).
- Verify `ref.onDispose` closes the WebSocket.
- Verify `game_started` handler extracts `game_id` and navigates.
- Run `just check && just test` from `frontend/`.

## Activity Log

> **CRITICAL**: Chronological order (oldest first, newest last).

### Updating Lane Status

1. **Edit directly**: Change `lane:` in frontmatter AND append activity log entry
2. **Use CLI**: `spec-kitty agent tasks move-task WP05 --to <lane> --note "message"`

**Valid lanes**: `planned`, `doing`, `for_review`, `done`

- 2026-03-31T07:30:22Z – system – lane=planned – Prompt created.
- 2026-03-31T14:36:16Z – headless-impl – shell_pid=93451 – lane=doing – Assigned agent via workflow command
