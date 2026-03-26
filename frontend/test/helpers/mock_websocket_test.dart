import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'mock_websocket.dart';

void main() {
  group('MockWebSocketChannel', () {
    late MockWebSocketChannel ws;

    setUp(() {
      ws = MockWebSocketChannel();
    });

    tearDown(() async {
      if (!ws.isClosed) await ws.close();
    });

    // -----------------------------------------------------------------------
    // Event injection
    // -----------------------------------------------------------------------

    test('server event reaches stream listeners', () async {
      final completer = Completer<dynamic>();
      ws.stream.listen(completer.complete);

      ws.addServerEvent({'type': 'game_started'});

      final received = await completer.future;
      expect(received, equals({'type': 'game_started'}));
    });

    test('multiple events are received in order', () async {
      final received = <dynamic>[];
      final sub = ws.stream.listen(received.add);

      ws.addServerEvent('first');
      ws.addServerEvent('second');
      ws.addServerEvent('third');

      // Broadcast streams deliver synchronously; flush microtasks to be safe.
      await Future.microtask(() {});

      expect(received, equals(['first', 'second', 'third']));
      await sub.cancel();
    });

    test('multiple listeners each receive the same event', () async {
      final receivedA = <dynamic>[];
      final receivedB = <dynamic>[];
      final subA = ws.stream.listen(receivedA.add);
      final subB = ws.stream.listen(receivedB.add);

      ws.addServerEvent('broadcast');
      await Future.microtask(() {});

      expect(receivedA, equals(['broadcast']));
      expect(receivedB, equals(['broadcast']));

      await subA.cancel();
      await subB.cancel();
    });

    // -----------------------------------------------------------------------
    // Client message capture
    // -----------------------------------------------------------------------

    test('sent messages are captured in sentMessages', () {
      ws.send({'action': 'vote', 'target': 'player_2'});

      expect(ws.sentMessages, equals([{'action': 'vote', 'target': 'player_2'}]));
    });

    test('multiple sent messages are captured in order', () {
      ws.send('ping');
      ws.send({'type': 'player_action'});
      ws.send(42);

      expect(ws.sentMessages, equals(['ping', {'type': 'player_action'}, 42]));
    });

    test('sentMessages is empty when no messages have been sent', () {
      expect(ws.sentMessages, isEmpty);
    });

    // -----------------------------------------------------------------------
    // Close lifecycle
    // -----------------------------------------------------------------------

    test('isClosed is false before closing', () {
      expect(ws.isClosed, isFalse);
    });

    test('isClosed is true after closing', () async {
      await ws.close();
      expect(ws.isClosed, isTrue);
    });

    test('events before close are received; events after close are ignored',
        () async {
      final received = <dynamic>[];
      final sub = ws.stream.listen(received.add);

      ws.addServerEvent('before');
      await ws.close();
      ws.addServerEvent('after'); // silently ignored

      await Future.microtask(() {});

      expect(received, equals(['before']));
      await sub.cancel();
    });

    test('stream emits done event when closed', () async {
      final doneCompleter = Completer<void>();
      ws.stream.listen(
        (_) {},
        onDone: doneCompleter.complete,
      );

      await ws.close();
      await doneCompleter.future; // Completes when stream signals done
    });

    // -----------------------------------------------------------------------
    // Error simulation
    // -----------------------------------------------------------------------

    test('addServerError delivers error to stream listeners', () async {
      final errorCompleter = Completer<Object>();
      ws.stream.listen(
        (_) {},
        onError: errorCompleter.complete,
        cancelOnError: false,
      );

      ws.addServerError(Exception('connection reset'));

      final err = await errorCompleter.future;
      expect(err, isA<Exception>());
      expect(err.toString(), contains('connection reset'));
    });

    test('addServerError is ignored after close', () async {
      // Listen first so we can detect spurious errors
      var errorCount = 0;
      ws.stream.listen(
        (_) {},
        onError: (_) => errorCount++,
        cancelOnError: false,
      );

      await ws.close();
      ws.addServerError(Exception('too late'));

      await Future.microtask(() {});
      expect(errorCount, equals(0));
    });
  });

  group('WebSocketChannelInterface', () {
    test('MockWebSocketChannel implements WebSocketChannelInterface', () {
      final ws = MockWebSocketChannel();
      expect(ws, isA<WebSocketChannelInterface>());
    });
  });
}
