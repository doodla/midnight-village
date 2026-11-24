import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/game/domain/screen_table.dart';
import 'package:midnight_village/features/lobby/domain/lobby_state.dart';

import '../helpers/contract/contract_samples.dart';
import '../helpers/contract/sample_sets.dart';
import '../helpers/stage_clock.dart';

// The other half of the stage clock rule (test/helpers/stage_clock.dart; the
// sweep holds every catalogue state to the drawn half): every timer the
// server has is placed, and every screen the server gives a deadline is one
// that counts it down.

/// Every settings key the server's samples carry that is a length of time.
Set<String> _timerKeys() {
  final keys = <String>{};
  void walk(Object? node) {
    if (node is Map) {
      for (final MapEntry(:key, :value) in node.entries) {
        if (key is String && key.endsWith('_seconds')) keys.add(key);
        walk(value);
      }
    } else if (node is List) {
      node.forEach(walk);
    }
  }

  for (final sample in ContractSamples.index) {
    walk(ContractSamples.load(sample.name));
  }
  return keys;
}

void main() {
  test('every timer the server keeps is one the app reads (Length), so it '
      'is placed: a stage clock or on the no-clock list with why', () {
    final known = {for (final l in Length.values) l.key};
    expect(_timerKeys().difference(known), isEmpty);
    for (final length in Length.values) {
      if (clockOf(length) case NoClock(:final why)) {
        expect(why, isNotEmpty, reason: '${length.key} says why');
      }
    }
  });

  test(
    'a screen whose /me/ the server gives a deadline is a screen with a '
    'stage clock, and every stage clock has a recorded deadline to count',
    () {
      final timed = <AppScreen>{
        for (final MapEntry(key: name, value: screen) in meScreens.entries)
          if (ContractSamples.map('http/game/$name')['deadline'] != null)
            screen,
      };
      final clocked = {
        for (final length in Length.values)
          if (clockOf(length) case StageClock(:final screen)) screen,
      };
      expect(timed.difference(clocked), isEmpty, reason: 'timed, no clock');
      expect(clocked.difference(timed), isEmpty, reason: 'never sampled');
    },
  );

  test('the look stage always has its deadline: a table that sets no look '
      'length has no look stage (the night opens at its first window)', () {
    final looks = [
      for (final MapEntry(key: name, value: screen) in meScreens.entries)
        if (screen == AppScreen.yourCard) name,
    ];
    expect(looks, isNotEmpty);
    for (final name in looks) {
      expect(
        ContractSamples.map('http/game/$name')['deadline'],
        isNotNull,
        reason: name,
      );
    }
  });
}
