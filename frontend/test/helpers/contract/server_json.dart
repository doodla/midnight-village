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

/// The ten seat tokens (`backend/apps/core/tokens.py`). The server hands
/// them out in an order seeded by the table code; tests take them in this
/// order, one per seat.
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
    'night_timeline': _nightTimeline(sample, seats, centerCards),
  });
}

/// The results' `night_timeline` for [seats] and the final [center], built
/// from the sample's: one card per role dealt (the players' original roles,
/// then the centre), and where each card ended (the players' final roles,
/// then the centre). The centre is taken as dealt as it ends, and the steps
/// are left empty (no test reads them yet). A deck that does not add up
/// throws.
Map<String, dynamic> _nightTimeline(
  Map<String, dynamic> results,
  List<ResultSeat> seats,
  List<String> center,
) {
  final sample = (results['night_timeline'] as Map).cast<String, dynamic>();
  final cardTemplate = ((sample['cards'] as List).first as Map)
      .cast<String, dynamic>();
  final dealtRoles = [for (final p in seats) p.originalRole, ...center];
  final cards = [
    for (final (i, role) in dealtRoles.indexed)
      withValues(cardTemplate, {
        'card_id': 'k$i',
        'role': role,
        'werewolf': role == 'Werewolf',
      }),
  ];
  final unused = [for (var i = 0; i < cards.length; i++) 'k$i'];
  String take(String role) {
    final id = unused.firstWhere(
      (id) => dealtRoles[int.parse(id.substring(1))] == role,
      orElse: () => throw ArgumentError('no $role card left in the deck'),
    );
    unused.remove(id);
    return id;
  }

  final dealtCenter = [
    for (var i = 0; i < center.length; i++) 'k${seats.length + i}',
  ];
  final finalPlayers = {
    for (final p in seats) '${p.seat.id}': take(p.finalRole),
  };
  final finalCenter = [for (final role in center) take(role)];
  return withValues(sample, {
    'seats': [for (final p in seats) p.seat.id],
    'cards': cards,
    'dealt': {
      'players': {for (final (i, p) in seats.indexed) '${p.seat.id}': 'k$i'},
      'center': dealtCenter,
    },
    'steps': <dynamic>[],
    'final': {'players': finalPlayers, 'center': finalCenter},
    'center_moved': [
      for (var i = 0; i < center.length; i++) finalCenter[i] != dealtCenter[i],
    ],
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
/// `lobby_update`'s `data`): [seats] in join order; [hostId] is the effective host, [originalHostId] the owner
/// (an acting host when they differ); [roles] is the deck, and with [deck]
/// false the host has not chosen one yet (`settings` is empty).
Map<String, dynamic> serverLobby({
  String code = 'ABC123',
  List<Seat> seats = defaultSeats,
  int? hostId,
  int? originalHostId,
  String status = 'waiting',
  Map<String, int>? roles,
  bool deck = true,
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
  final deckRoles =
      roles ?? {'Werewolf': 2, 'Seer': 1, 'Robber': 1, 'Villager': 2};
  return withValues(sample, {
    'code': code,
    'host': userJson(seats.firstWhere((s) => s.id == host)),
    'original_host_id': owner,
    'is_acting_host': owner != host,
    'status': status,
    'settings': {if (deck) 'roles': deckRoles},
    // The roles the table would deal, face up: the custom deck as it is.
    'deck_cards': deck ? deckRoles : const <String, int>{},
    'players': [
      for (final (i, seat) in seats.indexed)
        withValues(member, {
          'user': userJson(seat),
          'token': serverTokens[i],
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

// ---------------------------------------------------------------------------
// Home: where am I, recent games, players at tables
// ---------------------------------------------------------------------------

/// `GET /me/table/` ("where am I"). No [code]: at no table. [gameId] and
/// [phase] name the lobby's newest game when the caller plays in it (after
/// play again the table is `waiting` while that game is still `results`).
Map<String, dynamic> serverMyTable({
  String? code,
  String status = 'waiting',
  bool isHost = false,
  int seat = 0,
  String? gameId,
  String phase = 'night',
}) {
  if (code == null) return ContractSamples.map('http/lobby/my_table_none');
  final sample = ContractSamples.map('http/lobby/my_table_night');
  final table = (sample['table'] as Map).cast<String, dynamic>();
  final game = (table['game'] as Map).cast<String, dynamic>();
  return withValues(sample, {
    'table': withValues(table, {
      'lobby_code': code,
      'status': status,
      'is_host': isHost,
      'token': serverTokens[seat],
      'game': gameId == null
          ? null
          : withValues(game, {'game_id': gameId, 'phase': phase}),
    }),
  });
}

/// One finished game in `GET /onuw/me/recent-games/`.
typedef RecentGame = ({
  String gameId,
  int playerCount,
  List<String> winningTeams,
  bool youWon,
  int seat,
});

/// `GET /onuw/me/recent-games/`: [games], newest first.
Map<String, dynamic> serverRecentGames(List<RecentGame> games) {
  final sample = ContractSamples.map('http/game/recent_games');
  final entry = _entry(sample, 'games');
  return withValues(sample, {
    'games': [
      for (final g in games)
        withValues(entry, {
          'game_id': g.gameId,
          'player_count': g.playerCount,
          'winning_teams': g.winningTeams,
          'you_won': g.youWon,
          ...seatFields(g.seat),
        }),
    ],
  });
}

/// `GET /stats/online/`: players and tables with a phone connected.
Map<String, dynamic> serverOnlineStats({int players = 6, int tables = 1}) =>
    withValues(ContractSamples.map('http/core/online_stats'), {
      'players': players,
      'tables': tables,
    });
