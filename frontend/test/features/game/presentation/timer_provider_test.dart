import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/game/presentation/timer_provider.dart';

void main() {
  group('gameTimerProvider', () {
    test('null deadline stays in loading state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Listen to keep the provider alive.
      final sub = container.listen(gameTimerProvider(null), (_, __) {});
      addTearDown(sub.close);

      // A null-deadline timer produces an empty stream.
      // It starts as loading and never transitions to data.
      final asyncValue = container.read(gameTimerProvider(null));
      expect(asyncValue, isA<AsyncLoading<Duration>>());
    });

    test('past deadline yields Duration.zero', () async {
      final pastDeadline = DateTime.now().subtract(const Duration(seconds: 10));
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Keep the provider alive with a subscription.
      final sub = container.listen(gameTimerProvider(pastDeadline), (_, __) {});
      addTearDown(sub.close);

      // Wait for the stream to emit.
      final value = await container.read(
        gameTimerProvider(pastDeadline).future,
      );
      expect(value, Duration.zero);
    });

    test('future deadline yields positive duration', () async {
      final futureDeadline = DateTime.now().add(const Duration(seconds: 60));
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Keep the provider alive.
      final sub = container.listen(
        gameTimerProvider(futureDeadline),
        (_, __) {},
      );
      addTearDown(sub.close);

      final value = await container.read(
        gameTimerProvider(futureDeadline).future,
      );
      // Should be close to 60 seconds (within tolerance for test timing).
      expect(value.inSeconds, greaterThanOrEqualTo(58));
      expect(value.inSeconds, lessThanOrEqualTo(60));
    });

    test('emits decreasing durations over time', () async {
      // Use a deadline 3 seconds in the future.
      final deadline = DateTime.now().add(const Duration(seconds: 3));
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final emitted = <Duration>[];
      final sub = container.listen(gameTimerProvider(deadline), (
        previous,
        next,
      ) {
        if (next.hasValue) {
          emitted.add(next.value!);
        }
      }, fireImmediately: true);
      addTearDown(sub.close);

      // Wait long enough for at least 2 ticks.
      await Future<void>.delayed(const Duration(milliseconds: 1500));

      expect(emitted.length, greaterThanOrEqualTo(2));

      // Each subsequent value should be less than or equal to the previous.
      for (var i = 1; i < emitted.length; i++) {
        expect(
          emitted[i] <= emitted[i - 1],
          isTrue,
          reason: 'Expected ${emitted[i]} <= ${emitted[i - 1]} at index $i',
        );
      }
    });
  });
}
