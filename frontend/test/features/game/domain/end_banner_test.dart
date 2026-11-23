import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/game/domain/end_banner.dart';
import 'package:midnight_village/features/game/domain/game_outcome.dart';

import '../../../helpers/outcome_samples.dart';

// The end board's banner (SPEC section 4): every sentence, from the recorded
// results and who is looking.

EndBanner _banner(String sample, String viewer) {
  final results = recordedResults(sample);
  final id =
      (results['players'] as List).cast<Map<String, dynamic>>().firstWhere(
            (p) => p['display_name'] == viewer,
          )['player_id']
          as int;
  return endBannerOf(GameOutcome.fromJson(results), id);
}

void main() {
  group('line one, who was hanged', () {
    test('one name, two names, the Hunter\'s pick, no one', () {
      expect(
        _banner('results_doppelganger', 'Ana').forms.first,
        'Cleo hanged. You and the village win.',
      );
      expect(
        _banner('results_tie', 'Ana').forms.first,
        'Cleo and Dev hanged. You and the village win.',
      );
      expect(
        _banner('results', 'Ana').forms.first,
        'Fin hanged, Esme too. You and the village win.',
      );
      expect(
        _banner('results_nobody_dies', 'Ben').forms.first,
        'No one hanged. You lose to the Werewolves.',
      );
    });
  });

  group('line two, you', () {
    test('when you won: with the village, with the Werewolves, alone', () {
      expect(
        _banner('results_werewolves_win', 'Cleo').forms.first,
        'Fin hanged. You and the Werewolves win.',
      );
      expect(
        _banner('results_tanner_alone', 'Dev').forms.first,
        'Dev hanged. You win alone.',
      );
      expect(
        _banner('results_three_players', 'Ben').forms.first,
        'Ana hanged. You and the village win.',
      );
    });

    test('when you lost: to the village, to the Werewolves, to the Tanner', () {
      expect(
        _banner('results_doppelganger', 'Cleo').forms.first,
        'Cleo hanged. You lose to the village.',
      );
      expect(
        _banner('results_werewolves_win', 'Ana').forms.first,
        'Fin hanged. You lose to the Werewolves.',
      );
      expect(
        _banner('results_tanner_alone', 'Ana').forms.first,
        'Dev hanged. The Tanner wins. You lose.',
      );
    });

    test('every phone builds its own second line, the first is the same', () {
      for (final sample in ['results_werewolves_win', 'results_tie']) {
        final players = (recordedResults(sample)['players'] as List)
            .cast<Map<String, dynamic>>();
        final lines = {
          for (final p in players)
            _banner(sample, p['display_name'] as String).forms.first,
        };
        expect(lines.length, greaterThan(1), reason: sample);
        expect(
          lines.map((l) => l.substring(0, l.indexOf('hanged'))).toSet().length,
          1,
        );
      }
    });
  });

  group('the paper', () {
    test('bone when the village wins, red when the Werewolves or the Tanner '
        'win, whoever is looking', () {
      final expected = {
        'results': false,
        'results_tie': false,
        'results_doppelganger': false,
        'results_three_players': false,
        'results_werewolves_win': true,
        'results_nobody_dies': true,
        'results_tanner_alone': true,
      };
      for (final MapEntry(key: sample, value: red) in expected.entries) {
        final players = (recordedResults(sample)['players'] as List)
            .cast<Map<String, dynamic>>();
        for (final p in players) {
          expect(
            _banner(sample, p['display_name'] as String).red,
            red,
            reason:
                '$sample for ${p['display_name']}: never red merely '
                'because this player lost',
          );
        }
      }
    });
  });

  group('shortened by rule, never by cutting a name', () {
    test('the whole sentence first, the least last', () {
      for (final sample in ['results', 'results_tie', 'results_tanner_alone']) {
        final forms = _banner(sample, 'Ana').forms;
        expect(forms.length, greaterThan(1));
        // The whole sentence is the longest, the last the shortest.
        for (final form in forms) {
          expect(form.length, lessThanOrEqualTo(forms.first.length));
          expect(form.length, greaterThanOrEqualTo(forms.last.length));
        }
        expect(forms.last, matches(RegExp(r' hanged\. You (win|lose)\.$')));
      }
      expect(
        _banner('results_tie', 'Ana').forms,
        contains('2 hanged. You win.'),
      );
    });

    test('a name is whole in a form or not in it at all', () {
      for (final sample in ['results', 'results_tie']) {
        final names = [
          for (final p in recordedResults(sample)['players'] as List)
            (p as Map)['display_name'] as String,
        ];
        for (final form in _banner(sample, 'Ana').forms) {
          for (final name in names) {
            final letters = RegExp(
              '\\b${name.substring(0, 2)}\\w*',
            ).allMatches(form).map((m) => m[0]);
            // Any word that starts like a name is that name, whole.
            for (final word in letters) {
              if (names.any((n) => n.startsWith(word!) && n != word)) {
                fail('"$word" is a name cut short in "$form"');
              }
            }
          }
        }
      }
    });

    test('nobody hanged has no count form', () {
      final forms = _banner('results_nobody_dies', 'Ana').forms;
      expect(forms.every((f) => f.startsWith('No one hanged.')), isTrue);
    });
  });
}
