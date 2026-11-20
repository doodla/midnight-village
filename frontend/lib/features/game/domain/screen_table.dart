import 'package:flutter/foundation.dart';

import '../../lobby/domain/lobby_state.dart';
import '../../lobby/domain/where_am_i.dart';
import 'game_me.dart';

/// The screens of the rebuild (design brief numbering). 05 (the village
/// sleeps, between) and 07 are not screens of their own: 05 is what
/// [nightBoard] shows while `/me/` loads, 07 is folded into 08's My night
/// (first-time play spec, section 7).
enum AppScreen {
  join('01'),
  table('02'),
  deck('03'),
  yourCard('04'),
  nightBoard('06'),
  talk('08'),
  vote('09'),
  count('10'),
  results('11');

  const AppScreen(this.number);

  /// The brief's number.
  final String number;
}

/// Where the server says this player is, from `/me/table/` or a lobby body:
/// the input the screen table needs when there is no `/me/` (yet).
@immutable
class TableView {
  const TableView._({
    required this.atTable,
    required this.status,
    required this.isHost,
    required this.gameId,
    required this.gamePhase,
  });

  /// At no table (`{"table": null}`).
  static const nowhere = TableView._(
    atTable: false,
    status: null,
    isHost: false,
    gameId: null,
    gamePhase: null,
  );

  /// `GET /me/table/` ([MyTable.parse]; null: at no table).
  factory TableView.fromMyTable(MyTable? table) => table == null
      ? nowhere
      : TableView._(
          atTable: true,
          status: table.status,
          isHost: table.isHost,
          gameId: table.gameId,
          gamePhase: table.gamePhase,
        );

  /// A lobby body as [viewerId] sees it. A lobby does not say its game's
  /// phase: a finished table's game is over (results), a running one's is
  /// read from `/me/`.
  factory TableView.fromLobby(LobbyState lobby, {required int viewerId}) {
    final status = TableStatus.fromServer(lobby.status);
    return TableView._(
      atTable: lobby.players.any((p) => p.id == viewerId),
      status: status,
      isHost: lobby.hostId == viewerId,
      gameId: lobby.startedGameId,
      gamePhase: status == TableStatus.finished ? GamePhase.results : null,
    );
  }

  final bool atTable;
  final TableStatus? status;
  final bool isHost;
  final String? gameId;
  final GamePhase? gamePhase;
}

/// What only this phone decides, inside one server state: the host opened
/// the deck (03) from the table, or the player went on from the count (10)
/// to who won (11). Both are lost on a restart, which then lands on 02 and
/// 10, as the spec says ("in results phase it skips straight to 10").
@immutable
class LocalSteps {
  const LocalSteps({this.editingDeck = false, this.countSeen = false});

  final bool editingDeck;
  final bool countSeen;
}

/// THE server state -> screen table: exactly one screen for what the server
/// says (`/me/table/` or the lobby, and `/me/` of the table's game) and the
/// two local steps. Nothing else goes in: no socket event, no timer, no
/// screen history, so a phone that restarts or reconnects lands where every
/// other phone is from its fetches alone.
///
/// | Server says | Screen |
/// |---|---|
/// | at no table | 01 Join |
/// | table waiting (also after play again, the last game still `results`) | 02 Table; 03 Deck for the host who opened it |
/// | night, window 0 (the look stage) | 04 Your card |
/// | night, window 1 or 2; or night with no `/me/` yet | night board (05 while loading, 06) |
/// | discussion | 08 Talk |
/// | voting | 09 Vote |
/// | results | 10 The count; 11 Results once "See who won" was tapped |
///
/// `/me/` decides when it is the table's game (or the table names none). The
/// game phase only moves forward, so when `/me/table/` already names a later
/// phase than a `/me/` fetched before it, the later one wins (and the caller
/// fetches `/me/` again).
AppScreen screenFor(
  TableView table, {
  GameMe? me,
  LocalSteps local = const LocalSteps(),
}) {
  if (!table.atTable) return AppScreen.join;
  if (table.status == TableStatus.waiting) {
    return table.isHost && local.editingDeck ? AppScreen.deck : AppScreen.table;
  }
  final own = me != null && (table.gameId == null || me.gameId == table.gameId)
      ? me
      : null;
  final tablePhase = table.gamePhase;
  if (own != null &&
      (tablePhase == null || own.phase.index >= tablePhase.index)) {
    return switch (own.phase) {
      GamePhase.night =>
        own.window == 0 ? AppScreen.yourCard : AppScreen.nightBoard,
      GamePhase.discussion => AppScreen.talk,
      GamePhase.voting => AppScreen.vote,
      GamePhase.results => _end(local),
    };
  }
  return switch (tablePhase) {
    null || GamePhase.night => AppScreen.nightBoard,
    GamePhase.discussion => AppScreen.talk,
    GamePhase.voting => AppScreen.vote,
    GamePhase.results => _end(local),
  };
}

AppScreen _end(LocalSteps local) =>
    local.countSeen ? AppScreen.results : AppScreen.count;
