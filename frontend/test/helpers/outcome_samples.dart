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
// - `results_werewolves_win`: six; Fin, a Villager, is voted
//   out: no Werewolf dies, the Werewolves win.
// - `results_nobody_dies`: six; one vote each: nobody dies, the Werewolves
//   win.
// - `results_moved_dead_card`: six; Ben, dealt the Robber, robbed Cleo's
//   Werewolf and is voted out holding it: the village wins.
// - and the other ends (`results_five*`: game 7, a tie that kills
//   two, the Hunter chain, the Tanner, three players).
//
// Every body is checked against the samples before it is used.

/// The recorded results [name] (`results`, `results_doppelganger`,
/// `results_tanner`, `results_werewolves_win`, ...).
Map<String, dynamic> recordedResults(String name) =>
    _checked(ContractSamples.map('http/game/$name'));

/// [results] parsed as the app parses it.
GameOutcome outcomeOf(Map<String, dynamic> results) =>
    GameOutcome.fromJson(_checked(results));

Map<String, dynamic> _checked(Map<String, dynamic> body) {
  checkHttpBody('GET', '/onuw/games/g/results/', 200, body);
  return body;
}

/// [results] with [add] more players like its first Villager-team sleeper
/// (new ids, seats and unused tokens; a Villager card each that never
/// moved, one vote each for the first players in seat order, the village's
/// outcome; the recording's top vote must be 2 or more, so the dead stay
/// the dead), then every name in [rename]
/// renamed: the table sizes and names no recorded game has (ten at most,
/// names of 20 characters at most, as the server allows). Not an outcome
/// (who dies and wins are the recording's): it stays until a ten-player
/// game is recorded.
Map<String, dynamic> widened(
  Map<String, dynamic> results, {
  int add = 0,
  Map<String, String> rename = const {},
}) {
  final players = (results['players'] as List).cast<Map<String, dynamic>>();
  // The added votes (one each) must not change who dies: the recording's
  // top vote is 2 or more and held by one player alone.
  final tally = <Object?, int>{};
  for (final p in players) {
    final target = p['vote_target_id'];
    if (target != null) tally[target] = (tally[target] ?? 0) + 1;
  }
  final top = tally.values.fold(0, (a, b) => a > b ? a : b);
  if (top < 2 || tally.values.where((v) => v == top).length != 1) {
    throw ArgumentError('widened() needs a unique top vote of 2 or more');
  }
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

/// The recorded `/me/` at the results (`me_results`), as the phone of
/// [viewer] (a display name) at the table of [results] sees it: the same
/// game's players, and [host] (a display name) the host. Values only.
Map<String, dynamic> resultsMeFor(
  Map<String, dynamic> results, {
  required String viewer,
  required String host,
}) {
  final me = ContractSamples.map('http/game/me_results');
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
