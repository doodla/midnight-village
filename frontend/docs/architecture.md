# Frontend Architecture Playbook

This document defines how to structure any new feature in the Midnight Village frontend. It answers "where does this code go?" and "how do real-time events flow?" for any frontend developer.

**Core principle**: The client never computes game logic. The server is the single source of truth. Clients send actions; the server validates and broadcasts results.

---

## Feature Module Structure

Every feature lives under `lib/features/<feature-name>/` and is split into three layers.

### Three-Layer Architecture

```
lib/features/<feature>/
├── domain/       # Pure Dart models and state
├── data/         # Services, repositories, external I/O
└── presentation/ # Riverpod notifiers and screen widgets
```

#### Domain Layer (`lib/features/<feature>/domain/`)

- **What belongs here**: Pure Dart models, Freezed state classes, enums, value objects
- **No Flutter dependencies** — no `import 'package:flutter/...'`
- **No imports from `data/` or `presentation/`**
- **Examples**: `GameState`, `NightActionState`, `VoteState`, `User`

```dart
// lib/features/game/domain/game_state.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'game_state.freezed.dart';

@freezed
sealed class GameState with _$GameState {
  const factory GameState.lobby({required String gameCode}) = GameLobby;
  const factory GameState.night({required int secondsRemaining}) = GameNight;
  const factory GameState.discussion() = GameDiscussion;
  const factory GameState.voting() = GameVoting;
  const factory GameState.results({required GameResults results}) = GameResults;
}
```

#### Data Layer (`lib/features/<feature>/data/`)

- **What belongs here**: HTTP services (Dio calls), WebSocket repositories, response parsing
- **Imports allowed**: `domain/` models, `core/api/`, `core/storage/`
- **No Flutter dependencies** (unless unavoidable)
- **Examples**: `GameService` (HTTP), `GameRepository` (WebSocket)

```dart
// lib/features/game/data/game_service.dart
class GameService {
  GameService({required ApiClient apiClient}) : _client = apiClient;

  final ApiClient _client;

  Future<GameState> fetchCurrentGame() async { /* ... */ }
  Future<void> submitAction(NightAction action) async { /* ... */ }
}
```

#### Presentation Layer (`lib/features/<feature>/presentation/`)

- **What belongs here**: Riverpod notifiers (`@riverpod class`), screen widgets (`ConsumerWidget`)
- **Imports allowed**: `domain/` models, `data/` services, `design_system/` components
- **Examples**: `GameNotifier`, `NightPhaseScreen`, `VotingScreen`

```dart
// lib/features/game/presentation/game_notifier.dart
@riverpod
class GameNotifier extends _$GameNotifier {
  @override
  GameState build() { /* ... */ }

  void handleEvent(GameEvent event) { /* update state from server event */ }
}
```

### Dependency Rules

```
presentation → domain, data, design_system
data         → domain, core
domain       → (nothing — pure Dart)
design_system → (nothing — independent component library)
```

These rules prevent circular dependencies and keep game logic testable without Flutter.

### New Feature Checklist

When adding a new game feature (e.g., voting screen, night phase):

- [ ] Create `lib/features/<name>/domain/` with Freezed state models
- [ ] Create `lib/features/<name>/data/` with HTTP service and/or WebSocket repository
- [ ] Create `lib/features/<name>/presentation/` with Riverpod notifier + `ConsumerWidget` screen
- [ ] Add route to `lib/core/router/routes.dart`
- [ ] Use design system components in screens (`MvScaffold`, `MvButton`, `MvCard`, etc.)
- [ ] Add tests mirroring the source tree: `test/features/<name>/`

### Reference: Auth Feature

The existing `lib/features/auth/` is a canonical example of this structure:

- `domain/user.dart` — `User` model with invariants
- `domain/auth_state.dart` — Freezed sealed class (`AuthInitial`, `AuthLoading`, etc.)
- `data/auth_service.dart` — Dio HTTP calls to `/auth/guest/` and `/auth/token/refresh/`
- `data/auth_repository.dart` — Orchestrates service + storage
- `presentation/auth_notifier.dart` — `@riverpod class AuthNotifier` with state machine

---

## Real-Time Event Flow

WebSocket events travel from the server to a widget rebuild via this path:

```
Server (Django Channels)
  ↓  WebSocket JSON message
WebSocket connection (planned: core/api/ws_client.dart)
  ↓  raw JSON string
Event deserialization (data layer: game_repository.dart)
  ↓  typed domain event
Riverpod notifier (presentation: game_notifier.dart)
  ↓  state update
ConsumerWidget rebuild (presentation: game_screen.dart)
  ↓  updated props
Design system component renders new state
```

**Server authority**: The client never computes game outcomes. It only displays what the server sends. A client that receives `"revealed_role": "werewolf"` renders a werewolf card — it does NOT infer who else might be a werewolf.

### Event Scenario 1: Night Action Result Received

Server sends:
```json
{"type": "night_action_result", "role": "seer", "target": "player_3", "revealed_role": "werewolf"}
```

1. `GameRepository.stream` receives message, deserializes to `NightActionResultEvent`
2. `GameNotifier.handleEvent(event)` updates state:
   ```dart
   state = state.copyWith(nightResult: PeekResult(target: event.target, role: event.revealedRole));
   ```
3. `NightPhaseScreen` rebuilds, shows `RoleCard` face-up with the revealed role

The client does NOT decide which role was revealed. It renders exactly what the server says.

### Event Scenario 2: Phase Transition

Server sends:
```json
{"type": "phase_change", "phase": "voting"}
```

1. `GameRepository` deserializes to `PhaseChangeEvent(phase: GamePhase.voting)`
2. `GameNotifier` updates: `state = GameState.voting()`
3. GoRouter redirect guard detects `currentPhase == voting` → navigates to `/game/vote`

The server decides when phases change. The client only reacts.

### Event Scenario 3: Vote Progress Update

Server sends:
```json
{"type": "vote_update", "votes_submitted": 4, "total_players": 6}
```

1. `VoteRepository` deserializes to `VoteProgressEvent(submitted: 4, total: 6)`
2. `VotingNotifier` updates: `state = state.copyWith(submitted: 4, total: 6)`
3. `VotingScreen` shows "4 of 6 votes in" — **without revealing who voted for whom**

The client shows progress counts only. Individual vote choices are hidden until results.

### WebSocket Connection Lifecycle

```
connect()     ← on game join (HTTP POST succeeds, we have a game ID)
  ↓
ping/pong     ← periodic heartbeat to detect silent disconnects
  ↓
onDone        ← server closed connection (game ended or timeout)
onError       ← network error → trigger reconnection flow
  ↓
disconnect()  ← on game leave or app background
```

The WebSocket client lives in `core/api/` (planned: `ws_client.dart`). Feature repositories subscribe to the event stream; they do not manage the connection directly.

---

## Phase-Driven Navigation

### Phase → Route Mapping

Game phases map directly to routes. The server decides the current phase; the client only navigates.

| Phase        | Route              | Screen             |
|--------------|--------------------|--------------------|
| `lobby`      | `/game/lobby`      | `LobbyScreen`      |
| `night`      | `/game/night`      | `NightPhaseScreen` |
| `discussion` | `/game/discussion` | `DiscussionScreen` |
| `voting`     | `/game/vote`       | `VotingScreen`     |
| `results`    | `/game/results`    | `ResultsScreen`    |

Routes are defined in `lib/core/router/routes.dart` using typed GoRouter.

### Router Guard Pattern

A GoRouter redirect guard reads the current game phase and forces navigation to the correct screen:

```dart
// planned: lib/core/router/app_router.dart
redirect: (context, state) {
  final gamePhase = ref.read(gameNotifierProvider).currentPhase;
  if (gamePhase == null) return null; // not in a game

  final expectedPath = phaseToPath(gamePhase);
  if (state.uri.path != expectedPath) return expectedPath;
  return null; // already on correct screen
},
```

Phase transition flow:
```
Server sends phase_change event
  → GameNotifier updates currentPhase
  → Router guard fires on next navigation attempt
  → Player navigated to corresponding screen
```

The client **never** decides which phase to show based on local timer or action completion. It waits for the server's `phase_change` event.

### Reconnection Pattern

When the WebSocket disconnects mid-game:

**Step 1 — Detect disconnect**
- `WsClient.onDone` or `onError` handler fires
- Show `MvLoading(message: 'Reconnecting...')` immediately

**Step 2 — Re-establish connection (exponential backoff)**
```dart
// Backoff: 1s, 2s, 4s, 8s, cap at 30s
await Future.delayed(Duration(seconds: backoffSeconds));
await wsClient.connect(gameId: currentGameId);
```

**Step 3 — Fetch current state via HTTP**
```dart
// Always re-sync from server after reconnect, never trust stale local state
final gameState = await gameService.fetchCurrentGame();
```

**Step 4 — Update all Riverpod state**
```dart
ref.read(gameNotifierProvider.notifier).restoreFromSnapshot(gameState);
```

**Step 5 — Router guard navigates to correct phase screen**

The router guard fires automatically once state is restored.

#### Reconnection Edge Cases

| Situation | Behavior |
|---|---|
| Game ended while disconnected | `fetchCurrentGame()` returns phase=`results` → show `ResultsScreen` |
| Player was eliminated while disconnected | `fetchCurrentGame()` includes elimination status → `ResultsScreen` shows it |
| Mid-night-action disconnect | Action was skipped server-side after timer → reconnect shows updated state |
| No active game | `fetchCurrentGame()` returns 404 → navigate to lobby |

The client does NOT attempt to reconstruct what happened while disconnected. It fetches the current state from the server and renders it as-is.

### Reference: Session Restoration Pattern

`AuthNotifier._checkStoredSession()` in `lib/features/auth/presentation/auth_notifier.dart` shows this pattern: on startup, try to restore state from storage/network, then update Riverpod state, and let the router guard handle navigation. Reconnection follows the same shape.
