@Tags(['e2e'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/debug/debug_models.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/night/night_board.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/features/game/presentation/shell/talk_screen.dart';
import 'package:midnight_village/features/game/presentation/shell/your_card_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'harness/harness_config.dart';
import 'harness/live_table.dart';
import 'harness/phone.dart';
import 'harness/scenario_dsl.dart';
import 'harness/scenarios.dart';

/// UI runner over the reference games: each of [uiCriticalIds] is dealt
/// again exactly (forced through the debug API) at a table made as the app makes one,
/// and one player's phone plays it through the REAL widget tree of the
/// table's shell while the rest of the table makes the game's recorded
/// choices through the API, mapped to one `choose` per window.
///
/// - `1`  Bob, the Seer, looks at Alice (a Werewolf); a lone Werewolf looks
///        at the center, the Robber robs.
/// - `4`  Alice, the Doppelganger, copies Bob (the Robber) and robs Carol on
///        her follow-up turn in window 1; then window 2.
/// - `5`  Bob, the Hunter, has nothing to choose (the board asks nothing: "Nothing to do"); the
///        Hunter's chain and the Tanner's block at the end.
/// - `8`  Eve, the Insomniac, sees her card at dawn; the Drunk swaps.
/// - `21` Bob, the Seer, does nothing (he keeps his card): "You did nothing."
///
/// Each is checked against the reference game, not against the app: the
/// cards at the end of the night are the game's (the oracle), My night on the
/// phone says what the game says this player learned, and the count and the
/// results say who died and who won as the oracle says
/// (`harness/end_of_game.dart`), which is the game's outcome.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await HarnessConfig.setUp();
    HarnessConfig.stubSecureStorage();
    await HarnessConfig.loadFonts();
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
  });

  const phones = {'1': 1, '4': 0, '5': 1, '8': 4, '21': 1};
  for (final game in allScenarios.where((g) => g.isUiCritical)) {
    final seat = phones[game.id];
    if (seat == null) throw StateError('game ${game.id} has no phone');
    testWidgets('UI: ${game.name}', (tester) async {
      await runPhone(tester, 'p2-${game.name}', (r) => _play(r, game, seat));
    });
  }
}

/// The game's center index [i] on the board.
String _place(int i) => NightCopy.center[i];

Future<void> _play(Phone r, ReferenceGame g, int seat) async {
  final name = g.players[seat];
  final t = await r.open(
    roleCounts: g.roleCounts,
    roles: {
      for (var i = 0; i < g.players.length; i++) g.players[i]: g.dealt[i],
    },
    center: g.center,
    phone: name,
  );
  final hasDoppel = g.dealt.contains('Doppelganger');

  // 04: the card, held; Ready; everyone else looks too.
  await r.ui.pumpUntil(r.shows<YourCardScreen>, reason: '04 Your card');
  await r.holdThen(find.byType(FaceDownCard), () async {
    expect(r.text(g.dealt[seat]), isTrue, reason: 'the held face');
  });
  await r.tapButton(until: () => r.button.phase == ButtonPhase.done);
  await r.api(
    () => r.everyoneElse((p) => r.staged(p, 'ready', {'ready': true})),
  );

  if (hasDoppel) {
    await r.ui.pumpUntil(
      () => r.shows<NightBoard>() && r.board.prompt.window == 1,
      reason: 'window 1',
    );
    await r.shoot('window-1');
    if (g.dealt[seat] == 'Doppelganger') {
      await r.tapCard(g.players[g.choices['doppel_target'] as int]);
      final follow = _followUp(g);
      if (follow == null) {
        await r.tapButton(until: () => r.button.phase == ButtonPhase.done);
      } else {
        await r.tapButton(
          until: () =>
              r.board.prompt.turn == 1 && r.button.phase != ButtonPhase.done,
        );
        await r.shoot('follow-up');
        for (final pick in follow) {
          await r.tapCard(pick.$1 ?? _place(pick.$2!));
        }
        await r.tapButton(until: () => r.button.phase == ButtonPhase.done);
      }
    } else {
      // Nothing to choose in window 1: the board asks nothing.
      expect(r.board.prompt.sleeps, isTrue);
      expect(r.button.label, NightCopy.nothingToDo);
    }
    await r.api(() async {
      await r.everyoneElse((p) async {
        final i = g.players.indexOf(p.displayName);
        if (g.dealt[i] != 'Doppelganger') return r.choose(p, []);
        await r.choose(p, [_player(t, g, g.choices['doppel_target'] as int)]);
        final follow = _followUp(g);
        if (follow != null) {
          await r.choose(p, [for (final pick in follow) _wire(t, g, pick)]);
        }
      });
      expect(await t.controller.fireTimer(TimerKey.wave(1)), isTrue);
    });
  }

  // Window 2: the phone's own choice on the board (a phone with nothing to
  // choose is asked nothing and sends nothing), the rest through the API.
  await r.ui.pumpUntil(
    () =>
        r.shows<NightBoard>() &&
        r.board.prompt.window == 2 &&
        (r.board.prompt.sleeps || r.button.phase != ButtonPhase.done),
    reason: 'window 2',
  );
  await r.shoot('window-2');
  if (r.board.prompt.sleeps) {
    expect(r.button.label, NightCopy.nothingToDo);
  } else {
    final mine = _windowTwo(g, seat);
    if (mine.isEmpty) {
      await r.tapCard(NightCopy.you);
      // What passing is depends on the seat's role (the app's per-kind word).
      expect(r.button.label, r.board.prompt.kind.pass);
    } else {
      for (final pick in mine) {
        await r.tapCard(pick.$1 ?? _place(pick.$2!));
      }
    }
    await r.shoot('picked');
    await r.tapButton(until: () => r.button.phase == ButtonPhase.done);
    await r.shoot('chosen');
  }
  await r.api(
    () => r.everyoneElse((p) {
      final i = g.players.indexOf(p.displayName);
      return r.choose(p, [
        for (final pick in _windowTwo(g, i)) _wire(t, g, pick),
      ]);
    }),
  );
  await r.ui.pumpUntil(r.shows<TalkScreen>, reason: 'the talk');
  await r.shoot('talk');

  // The night as the game says it went: every card where it ended.
  final oracle = await r.api(t.controller.oracle);
  for (final (i, player) in g.players.indexed) {
    expect(
      oracle.players.firstWhere((p) => p.displayName == player).currentRole,
      g.finalCards[i],
      reason: '${g.name}: $player at dawn',
    );
  }

  // My night says what this player learned, as the game says it: the night's
  // picture story, shown while the note is held (and up by itself as the talk
  // opens where the night told this player something: read there too, then a
  // touch puts it away). Every line is in what the hold shows.
  final lines = _learned(g, seat);
  void expectLearned(List<String> read, String when) {
    for (final line in lines) {
      expect(
        read.any((text) => text.contains(line)),
        isTrue,
        reason: '${g.name}: $name learned "$line"; My night $when read $read',
      );
    }
  }

  await r.putAwayMyNight(() async {
    expectLearned(r.readMyNight(), 'as the talk opened');
    await r.shoot('talk-open');
  });
  await r.openMyNight(() async {
    expectLearned(r.readMyNight(), 'held');
    await r.shoot('talk-my-night');
  });

  // The day: the phone votes as in the game, everyone else too.
  final votes = g.votes!;
  await r.talkAndVote(
    t,
    accuse: g.players[votes[seat]!],
    votes: {
      for (final MapEntry(key: voter, value: target) in votes.entries)
        if (voter != seat && target != null)
          g.players[voter]: g.players[target],
    },
  );
  final end = (await r.api(t.controller.oracle)).results!;
  expect(end.winningTeams, g.winners!.toSet(), reason: '${g.name}: winners');
}

/// A pick by a player's name, or by a center index.
typedef _Pick = (String?, int?);

_Pick _byIndex(ReferenceGame g, int playerIndex) =>
    (g.players[playerIndex], null);

/// What [seat] picks in window 2, from the game's choices (its dealt card
/// decides who wakes; a Doppelganger acted in window 1 for these games).
List<_Pick> _windowTwo(ReferenceGame g, int seat) {
  final ch = g.choices;
  return switch (g.dealt[seat]) {
    'Werewolf' when ch['wolf_center'] != null && _loneWolf(g) => [
      (null, ch['wolf_center'] as int),
    ],
    'Seer' => _seer(g, ch['seer']),
    'Robber' when ch['robber'] != null => [_byIndex(g, ch['robber'] as int)],
    'Troublemaker' when ch['troublemaker'] != null => [
      for (final i in ch['troublemaker'] as List) _byIndex(g, i as int),
    ],
    'Drunk' when ch['drunk'] != null => [(null, ch['drunk'] as int)],
    _ => const [],
  };
}

bool _loneWolf(ReferenceGame g) =>
    g.dealt.where((r) => r == 'Werewolf').length +
        (g.copied == 'Werewolf' ? 1 : 0) ==
    1;

List<_Pick> _seer(ReferenceGame g, Object? choice) => switch (choice) {
  ['player', final int i] => [_byIndex(g, i)],
  ['center', final List<dynamic> both] => [
    for (final i in both) (null, i as int),
  ],
  _ => const [],
};

/// The Doppelganger's follow-up picks in window 1 (a copied Seer, Robber,
/// Troublemaker or Drunk acts at once), or null when she has none.
List<_Pick>? _followUp(ReferenceGame g) {
  final follow = g.choices['doppel_follow'];
  if (follow == null) return null;
  return switch (g.copied) {
    'Seer' => _seer(g, follow),
    'Robber' => [_byIndex(g, follow as int)],
    'Troublemaker' => [for (final i in follow as List) _byIndex(g, i as int)],
    'Drunk' => [(null, follow as int)],
    _ => null,
  };
}

DebugPlayer _seatPlayer(LiveTable t, ReferenceGame g, int i) =>
    t.player(g.players[i]);

Map<String, Object> _player(LiveTable t, ReferenceGame g, int i) => {
  'player_id': _seatPlayer(t, g, i).userId,
};

/// A pick as the wire carries it.
Map<String, Object> _wire(LiveTable t, ReferenceGame g, _Pick pick) =>
    switch (pick) {
      (final String name, _) => {'player_id': t.player(name).userId},
      (_, final int i) => {'center_index': i},
      _ => throw ArgumentError(pick),
    };

/// The words My night's story shows for what [seat] did and saw in the
/// game: its one sentence and the cards it shows face up (never what was done
/// to the seat).
List<String> _learned(ReferenceGame g, int seat) {
  final views = g.views[seat] ?? const [];
  String card(String who, Object role) =>
      NightStoryCopy.cardUp.fill({'who': who, 'role': '$role'});
  final dealt = g.dealt[seat];
  if (dealt == 'Doppelganger') {
    final copied = g.players[g.choices['doppel_target'] as int];
    final c = {'copied': copied};
    final picks = _followUp(g) ?? const <_Pick>[];
    final sentence = switch (g.copied) {
      'Seer' when picks.length == 1 && picks.single.$1 != null =>
        NightStoryCopy.copiedSaw.fill({...c, 'name': picks.single.$1!}),
      'Seer' when picks.length == 2 => NightStoryCopy.copiedCenter.fill(c),
      'Robber' when picks.length == 1 && picks.single.$1 != null =>
        NightStoryCopy.copiedTook.fill({...c, 'name': picks.single.$1!}),
      'Troublemaker' when picks.length == 2 =>
        NightStoryCopy.copiedSwapped.fill({
          ...c,
          'a': picks[0].$1!,
          'b': picks[1].$1!,
        }),
      'Drunk' when picks.length == 1 && picks.single.$2 != null =>
        NightStoryCopy.copiedDrunk.fill({
          ...c,
          'pos': NightCopy.center[picks.single.$2!].toLowerCase(),
        }),
      // Copied, and nothing to do at once: at least what she copied.
      _ => 'You copied $copied',
    };
    return [
      sentence,
      for (final view in views)
        if (view.kind == 'copied') card(copied, view.value as String),
    ];
  }
  if (views.isEmpty) {
    // A Seer who kept his card did nothing; anyone else simply slept.
    return dealt == 'Seer' ? [SawCopy.didNothing] : const [];
  }
  return [
    for (final view in views)
      ...switch ((view.kind, view.value)) {
        ('saw_player', [final int i, final String role]) => [
          NightStoryCopy.seerPlayer.fill({'name': g.players[i], 'role': role}),
          card(g.players[i], role),
        ],
        ('took', final String role) => [
          NightStoryCopy.robbed.fill({
            'name': g.players[g.choices['robber'] as int],
            'role': role,
          }),
        ],
        ('own_card', final String role) => [
          (role == dealt ? NightStoryCopy.still : NightStoryCopy.now).fill({
            'role': role,
          }),
        ],
        ('saw_center', final List<dynamic> seen) => [
          if (dealt == 'Seer') NightStoryCopy.seerCenter,
          for (final [_, role] in seen.cast<List<dynamic>>()) '$role',
        ],
        ('werewolves', []) => [
          if (dealt == 'Minion')
            SawCopy.noWerewolves
          else
            NightStoryCopy.onlyWerewolf,
        ],
        ('werewolves', final List<dynamic> wolves) => [
          'the Werewolf',
          for (final i in wolves) g.players[i as int],
        ],
        ('masons', []) => [NightStoryCopy.onlyMason],
        ('masons', final List<dynamic> masons) => [
          'the Masons.',
          for (final i in masons) g.players[i as int],
        ],
        _ => const <String>[],
      },
  ];
}
