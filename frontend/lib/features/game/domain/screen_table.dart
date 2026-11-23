import 'package:flutter/foundation.dart';

import '../../../core/router/back_rule.dart';

import '../../lobby/domain/lobby_state.dart';
import '../../lobby/domain/where_am_i.dart';
import 'game_me.dart';

/// The screens of the rebuild (design brief numbering). 05 (the village
/// sleeps, between) and 07 are not screens of their own: 05 is what
/// [nightBoard] shows while `/me/` loads, 07 is folded into 08's My night
/// (first-time play spec, section 7).
enum AppScreen {
  join('01', 'Join'),
  table('02', 'Table'),
  deck('03', 'Deck'),
  yourCard('04', 'Your card'),
  nightBoard('06', 'Night board'),
  talk('08', 'Talk'),
  vote('09', 'Vote'),
  count('10', 'The count'),
  results('11', 'Results'),

  /// The end board (`docs/specs/frontend/end-board.md`): the one screen of
  /// the results phase, in place of 10 and 11 (which are no longer shown).
  end('10', 'End board');

  const AppScreen(this.number, this.briefName);

  /// The brief's number.
  final String number;

  /// The brief's name for it: what a developer calls the screen (the
  /// placeholder of a screen not rebuilt yet shows it), never player copy.
  final String briefName;
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
  /// phase, nor whether the viewer plays in it: only a game this phone knows
  /// it started ([LobbyState.startedGameId]) is named; a finished one is over
  /// (results), a running one's phase is read from `/me/`.
  factory TableView.fromLobby(LobbyState lobby, {required int viewerId}) {
    final status = TableStatus.fromServer(lobby.status);
    final gameId = lobby.startedGameId;
    return TableView._(
      atTable: lobby.players.any((p) => p.id == viewerId),
      status: status,
      isHost: lobby.hostId == viewerId,
      gameId: gameId,
      gamePhase: gameId != null && status == TableStatus.finished
          ? GamePhase.results
          : null,
    );
  }

  final bool atTable;
  final TableStatus? status;
  final bool isHost;
  final String? gameId;
  final GamePhase? gamePhase;
}

/// What only this phone decides, inside one server state: the host opened
/// the deck (03) from the table. The deck is lost on a restart (02).
/// [countSeen] is the old step from the count (10) to who won (11); the
/// results phase is the end board now, whatever it says.
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
/// | table playing or finished, no game of this player's named | 02 Table |
/// | night, window 0 (the look stage) | 04 Your card |
/// | night, window 1 or 2; or night with no `/me/` yet | night board (05 while loading, 06) |
/// | discussion | 08 Talk |
/// | voting | 09 Vote |
/// | results | the end board |
///
/// `/me/` decides when it is the table's game. The game phase only moves
/// forward, so when `/me/table/` already names a later
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
  final gameId = table.gameId;
  // A table that names no game of this player's (joined while it played,
  // or its game is unknown here): the table, never a board that waits.
  if (gameId == null) return AppScreen.table;
  final own = me?.gameId == gameId ? me : null;
  final tablePhase = table.gamePhase;
  if (own != null &&
      (tablePhase == null || own.phase.index >= tablePhase.index)) {
    return switch (own.phase) {
      GamePhase.night =>
        own.window == 0 ? AppScreen.yourCard : AppScreen.nightBoard,
      GamePhase.discussion => AppScreen.talk,
      GamePhase.voting => AppScreen.vote,
      GamePhase.results => AppScreen.end,
    };
  }
  return switch (tablePhase) {
    null || GamePhase.night => AppScreen.nightBoard,
    GamePhase.discussion => AppScreen.talk,
    GamePhase.voting => AppScreen.vote,
    GamePhase.results => AppScreen.end,
  };
}

/// What Back does on each screen with nothing open on it (`BackPolicy` does
/// it; a sheet, a dialog or something open on the screen is closed first).
/// Every screen the table can name has a rule here: a new screen does not
/// build until it has one.
///
/// | Screen | Back |
/// |---|---|
/// | 01 Join | leaves the app |
/// | 02 Table | asks first: the table's leave confirmation |
/// | 03 Deck | back to 02 |
/// | 04 to the end board, the game | nothing; only Leave exits |
BackRule backRuleFor(AppScreen screen) => switch (screen) {
  AppScreen.join => BackRule.leavesApp,
  AppScreen.table => BackRule.asksToLeave,
  AppScreen.deck => BackRule.closesToTable,
  AppScreen.yourCard ||
  AppScreen.nightBoard ||
  AppScreen.talk ||
  AppScreen.vote ||
  AppScreen.count ||
  AppScreen.results ||
  AppScreen.end => BackRule.staysPut,
};
