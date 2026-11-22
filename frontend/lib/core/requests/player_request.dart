import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../logging/app_logger.dart';

/// The one door every request a player's tap makes goes out through.
///
/// A tap on a control is answered by the control, not by the request: the
/// tapped control shows busy in the same frame ([Pending]), a request in
/// flight is never sent twice, and a failure belongs to the control that
/// asked (its words and its "Try again" are on it, never on another screen
/// later). That only holds if no request is sent around the door, so the
/// door is enforced where the requests leave the phone: an
/// `AuthenticatedClient` that is gated refuses a `POST`, `PATCH` or `DELETE`
/// made outside [playerRequest] (a [StateError] in development and in
/// tests; in a release build it is logged and sent, because the live game
/// never breaks for a rule about code).
///
/// Taps whose result the phone shows at once (a choose, a vote, "Ready", a
/// deck or timer change) are optimistic: they go through the game's
/// `Outbox` or the lobby's settings queue, and both send through here.
/// Taps that lead to another screen (start, join, deal, leave, play again)
/// keep their control busy until that screen is up (`Pending.run`).
///
/// Reads (`GET`) are not player requests: every screen's fetch heals by
/// itself (`core/healing`).
Future<T> playerRequest<T>(Future<T> Function() send) =>
    runZoned(send, zoneValues: {_door: true});

final _door = Object();

/// This code runs inside a [playerRequest].
bool get insidePlayerRequest => Zone.current[_door] == true;

/// What a gated client does with a request made outside the door ([what]:
/// "POST /lobbies/").
void requirePlayerRequest(String what) {
  if (insidePlayerRequest) return;
  final problem =
      '$what was sent outside playerRequest(): a request a player made '
      'goes through core/requests/player_request.dart, so its control '
      'shows busy and never double-sends';
  if (kReleaseMode) {
    logger.w(problem);
    return;
  }
  throw StateError(problem);
}

/// Waits for [wait] while [provider] is held, so a provider nobody else
/// listens to is not dropped mid-fetch. A plain `ref.read(p.future)` of an
/// auto-disposed provider fails with "Cannot use the Ref ... after it has
/// been disposed" when the screen changes while it is awaited: that showed
/// as "Not sent." for a request that had worked (a table started, then left).
///
/// Every await on a provider's `.future` goes through here
/// (`player_request_test.dart` scans for any that does not).
Future<R> whileHeld<R>(
  Ref ref,
  ProviderListenable<Object?> provider,
  Future<R> Function() wait,
) async {
  final held = ref.listen(provider, (_, _) {});
  try {
    return await wait();
  } finally {
    held.close();
  }
}

/// [whileHeld] for code that has a container, not a [Ref] (a button's
/// handler, whose widget goes with the screen it leads to).
Future<R> whileHeldIn<R>(
  ProviderContainer container,
  ProviderListenable<Object?> provider,
  Future<R> Function() wait,
) async {
  final held = container.listen(provider, (_, _) {});
  try {
    return await wait();
  } finally {
    held.close();
  }
}
