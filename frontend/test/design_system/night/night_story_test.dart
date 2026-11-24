import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/faces/night_report.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/night/night_story.dart';

import '../../helpers/contract/contract_samples.dart';
import '../../helpers/sheet/night_record.dart';
import '../../helpers/sheet/story_samples.dart';

// My night's picture story (08, held), judged by RULES a player would notice,
// each read against the night's own record (night_record.dart, from the API
// contract): which other cards, face up in which role, which names the one
// sentence carries. Every night is a recorded talk `/me/`
// (story_samples.dart), so no test names a player, a seat or a role of one
// game: a different recorded game changes nothing here.

/// A role as the server writes it ("Werewolf"), read from the enum's own
/// name, not from the app's display words.
extension on RoleId {
  String get canonical => name[0].toUpperCase() + name.substring(1);
}

NightStory _story(String night) =>
    NightStory.of(NightReport.fromMe(allNights[night]!()));

NightRecord _record(String night) => NightRecord(allNights[night]!());

/// A card as the record writes it: "Ben:Seer", "Left:down".
String _card(StoryCard c) => card(c.label, c.role?.canonical);

/// Every card but this phone's own.
List<StoryCard> _othersOf(NightStory s) => [
  for (final row in s.rows)
    for (final c in row)
      if (c.who != StoryWho.you) c,
];

/// The nights whose record satisfies [test], never none (a rule about nothing
/// would pass for ever).
List<String> _nights(bool Function(NightRecord r) test) {
  final nights = [
    for (final n in allNights.keys)
      if (test(_record(n))) n,
  ];
  if (nights.isEmpty) throw StateError('a rule with no night to hold it');
  return nights;
}

bool _acts(NightRecord r, String type) => r.acts.any((e) => e.type == type);

/// A night of a role dealt as itself (not a Doppelganger's copy).
bool _own(NightRecord r, String type) => !r.isDoppelganger && _acts(r, type);

/// The names of a sentence, as the story marks them.
List<String> _marked(NightStory s) => [
  for (final p in s.line.parts)
    if (p.name) p.text,
];

bool _says(String text, String word) =>
    RegExp('\\b${RegExp.escape(word)}\\b').hasMatch(text);

void main() {
  test('every recorded talk of a night is a night of the story', () {
    final recorded = {
      for (final s in ContractSamples.index)
        if (s.isHttp &&
            s.status == 200 &&
            s.name.startsWith('http/game/me_discussion_choose_'))
          s.name.substring('http/game/'.length),
    };
    expect(nightSamples.values.toSet().containsAll(recorded), isTrue);
  });

  for (final night in allNights.keys) {
    test('$night: this phone is on top as dealt, the other cards are what '
        'the record shows', () {
      final story = _story(night);
      final record = _record(night);
      final you = story.cardAt(NightStory.youRef);
      expect(you.who, StoryWho.you);
      expect(you.label, 'You');
      expect(you.faceUp, isTrue);
      expect(you.role?.canonical, record.dealt);
      expect(
        [for (final c in _othersOf(story)) _card(c)]..sort(),
        [...record.cards]..sort(),
      );
      expect(story.sleeps, record.sleeps);
    });
  }

  group('a look at a player', () {
    for (final night in _nights((r) => _own(r, 'peek_player'))) {
      test('$night: one other card, face up, the player and role the record '
          'names', () {
        final story = _story(night);
        final look = _record(night).acts.single.info;
        final others = _othersOf(story);
        expect(others, hasLength(1));
        expect(others.single.faceUp, isTrue);
        expect(others.single.label, look['target_name']);
        expect(others.single.role?.canonical, look['role']);
        expect(story.line.text, contains(look['target_name'] as String));
        expect(_says(story.line.text, look['role'] as String), isTrue);
      });
    }
  });

  group('a swap of two others (the Troublemaker)', () {
    for (final night in _nights((r) => _own(r, 'swap_others'))) {
      test('$night: exactly the two players the record names, both face '
          'down, both in the sentence', () {
        final story = _story(night);
        final swap = _record(night).acts.single.info;
        final pair = [swap['player1_name'], swap['player2_name']];
        final others = _othersOf(story);
        expect([for (final c in others) c.label], unorderedEquals(pair));
        expect(others.every((c) => !c.faceUp), isTrue);
        for (final name in pair) {
          expect(story.line.text, contains(name as String));
        }
      });
    }
  });

  group('the Insomniac', () {
    final nights = _nights((r) => _own(r, 'insomniac'));
    for (final night in nights) {
      test('$night: one "Now" card, face up, in the role the record ends '
          'on; the sentence says still or now', () {
        final story = _story(night);
        final record = _record(night);
        final current = record.acts.single.info['current_role'] as String;
        final others = _othersOf(story);
        expect(others, hasLength(1));
        expect(others.single.who, StoryWho.now);
        expect(others.single.label, 'Now');
        expect(others.single.role?.canonical, current);
        final text = story.line.text;
        expect(_says(text, current), isTrue);
        expect(_says(text, current == record.dealt ? 'still' : 'now'), isTrue);
      });
    }

    test('the recordings hold a card that stayed and one that changed', () {
      expect(
        {
          for (final n in nights)
            _record(n).acts.single.info['current_role'] == _record(n).dealt,
        },
        {true, false},
      );
    });
  });

  group('a Doppelganger', () {
    for (final night in _nights((r) => r.isDoppelganger && r.copy != null)) {
      test('$night: her copy sits beside her card, the player and role the '
          'record names; the sentence opens on it', () {
        final story = _story(night);
        final record = _record(night);
        expect(story.rows.first.first.who, StoryWho.you);
        final copy = story.rows.first[1];
        expect(copy.label, record.copiedName);
        expect(copy.role?.canonical, record.copiedRole);
        expect(story.line.text, startsWith('You copied ${record.copiedName}'));
      });

      test('$night: then her copy\'s own rule: its entries show the cards '
          'they show for the role dealt', () {
        final record = _record(night);
        final rest = [for (final e in record.acts) ...record.cardsOf(e)];
        final shown = [for (final c in _othersOf(_story(night))) _card(c)]
          ..remove(card(record.copiedName!, record.copiedRole));
        expect(shown..sort(), rest..sort());
      });
    }

    test('one whose look timed out has the story of a sleeper', () {
      for (final night in _nights((r) => r.isDoppelganger && r.copy == null)) {
        final story = _story(night);
        expect(story.rows, hasLength(1));
        expect(story.sleeps, isTrue);
        expect(story.line.text, isNot(contains('copied')));
      }
    });
  });

  group('cards moved unseen stay face down', () {
    for (final night in _nights((r) => _acts(r, 'swap_others'))) {
      test('$night: the players swapped are face down', () {
        final swap = _record(
          night,
        ).acts.firstWhere((e) => e.type == 'swap_others').info;
        for (final name in [swap['player1_name'], swap['player2_name']]) {
          expect(
            _othersOf(_story(night)).where((c) => c.label == name),
            anyElement((StoryCard c) => !c.faceUp),
            reason: '$name in $night',
          );
        }
      });
    }

    for (final night in _nights((r) => _acts(r, 'swap_with_center'))) {
      test('$night: the centre cards are all face down', () {
        final centre = _othersOf(
          _story(night),
        ).where((c) => c.who == StoryWho.center);
        expect(centre, hasLength(3));
        expect(centre.every((c) => !c.faceUp), isTrue);
      });
    }
  });

  group('a centre look', () {
    for (final night in _nights((r) => _acts(r, 'peek_center'))) {
      test('$night: all three centre cards, face up only where the record '
          'looked', () {
        final look = _record(
          night,
        ).acts.firstWhere((e) => e.type == 'peek_center');
        final at = (look.info['center_indices'] as List).cast<int>();
        final centre = _othersOf(
          _story(night),
        ).where((c) => c.who == StoryWho.center).toList();
        expect(centre.map((c) => c.label), ['Left', 'Middle', 'Right']);
        expect(
          [for (final c in centre) c.faceUp],
          [for (var i = 0; i < 3; i++) at.contains(i)],
        );
      });
    }
  });

  group('the one sentence', () {
    for (final night in allNights.keys) {
      test('$night: one sentence, with the names and roles the record '
          'gives it, and no one else', () {
        final story = _story(night);
        final record = _record(night);
        final text = story.line.text;
        expect(RegExp(r'[.!?](\s|$)').allMatches(text), hasLength(1));
        expect(text, endsWith('.'));
        for (final name in record.sentenceNames) {
          expect(_says(text, name), isTrue, reason: '$name in "$text"');
        }
        for (final role in record.sentenceRoles) {
          expect(_says(text, role), isTrue, reason: '$role in "$text"');
        }
        // Nothing about anyone else's night: no player the record does not
        // name, in the sentence or on a card.
        final labels = story.rows.expand((r) => r).map((c) => c.label);
        for (final other in record.table.where(
          (n) => !record.names.contains(n),
        )) {
          expect(_says(text, other), isFalse, reason: '$other in "$text"');
          expect(labels, isNot(contains(other)), reason: other);
        }
        expect(
          _marked(story).toSet().difference({...record.names, ...record.table}),
          isEmpty,
        );
        expect(story.line.parts.map((p) => p.text).join(), text);
      });
    }

    test('a team is named as names; the rest of the sentence is plain', () {
      for (final night in _nights((r) => _own(r, 'see_team'))) {
        final team = (_record(night).acts.single.info['teammate_names'] as List)
            .cast<String>();
        expect(_marked(_story(night)), team, reason: night);
      }
    });
  });

  group('a story is this phone\'s night only', () {
    test('a Seer\'s story says nothing of a swap made on their cards', () {
      for (final night in _nights((r) => _own(r, 'peek_player'))) {
        expect(_story(night).line.text, isNot(contains('swap')), reason: night);
      }
    });

    test('a Seer who timed out has the story of one who chose nothing', () {
      for (final night in ['seer-timed-out', 'seer-skipped']) {
        expect([for (final e in _record(night).entries) e.type], ['skip']);
      }
      expect(_story('seer-timed-out'), _story('seer-skipped'));
    });

    test('threads join cards the story has', () {
      for (final night in allNights.keys) {
        final story = _story(night);
        for (final link in story.links) {
          for (final ref in [link.from, link.to, ?link.pair]) {
            expect(ref.row, inInclusiveRange(0, story.rows.length - 1));
            expect(
              ref.col,
              inInclusiveRange(0, story.rows[ref.row].length - 1),
              reason: '$night: $link',
            );
          }
        }
      }
    });
  });

  test('a screen reader hears the sentence, then every card', () {
    for (final night in _nights((r) => _own(r, 'swap_others'))) {
      final story = _story(night);
      final record = _record(night);
      final swap = record.acts.single.info;
      expect(
        story.spoken,
        '${story.line.text} You: ${record.dealt}. '
        '${swap['player1_name']}: face down. '
        '${swap['player2_name']}: face down.',
      );
    }
  });
}
