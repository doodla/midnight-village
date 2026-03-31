import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'timer_provider.g.dart';

/// Countdown timer that computes remaining time from a server-provided deadline.
///
/// Ticks every second by computing `deadline - now`. Returns [Duration.zero]
/// when the deadline has passed. Returns nothing (empty stream) when
/// [deadline] is null.
///
/// This is deadline-driven, not a local countdown. The server's deadline is
/// the source of truth, so clock drift between ticks does not accumulate.
@riverpod
Stream<Duration> gameTimer(Ref ref, DateTime? deadline) async* {
  if (deadline == null) return;

  while (true) {
    final remaining = deadline.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      yield Duration.zero;
      return;
    }
    yield remaining;
    await Future.delayed(const Duration(seconds: 1));
  }
}
