import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/faces/night_report.dart';
import 'package:midnight_village/design_system/night/night_story.dart';

import '../../helpers/sheet/story_samples.dart';

// My night's picture story (08, held), from each phone's own night record:
// every role and case, recorded where a game recorded it, else a recorded
// talk edited off the contract (story_samples.dart). Cards read
// "label:role" ("down" for face down); threads "kind from>to".

NightStory _story(String night) =>
    NightStory.of(NightReport.fromMe(allNights[night]!()));

List<List<String>> _rows(NightStory s) => [
  for (final row in s.rows) [for (final c in row) '$c'],
];

List<String> _links(NightStory s) => [for (final l in s.links) '$l'];

typedef _Want = ({
  List<List<String>> rows,
  List<String> links,
  String line,
  bool sleeps,
});

_Want _want(
  List<List<String>> rows,
  List<String> links,
  String line, {
  bool sleeps = false,
}) => (rows: rows, links: links, line: line, sleeps: sleeps);

const _you = '0.0';
String _at(int row, int col) => '$row.$col';

final _cases = <String, _Want>{
  'troublemaker': _want(
    [
      ['You:troublemaker'],
      ['Ana:down', 'Ben:down'],
    ],
    ['act $_you>${_at(1, 0)}+${_at(1, 1)}', 'swap ${_at(1, 0)}>${_at(1, 1)}'],
    'You swapped Ana and Ben.',
  ),
  'seer': _want(
    [
      ['You:seer'],
      ['Cleo:werewolf'],
    ],
    ['look $_you>${_at(1, 0)}'],
    "Cleo's card was the Werewolf.",
  ),
  'seer-centre': _want(
    [
      ['You:seer'],
      ['Left:villager', 'Middle:villager', 'Right:down'],
    ],
    ['look $_you>${_at(1, 0)}', 'look $_you>${_at(1, 1)}'],
    'You saw 2 center cards.',
  ),
  'seer-skipped': _want(
    [
      ['You:seer'],
    ],
    [],
    'You did nothing.',
    sleeps: true,
  ),
  // The server records the same skip for a Seer who timed out as for one who
  // chose nothing: the story is `seer-skipped`'s (and a test below says so).
  'seer-timed-out': _want(
    [
      ['You:seer'],
    ],
    [],
    'You did nothing.',
    sleeps: true,
  ),
  'robber': _want(
    [
      ['You:robber'],
      ['Ana:seer'],
    ],
    ['swap $_you>${_at(1, 0)}'],
    "You took Ana's card, the Seer.",
  ),
  'werewolf-pair': _want(
    [
      ['You:werewolf'],
      ['Ida:werewolf'],
    ],
    ['see $_you>${_at(1, 0)}'],
    'You and Ida are the Werewolves.',
  ),
  'werewolf-lone-looked': _want(
    [
      ['You:werewolf'],
      ['Left:werewolf', 'Middle:down', 'Right:down'],
    ],
    ['look $_you>${_at(1, 0)}'],
    'You are the only Werewolf.',
  ),
  'werewolf-lone': _want(
    [
      ['You:werewolf'],
    ],
    [],
    'You are the only Werewolf.',
  ),
  'minion': _want(
    [
      ['You:minion'],
      ['Cleo:werewolf', 'Ida:werewolf'],
    ],
    ['look $_you>${_at(1, 0)}', 'look $_you>${_at(1, 1)}'],
    'Cleo and Ida are the Werewolves.',
  ),
  'minion-none': _want(
    [
      ['You:minion'],
    ],
    [],
    'There were no Werewolves.',
  ),
  'mason': _want(
    [
      ['You:mason'],
      ['Fin:mason'],
    ],
    ['see $_you>${_at(1, 0)}'],
    'You and Fin are the Masons.',
  ),
  'mason-alone': _want(
    [
      ['You:mason'],
    ],
    [],
    'You are the only Mason.',
  ),
  'drunk': _want(
    [
      ['You:drunk'],
      ['Left:down', 'Middle:down', 'Right:down'],
    ],
    ['swap $_you>${_at(1, 1)}'],
    'You took the middle card, unseen.',
  ),
  'insomniac-same': _want(
    [
      ['You:insomniac'],
      ['Now:insomniac'],
    ],
    ['look $_you>${_at(1, 0)}'],
    'Your card is still the Insomniac.',
  ),
  'insomniac-changed': _want(
    [
      ['You:insomniac'],
      ['Now:seer'],
    ],
    ['look $_you>${_at(1, 0)}'],
    'Your card is now the Seer.',
  ),
  for (final role in ['villager', 'hunter', 'tanner'])
    role: _want(
      [
        ['You:$role'],
      ],
      [],
      'You slept.',
      sleeps: true,
    ),
  'doppelganger-seer': _want(
    [
      ['You:doppelganger', 'Ben:seer'],
      ['Left:villager', 'Middle:villager', 'Right:down'],
    ],
    [
      'look $_you>${_at(0, 1)}',
      'look $_you>${_at(1, 0)}',
      'look $_you>${_at(1, 1)}',
    ],
    'You copied Ben, then saw 2 center cards.',
  ),
  'doppelganger-minion': _want(
    [
      ['You:doppelganger', 'Dev:minion'],
      ['Cleo:werewolf', 'Esme:werewolf'],
    ],
    [
      'look $_you>${_at(0, 1)}',
      'look $_you>${_at(1, 0)}',
      'look $_you>${_at(1, 1)}',
    ],
    'You copied Dev, then saw the Werewolves.',
  ),
  'doppelganger-troublemaker': _want(
    [
      ['You:doppelganger', 'Gus:troublemaker'],
      ['Ben:down', 'Cleo:down'],
    ],
    [
      'look $_you>${_at(0, 1)}',
      'act $_you>${_at(1, 0)}+${_at(1, 1)}',
      'swap ${_at(1, 0)}>${_at(1, 1)}',
    ],
    'You copied Gus, then swapped Ben and Cleo.',
  ),
  'doppelganger-robber': _want(
    [
      ['You:doppelganger', 'Gus:robber'],
      ['Ana:seer'],
    ],
    ['look $_you>${_at(0, 1)}', 'swap $_you>${_at(1, 0)}'],
    "You copied Gus, then took Ana's card.",
  ),
  'doppelganger-drunk': _want(
    [
      ['You:doppelganger', 'Gus:drunk'],
      ['Left:down', 'Middle:down', 'Right:down'],
    ],
    ['look $_you>${_at(0, 1)}', 'swap $_you>${_at(1, 1)}'],
    'You copied Gus, then took the middle card.',
  ),
  'doppelganger-werewolf': _want(
    [
      ['You:doppelganger', 'Ida:werewolf'],
      ['Ida:werewolf'],
    ],
    ['look $_you>${_at(0, 1)}', 'see $_you>${_at(1, 0)}'],
    'You copied Ida, the Werewolf.',
  ),
  'doppelganger-insomniac': _want(
    [
      ['You:doppelganger', 'Esme:insomniac'],
      ['Now:doppelganger'],
    ],
    ['look $_you>${_at(0, 1)}', 'look $_you>${_at(1, 0)}'],
    'You copied Esme, the Insomniac.',
  ),
  'doppelganger-villager': _want(
    [
      ['You:doppelganger', 'Fin:villager'],
    ],
    ['look $_you>${_at(0, 1)}'],
    'You copied Fin, the Villager.',
  ),
  'doppelganger-nothing': _want(
    [
      ['You:doppelganger'],
    ],
    [],
    'You did nothing.',
    sleeps: true,
  ),
};

void main() {
  test('every night has its case, and every case its night', () {
    expect(_cases.keys.toSet(), allNights.keys.toSet());
  });

  for (final MapEntry(key: night, value: want) in _cases.entries) {
    final edited = editedNights.containsKey(night) ? ' (off the contract)' : '';
    test('$night$edited: ${want.line}', () {
      final story = _story(night);
      expect(_rows(story), want.rows);
      expect(_links(story), want.links);
      expect(story.line.text, want.line);
      expect(story.sleeps, want.sleeps);
    });
  }

  test('a Seer who timed out has the story of one who chose nothing', () {
    final timedOut = _story('seer-timed-out');
    final skipped = _story('seer-skipped');
    expect(_rows(timedOut), _rows(skipped));
    expect(_links(timedOut), _links(skipped));
    expect(timedOut.line.text, skipped.line.text);
    expect(timedOut.sleeps, skipped.sleeps);
  });

  test('your own card is on top, as dealt, marked You', () {
    for (final night in allNights.keys) {
      final you = _story(night).cardAt(NightStory.youRef);
      expect(you.who, StoryWho.you, reason: night);
      expect(you.faceUp, isTrue, reason: night);
    }
  });

  test('a story says nothing the record did not: a swapped player sees '
      'only their own night', () {
    // Game 7: Dev, the Troublemaker, swapped Ana and Ben; Ana's phone
    // (the Seer) shows her look at Cleo, nothing of the swap.
    final ana = _story('seer');
    expect(ana.line.text, isNot(contains('swap')));
    expect([for (final row in ana.rows) ...row].map((c) => c.label), [
      'You',
      'Cleo',
    ]);
  });

  test('the Troublemaker and the Drunk never see the cards they moved', () {
    for (final night in ['troublemaker', 'drunk', 'doppelganger-drunk']) {
      final moved = _story(night).rows.skip(1).expand((r) => r);
      expect(moved.every((c) => !c.faceUp), isTrue, reason: night);
    }
  });

  test("a Doppelganger's line opens on what she did, never on sleep", () {
    for (final night in allNights.keys.where(
      (n) => n.startsWith('doppelganger') && n != 'doppelganger-nothing',
    )) {
      expect(_story(night).line.text, startsWith('You copied'), reason: night);
    }
  });

  test('names are marked as names; the rest is plain', () {
    final parts = _story('minion').line.parts;
    expect(
      [
        for (final p in parts)
          if (p.name) p.text,
      ],
      ['Cleo', 'Ida'],
    );
    expect(parts.map((p) => p.text).join(), 'Cleo and Ida are the Werewolves.');
  });

  test('a screen reader hears the sentence, then every card', () {
    expect(
      _story('troublemaker').spoken,
      'You swapped Ana and Ben. You: Troublemaker. Ana: face down. '
      'Ben: face down.',
    );
  });
}
