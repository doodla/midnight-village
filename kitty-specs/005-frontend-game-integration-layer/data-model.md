# Data Model: Frontend Game Integration Layer

**Feature**: 005-frontend-game-integration-layer
**Date**: 2026-03-31

## Updated Existing Models

### VoteResult (update `design_system/models/game_result.dart`)

Make target fields nullable to represent abstainers (disconnected/timed-out players).

```dart
@freezed
abstract class VoteResult with _$VoteResult {
  const factory VoteResult({
    required String voterId,
    required String voterName,
    String? targetId,       // was: required String — null for abstainers
    String? targetName,     // was: required String — null for abstainers
  }) = _VoteResult;

  factory VoteResult.fromJson(Map<String, dynamic> json) =>
      _$VoteResultFromJson(json);
}
```

### PlayerResult (update `design_system/models/game_result.dart`)

Add vote target and elimination reason fields.

```dart
enum EliminationReason { vote, hunterChain }

@freezed
abstract class PlayerResult with _$PlayerResult {
  const factory PlayerResult({
    required String id,
    required String displayName,
    required RoleId originalRole,
    required RoleId finalRole,
    required TeamId team,
    required bool isEliminated,
    required bool isWinner,
    String? voteTargetId,                    // NEW — who this player voted for
    String? voteTargetName,                  // NEW — display name of vote target
    EliminationReason? eliminationReason,    // NEW — null if not eliminated
  }) = _PlayerResult;

  factory PlayerResult.fromJson(Map<String, dynamic> json) =>
      _$PlayerResultFromJson(json);
}
```

### GameResult (update `design_system/models/game_result.dart`)

Add center cards and vote results.

```dart
@freezed
abstract class GameResult with _$GameResult {
  const factory GameResult({
    required List<TeamId> winningTeams,
    required List<PlayerResult> players,
    required List<VoteResult> votes,         // NEW — per-player vote pairs
    required List<RoleId> centerCards,       // NEW — final center card identities
  }) = _GameResult;

  factory GameResult.fromJson(Map<String, dynamic> json) =>
      _$GameResultFromJson(json);
}
```

---

## New Domain Models

### Lobby Feature (`features/lobby/domain/`)

#### LobbyPlayer (`lobby_state.dart`)

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

#### LobbyState (`lobby_state.dart`)

```dart
@freezed
abstract class LobbyState with _$LobbyState {
  const factory LobbyState({
    required String code,
    required int hostId,
    required List<LobbyPlayer> players,
    required String status,                 // "waiting" | "in_game" | "finished"
    required int maxPlayers,
    required Map<String, int> roleConfig,   // role name -> count
  }) = _LobbyState;

  factory LobbyState.fromJson(Map<String, dynamic> json) =>
      _$LobbyStateFromJson(json);
}
```

#### RoleConfig (`role_config.dart`)

Not a Freezed model — a utility class for role configuration validation and presets.

```dart
class RoleConfig {
  /// Validates that total role count == playerCount + 3.
  static bool isValid(Map<RoleId, int> roles, int playerCount) {
    final total = roles.values.fold(0, (sum, count) => sum + count);
    return total == playerCount + 3;
  }

  /// Returns the step size for incrementing/decrementing a role.
  /// Mason increments by 2 (must always be 0 or 2).
  static int stepSize(RoleId role) => role == RoleId.mason ? 2 : 1;

  /// Maximum count per role (2 for Werewolf, 2 for Mason, 1 for all others).
  static int maxCount(RoleId role) => switch (role) {
    RoleId.werewolf => 2,
    RoleId.mason => 2,
    RoleId.villager => 3,
    _ => 1,
  };

  /// Recommended setups by player count, from docs/specs/onuw/recommended-setups.md.
  static Map<String, Map<RoleId, int>> presetsForPlayerCount(int count) {
    // Returns named presets (e.g., "Basic", "Intermediate", "Advanced")
    // populated from the game spec's recommended setups.
    // Implementation reads from a const map.
  }
}
```

### Game Feature (`features/game/domain/`)

#### GameSessionState (`game_session_state.dart`)

The central game state that the `GameNotifier` manages.

```dart
@freezed
abstract class GameSessionState with _$GameSessionState {
  const factory GameSessionState({
    required String gameId,
    required GamePhase phase,
    required int currentWave,
    DateTime? deadline,
    required YourRole yourRole,
    required List<GamePlayer> players,
    ActionPrompt? actionPrompt,
    NightSubView? nightSubView,
    ActionResult? lastActionResult,
    required VoteProgress voteProgress,
    GameResult? results,
    required List<RoleId> rolesInGame,
  }) = _GameSessionState;
}
```

#### YourRole (`game_session_state.dart`)

```dart
@freezed
abstract class YourRole with _$YourRole {
  const factory YourRole({
    required RoleId originalRole,
    required bool hasActed,
    RoleId? currentRole,     // only available in results phase
  }) = _YourRole;

  factory YourRole.fromJson(Map<String, dynamic> json) =>
      _$YourRoleFromJson(json);
}
```

#### GamePlayer (`game_session_state.dart`)

Public player info visible during gameplay (no role info).

```dart
@freezed
abstract class GamePlayer with _$GamePlayer {
  const factory GamePlayer({
    required int playerId,
    required String displayName,
    @Default(false) bool hasVoted,          // visible in voting phase only
    @Default(PlayerStatus.active) PlayerStatus status,
  }) = _GamePlayer;

  factory GamePlayer.fromJson(Map<String, dynamic> json) =>
      _$GamePlayerFromJson(json);
}
```

#### ActionPrompt (`night_state.dart`)

Received via WebSocket `action_prompt` event or from `GameMeSerializer.action_prompt`.

```dart
@freezed
abstract class ActionPrompt with _$ActionPrompt {
  const factory ActionPrompt({
    required String roleActingAs,           // display name for role identity strip
    required List<String> actionTypes,      // e.g., ["peek_player", "peek_center"]
    required Map<String, dynamic> validTargets,
    required int wave,
  }) = _ActionPrompt;

  factory ActionPrompt.fromJson(Map<String, dynamic> json) =>
      _$ActionPromptFromJson(json);
}
```

#### ActionResult (`night_state.dart`)

Received via WebSocket `action_result` event.

```dart
@freezed
abstract class ActionResult with _$ActionResult {
  const factory ActionResult({
    required int wave,
    required Map<String, dynamic> revealedInfo,
  }) = _ActionResult;

  factory ActionResult.fromJson(Map<String, dynamic> json) =>
      _$ActionResultFromJson(json);
}
```

#### NightSubView (`night_state.dart`)

Enum for the night phase sub-view state machine.

```dart
enum NightSubView {
  waiting,            // "The village sleeps..."
  seerChoice,         // Seer: peek_player vs peek_center
  actionPrompt,       // NightActionPrompt widget
  actionResult,       // Peek/swap result display
  loneWerewolfPeek,   // CenterCards with maxSelections: 1
}
```

#### VoteProgress (`voting_state.dart`)

Tracks vote submission progress without revealing targets.

```dart
@freezed
abstract class VoteProgress with _$VoteProgress {
  const factory VoteProgress({
    @Default({}) Map<int, bool> playerVoted,  // playerId -> hasVoted
    @Default(false) bool currentPlayerVoted,
  }) = _VoteProgress;
}
```

#### VoteRevealData (`voting_state.dart`)

Intermediate state between vote_reveal and game_results events.

```dart
@freezed
abstract class VoteRevealData with _$VoteRevealData {
  const factory VoteRevealData({
    required List<VoteResult> votes,
    required Map<String, int> tally,          // playerName -> vote count
  }) = _VoteRevealData;
}
```

### Core Infrastructure (`core/`)

#### WebSocketConnectionState (`core/websocket/websocket_channel.dart`)

```dart
enum WebSocketConnectionState {
  connecting,
  connected,
  disconnected,
  reconnecting,
}
```

#### WebSocketEvent (`core/websocket/websocket_channel.dart`)

Typed wrapper for raw WebSocket JSON messages.

```dart
@freezed
abstract class WebSocketEvent with _$WebSocketEvent {
  const factory WebSocketEvent({
    required String type,
    required Map<String, dynamic> data,
  }) = _WebSocketEvent;

  factory WebSocketEvent.fromJson(Map<String, dynamic> json) {
    return WebSocketEvent(
      type: json['type'] as String,
      data: Map<String, dynamic>.from(json)..remove('type'),
    );
  }
}
```

---

## New Riverpod Providers

### Core Providers (`features/auth/presentation/auth_notifier.dart` — extend existing)

```dart
/// Provides the authenticated API client with JWT interceptor.
/// keepAlive: true — shared across features.
@Riverpod(keepAlive: true)
AuthenticatedClient authenticatedClient(Ref ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  final apiClient = ref.watch(apiClientProvider);
  return AuthenticatedClient(
    tokenStorage: tokenStorage,
    refreshClient: apiClient,  // unauthenticated client for refresh calls
  );
}
```

### Lobby Providers (`features/lobby/presentation/lobby_notifier.dart`)

```dart
/// Provides the lobby service (HTTP calls).
@riverpod
LobbyService lobbyService(Ref ref) {
  return LobbyService(client: ref.watch(authenticatedClientProvider));
}

/// Manages lobby state for a given lobby code.
/// Family provider — one instance per lobby code.
@riverpod
class LobbyNotifier extends _$LobbyNotifier {
  @override
  Future<LobbyState> build(String lobbyCode) async {
    // 1. Fetch lobby state via GET /api/lobbies/<code>/
    // 2. Connect lobby WebSocket
    // 3. Listen to WS events, update state
    // 4. ref.onDispose: close WebSocket
  }

  Future<void> toggleReady() async { /* POST /api/lobbies/<code>/ready/ */ }
  Future<void> leave() async { /* POST /api/lobbies/<code>/leave/ */ }
  Future<void> startGame() async { /* POST /api/onuw/lobbies/<code>/start/ */ }
  Future<void> updateRoleConfig(Map<String, int> roles) async { /* PATCH /api/lobbies/<code>/ */ }
}
```

### Game Providers (`features/game/presentation/game_notifier.dart`)

```dart
/// Provides the game service (HTTP calls).
@riverpod
GameService gameService(Ref ref) {
  return GameService(client: ref.watch(authenticatedClientProvider));
}

/// Manages game state for a given game ID.
/// Family provider — one instance per game.
@riverpod
class GameNotifier extends _$GameNotifier {
  @override
  Future<GameSessionState> build(String gameId) async {
    // 1. Fetch game state via GET /games/<gameId>/me/
    // 2. Connect game WebSocket
    // 3. Listen to WS events, update state per event type
    // 4. ref.onDispose: close WebSocket
  }

  Future<void> submitAction(String actionType, Map<String, dynamic> targets) async {
    // POST /api/onuw/games/<id>/action/
  }
  Future<void> submitVote(int targetPlayerId) async {
    // POST /api/onuw/games/<id>/vote/
  }
  Future<void> endDiscussion() async {
    // POST /api/onuw/games/<id>/end-discussion/
  }
  Future<void> fetchResults() async {
    // GET /api/onuw/games/<id>/results/
  }
}
```

### Timer Provider (`features/game/presentation/timer_provider.dart`)

```dart
/// Countdown timer from a server-provided deadline.
/// Returns remaining Duration, ticking every second.
/// Returns null when no deadline or deadline has passed.
@riverpod
Stream<Duration?> countdownTimer(Ref ref, DateTime? deadline) async* {
  if (deadline == null) {
    yield null;
    return;
  }
  while (true) {
    final remaining = deadline.difference(DateTime.now());
    if (remaining.isNegative) {
      yield Duration.zero;
      return;
    }
    yield remaining;
    await Future.delayed(const Duration(seconds: 1));
  }
}
```

### WebSocket Provider (`core/websocket/` — new file)

```dart
/// Provides a WebSocket connection for a given URL.
/// Manages connection lifecycle and reconnection.
@riverpod
ReconnectingWebSocket webSocketConnection(Ref ref, String url) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  final ws = ReconnectingWebSocket(url: url, tokenStorage: tokenStorage);
  ref.onDispose(() => ws.dispose());
  return ws;
}
```

---

## Entity Relationship Summary

```
AuthState (existing)
  └── User (existing)

LobbyState (new)
  ├── LobbyPlayer[] (new)
  └── roleConfig: Map<String, int>

GameSessionState (new)
  ├── YourRole (new)
  ├── GamePlayer[] (new)
  ├── ActionPrompt? (new)
  ├── ActionResult? (new)
  ├── VoteProgress (new)
  ├── GameResult (updated)
  │   ├── PlayerResult[] (updated — +voteTarget, +eliminationReason)
  │   ├── VoteResult[] (updated — nullable targets)
  │   └── centerCards: RoleId[]
  └── rolesInGame: RoleId[]

WebSocketEvent (new) — parsed from raw JSON
WebSocketConnectionState (new) — enum for overlay
```
