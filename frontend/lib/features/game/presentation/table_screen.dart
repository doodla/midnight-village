import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/storage/device_preferences.dart';
import '../../../design_system/skin/skin_choice.dart';
import '../../lobby/domain/where_am_i.dart';
import '../../lobby/presentation/where_am_i_provider.dart';
import '../domain/game_me.dart';
import '../domain/screen_table.dart';
import 'protocol_two_game.dart';

part 'table_screen.g.dart';

/// The two steps only this phone takes, each recorded with the server state
/// it was taken in, and meaning nothing in any other: a deal, play again or
/// a new game makes them lapse on their own, so neither can strand a phone.
/// "See who won" is also kept on this device ([wonPrefix]) and read before
/// the first frame ([restoreLocalSteps]), so a phone that restarts at the
/// results lands where it was, 10 or 11.
@immutable
class StepRecord {
  const StepRecord({this.deckAt, this.wonIn});

  /// Where this device keeps the finished game whose count it left for who
  /// won (`DevicePreferences`, one key: the latest game).
  static const wonPrefix = 'mv.won.v1.';

  /// The waiting table (code and its last game) where the host opened 03.
  final String? deckAt;

  /// The finished game whose count was left for who won.
  final String? wonIn;
}

String? _restoredWonIn;

/// Reads the game whose count this device left for who won, before the first
/// frame (`main` awaits it, as it does the learned cues), so a restart at
/// the results never shows 10 for a moment on its way to 11.
Future<void> restoreLocalSteps({DevicePreferences? preferences}) async {
  final keys = await (preferences ?? DevicePreferences()).readFlags(
    StepRecord.wonPrefix,
  );
  _restoredWonIn = keys.firstOrNull?.substring(StepRecord.wonPrefix.length);
}

/// Forgets what [restoreLocalSteps] read, so a test starts as a new device.
@visibleForTesting
void forgetRestoredLocalSteps() => _restoredWonIn = null;

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
  StepRecord build() => StepRecord(wonIn: _restoredWonIn);

  /// The host opens 03 Deck at the waiting [table].
  void openDeck(MyTable table) =>
      state = StepRecord(deckAt: _deckKey(table), wonIn: state.wonIn);

  /// 03 closes (Use this deck, or back).
  void closeDeck() => state = StepRecord(wonIn: state.wonIn);

  /// "See who won" on 10, for game [gameId]; kept on this device.
  Future<void> seeWhoWon(String gameId) async {
    state = StepRecord(deckAt: state.deckAt, wonIn: gameId);
    _restoredWonIn = gameId;
    final preferences = ref.read(devicePreferencesProvider);
    await preferences.clearFlags(StepRecord.wonPrefix);
    await preferences.setFlag('${StepRecord.wonPrefix}$gameId');
  }
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
