/// The phone's one idea of the server's clock: what every stage clock counts
/// with (`LiveGameNotifier.untilServer`).
///
/// Everything the phone hears says only that the server's clock had reached
/// some moment by the time it arrived: an answer's `Date` header (whole
/// seconds, stamped before the answer left, and on the live host often many
/// seconds old: owner, 28 November 2026, "The timer is fucked. Keeps jumping
/// around"), or a view's `stage_started_at` (the stage had opened before any
/// view of it was built). Each is a floor, never the time itself. So the
/// clock keeps the highest floor heard, as an offset from the phone's own
/// clock: an answer that knows less (an older stamp, a slower trip) never
/// moves it back, and one that knows more only moves it forward. The phone's
/// clock gives only the time since (it keeps counting while the phone
/// sleeps); its own reading counts only while no `Date` was ever readable (a
/// browser not shown the header), as one more floor.
class ServerClock {
  ServerClock(this._phone);

  final DateTime Function() _phone;

  /// The highest floor heard, as the server's clock minus the phone's.
  Duration? _offset;

  /// An answer's `Date` was read: the phone's own reading no longer counts.
  bool _stamped = false;

  /// An answer's `Date` header ([stamp]) or a view's `stage_started_at`: the
  /// server's clock had reached it by now. True when the clock moved by more
  /// than [by] (the clocks on screen read again).
  bool heard(
    DateTime? atLeast, {
    bool stamp = false,
    Duration by = Duration.zero,
  }) {
    if (atLeast == null) return false;
    final before = _effective;
    final offset = atLeast.difference(_phone());
    if (_offset == null || offset > _offset!) _offset = offset;
    if (stamp) _stamped = true;
    final after = _effective;
    return after != before && (before == null || (after! - before).abs() > by);
  }

  Duration? get _effective {
    final offset = _offset;
    if (_stamped) return offset;
    if (offset == null || offset < Duration.zero) return Duration.zero;
    return offset;
  }

  /// The server's clock now.
  DateTime now() => _phone().add(_effective ?? Duration.zero);

  /// How long until [time] on the server's clock.
  Duration until(DateTime time) => time.difference(now());
}
