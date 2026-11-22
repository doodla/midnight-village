import '../../../core/storage/device_preferences.dart';
import '../domain/where_am_i.dart';

/// The seat this device last had, kept on it for the account that had it
/// ([prefix]`<user>:<seat>`; the seat is `<code>` at a waiting table,
/// `<code>|<game>` in a game; nothing at no table), written from every
/// `/me/table/` answer ([keep]) and read before the first frame ([restore]),
/// so that opening the app reads that seat's game (or lobby) beside
/// `/me/table/` instead of after it (`tableScreenProvider`).
///
/// Only a quiet head start: `/me/table/` decides, a seat it does not name is
/// let go, and the read beside it closes nothing, says nothing and never
/// asks for the table again (`LiveGameNotifier`, which acts only for a game
/// `/me/table/` names). Another account never reads it; an account that is
/// gone (or signed out) takes it with it ([forgetAccount]).
abstract final class LastSeat {
  static const prefix = 'mv.seat.v1.';

  static String? _opening;
  static String? _kept;
  static Future<void> _writes = Future.value();

  /// The seat read at start for account [userId], until `/me/table/` names
  /// another ([letGo]); null for any other account.
  static String? openingFor(int userId) {
    final kept = _opening;
    final mark = '$userId:';
    if (kept == null || !kept.startsWith(mark)) return null;
    return kept.substring(mark.length);
  }

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

  /// The account is gone or signed out: its seat goes with it.
  static void forgetAccount(DevicePreferences preferences) {
    final had = _kept != null;
    _opening = null;
    _kept = null;
    if (had) _write(preferences, null);
  }

  static void _reset(String? kept) {
    _opening = kept;
    _kept = kept;
    _writes = Future.value();
  }

  /// The seat [table] is, as kept.
  static String? of(MyTable? table) => switch (table) {
    null => null,
    MyTable(status: TableStatus.waiting) => table.lobbyCode,
    MyTable(:final gameId?) => '${table.lobbyCode}|$gameId',
    _ => table.lobbyCode,
  };

  /// Keeps where `/me/table/` says account [userId] sits (written only when
  /// it changed; writes go one after another).
  static void keep(DevicePreferences preferences, int userId, MyTable? table) {
    final seat = of(table);
    final kept = seat == null ? null : '$userId:$seat';
    if (kept == _kept) return;
    _kept = kept;
    _write(preferences, kept);
  }

  static void _write(DevicePreferences preferences, String? kept) {
    _writes = _writes.then((_) async {
      await preferences.clearFlags(prefix);
      if (kept != null) await preferences.setFlag('$prefix$kept');
    });
  }
}
