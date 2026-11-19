import 'contract_samples.dart';

/// Fixtures for server payloads, each started from a recorded sample
/// (`contract_samples/`): a test may choose the VALUES (names, ids, roles,
/// counts, which player), never the keys. Setting a key the sample does not
/// have throws.
///
/// The bigger builders live next to their users: `GameMeJsonBuilder`
/// (game_state_factory.dart), `GameEvents` (game_events.dart).

/// A seat at the table: a player id and the name the server shows for it.
typedef Seat = ({int id, String name});

/// The three players most tests sit at the table.
const List<Seat> defaultSeats = [
  (id: 1, name: 'Alice'),
  (id: 2, name: 'Bob'),
  (id: 3, name: 'Charlie'),
];

/// The ten seat tokens, in the server's order (`backend/apps/core/tokens.py`).
const serverTokens = [
  'crow',
  'key',
  'moth',
  'bell',
  'thorn',
  'antler',
  'hare',
  'lantern',
  'spindle',
  'scythe',
];

/// The seat fields of the player at [index] in seat (join) order: their
/// own token and their seat number, as every players list carries them.
Map<String, dynamic> seatFields(int index) => {
  'token': serverTokens[index],
  'seat': index,
};

/// [base] with [values] written over keys it already has.
Map<String, dynamic> withValues(
  Map<String, dynamic> base,
  Map<String, dynamic> values,
) {
  for (final key in values.keys) {
    if (!base.containsKey(key)) {
      throw ArgumentError.value(
        key,
        'values',
        'the server does not send this key here (it sends ${base.keys})',
      );
    }
  }
  return {...base, ...values};
}

/// The first element of the list at [key] in [sample]: the template for one
/// entry (a player, a lobby member).
Map<String, dynamic> _entry(Map<String, dynamic> sample, String key) =>
    ((sample[key] as List).first as Map).cast<String, dynamic>();

// ---------------------------------------------------------------------------
// Night
// ---------------------------------------------------------------------------

/// The night prompt kinds the server has, as recorded (`action_prompt_<kind>`).
const promptKinds = [
  'seer',
  'robber',
  'troublemaker',
  'drunk',
  'insomniac',
  'minion',
  'mason',
  'werewolf_pack',
  'werewolf_lone',
  'doppelganger',
  'doppelganger_followup',
];

/// The prompt the server builds for [kind] (as in `action_prompt` and
/// `/me/`'s `action_prompt`), for window [wave], with the other players
/// [playerIds] as targets where the prompt takes players, and [seeTeam] as the
/// teammates a team role is shown (a team prompt only).
Map<String, dynamic> serverPrompt(
  String kind, {
  int wave = 2,
  List<int>? playerIds,
  List<int>? seeTeam,
}) {
  final event = ContractSamples.map('ws/game/action_prompt_$kind')
    ..remove('type');
  final targets = (event['valid_targets'] as Map).cast<String, dynamic>();
  return withValues(event, {
    'wave': wave,
    'valid_targets': withValues(targets, {
      if (playerIds != null && targets.containsKey('player_ids'))
        'player_ids': playerIds,
      if (seeTeam != null) 'see_team': seeTeam,
    }),
  });
}

/// The night result kinds the server has, as recorded (`action_result_<kind>`).
const nightResultKinds = [
  'peek_player',
  'peek_center',
  'swap_with_player',
  'swap_others',
  'swap_with_center',
  'insomniac',
  'see_team_werewolves',
  'see_team_lone_werewolf',
  'see_team_minion',
  'see_team_masons',
  'doppelganger_look',
  'skip',
];

/// One night result as the server sends it (an `action_result` without its
/// `type`, which is also an entry of `/me/`'s `night_results`), for window
/// [wave], with [info] written over the values of its `revealed_info`.
Map<String, dynamic> serverNightResult(
  String kind, {
  int wave = 2,
  Map<String, dynamic> info = const {},
}) {
  final event = ContractSamples.map('ws/game/action_result_$kind')
    ..remove('type');
  final revealed = (event['revealed_info'] as Map).cast<String, dynamic>();
  return withValues(event, {
    'wave': wave,
    'revealed_info': withValues(revealed, info),
  });
}

// ---------------------------------------------------------------------------
// Players
// ---------------------------------------------------------------------------

/// `GET /onuw/games/<id>/players/`: [seats], everyone connected but
/// [away]; with [hasVoted] (the vote) each player's flag.
Map<String, dynamic> serverPlayerList({
  List<Seat> seats = defaultSeats,
  Set<int> away = const {},
  Map<int, bool>? hasVoted,
}) {
  final sample = ContractSamples.map('http/game/players_voting');
  final template = _entry(sample, 'players')..remove('has_voted');
  return withValues(sample, {
    'players': [
      for (final (i, seat) in seats.indexed)
        withValues(template, {
          'player_id': seat.id,
          'display_name': seat.name,
          ...seatFields(i),
          'connected': !away.contains(seat.id),
        })..addAll({
          if (hasVoted != null) 'has_voted': hasVoted[seat.id] ?? false,
        }),
    ],
  });
}

// ---------------------------------------------------------------------------
// Results
// ---------------------------------------------------------------------------

/// One player in `GET /results/`.
class ResultSeat {
  const ResultSeat(
    this.seat, {
    required this.originalRole,
    String? finalRole,
    this.team = 'village',
    this.won = true,
    this.eliminatedBy,
    this.votedFor,
  }) : finalRole = finalRole ?? originalRole;

  final Seat seat;

  /// Server casing: `Werewolf`, `Seer`, ...
  final String originalRole;
  final String finalRole;

  /// `village`, `werewolf` or `neutral`.
  final String team;
  final bool won;

  /// `vote` or `hunter_chain` when eliminated.
  final String? eliminatedBy;
  final int? votedFor;
}

/// `GET /onuw/games/<id>/results/`. Defaults: [defaultSeats], all Villagers
/// who won, nobody eliminated.
Map<String, dynamic> serverResults({
  List<ResultSeat>? players,
  List<String> winningTeams = const ['village'],
  String reason = 'No werewolves were among the players.',
  List<String> centerCards = const ['Werewolf', 'Seer', 'Villager'],
  List<Map<String, dynamic>> nightActionsLog = const [],
}) {
  final seats =
      players ??
      [for (final s in defaultSeats) ResultSeat(s, originalRole: 'Villager')];
  final sample = ContractSamples.map('http/game/results');
  final player = _entry(sample, 'players');
  final eliminated = _entry(sample, 'eliminated_players');
  return withValues(sample, {
    'winning_teams': winningTeams,
    'reason': reason,
    'eliminated_players': [
      for (final p in seats)
        if (p.eliminatedBy != null)
          withValues(eliminated, {
            'player_id': p.seat.id,
            'display_name': p.seat.name,
            'role': p.finalRole,
            'elimination_reason': p.eliminatedBy,
          }),
    ],
    'players': [
      for (final (i, p) in seats.indexed)
        withValues(player, {
          'player_id': p.seat.id,
          'display_name': p.seat.name,
          ...seatFields(i),
          'original_role': p.originalRole,
          'final_role': p.finalRole,
          'team': p.team,
          'is_eliminated': p.eliminatedBy != null,
          'elimination_reason': p.eliminatedBy,
          'outcome': p.won ? 'win' : 'lose',
          'vote_target_id': p.votedFor,
        }),
    ],
    'center_cards': centerCards,
    'night_actions_log': nightActionsLog,
  });
}

/// One entry of the results' `night_actions_log`: [playerId] acting as
/// [role] in wake-order group [orderGroup] (2 team views, 3 Seer..Drunk,
/// 4 Insomniac), with what they chose and what the engine answered.
Map<String, dynamic> serverLogEntry({
  required int orderGroup,
  required int order,
  required int playerId,
  required String role,
  required String actionType,
  Map<String, dynamic> targets = const {},
  Map<String, dynamic> result = const {},
}) => withValues(
  _entry(ContractSamples.map('http/game/results'), 'night_actions_log'),
  {
    'wave': orderGroup,
    'result': result,
    'targets': targets,
    'player_id': playerId,
    'action_type': actionType,
    'role_acting_as': role,
    'timestamp_order': order,
  },
);

// ---------------------------------------------------------------------------
// Lobby
// ---------------------------------------------------------------------------

/// The lobby body (`GET /lobbies/<code>/` and the other lobby calls, and
/// `lobby_update`'s `data`): [seats] in join order, all ready unless in
/// [notReady]; [hostId] is the effective host, [originalHostId] the owner
/// (an acting host when they differ).
Map<String, dynamic> serverLobby({
  String code = 'ABC123',
  List<Seat> seats = defaultSeats,
  int? hostId,
  int? originalHostId,
  String status = 'waiting',
  Map<String, int>? roles,
  Set<int> notReady = const {},
}) {
  final sample = ContractSamples.map('http/lobby/detail_waiting');
  final member = _entry(sample, 'players');
  final user = (member['user'] as Map).cast<String, dynamic>();
  Map<String, dynamic> userJson(Seat seat) => withValues(user, {
    'id': seat.id,
    'username':
        '00000000-0000-4000-8000-${seat.id.toString().padLeft(12, '0')}',
    'display_name': seat.name,
  });
  final host = hostId ?? seats.first.id;
  final owner = originalHostId ?? host;
  return withValues(sample, {
    'code': code,
    'host': userJson(seats.firstWhere((s) => s.id == host)),
    'original_host_id': owner,
    'is_acting_host': owner != host,
    'status': status,
    'settings': {
      'roles': roles ?? {'Werewolf': 2, 'Seer': 1, 'Robber': 1, 'Villager': 2},
    },
    'players': [
      for (final (i, seat) in seats.indexed)
        withValues(member, {
          'user': userJson(seat),
          'token': serverTokens[i],
          'is_ready': !notReady.contains(seat.id),
          'joined_at': DateTime.utc(
            2026,
            11,
            19,
            20,
            51 + i,
          ).toIso8601String().replaceFirst('.000', ''),
        }),
    ],
  });
}
