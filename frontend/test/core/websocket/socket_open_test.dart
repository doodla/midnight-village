import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/storage/token_storage.dart';
import 'package:midnight_village/core/websocket/reconnecting_websocket.dart';
import 'package:midnight_village/core/websocket/websocket_channel.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/game_events.dart';
import '../../helpers/mock_websocket.dart';
import '../../helpers/timer_control.dart';

// "Connected" means the server has accepted the connection, never that
// connecting has started. The app reads the lobby and the game again when it
// hears "connected" after a drop: said too early, that read can answer before
// the socket can hear anything, and an event sent in between is in neither.

class _Tokens extends Mock implements TokenStorage {}

typedef _State = WebSocketConnectionState;

void main() {
  late _Tokens tokens;
  late List<MockWebSocketChannel> channels;
  late List<Completer<void>> openings;

  setUp(() {
    tokens = _Tokens();
    channels = [];
    openings = [];
    when(() => tokens.accessToken).thenAnswer((_) async => 'jwt');
  });

  /// Each channel opens when the test completes its opening.
  ReconnectingWebSocket socket({
    Duration openTimeout = const Duration(seconds: 10),
  }) => ReconnectingWebSocket(
    url: 'ws://localhost:8000/ws/game/123/',
    tokenStorage: tokens,
    openTimeout: openTimeout,
    channelFactory: (_) {
      final opening = Completer<void>();
      openings.add(opening);
      final channel = MockWebSocketChannel(opens: opening.future);
      channels.add(channel);
      return channel;
    },
  );

  testWithTimerControl('an opening that takes a while: not connected until '
      'it is open, and nothing waits once it is', (control) {
    final ws = socket();
    final states = <_State>[];
    ws.connectionState.listen(states.add);
    var ready = false;
    unawaited(ws.ready.then((_) => ready = true));

    unawaited(ws.connect());
    control.flushMicrotasks();
    control.advanceBy(const Duration(milliseconds: 800));
    expect(states, [_State.connecting], reason: 'still opening');
    expect(ready, isFalse);

    openings.single.complete();
    control.flushMicrotasks();
    expect(states, [_State.connecting, _State.connected]);
    expect(ready, isTrue);
    ws.dispose();
  });

  testWithTimerControl('an event the server sends the moment it opens is '
      'heard: the socket listens from the start', (control) {
    final ws = socket();
    final heard = <dynamic>[];
    final order = <String>[];
    ws.stream.listen((e) {
      heard.add(e);
      order.add('event');
    });
    ws.connectionState.listen((s) {
      if (s == _State.connected) order.add('connected');
    });

    unawaited(ws.connect());
    control.flushMicrotasks();
    // The server accepts and sends at once, before the app has run again.
    openings.single.complete();
    channels.single.addServerEvent(GameEvents.phaseChange(phase: 'voting'));
    control.flushMicrotasks();

    expect(heard, hasLength(1));
    expect(order.toSet(), {'connected', 'event'});
    ws.dispose();
  });

  testWithTimerControl('an opening that fails never looks connected and is '
      'tried again after the backoff, which grows', (control) {
    final ws = socket();
    final states = <_State>[];
    ws.connectionState.listen(states.add);

    unawaited(ws.connect());
    control.flushMicrotasks();
    openings[0].completeError(StateError('refused'));
    control.flushMicrotasks();
    expect(states, [
      _State.connecting,
      _State.disconnected,
      _State.reconnecting,
    ]);
    expect(channels[0].isClosed, isTrue, reason: 'the dead channel is closed');

    control.advanceBySeconds(1);
    control.flushMicrotasks();
    expect(channels, hasLength(2), reason: 'second attempt after 1 s');
    openings[1].completeError(StateError('refused'));
    control.flushMicrotasks();

    control.advanceBySeconds(1);
    control.flushMicrotasks();
    expect(channels, hasLength(2), reason: 'the backoff is now 2 s');
    control.advanceBySeconds(1);
    control.flushMicrotasks();
    expect(channels, hasLength(3));

    openings[2].complete();
    control.flushMicrotasks();
    expect(states.last, _State.connected);
    expect(states.where((s) => s == _State.connected), hasLength(1));
    ws.dispose();
  });

  testWithTimerControl('an opening that never finishes is given up after the '
      'open timeout and tried again: it cannot hang', (control) {
    final ws = socket(openTimeout: const Duration(seconds: 10));
    final states = <_State>[];
    ws.connectionState.listen(states.add);

    unawaited(ws.connect());
    control.flushMicrotasks();
    control.advanceBySeconds(9);
    control.flushMicrotasks();
    expect(states, [_State.connecting]);

    control.advanceBySeconds(1);
    control.flushMicrotasks();
    expect(states, contains(_State.reconnecting));
    expect(states, isNot(contains(_State.connected)));
    expect(channels[0].isClosed, isTrue);

    control.advanceBySeconds(1);
    control.flushMicrotasks();
    expect(channels, hasLength(2));
    // The first one opening at last changes nothing: it was given up.
    openings[0].complete();
    control.flushMicrotasks();
    expect(states, isNot(contains(_State.connected)));
    openings[1].complete();
    control.flushMicrotasks();
    expect(states.last, _State.connected);
    ws.dispose();
  });

  testWithTimerControl('the connection closes while it opens, then the '
      'opening reports done: not connected, tried again once', (control) {
    final ws = socket();
    final states = <_State>[];
    ws.connectionState.listen(states.add);

    unawaited(ws.connect());
    control.flushMicrotasks();
    unawaited(channels[0].close()); // gone before it ever opened
    control.flushMicrotasks();
    openings[0].complete(); // and only now the opening says "open"
    control.flushMicrotasks();
    expect(states, isNot(contains(_State.connected)));
    expect(states.where((s) => s == _State.reconnecting), hasLength(1));

    control.advanceBySeconds(1);
    control.flushMicrotasks();
    expect(channels, hasLength(2), reason: 'one new attempt, not two');
    control.advanceBySeconds(5);
    control.flushMicrotasks();
    expect(channels, hasLength(2), reason: 'it is opening: no other attempt');
    ws.dispose();
  });

  testWithTimerControl('while the server cannot be reached a phone keeps '
      'trying every two seconds at most', (control) {
    final ws = socket();
    unawaited(ws.connect());
    control.flushMicrotasks();
    for (var i = 0; i < 20; i++) {
      openings.last.completeError(StateError('refused'));
      control.flushMicrotasks();
      final before = channels.length;
      control.advanceBySeconds(2);
      control.flushMicrotasks();
      expect(channels.length, before + 1, reason: 'attempt ${i + 2}');
    }
    ws.dispose();
  });

  testWithTimerControl('connect again while an attempt is opening: the '
      'earlier channel is closed, not left open', (control) {
    final ws = socket();
    unawaited(ws.connect());
    control.flushMicrotasks();
    unawaited(ws.connect());
    control.flushMicrotasks();
    expect(channels, hasLength(2));
    expect(channels[0].isClosed, isTrue);
    // The earlier attempt opening late says nothing: only the current one
    // may say "connected" (a stale one would set off the read too early).
    final states = <_State>[];
    ws.connectionState.listen(states.add);
    openings[0].complete();
    control.flushMicrotasks();
    expect(states, isNot(contains(_State.connected)));
    openings[1].complete();
    control.flushMicrotasks();
    expect(states.where((s) => s == _State.connected), hasLength(1));
    ws.dispose();
  });

  test('a read is made each time a downed socket is about to be tried '
      'again, and at no other state', () {
    var reads = 0;
    void read() => reads++;
    expect(readOnDrop(_State.disconnected, read), isTrue);
    expect(reads, 0);
    expect(readOnDrop(_State.reconnecting, read), isTrue);
    expect(readOnDrop(_State.reconnecting, read), isTrue);
    expect(reads, 2);
  });

  test('a read that fails later does not escape as an unhandled error', () {
    expect(() => readOnDrop(_State.reconnecting, () async {}), returnsNormally);
  });

  testWithTimerControl('disposed while it opens: no state after, no retry, '
      'and ready does not hang', (control) {
    final ws = socket();
    final states = <_State>[];
    ws.connectionState.listen(states.add);
    var ready = false;
    unawaited(ws.ready.then((_) => ready = true));

    unawaited(ws.connect());
    control.flushMicrotasks();
    ws.dispose();
    openings.single.complete();
    control.flushMicrotasks();
    control.advanceBySeconds(60);
    control.flushMicrotasks();

    expect(states, [_State.connecting]);
    expect(channels, hasLength(1));
    expect(ready, isTrue);
  });

  testWithTimerControl('after a drop, connected is said again only when the '
      'new connection is open', (control) {
    final ws = socket();
    final states = <_State>[];
    ws.connectionState.listen(states.add);

    unawaited(ws.connect());
    control.flushMicrotasks();
    openings[0].complete();
    control.flushMicrotasks();
    expect(states.last, _State.connected);

    unawaited(channels[0].close()); // the connection drops
    control.flushMicrotasks();
    control.advanceBySeconds(1);
    control.flushMicrotasks();
    expect(channels, hasLength(2));
    expect(
      states.last,
      _State.connecting,
      reason: 'the new connection has started, not opened',
    );

    openings[1].complete();
    control.flushMicrotasks();
    expect(states.last, _State.connected);
    ws.dispose();
  });
}
