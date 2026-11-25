import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../logging/app_logger.dart';
import '../perf/perf.dart';

/// The token of the one door every request a player's tap makes goes out
/// through. Every method that writes to the server (`POST`, `PATCH`,
/// `DELETE`: the services' write methods and `AuthenticatedClient`'s) takes a
/// [Door], and the only way to get one is [playerRequest], so a write made
/// outside the door does not build.
///
/// A tap on a control is answered by the control, not by the request: the
/// tapped control shows busy in the same frame (`Pending`), a request in
/// flight is never sent twice, and a failure belongs to the control that
/// asked (its words and its "Try again" are on it, never on another screen
/// later).
///
/// A door is open only while its [playerRequest] runs: a token kept past it
/// (in a timer or a socket's callback made inside) is shut, and a write with
/// it throws in development and tests and is logged and sent in a release
/// build (the live game never breaks for a rule about code).
///
/// Taps whose result the phone shows at once (a choose, a vote, "Ready", a
/// deck or timer change) are optimistic: they go through the game's `Outbox`
/// or the lobby's settings queue, and both send through here. Taps that lead
/// to another screen (start, join, deal, leave, play again) keep their
/// control busy until that screen is up (`Pending.run`). Reads (`GET`) are no
/// player requests: every screen's fetch heals by itself (`core/healing`).
final class Door {
  Door._();

  /// A door for a test of a service's own parsing, or of a mock's answers.
  @visibleForTesting
  factory Door.forTest() => Door._();

  var _open = true;

  /// A write about to leave the phone with this door ([what]:
  /// "POST /lobbies/").
  void require(String what) {
    if (_open) return;
    final problem =
        '$what was sent with a door that is shut: a request goes out inside '
        'its playerRequest(), and the token is not kept';
    if (kReleaseMode) {
      logger.w(problem);
      return;
    }
    throw StateError(problem);
  }
}

/// How many player requests are out right now. The app does not renew
/// itself for a new build while one is (`NewBuild`, `reload_rule.dart`);
/// it looks again when this falls back to none.
final ValueNotifier<int> playerRequestsOut = ValueNotifier(0);

/// Runs [send] with the door open, and shuts it when [send] is done.
Future<T> playerRequest<T>(Future<T> Function(Door door) send) async {
  final door = Door._();
  // The field recorder: a tap's request, until its answer is applied.
  final perf = Perf.recorder.playerRequestStarted();
  playerRequestsOut.value++;
  try {
    return await send(door);
  } finally {
    door._open = false;
    playerRequestsOut.value--;
    perf?.applied();
  }
}

/// Waits for [wait] while [provider] is held, so a provider nobody else
/// listens to is not dropped mid-fetch. A plain `ref.read(p.future)` of an
/// auto-disposed provider fails with "Cannot use the Ref ... after it has
/// been disposed" when the screen changes while it is awaited: that showed
/// as "Not sent." for a request that worked (a table started, then left).
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

/// Waits for [provider] to answer a read made now (it was just
/// invalidated): true when it answered, false when the read is failing (a
/// provider with `retryForever` stays pending while it fails, so a wait for
/// its `.future` would never end). A control that waits for the next screen
/// is freed by false, and says "One moment" with "Try again" in the
/// screen's own words (`Pending`), instead of spinning for as long as the
/// phone is out of reach.
Future<bool> readAnswered(
  Ref ref,
  ProviderListenable<AsyncValue<Object?>> provider,
) {
  final done = Completer<bool>();
  final held = ref.listen<AsyncValue<Object?>>(
    provider,
    (_, now) => _answered(now, done),
    fireImmediately: true,
  );
  return done.future.whenComplete(held.close);
}

/// Waits until [provider] has answered (the read may fail and be made again
/// any number of times meanwhile).
Future<void> readSucceeded(
  Ref ref,
  ProviderListenable<AsyncValue<Object?>> provider,
) {
  final done = Completer<void>();
  final held = ref.listen<AsyncValue<Object?>>(provider, (_, now) {
    if (!done.isCompleted && !now.isLoading && now.hasValue && !now.hasError) {
      done.complete();
    }
  }, fireImmediately: true);
  return done.future.whenComplete(held.close);
}

/// [readAnswered] for code that has a container.
Future<bool> readAnsweredIn(
  ProviderContainer container,
  ProviderListenable<AsyncValue<Object?>> provider,
) {
  final done = Completer<bool>();
  final held = container.listen<AsyncValue<Object?>>(
    provider,
    (_, now) => _answered(now, done),
    fireImmediately: true,
  );
  return done.future.whenComplete(held.close);
}

void _answered(AsyncValue<Object?> now, Completer<bool> done) {
  if (done.isCompleted) return;
  if (now.hasError) {
    done.complete(false);
  } else if (!now.isLoading && now.hasValue) {
    done.complete(true);
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
