import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/models/game_phase.dart';

import '../mock_websocket.dart';
import '../test_harness.dart';

/// Examples: WebSocket event injection via pumpWithGameState
///
/// These tests demonstrate how to use [MockWebSocketChannel] together with
/// the [pumpWithGameState] harness to simulate server events and assert on
/// UI changes. Copy the pattern for any test where the UI must react to
/// real-time WebSocket messages.
void main() {
  group('WebSocket event injection harness', () {
    final testPlayers = List.generate(
      3,
      (i) => PlayerInfo(id: 'id-$i', name: 'Player $i'),
    );

    testWidgets('phase_change event updates phase display', (tester) async {
      final mockWs = MockWebSocketChannel();

      // Boot with discussion phase; inject the same mock into the harness so
      // addServerEvent() delivers to the widget's stream listener.
      await tester.pumpWithGameState(
        _WebSocketReactiveWidget(webSocket: mockWs),
        phase: GamePhase.discussion,
        players: testPlayers,
        webSocket: mockWs,
      );

      expect(find.text('Phase: Discussion'), findsOneWidget);

      // Simulate the server sending a phase transition.
      mockWs.addServerEvent(
        jsonEncode({'type': 'phase_change', 'phase': 'voting'}),
      );
      await tester.pump();

      expect(find.text('Phase: Voting'), findsOneWidget);
    });

    testWidgets('client messages sent by widget are captured', (tester) async {
      final mockWs = MockWebSocketChannel();

      await tester.pumpWithGameState(
        _SendActionWidget(webSocket: mockWs),
        phase: GamePhase.voting,
        players: testPlayers,
        webSocket: mockWs,
      );

      // Trigger the UI action that sends over the WebSocket.
      await tester.tap(find.text('Vote'));
      await tester.pump();

      // Assert on the exact payload the widget sent.
      expect(mockWs.sentMessages, hasLength(1));
      final sent =
          jsonDecode(mockWs.sentMessages.first as String) as Map<String, dynamic>;
      expect(sent['type'], equals('submit_vote'));
    });

    testWidgets('server errors surface to the UI without crashing',
        (tester) async {
      final mockWs = MockWebSocketChannel();

      await tester.pumpWithGameState(
        _WebSocketReactiveWidget(webSocket: mockWs),
        phase: GamePhase.discussion,
        players: testPlayers,
        webSocket: mockWs,
      );

      // Simulate a server-side error (e.g. disconnection).
      mockWs.addServerError(Exception('Server disconnected'));
      await tester.pump();

      expect(find.text('Connection error'), findsOneWidget);
    });

    testWidgets('multiple events are processed in order', (tester) async {
      final mockWs = MockWebSocketChannel();

      await tester.pumpWithGameState(
        _WebSocketReactiveWidget(webSocket: mockWs),
        phase: GamePhase.lobby,
        players: testPlayers,
        webSocket: mockWs,
      );

      // night → discussion → voting
      for (final phase in [GamePhase.night, GamePhase.discussion, GamePhase.voting]) {
        mockWs.addServerEvent(
          jsonEncode({'type': 'phase_change', 'phase': phase.name}),
        );
        await tester.pump();
        expect(find.text('Phase: ${phase.displayName}'), findsOneWidget);
      }
    });
  });
}

// ---------------------------------------------------------------------------
// Test widgets
// ---------------------------------------------------------------------------

/// Widget that subscribes to a WebSocket and updates its phase display on
/// each `phase_change` event.
///
/// This pattern shows the subscription lifecycle:
/// 1. Read initial state from [gameStateProvider].
/// 2. Subscribe to the WebSocket stream in [initState].
/// 3. Call [setState] to trigger a rebuild when an event arrives.
class _WebSocketReactiveWidget extends ConsumerStatefulWidget {
  const _WebSocketReactiveWidget({required this.webSocket});

  final MockWebSocketChannel webSocket;

  @override
  ConsumerState<_WebSocketReactiveWidget> createState() =>
      _WebSocketReactiveWidgetState();
}

class _WebSocketReactiveWidgetState
    extends ConsumerState<_WebSocketReactiveWidget> {
  GamePhase? _livePhase;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    widget.webSocket.stream.listen(
      _onEvent,
      onError: (_) => setState(() => _hasError = true),
    );
  }

  void _onEvent(dynamic raw) {
    final event = jsonDecode(raw as String) as Map<String, dynamic>;
    if (event['type'] == 'phase_change') {
      final phase = GamePhase.values.firstWhere(
        (p) => p.name == event['phase'],
      );
      setState(() => _livePhase = phase);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) return const Text('Connection error');
    final gameState = ref.watch(gameStateProvider);
    final displayPhase = _livePhase ?? gameState.phase;
    return Text('Phase: ${displayPhase.displayName}');
  }
}

/// Widget that sends a vote action over the WebSocket when tapped.
class _SendActionWidget extends ConsumerWidget {
  const _SendActionWidget({required this.webSocket});

  final MockWebSocketChannel webSocket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => webSocket.send(
        jsonEncode({'type': 'submit_vote', 'target': 'player-0'}),
      ),
      child: const Text('Vote'),
    );
  }
}
