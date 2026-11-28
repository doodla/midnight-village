import 'package:flutter/foundation.dart';

import '../../../design_system/skin/art_set.dart' show TokenId;
import '../../game/domain/game_me.dart' show GamePhase;
import '../../game/domain/game_outcome.dart' show teamFromServer;
import '../../../design_system/models/role.dart' show TeamId;
import 'lobby_state.dart';

/// A table's state, as `/me/table/` and the lobby bodies name it.
enum TableStatus {
  waiting('waiting'),
  inGame('in_game'),
  finished('finished');

  const TableStatus(this.server);

  final String server;

  static TableStatus fromServer(Object? name) =>
      values.where((s) => s.server == name).firstOrNull ??
      (throw FormatException('Unknown table status', name));
}

/// `GET /me/table/` ("where am I"): the table this player sits at, from its
/// membership, and the table's newest game when the player plays in it.
/// [MyTable.parse] gives null for `{"table": null}` (at no table).
@immutable
class MyTable {
  const MyTable._({
    required this.lobbyCode,
    required this.gameType,
    required this.status,
    required this.isHost,
    required this.token,
    required this.gameId,
    required this.gamePhase,
  });

  /// Two answers that say the same thing are equal: a poll that changes
  /// nothing redraws nothing.
  @override
  bool operator ==(Object other) =>
      other is MyTable &&
      other.lobbyCode == lobbyCode &&
      other.gameType == gameType &&
      other.status == status &&
      other.isHost == isHost &&
      other.token == token &&
      other.gameId == gameId &&
      other.gamePhase == gamePhase;

  @override
  int get hashCode => Object.hash(
    lobbyCode,
    gameType,
    status,
    isHost,
    token,
    gameId,
    gamePhase,
  );

  /// The whole body: null when the player is at no table.
  static MyTable? parse(Map<String, dynamic> body) {
    if (!body.containsKey('table')) {
      throw FormatException('Not a /me/table/ body', body);
    }
    final table = body['table'] as Map<String, dynamic>?;
    if (table == null) return null;
    final game = table['game'] as Map<String, dynamic>?;
    return MyTable._(
      lobbyCode: table['lobby_code'] as String,
      gameType: table['game_type'] as String,
      status: TableStatus.fromServer(table['status']),
      isHost: table['is_host'] as bool,
      token: TokenId.fromServer(table['token'] as String),
      gameId: game == null ? null : game['game_id'] as String,
      gamePhase: game == null ? null : GamePhase.fromServer(game['phase']),
    );
  }

  /// Where [viewerId] sits as a table's own answer or event says it (a
  /// table started or joined, a deal, play again): the same seat
  /// `/me/table/` would name right after it, so it is not asked for
  /// (`SeatSeed`). [game] is the table's newest game this player plays in,
  /// as the answer or event names it (none for a table started or joined).
  /// Null when the viewer is not at the table (it is then asked for).
  static MyTable? seatedAt(
    LobbyState lobby, {
    required int viewerId,
    ({String id, GamePhase phase})? game,
  }) {
    final me = lobby.players.where((p) => p.id == viewerId).firstOrNull;
    if (me == null) return null;
    return MyTable._(
      lobbyCode: lobby.code,
      gameType: lobby.gameType,
      status: TableStatus.fromServer(lobby.status),
      isHost: lobby.hostId == viewerId,
      token: me.token,
      gameId: game?.id,
      gamePhase: game?.phase,
    );
  }

  /// This seat after play again (`play_again`): the same table, waiting,
  /// its newest game still this one, at its results. What `/me/table/`
  /// names right after it, so it is not asked for (`SeatSeed`).
  MyTable backToWaiting() => MyTable._(
    lobbyCode: lobbyCode,
    gameType: gameType,
    status: TableStatus.waiting,
    isHost: isHost,
    token: token,
    gameId: gameId,
    gamePhase: gameId == null ? null : GamePhase.results,
  );

  /// This seat with its game at [phase], as `/me/` says it is now (a stage
  /// changed): the table is in that game, finished once it is at the results
  /// (the server ends the game and the table together). What `/me/table/`
  /// names then, so it is not asked for (`SeatSeed`).
  MyTable inGameAt(GamePhase phase) => MyTable._(
    lobbyCode: lobbyCode,
    gameType: gameType,
    status: phase == GamePhase.results
        ? TableStatus.finished
        : TableStatus.inGame,
    isHost: isHost,
    token: token,
    gameId: gameId,
    gamePhase: phase,
  );

  final String lobbyCode;
  final String gameType;
  final TableStatus status;
  final bool isHost;
  final TokenId? token;

  /// The table's newest game, when this player plays in it (after play
  /// again, the finished one, until the next deal).
  final String? gameId;
  final GamePhase? gamePhase;
}

/// `GET /stats/online/`: players with a phone at a table right now, and how
/// many tables (asked without logging in).
@immutable
class OnlineStats {
  const OnlineStats._(this.players, this.tables);

  factory OnlineStats.fromJson(Map<String, dynamic> json) =>
      OnlineStats._(json['players'] as int, json['tables'] as int);

  final int players;
  final int tables;
}

/// One of the player's finished games (`GET /onuw/me/recent-games/`): only
/// what the whole table was told at the end.
@immutable
class RecentGame {
  const RecentGame._({
    required this.gameId,
    required this.endedAt,
    required this.playerCount,
    required this.winningTeams,
    required this.youWon,
    required this.token,
    required this.seat,
  });

  factory RecentGame.fromJson(Map<String, dynamic> json) => RecentGame._(
    gameId: json['game_id'] as String,
    endedAt: DateTime.parse(json['ended_at'] as String),
    playerCount: json['player_count'] as int,
    winningTeams: [
      for (final team in json['winning_teams'] as List) teamFromServer(team),
    ],
    youWon: json['you_won'] as bool,
    token: TokenId.fromServer(json['token'] as String),
    seat: json['seat'] as int,
  );

  /// The body's `games`, newest first.
  static List<RecentGame> listFrom(Map<String, dynamic> body) => [
    for (final game in (body['games'] as List).cast<Map<String, dynamic>>())
      RecentGame.fromJson(game),
  ];

  final String gameId;
  final DateTime endedAt;
  final int playerCount;
  final List<TeamId> winningTeams;
  final bool youWon;

  /// This player's token and seat in that game.
  final TokenId? token;
  final int seat;
}
