import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../lobby/domain/where_am_i.dart';
import '../../lobby/presentation/where_am_i_provider.dart';
import '../domain/game_me.dart';
import '../domain/screen_table.dart';
import 'protocol_two_game.dart';

part 'table_screen.g.dart';

/// The two steps only this phone takes, each recorded with the server state
/// it was taken in, and meaning nothing in any other: a deal, play again or
/// a new game makes them lapse on their own, so neither can strand a phone.
@immutable
class StepRecord {
  const StepRecord({this.deckAt, this.wonIn});

  /// The waiting table (code and its last game) where the host opened 03.
  final String? deckAt;

  /// The finished game whose count was left for who won.
  final String? wonIn;
}

String _deckKey(MyTable table) => '${table.lobbyCode}|${table.gameId}';

/// What the local steps mean for [table] now.
LocalSteps localStepsFor(StepRecord record, MyTable? table) => LocalSteps(
  editingDeck:
      table != null &&
      table.status == TableStatus.waiting &&
      record.deckAt == _deckKey(table),
  countSeen:
      table != null &&
      table.gameId != null &&
      table.status != TableStatus.waiting &&
      record.wonIn == table.gameId,
);

@Riverpod(keepAlive: true)
class LocalStepsNotifier extends _$LocalStepsNotifier {
  @override
  StepRecord build() => const StepRecord();

  /// The host opens 03 Deck at the waiting [table].
  void openDeck(MyTable table) =>
      state = StepRecord(deckAt: _deckKey(table), wonIn: state.wonIn);

  /// 03 closes (Use this deck, or back).
  void closeDeck() => state = StepRecord(wonIn: state.wonIn);

  /// "See who won" on 10, for game [gameId].
  void seeWhoWon(String gameId) =>
      state = StepRecord(deckAt: state.deckAt, wonIn: gameId);
}

/// The screen to show, and the game it is of (null: no game).
@immutable
class TableScreen {
  const TableScreen(this.screen, {this.gameId});

  final AppScreen screen;
  final String? gameId;

  @override
  bool operator ==(Object other) =>
      other is TableScreen && other.screen == screen && other.gameId == gameId;

  @override
  int get hashCode => Object.hash(screen, gameId);

  @override
  String toString() => 'TableScreen(${screen.number}, $gameId)';
}

/// The one screen for this phone: `/me/table/` names the table and its game
/// (so a new deal replaces the old game), that game's `/me/` refines it, and
/// the local steps are applied ([screenFor]). While either is fetched again
/// the values held are used, so the screen never drops to loading or an
/// error while there is something to show. A game that is gone is 01.
@riverpod
AsyncValue<TableScreen> tableScreen(Ref ref) {
  final tableAsync = ref.watch(myTableProvider);
  if (!tableAsync.hasValue) {
    return tableAsync.hasError && !tableAsync.isLoading
        ? AsyncError(tableAsync.error!, tableAsync.stackTrace!)
        : const AsyncLoading();
  }
  final table = tableAsync.value;
  final local = localStepsFor(ref.watch(localStepsProvider), table);
  final gameId = table?.gameId;
  GameMe? me;
  if (gameId != null && table!.status != TableStatus.waiting) {
    final game = ref.watch(protocolTwoGameProvider(gameId)).value;
    if (game != null && game.tableClosed) {
      return const AsyncData(TableScreen(AppScreen.join));
    }
    me = game?.me;
  }
  return AsyncData(
    TableScreen(
      screenFor(TableView.fromMyTable(table), me: me, local: local),
      gameId: table?.status == TableStatus.waiting ? null : gameId,
    ),
  );
}
