// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timer_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Countdown timer that computes remaining time from a server-provided deadline.
///
/// Ticks every second by computing `deadline - now`. Returns [Duration.zero]
/// when the deadline has passed. Returns nothing (empty stream) when
/// [deadline] is null.
///
/// This is deadline-driven, not a local countdown. The server's deadline is
/// the source of truth, so clock drift between ticks does not accumulate.

@ProviderFor(gameTimer)
const gameTimerProvider = GameTimerFamily._();

/// Countdown timer that computes remaining time from a server-provided deadline.
///
/// Ticks every second by computing `deadline - now`. Returns [Duration.zero]
/// when the deadline has passed. Returns nothing (empty stream) when
/// [deadline] is null.
///
/// This is deadline-driven, not a local countdown. The server's deadline is
/// the source of truth, so clock drift between ticks does not accumulate.

final class GameTimerProvider
    extends
        $FunctionalProvider<AsyncValue<Duration>, Duration, Stream<Duration>>
    with $FutureModifier<Duration>, $StreamProvider<Duration> {
  /// Countdown timer that computes remaining time from a server-provided deadline.
  ///
  /// Ticks every second by computing `deadline - now`. Returns [Duration.zero]
  /// when the deadline has passed. Returns nothing (empty stream) when
  /// [deadline] is null.
  ///
  /// This is deadline-driven, not a local countdown. The server's deadline is
  /// the source of truth, so clock drift between ticks does not accumulate.
  const GameTimerProvider._({
    required GameTimerFamily super.from,
    required DateTime? super.argument,
  }) : super(
         retry: null,
         name: r'gameTimerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$gameTimerHash();

  @override
  String toString() {
    return r'gameTimerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<Duration> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Duration> create(Ref ref) {
    final argument = this.argument as DateTime?;
    return gameTimer(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is GameTimerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$gameTimerHash() => r'5f3d8dfb60fffbc428bc6d3b69672216fa030fc4';

/// Countdown timer that computes remaining time from a server-provided deadline.
///
/// Ticks every second by computing `deadline - now`. Returns [Duration.zero]
/// when the deadline has passed. Returns nothing (empty stream) when
/// [deadline] is null.
///
/// This is deadline-driven, not a local countdown. The server's deadline is
/// the source of truth, so clock drift between ticks does not accumulate.

final class GameTimerFamily extends $Family
    with $FunctionalFamilyOverride<Stream<Duration>, DateTime?> {
  const GameTimerFamily._()
    : super(
        retry: null,
        name: r'gameTimerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Countdown timer that computes remaining time from a server-provided deadline.
  ///
  /// Ticks every second by computing `deadline - now`. Returns [Duration.zero]
  /// when the deadline has passed. Returns nothing (empty stream) when
  /// [deadline] is null.
  ///
  /// This is deadline-driven, not a local countdown. The server's deadline is
  /// the source of truth, so clock drift between ticks does not accumulate.

  GameTimerProvider call(DateTime? deadline) =>
      GameTimerProvider._(argument: deadline, from: this);

  @override
  String toString() => r'gameTimerProvider';
}
