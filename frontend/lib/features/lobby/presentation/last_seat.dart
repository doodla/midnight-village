import '../../../core/storage/device_preferences.dart';
import '../domain/where_am_i.dart';

/// The seat this device last had, kept on it ([prefix]: `<code>` at a
/// waiting table, `<code>|<game>` in a game; nothing at no table), written
/// from every `/me/table/` answer ([keep]) and read before the first frame
/// ([restore]), so that opening the app reads that seat's game (or lobby)
/// beside `/me/table/` instead of after it (`tableScreenProvider`). Only a
/// head start: `/me/table/` decides, and a seat it does not name is let go.
abstract final class LastSeat {
  static const prefix = 'mv.seat.v1.';

  static String? _opening;
  static String? _kept;
  static Future<void> _writes = Future.value();

  /// The seat read at start, until `/me/table/` names another ([letGo]).
  static String? get opening => _opening;

  /// `/me/table/` named another seat: the opening's head start is over.
  static void letGo() => _opening = null;

  /// Reads the kept seat (`main` awaits it before the first frame).
  static Future<void> restore(DevicePreferences preferences) async {
    final seats = await preferences.readFlags(prefix);
    _reset(seats.firstOrNull?.substring(prefix.length));
  }

  /// Forgets what [restore] read, so a test starts as a new device
  /// (`forgetRestoredLocalSteps`).
  static void forget() => _reset(null);

  static void _reset(String? seat) {
    _opening = seat;
    _kept = seat;
    _writes = Future.value();
  }

  /// The seat [table] is, as kept.
  static String? of(MyTable? table) => switch (table) {
    null => null,
    MyTable(status: TableStatus.waiting) => table.lobbyCode,
    MyTable(:final gameId?) => '${table.lobbyCode}|$gameId',
    _ => table.lobbyCode,
  };

  /// Keeps where `/me/table/` says this phone sits (written only when it
  /// changed; writes go one after another).
  static void keep(DevicePreferences preferences, MyTable? table) {
    final seat = of(table);
    if (seat == _kept) return;
    _kept = seat;
    _writes = _writes.then((_) async {
      await preferences.clearFlags(prefix);
      if (seat != null) await preferences.setFlag('$prefix$seat');
    });
  }
}
