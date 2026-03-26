import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/models/game_phase.dart';
import 'package:midnight_village/features/auth/domain/auth_state.dart';
import 'package:midnight_village/features/auth/domain/user.dart';
import 'package:midnight_village/features/auth/presentation/auth_notifier.dart';

import '../design_system/test_helpers/pump_with_tokens.dart';
import 'mock_websocket.dart';

// ---------------------------------------------------------------------------
// Placeholder game state types
//
// These stubs exist until real game state types are defined in the app.
// When real game state lands, update [gameStateProvider] and [PlayerInfo]
// to use the canonical types from lib/.
// ---------------------------------------------------------------------------

/// Minimal game state for test harnesses.
///
/// Holds the current [phase] and list of [players]. Replace with the real
/// app type when it is added to `lib/`.
class GameState {
  const GameState({required this.phase, required this.players});

  final GamePhase phase;
  final List<PlayerInfo> players;
}

/// Minimal player descriptor for test harnesses.
///
/// Replace with the real app type when it is added to `lib/`.
class PlayerInfo {
  const PlayerInfo({required this.id, required this.name});

  final String id;
  final String name;
}

/// Provides the current game state.
///
/// Defaults to lobby with no players. Override via
/// [pumpWithGameState] — or directly with
/// `gameStateProvider.overrideWithValue(GameState(...))` — in tests.
final gameStateProvider = Provider<GameState>(
  (_) => const GameState(phase: GamePhase.lobby, players: []),
  name: 'gameStateProvider',
);

/// Provides the active WebSocket channel.
///
/// Defaults to a fresh [MockWebSocketChannel]. Override via
/// [pumpWithGameState] to inject a channel whose events you can control.
final webSocketProvider = Provider<WebSocketChannelInterface>(
  (_) => MockWebSocketChannel(),
  name: 'webSocketProvider',
);

// ---------------------------------------------------------------------------
// Test harness extensions
// ---------------------------------------------------------------------------

extension TestHarnessExtension on WidgetTester {
  /// Pumps [widget] with an authenticated user pre-configured.
  ///
  /// Auth state is injected directly — no token-storage access or network
  /// requests occur during setup. Setup cost is 3–5 lines.
  ///
  /// Composes on top of [pumpWithTokens]: the theme setup from that helper
  /// is preserved, and [overrides] are appended after the auth override.
  ///
  /// Example:
  /// ```dart
  /// await tester.pumpAuthenticated(
  ///   const MyWidget(),
  ///   playerName: 'Alice',
  /// );
  /// expect(find.text('Alice'), findsOneWidget);
  /// ```
  Future<void> pumpAuthenticated(
    Widget widget, {
    String playerName = 'TestPlayer',
    int userId = 1,
    List<Override>? overrides,
  }) async {
    await pumpWithTokens(
      widget,
      overrides: [
        authProvider.overrideWithValue(
          AuthState.authenticated(
            User(id: userId, displayName: playerName),
          ),
        ),
        ...?overrides,
      ],
    );
  }

  /// Pumps [widget] with a specific game phase and player list.
  ///
  /// Composes on [pumpAuthenticated] — auth state is also pre-configured
  /// so widgets that require login work without extra setup.
  ///
  /// Pass a [webSocket] to capture outgoing messages or inject server events.
  /// When omitted, a fresh [MockWebSocketChannel] is created automatically.
  ///
  /// Example:
  /// ```dart
  /// final players = List.generate(5, (i) => PlayerInfo(id: '$i', name: 'P$i'));
  /// await tester.pumpWithGameState(
  ///   const GameWidget(),
  ///   phase: GamePhase.voting,
  ///   players: players,
  /// );
  /// expect(find.text('Voting'), findsOneWidget);
  /// ```
  Future<void> pumpWithGameState(
    Widget widget, {
    required GamePhase phase,
    required List<PlayerInfo> players,
    MockWebSocketChannel? webSocket,
    String playerName = 'TestPlayer',
    int userId = 1,
    List<Override>? overrides,
  }) async {
    final mockWs = webSocket ?? MockWebSocketChannel();
    await pumpAuthenticated(
      widget,
      playerName: playerName,
      userId: userId,
      overrides: [
        gameStateProvider.overrideWithValue(
          GameState(phase: phase, players: players),
        ),
        webSocketProvider.overrideWithValue(mockWs),
        ...?overrides,
      ],
    );
  }
}
