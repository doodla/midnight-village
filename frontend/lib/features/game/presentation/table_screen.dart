import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/storage/device_preferences.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../lobby/domain/where_am_i.dart';
import '../../lobby/presentation/last_seat.dart';
import '../../lobby/presentation/lobby_notifier.dart';
import '../../lobby/presentation/where_am_i_provider.dart';
import '../domain/game_me.dart';
import '../domain/screen_table.dart';
import 'live_game.dart';

part 'table_screen.g.dart';

/// The step only this phone takes (the host opening 03), recorded with the
/// server state it was taken in, and meaning nothing in any other: a deal,
/// play again or a new game makes it lapse on its own, so it cannot strand a
/// phone.
@immutable
class StepRecord {
  const StepRecord({this.deckAt});

  /// The waiting table (code and its last game) where the host opened 03.
  final String? deckAt;
}

/// Reads the seat this device last had ([LastSeat]) before the first frame
/// (`main` awaits it, as it does the learned cues), so the seat's own read
/// goes out at once.
Future<void> restoreLocalSteps({DevicePreferences? preferences}) async {
  await LastSeat.restore(preferences ?? DevicePreferences());
}

/// Forgets what [restoreLocalSteps] read, so a test starts as a new device.
@visibleForTesting
void forgetRestoredLocalSteps() => LastSeat.forget();

/// While the seat read at start ([LastSeat.opening]) is still the one
/// `/me/table/` names (or it has not answered yet), its game's `/me/` or its
/// lobby is read and kept: the screen that follows finds it on its way.
void _readLastSeatBeside(Ref ref, AsyncValue<MyTable?> table) {
  final user = switch (ref.watch(authProvider)) {
    AuthAuthenticated(:final user) => user.id,
    _ => null,
  };
  final seat = user == null ? null : LastSeat.openingFor(user);
  if (seat == null) return;
  if (table.hasValue && LastSeat.of(table.value) != seat) {
    LastSeat.letGo();
    return;
  }
  final split = seat.indexOf('|');
  if (split < 0) {
    ref.watch(lobbyProvider(seat));
  } else {
    ref.watch(liveGameProvider(seat.substring(split + 1)));
  }
}

String _deckKey(MyTable table) => '${table.lobbyCode}|${table.gameId}';

/// What the local steps mean for [table] now.
LocalSteps localStepsFor(StepRecord record, MyTable? table) => LocalSteps(
  editingDeck:
      table != null &&
      table.status == TableStatus.waiting &&
      record.deckAt == _deckKey(table),
);

@Riverpod(keepAlive: true)
class LocalStepsNotifier extends _$LocalStepsNotifier {
  @override
  StepRecord build() => const StepRecord();

  /// The host opens 03 Deck at the waiting [table].
  void openDeck(MyTable table) => state = StepRecord(deckAt: _deckKey(table));

  /// 03 closes (Use this deck, or back).
  void closeDeck() => state = const StepRecord();
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
///
/// Opening the app, the seat this device last had ([LastSeat]) is read
/// beside `/me/table/`, not after it: its game's `/me/` (or its waiting
/// table's lobby) goes out at the same time, so a player still there sees
/// their screen one round trip after the app opens. `/me/table/` decides;
/// a seat it does not name is dropped (one read spent).
@riverpod
AsyncValue<TableScreen> tableScreen(Ref ref) {
  final tableAsync = ref.watch(myTableProvider);
  _readLastSeatBeside(ref, tableAsync);
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
    final game = ref.watch(liveGameProvider(gameId)).value;
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
