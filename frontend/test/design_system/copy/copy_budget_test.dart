// Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';

import 'bad_copy_fixture.dart';
import 'copy_rules.dart';
import 'copy_source.dart';
import 'screen_states.dart';

// docs/specs/frontend/first-time-play.md section 1, checked mechanically:
// every line written in lib/design_system/copy/copy.dart, and every state of
// every screen (screen_states.dart) as the words visible at once.

/// copy.dart and its parts.
const _copyFiles = [
  'lib/design_system/copy/copy.dart',
  'lib/design_system/copy/end_copy.dart',
  'lib/design_system/copy/story_copy.dart',
];

/// Every line the screens, banners and screen reader use, as written.
final _counted = [
  for (final screen in screens.values)
    for (final lines in screen.states.values)
      for (final line in lines) line.text,
  for (final row in timelineRows) '$row',
  for (final prefix in timelinePrefixes) '$prefix',
  for (final (banner, button) in banners) ...[banner, ?button],
  for (final label in spoken) '$label',
];

void main() {
  final read = [for (final f in _copyFiles) stringsIn(f)];
  final copy = (
    strings: [for (final r in read) ...r.strings],
    interpolated: [for (final r in read) ...r.interpolated],
  );

  group('rule 1: how words are counted', () {
    test('a word is a piece with a letter; gaps, role names, digits and '
        'glyphs are not words', () {
      expect(wordCount("Cleo's card: {role}."), 2);
      expect(wordCount("{name}'s card: {role}."), 1);
      expect(wordCount('{pos}: {role}. {pos}: {role}.'), 0);
      expect(wordCount('Nobody got 2 or more votes.'), 5);
      expect(wordCount('No Werewolf player: nobody dies.'), 4);
      expect(wordCount('Werewolves: {names}.'), 0);
      // A unit symbol after a number or a gap is not a word; elsewhere it is.
      expect(wordCount('{n} s'), 0);
      expect(wordCount('14 s left'), 1);
      expect(wordCount('s marks the spot'), 4);
      expect(wordCount("Don't look."), 2);
      expect(wordCount('Ready ✓'), 1);
      expect(wordCount('Doppelganger · {copied}:'), 0);
      expect(wordCount('Midnight Village'), 0);
    });

    test('the role text totals are the spec\'s', () {
      // The spec's table: Werewolf 23 ... Tanner 11 (24 November 2026: the
      // rows and "Werewolf team" added no words to any role).
      final totals = {
        for (final (role, lines) in [
          for (final s in screens['03b Role sheet']!.states.entries)
            (s.key, s.value.where((l) => l.kind == Shown.face)),
        ])
          role: lines.fold(0, (sum, l) => sum + wordCount(l.text)),
      };
      expect(totals, {
        'werewolf': 23,
        'minion': 28,
        'villager': 15,
        'seer': 20,
        'robber': 22,
        'troublemaker': 20,
        'drunk': 21,
        'insomniac': 20,
        'mason': 19,
        'hunter': 21,
        'tanner': 11,
        'doppelganger': 21,
      });
    });
  });

  group('copy.dart', () {
    test('builds nothing in place: no interpolation', () {
      expect(copy.interpolated, isEmpty);
    });

    test('says each thing once', () {
      final seen = <String>{};
      expect([
        for (final s in copy.strings)
          if (!seen.add(s)) s,
      ], isEmpty);
    });

    test('every line keeps rules 6 and 9: sentences of 8 words at most, no '
        '"!", one question, nothing banned, no gesture explained', () {
      expect([
        for (final line in copy.strings)
          ...lineViolations(line, isCue: line == CommonCopy.hold),
      ], isEmpty);
    });

    test('every line is on a screen, a banner or the screen reader, so the '
        'budgets count it', () {
      expect([
        for (final line in copy.strings)
          if (!_counted.any((counted) => counted.contains(line))) line,
      ], isEmpty);
    });

    test('the only question is "Who dies today?"', () {
      expect(copy.strings.where((s) => s.contains('?')), [onlyQuestion]);
    });
  });

  group('rule 2: budgets, with rules 3 and 4 in each state', () {
    for (final MapEntry(key: name, value: screen) in screens.entries) {
      test('$name: at most ${screen.budget} words', () {
        expect(screen.states, isNotEmpty);
        // A state with its own allowance is held to that ([stateAllowances]).
        final allowed = stateAllowances[name] ?? const <String, int>{};
        expect(
          allowed.keys.where((s) => !screen.states.containsKey(s)),
          isEmpty,
          reason: 'an allowance names a state that is not listed',
        );
        int budgetOf(String state) => allowed[state] ?? screen.budget;
        final totals = {
          for (final MapEntry(key: state, value: lines)
              in screen.states.entries)
            state: lines.fold(0, (sum, l) => sum + wordCount(l.text)),
        };
        expect([
          for (final MapEntry(:key, :value) in totals.entries)
            if (value > budgetOf(key)) '$key: $value',
        ], isEmpty);
        expect([
          for (final MapEntry(key: state, value: lines)
              in screen.states.entries)
            for (final v in stateViolations(lines, budget: budgetOf(state)))
              '$state: $v',
        ], isEmpty);
      });
    }

    test('11: each timeline row is 3 words at most; prefixes are names', () {
      expect([
        for (final row in timelineRows)
          if (wordCount('$row') > timelineRowMax) '$row',
        for (final prefix in timelinePrefixes)
          if (wordCount('$prefix') > 0) '$prefix',
      ], isEmpty);
    });
  });

  test('banners: 6 words with their button', () {
    expect([
      for (final (banner, button) in banners)
        ...bannerViolations(banner, button: button),
    ], isEmpty);
  });

  test('screen-reader labels: 8 words at most', () {
    expect([
      for (final label in spoken) ...spokenViolations('$label'),
    ], isEmpty);
  });

  group('the rules fail on bad copy (bad_copy_fixture.dart)', () {
    final bad = stringsIn('test/design_system/copy/bad_copy_fixture.dart');

    test('every rule finds its breach, read from the file as copy.dart '
        'is', () {
      expect(bad.strings, contains(BadCopy.longSentence));
      expect(lineViolations(BadCopy.longSentence), [
        contains('sentence of 10 words'),
      ]);
      expect(lineViolations(BadCopy.shout), [contains('"!"')]);
      expect(lineViolations(BadCopy.question), [contains('asks a question')]);
      expect(lineViolations(BadCopy.banned), [
        contains('banned "Waiting for"'),
      ]);
      expect(lineViolations(BadCopy.gesture), [
        contains('explains a gesture ("Tap")'),
      ]);
      expect(
        stateViolations([
          headline(BadCopy.headline),
          button(BadCopy.button),
        ], budget: 20),
        [contains('headline'), contains('button "I know my role" is 4')],
      );
      expect(bannerViolations(BadCopy.banner, button: BadCopy.bannerButton), [
        contains('is 7 words'),
      ]);
      expect(spokenViolations(BadCopy.spoken), [contains('is 10 words')]);
    });

    test('a state over its budget, or with two headlines, fails', () {
      expect(
        stateViolations([
          headline(VoteCopy.headline),
          headline(TalkCopy.headline),
          button(VoteCopy.pickName),
        ], budget: 8),
        [contains('9 words for a budget of 8'), contains('2 headlines')],
      );
    });

    test('a line that interpolates is found', () {
      expect(bad.interpolated, isEmpty);
      expect(stringsIn(_selfPath).interpolated, isNotEmpty);
    });
  });
}

/// This file, which interpolates (in its messages).
const _selfPath = 'test/design_system/copy/copy_budget_test.dart';
