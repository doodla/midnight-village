import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/websocket/reconnecting_websocket.dart';
import 'package:midnight_village/core/websocket/websocket_channel.dart';
import 'package:midnight_village/core/storage/token_storage.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/mock_websocket.dart';
import '../../helpers/timer_control.dart';
import '../../helpers/game_events.dart';

class MockTokenStorage extends Mock implements TokenStorage {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ReconnectingWebSocket _makeWs({
  required MockTokenStorage tokenStorage,
  required WebSocketChannelInterface Function(Uri) channelFactory,
  Duration initialBackoff = const Duration(seconds: 1),
  Duration maxBackoff = const Duration(seconds: 30),
}) {
  return ReconnectingWebSocket(
    url: 'ws://localhost:8000/ws/game/123/',
    tokenStorage: tokenStorage,
    initialBackoff: initialBackoff,
    maxBackoff: maxBackoff,
    channelFactory: channelFactory,
  );
}

void main() {
  group('ReconnectingWebSocket', () {
    late MockTokenStorage tokenStorage;
    late List<MockWebSocketChannel> createdChannels;
    late List<Uri> connectedUris;

    setUp(() {
      tokenStorage = MockTokenStorage();
      createdChannels = [];
      connectedUris = [];
      when(() => tokenStorage.accessToken).thenAnswer((_) async => 'jwt-abc');
    });

    WebSocketChannelInterface successFactory(Uri uri) {
      connectedUris.add(uri);
      // Accepts sends: this file tests the socket plumbing itself.
      final ch = MockWebSocketChannel(acceptsSends: true);
      createdChannels.add(ch);
      return ch;
    }

    // -------------------------------------------------------------------------
    // Connection: JWT query parameter
    // -------------------------------------------------------------------------

    test('connect appends token as query parameter', () async {
      final ws = _makeWs(
        tokenStorage: tokenStorage,
        channelFactory: successFactory,
      );
      await ws.connect();

      expect(connectedUris[0].queryParameters['token'], equals('jwt-abc'));
      expect(connectedUris[0].path, equals('/ws/game/123/'));

      ws.dispose();
    });

    test('connect emits connecting then connected states', () async {
      final ws = _makeWs(
        tokenStorage: tokenStorage,
        channelFactory: successFactory,
      );
      final states = <WebSocketConnectionState>[];
      ws.connectionState.listen(states.add);

      await ws.connect();

      expect(
        states,
        equals([
          WebSocketConnectionState.connecting,
          WebSocketConnectionState.connected,
        ]),
      );

      ws.dispose();
    });

    // -------------------------------------------------------------------------
    // Message forwarding
    // -------------------------------------------------------------------------

    test('messages from underlying channel forwarded on stream', () async {
      final ws = _makeWs(
        tokenStorage: tokenStorage,
        channelFactory: successFactory,
      );
      await ws.connect();

      final received = <dynamic>[];
      ws.stream.listen(received.add);

      final event = GameEvents.gameStarted(gameId: 'g1');
      createdChannels[0].addServerEvent(event);
      await Future.microtask(() {});

      expect(received, [event]);

      ws.dispose();
    });

    // -------------------------------------------------------------------------
    // Exponential backoff: factory fails repeatedly
    //
    // Backoff escalates only on FAILED connection attempts (factory throws).
    // On success: backoff resets to initialBackoff.
    // -------------------------------------------------------------------------

    testWithTimerControl(
      'backoff escalates on consecutive failed connection attempts',
      (control) {
        // Factory always fails (simulates server down)
        var callCount = 0;
        final ws = _makeWs(
          tokenStorage: tokenStorage,
          channelFactory: (uri) {
            connectedUris.add(uri);
            callCount++;
            throw StateError('connection refused');
          },
        );

        unawaited(ws.connect());
        control.flushMicrotasks(); // attempt 1: fails → 1s timer, backoff→2s

        expect(callCount, equals(1));

        // 1s elapses → attempt 2
        control.advanceBySeconds(1);
        control.flushMicrotasks();
        expect(callCount, equals(2)); // 2s timer set, backoff→4s

        // 2s elapses → attempt 3
        control.advanceBySeconds(2);
        control.flushMicrotasks();
        expect(callCount, equals(3)); // 4s timer set, backoff→8s

        // 4s elapses → attempt 4
        control.advanceBySeconds(4);
        control.flushMicrotasks();
        expect(callCount, equals(4)); // 8s timer set, backoff→16s

        // 8s elapses → attempt 5
        control.advanceBySeconds(8);
        control.flushMicrotasks();
        expect(callCount, equals(5));

        ws.dispose();
      },
    );

    testWithTimerControl('backoff caps at maxBackoff (30s)', (control) {
      var callCount = 0;
      final ws = _makeWs(
        tokenStorage: tokenStorage,
        channelFactory: (_) {
          callCount++;
          throw StateError('server down');
        },
        initialBackoff: const Duration(seconds: 16),
        maxBackoff: const Duration(seconds: 30),
      );

      unawaited(ws.connect());
      control.flushMicrotasks(); // attempt 1: 16s timer, backoff→30s

      // 16s elapses → attempt 2
      control.advanceBySeconds(16);
      control.flushMicrotasks(); // attempt 2: 30s timer (capped), backoff→30s

      final callsAtCap = callCount;

      // Advance 29s: timer at 30s has NOT fired yet
      control.advanceBySeconds(29);
      control.flushMicrotasks();
      expect(callCount, equals(callsAtCap));

      // Advance 1 more second → fires at 30s (not 32s)
      control.advanceBySeconds(1);
      control.flushMicrotasks();
      expect(callCount, equals(callsAtCap + 1));

      ws.dispose();
    });

    // -------------------------------------------------------------------------
    // State stream transitions
    // -------------------------------------------------------------------------

    testWithTimerControl(
      'connectionState transitions: connecting→connected→disconnected→reconnecting→connected',
      (control) {
        final ws = _makeWs(
          tokenStorage: tokenStorage,
          channelFactory: successFactory,
        );
        final states = <WebSocketConnectionState>[];
        ws.connectionState.listen(states.add);

        unawaited(ws.connect());
        control.flushMicrotasks();

        expect(
          states,
          containsAll([
            WebSocketConnectionState.connecting,
            WebSocketConnectionState.connected,
          ]),
        );

        // Simulate disconnect
        unawaited(createdChannels[0].close());
        control.flushMicrotasks();

        expect(
          states,
          containsAll([
            WebSocketConnectionState.disconnected,
            WebSocketConnectionState.reconnecting,
          ]),
        );

        // Reconnect after 1s
        control.advanceBySeconds(1);
        control.flushMicrotasks();

        expect(states.last, equals(WebSocketConnectionState.connected));

        ws.dispose();
      },
    );

    // -------------------------------------------------------------------------
    // JWT re-read on each reconnect
    // -------------------------------------------------------------------------

    testWithTimerControl(
      'reads fresh JWT from TokenStorage on each reconnection attempt',
      (control) {
        var callCount = 0;
        when(() => tokenStorage.accessToken).thenAnswer((_) async {
          callCount++;
          return 'token-$callCount';
        });

        final ws = _makeWs(
          tokenStorage: tokenStorage,
          channelFactory: successFactory,
        );

        unawaited(ws.connect());
        control.flushMicrotasks();

        expect(connectedUris[0].queryParameters['token'], equals('token-1'));

        unawaited(createdChannels[0].close());
        control.flushMicrotasks();

        control.advanceBySeconds(1);
        control.flushMicrotasks();

        // Second attempt uses a freshly-read token
        expect(connectedUris[1].queryParameters['token'], equals('token-2'));

        ws.dispose();
      },
    );

    // -------------------------------------------------------------------------
    // Backoff reset after successful reconnect
    // -------------------------------------------------------------------------

    testWithTimerControl(
      'backoff resets to initialBackoff after successful reconnection',
      (control) {
        // Factory: fails on attempt 2, succeeds otherwise.
        // Sequence: connect(success) → disconnect → attempt2(fail) → attempt3(success)
        // After success: next disconnect starts from initialBackoff again.
        var callCount = 0;
        final ws = _makeWs(
          tokenStorage: tokenStorage,
          channelFactory: (uri) {
            connectedUris.add(uri);
            callCount++;
            if (callCount == 2) throw StateError('temporary failure');
            final ch = MockWebSocketChannel();
            createdChannels.add(ch);
            return ch;
          },
        );

        unawaited(ws.connect());
        control.flushMicrotasks(); // attempt 1: success (createdChannels[0])

        // Disconnect → attempt 2 after 1s (fails) → attempt 3 after 2s (succeeds → reset)
        unawaited(createdChannels[0].close());
        control.flushMicrotasks(); // disconnected, 1s timer set

        control.advanceBySeconds(1);
        control.flushMicrotasks(); // attempt 2: fails, 2s timer set

        control.advanceBySeconds(2);
        control.flushMicrotasks(); // attempt 3: succeeds → backoff reset to 1s

        expect(
          createdChannels,
          hasLength(2),
        ); // channels[1] = attempt 3 channel

        // Now disconnect channel[1]. Backoff was reset → should reconnect at 1s
        unawaited(createdChannels[1].close());
        control.flushMicrotasks();

        // At 0s: no new channel yet
        expect(createdChannels, hasLength(2));

        // At 1s: reconnect fires (1s = initialBackoff, not 4s)
        control.advanceBySeconds(1);
        control.flushMicrotasks();
        expect(createdChannels, hasLength(3));

        ws.dispose();
      },
    );

    // -------------------------------------------------------------------------
    // Dispose stops reconnection
    // -------------------------------------------------------------------------

    testWithTimerControl('dispose cancels pending reconnect timer', (control) {
      final ws = _makeWs(
        tokenStorage: tokenStorage,
        channelFactory: successFactory,
      );

      unawaited(ws.connect());
      control.flushMicrotasks();

      unawaited(createdChannels[0].close());
      control.flushMicrotasks(); // 1s reconnect timer set

      ws.dispose();

      // Advance past reconnect interval — no new channel
      control.advanceBySeconds(5);
      control.flushMicrotasks();
      expect(createdChannels, hasLength(1));

      expect(ws.isClosed, isTrue);
    });

    // -------------------------------------------------------------------------
    // send() and isClosed
    // -------------------------------------------------------------------------

    test('send delegates to current underlying channel', () async {
      final ws = _makeWs(
        tokenStorage: tokenStorage,
        channelFactory: successFactory,
      );
      await ws.connect();

      ws.send({'type': 'vote', 'target': 'player_1'});

      expect(
        createdChannels[0].sentMessages,
        equals([
          {'type': 'vote', 'target': 'player_1'},
        ]),
      );

      ws.dispose();
    });

    test('isClosed is false before dispose and true after', () async {
      final ws = _makeWs(
        tokenStorage: tokenStorage,
        channelFactory: successFactory,
      );
      await ws.connect();

      expect(ws.isClosed, isFalse);
      ws.dispose();
      expect(ws.isClosed, isTrue);
    });
  });
}
