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
///
/// The phone's clock can be set while the app is open (automatic time sync,
/// a hand in the settings). So beside it runs a stopwatch, which only counts:
/// when the two part by more than [stepAtLeast] between two readings, the
/// phone's clock stepped, and the offset moves by the step the other way, so
/// the server's clock goes on as if nothing happened. Across a sleep (the app
/// went away and came back: [cameBack]) the stopwatch may have stopped while
/// the phone's clock kept counting, so the phone's clock is the truth there
/// and nothing moves.
class ServerClock {
  ServerClock(this._phone, this._stopwatch);

  final DateTime Function() _phone;
  final Duration Function() _stopwatch;

  /// How far apart the phone's clock and the stopwatch must part between two
  /// readings to count as the phone's clock being set.
  static const stepAtLeast = Duration(seconds: 1);

  /// The highest floor heard, as the server's clock minus the phone's.
  Duration? _offset;

  /// The phone's own reading as a floor, moved by its clock's steps.
  Duration _own = Duration.zero;

  /// An answer's `Date` was read: the phone's own reading no longer counts.
  bool _stamped = false;

  DateTime? _lastPhone;
  Duration? _lastStopwatch;
  bool _away = false;

  /// The app came back to the foreground: the phone's clock is the truth for
  /// the time it was away.
  void cameBack() => _away = true;

  DateTime _read() {
    final phone = _phone();
    final stopwatch = _stopwatch();
    final lastPhone = _lastPhone;
    final lastStopwatch = _lastStopwatch;
    if (lastPhone != null && lastStopwatch != null && !_away) {
      final step = phone.difference(lastPhone) - (stopwatch - lastStopwatch);
      if (step.abs() > stepAtLeast) {
        if (_offset case final offset?) _offset = offset - step;
        _own -= step;
      }
    }
    _away = false;
    _lastPhone = phone;
    _lastStopwatch = stopwatch;
    return phone;
  }

  /// An answer's `Date` header ([stamp]) or a view's `stage_started_at`: the
  /// server's clock had reached it by now. True when the clock moved by more
  /// than [by] (the clocks on screen read again).
  bool heard(
    DateTime? atLeast, {
    bool stamp = false,
    Duration by = Duration.zero,
  }) {
    if (atLeast == null) return false;
    final phone = _read();
    final before = _effective;
    final offset = atLeast.difference(phone);
    if (_offset == null || offset > _offset!) _offset = offset;
    if (stamp) _stamped = true;
    final after = _effective;
    return after != before && (before == null || (after! - before).abs() > by);
  }

  Duration? get _effective {
    final offset = _offset;
    if (_stamped) return offset;
    if (offset == null || offset < _own) return _own;
    return offset;
  }

  /// The server's clock now.
  DateTime now() {
    final phone = _read();
    return phone.add(_effective ?? Duration.zero);
  }

  /// How long until [time] on the server's clock.
  Duration until(DateTime time) => time.difference(now());
}
