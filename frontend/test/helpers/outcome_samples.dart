import 'package:midnight_village/design_system/skin/art_set.dart';
import 'package:midnight_village/features/game/domain/game_outcome.dart';

import 'contract/contract_samples.dart';
import 'contract/contract_shape.dart';

// The end of a game as 10 The count and 11 Results draw it, from the
// recorded results bodies (contract_samples/http/game/results*.json):
//
// - `results`: six at the table; Fin, the Hunter, is voted out and takes
//   Esme, a Werewolf: the village wins (two die, one by the Hunter).
// - `results_doppelganger`: eight; Cleo, the lone Werewolf, is voted out:
//   the village wins (Ana, the Doppelganger, copied the Seer).
// - `results_tanner`: eight; Dev, the Tanner, is voted out and wins alone.
//
// No game was recorded where the Werewolves win or nobody dies; those two
// are the `results` game with only its votes changed (and what the server
// would then say: who died, who won), each marked as derived, until the
// recorder has them (a recorder gap). Every body is checked against the
// samples before it is used.

/// The recorded results [name] (`results`, `results_doppelganger`,
/// `results_tanner`).
Map<String, dynamic> recordedResults(String name) =>
    _checked(ContractSamples.map('http/game/$name'));

/// [results] parsed as the app parses it.
GameOutcome outcomeOf(Map<String, dynamic> results) =>
    GameOutcome.fromJson(_checked(results));

Map<String, dynamic> _checked(Map<String, dynamic> body) {
  checkHttpBody('GET', '/onuw/games/g/results/', 200, body);
  return body;
}

/// DERIVED (no recording): the `results` game where Ana, dealt the Seer and
/// swapped to the Troublemaker by Dev, gets three votes and dies; no
/// Werewolf dies, so the Werewolves win. Only the votes, the deaths and the
/// outcomes differ from the recording.
Map<String, dynamic> derivedWerewolvesWin() => _revote(
  {1: 2, 2: 1, 3: 1, 4: 6, 5: 1, 6: 4},
  dead: {1},
  winners: 'werewolf',
);

/// DERIVED (no recording): the `results` game where every vote names a
/// different player, so nobody dies and the Werewolves win.
Map<String, dynamic> derivedNobodyDies() => _revote(
  {1: 2, 2: 3, 3: 4, 4: 5, 5: 6, 6: 1},
  dead: const {},
  winners: 'werewolf',
);

/// The `results` game with [votes] (voter id -> target id), [dead] voted
/// out and [winners] the one winning team.
Map<String, dynamic> _revote(
  Map<int, int> votes, {
  required Set<int> dead,
  required String winners,
}) {
  final body = ContractSamples.map('http/game/results');
  final players = (body['players'] as List).cast<Map<String, dynamic>>();
  final eliminated = (body['eliminated_players'] as List)
      .cast<Map<String, dynamic>>()
      .first;
  for (final p in players) {
    final id = p['player_id'] as int;
    p['vote_target_id'] = votes[id];
    p['is_eliminated'] = dead.contains(id);
    p['elimination_reason'] = dead.contains(id) ? 'vote' : null;
    p['outcome'] = p['team'] == winners ? 'win' : 'lose';
  }
  body['winning_teams'] = [winners];
  body['eliminated_players'] = [
    for (final p in players)
      if (dead.contains(p['player_id']))
        {
          ...eliminated,
          'player_id': p['player_id'],
          'display_name': p['display_name'],
          'role': p['final_role'],
          'elimination_reason': 'vote',
        },
  ];
  return _checked(body);
}

/// [results] with [add] more players like its first Villager-team sleeper
/// (new ids, seats and unused tokens; a Villager card each that never
/// moved, one vote each for the first players in seat order, the village's
/// outcome; the recording's top vote must be 2 or more, so the dead stay
/// the dead), then every name in [rename]
/// renamed: the table sizes and names no recorded game has (ten at most,
/// names of 20 characters at most, as the server allows).
Map<String, dynamic> widened(
  Map<String, dynamic> results, {
  int add = 0,
  Map<String, String> rename = const {},
}) {
  final players = (results['players'] as List).cast<Map<String, dynamic>>();
  final timeline = results['night_timeline'] as Map<String, dynamic>;
  final cards = (timeline['cards'] as List).cast<Map<String, dynamic>>();
  final villageWon = (results['winning_teams'] as List).contains('village');
  final unused = TokenId.values
      .map((t) => t.name)
      .where((t) => !players.any((p) => p['token'] == t))
      .toList();
  final like = players.firstWhere((p) => p['team'] == 'village');
  for (var i = 0; i < add; i++) {
    final last = players.last;
    final id = (last['player_id'] as int) + 1;
    final card = 'k${cards.length}';
    players.add({
      ...like,
      'player_id': id,
      'display_name': 'Seat $id',
      'token': unused[i],
      'seat': (last['seat'] as int) + 1,
      'original_role': 'Villager',
      'final_role': 'Villager',
      'is_eliminated': false,
      'elimination_reason': null,
      // One vote each for the first players, below the most any player got
      // in the recording, so the same players die.
      'vote_target_id': players[i]['player_id'],
      'outcome': villageWon ? 'win' : 'lose',
    });
    cards.add({...cards.first, 'card_id': card, 'role': 'Villager'});
    (timeline['seats'] as List).add(id);
    for (final positions in [
      timeline['dealt'],
      timeline['final'],
      for (final step in (timeline['steps'] as List).cast<Map>())
        step['positions_after'],
    ]) {
      ((positions as Map)['players'] as Map)['$id'] = card;
    }
  }
  for (final p in players) {
    p['display_name'] = rename[p['display_name']] ?? p['display_name'];
  }
  return _checked(results);
}

/// Long names as a table has them (at most the server's 20 characters).
const longEndNames = {
  'Ana': 'Christopher',
  'Ben': 'Maximiliano',
  'Cleo': 'Jo',
  'Dev': 'Esmeralda',
  'Esme': 'Bartholomew',
  'Fin': 'Rosalind Fairweather',
  'Gus': 'Ida',
  'Hana': 'Penelope',
  'Seat 15': 'Wolfgang',
  'Seat 16': 'Annabelle Whitlock',
};

/// The recorded `/me/` at the results (`me_results_v2`), as the phone of
/// [viewer] (a display name) at the table of [results] sees it: the same
/// game's players, and [host] (a display name) the host. Values only.
Map<String, dynamic> resultsMeFor(
  Map<String, dynamic> results, {
  required String viewer,
  required String host,
}) {
  final me = ContractSamples.map('http/game/me_results_v2');
  final players = (results['players'] as List).cast<Map<String, dynamic>>();
  int idOf(String name) =>
      players.firstWhere((p) => p['display_name'] == name)['player_id'] as int;
  final template = (me['players'] as List).cast<Map<String, dynamic>>().first;
  me['players'] = [
    for (final p in players)
      {
        ...template,
        'player_id': p['player_id'],
        'display_name': p['display_name'],
        'token': p['token'],
        'seat': p['seat'],
      },
  ];
  me['player_id'] = idOf(viewer);
  me['host_id'] = idOf(host);
  me['is_host'] = viewer == host;
  return me;
}
