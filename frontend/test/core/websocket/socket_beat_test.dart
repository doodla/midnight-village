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
// heartbeat sends every socket a tiny frame (`beat`); once this server is known
// to beat, a socket that hears no frame for about two beats and a half is
// opened again, and opening again reads everything its screen depends on.

class _Tokens extends Mock implements TokenStorage {}

typedef _State = WebSocketConnectionState;

void main() {
  late _Tokens tokens;
  late List<MockWebSocketChannel> channels;

  setUp(() {
    ReconnectingWebSocket.forgetTheBeat();
    tokens = _Tokens();
    channels = [];
    when(() => tokens.accessToken).thenAnswer((_) async => 'jwt');
  });

  ReconnectingWebSocket socket() => ReconnectingWebSocket(
    url: 'ws://localhost:8000/ws/game/123/',
    tokenStorage: tokens,
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

  testWithTimerControl('an older server that never beats: "connected" is '
      'believed as it is, however quiet the socket', (control) {
    final s = open(control);
    control.advanceBy(const Duration(minutes: 5));
    expect(s.states, [_State.connecting, _State.connected]);
    expect(channels, hasLength(1));
    s.ws.dispose();
  });

  testWithTimerControl('a beat is not passed on: nobody listening hears it', (
    control,
  ) {
    final s = open(control);
    channels.single.addServerEvent(GameEvents.beat());
    control.flushMicrotasks();
    expect(s.heard, isEmpty);
    s.ws.dispose();
  });

  testWithTimerControl('a socket that keeps hearing its beats stays up', (
    control,
  ) {
    final s = open(control);
    for (var i = 0; i < 8; i++) {
      channels.single.addServerEvent(GameEvents.beat());
      control.advanceBy(const Duration(seconds: 15));
    }
    expect(s.states, [_State.connecting, _State.connected]);
    s.ws.dispose();
  });

  testWithTimerControl('silent past two beats and a half: dropped and opened '
      'again (and opening again is what reads everything)', (control) {
    final s = open(control);
    channels.single.addServerEvent(GameEvents.beat());
    control.advanceBy(const Duration(seconds: 36));
    expect(s.states.last, _State.connected, reason: 'not yet');
    control.advanceBy(const Duration(seconds: 2));
    expect(s.states.sublist(2, 4), [_State.disconnected, _State.reconnecting]);
    expect(channels.first.isClosed, isTrue, reason: 'the dead one is closed');
    control.advanceBy(const Duration(seconds: 1));
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
    control.advanceBy(const Duration(seconds: 38));
    expect(second.states, contains(_State.reconnecting));
    second.ws.dispose();
  });

  testWithTimerControl('the app comes back: a socket that missed a beat is '
      'opened again at once; one that did not is left alone', (control) {
    final s = open(control);
    channels.single.addServerEvent(GameEvents.beat());
    control.advanceBy(const Duration(seconds: 10));
    s.ws.verify();
    control.flushMicrotasks();
    expect(s.states, [_State.connecting, _State.connected], reason: 'fresh');
    control.advanceBy(const Duration(seconds: 9)); // 19 s: a beat is overdue
    s.ws.verify();
    control.flushMicrotasks();
    expect(s.states.sublist(2, 4), [_State.disconnected, _State.reconnecting]);
    s.ws.dispose();
  });
}
