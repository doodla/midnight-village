import 'dart:async';

import 'websocket_channel.dart';

/// A socket has just been seen down, in state [seen]. Each time it is about
/// to be tried again ([WebSocketConnectionState.reconnecting], at most every
/// two seconds), [read] state once over HTTP. Returns true, to be kept as the
/// caller's "was down".
///
/// Why read while it is down, and not only when it is back: the read heals
/// what the socket cannot. A sign-in that ran out is renewed by an HTTP read,
/// and only then can the socket open again (the server refuses the old one
/// before it accepts the connection). While the network is down too the read
/// fails quietly and the next try reads again; the first one that gets
/// through renews the sign-in and shows what changed meanwhile.
bool readOnDrop(WebSocketConnectionState seen, FutureOr<void> Function() read) {
  if (seen == WebSocketConnectionState.reconnecting) {
    unawaited(Future<void>.sync(read));
  }
  return true;
}
