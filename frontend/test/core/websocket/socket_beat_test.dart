import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/storage/token_storage.dart';
import 'package:midnight_village/core/websocket/reconnecting_websocket.dart';
import 'package:midnight_village/core/websocket/websocket_channel.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/game_events.dart';
import '../../helpers/mock_websocket.dart';
import '../../helpers/timer_control.dart';

// A socket can look open and be dead (a phone that slept, a network that
// changed under it): it then hears nothing and says nothing. The server's
// heartbeat sends every socket a frame (`beat`) as it opens and on time; once
// this server is known to beat, a socket that hears no frame for about two
// beats and a half is opened again, and opening again reads everything its
// screen depends on.

class _Tokens extends Mock implements TokenStorage {}

typedef _State = WebSocketConnectionState;

void main() {
  late _Tokens tokens;
  late List<MockWebSocketChannel> channels;
  // The wall clock the socket compares on resume: moved by hand, so a test
  // can let time pass with no timer running (a phone asleep).
  late DateTime wall;

  setUp(() {
    ReconnectingWebSocket.forgetTheBeat();
    tokens = _Tokens();
    channels = [];
    wall = DateTime.utc(2026, 11, 28, 20);
    when(() => tokens.accessToken).thenAnswer((_) async => 'jwt');
  });

  ReconnectingWebSocket socket() => ReconnectingWebSocket(
    url: 'ws://localhost:8000/ws/game/123/',
    tokenStorage: tokens,
    now: () => wall,
    channelFactory: (_) {
      final channel = MockWebSocketChannel();
      channels.add(channel);
      return channel;
    },
  );

  ({ReconnectingWebSocket ws, List<_State> states, List<dynamic> heard}) open(
    TimerControl control,
  ) {
    final ws = socket();
    final states = <_State>[];
    final heard = <dynamic>[];
    ws.connectionState.listen(states.add);
    ws.stream.listen(heard.add);
    unawaited(ws.connect());
    control.flushMicrotasks();
    return (ws: ws, states: states, heard: heard);
  }

  /// [time] passes on the wall clock and the timers alike (the app awake).
  void awake(TimerControl control, Duration time) {
    wall = wall.add(time);
    control.advanceBy(time);
  }

  testWithTimerControl('an older server that never beats: "connected" is '
      'believed as it is, however quiet the socket', (control) {
    final s = open(control);
    awake(control, const Duration(minutes: 5));
    expect(s.states, [_State.connecting, _State.connected]);
    expect(channels, hasLength(1));
    expect(s.ws.verify(), isFalse);
    s.ws.dispose();
  });

  testWithTimerControl('a beat is passed on (the screens read its token)', (
    control,
  ) {
    final s = open(control);
    channels.single.addServerEvent(GameEvents.beat());
    control.flushMicrotasks();
    expect(s.heard, [GameEvents.beat()]);
    s.ws.dispose();
  });

  testWithTimerControl('a socket that keeps hearing its beats stays up', (
    control,
  ) {
    final s = open(control);
    for (var i = 0; i < 8; i++) {
      channels.single.addServerEvent(GameEvents.beat());
      awake(control, const Duration(seconds: 15));
    }
    expect(s.states, [_State.connecting, _State.connected]);
    s.ws.dispose();
  });

  testWithTimerControl('silent past two beats and a half: dropped and opened '
      'again (and opening again is what reads everything)', (control) {
    final s = open(control);
    channels.single.addServerEvent(GameEvents.beat());
    awake(control, const Duration(seconds: 36));
    expect(s.states.last, _State.connected, reason: 'not yet');
    awake(control, const Duration(seconds: 2));
    expect(s.states.sublist(2, 4), [_State.disconnected, _State.reconnecting]);
    expect(channels.first.isClosed, isTrue, reason: 'the dead one is closed');
    awake(control, const Duration(seconds: 1));
    control.flushMicrotasks();
    expect(channels, hasLength(2));
    expect(s.states.last, _State.connected);
    s.ws.dispose();
  });

  testWithTimerControl('a socket opened after the server was heard beating '
      'must beat too: one that never does is opened again', (control) {
    final first = open(control);
    channels.single.addServerEvent(GameEvents.beat());
    first.ws.dispose();
    final second = open(control);
    awake(control, const Duration(seconds: 38));
    expect(second.states, contains(_State.reconnecting));
    second.ws.dispose();
  });

  testWithTimerControl('two connections in a row with no beat at all (a '
      'rollback, an older instance): the beat is forgotten, so the socket is '
      'believed again rather than dropped every 40 s', (control) {
    final s = open(control);
    channels.single.addServerEvent(GameEvents.beat()); // learned
    s.ws.dispose();
    final later = open(control);
    awake(control, const Duration(seconds: 38)); // beatless: dropped
    awake(control, const Duration(seconds: 2)); // the next connection opens
    control.flushMicrotasks();
    expect(channels, hasLength(3));
    awake(control, const Duration(seconds: 38)); // beatless again: dropped
    awake(control, const Duration(seconds: 2));
    control.flushMicrotasks();
    final opened = channels.length;
    awake(control, const Duration(minutes: 5));
    expect(channels, hasLength(opened), reason: 'no beat expected any more');
    expect(later.states.last, _State.connected);
    later.ws.dispose();
  });

  testWithTimerControl('the app comes back after its phone slept (the wall '
      'clock moved, no timer ran): the socket is reopened at once, with no '
      '"reconnecting" and no backoff', (control) {
    final s = open(control);
    channels.single.addServerEvent(GameEvents.beat());
    s.ws.pause();
    wall = wall.add(const Duration(minutes: 5)); // asleep: timers stood still
    expect(s.ws.verify(), isTrue);
    control.flushMicrotasks();
    expect(s.states.sublist(2), [
      _State.disconnected,
      _State.connecting,
      _State.connected,
    ]);
    expect(channels, hasLength(2));
    expect(channels.first.isClosed, isTrue);
    s.ws.dispose();
  });

  testWithTimerControl('the app comes back to a socket that is hearing its '
      'beats: nothing is done, and the watchdog goes on from the clock', (
    control,
  ) {
    final s = open(control);
    channels.single.addServerEvent(GameEvents.beat());
    awake(control, const Duration(seconds: 10));
    s.ws.pause();
    expect(s.ws.verify(), isFalse);
    expect(s.states, [_State.connecting, _State.connected]);
    awake(control, const Duration(seconds: 28)); // 38 s since the last frame
    expect(s.states, contains(_State.reconnecting), reason: 'still watched');
    s.ws.dispose();
  });

  testWithTimerControl('while the app is hidden nothing watches the silence', (
    control,
  ) {
    final s = open(control);
    channels.single.addServerEvent(GameEvents.beat());
    s.ws.pause();
    awake(control, const Duration(minutes: 3));
    expect(s.states, [_State.connecting, _State.connected]);
    s.ws.dispose();
  });

  testWithTimerControl('a connection being reopened passes nothing more on '
      '(not even before the new one starts)', (control) {
    final lingering = _Lingering();
    final ws = ReconnectingWebSocket(
      url: 'ws://localhost:8000/ws/game/123/',
      tokenStorage: tokens,
      now: () => wall,
      channelFactory: (_) => channels.isEmpty
          ? (channels..add(lingering)).last
          : (channels..add(MockWebSocketChannel())).last,
    );
    final heard = <dynamic>[];
    ws.stream.listen(heard.add);
    unawaited(ws.connect());
    control.flushMicrotasks();
    lingering.addServerEvent(GameEvents.beat());
    wall = wall.add(const Duration(minutes: 1));
    heard.clear();
    expect(ws.verify(), isTrue); // reopening: the old one is being dropped
    lingering.addServerEvent(GameEvents.beat()); // it still delivers
    control.flushMicrotasks();
    expect(heard, isEmpty);
    ws.dispose();
  });
}

/// A channel that goes on delivering after it is told to close (the moment
/// between a close and the connection's end).
class _Lingering extends MockWebSocketChannel {
  @override
  Future<void> close([int? code, String? reason]) async {}
}
