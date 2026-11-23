import 'dart:async';

import 'build_id.dart';

/// Why the app is looking at whether it may renew itself now. The rule that
/// reads this is `mayReloadNow` (`features/game/domain/reload_rule.dart`).
enum Moment {
  /// A newer build was just learned of, or an earlier hold ended (a request
  /// settled, the slow look).
  learned,

  /// The screen changed: the table moved to its next phase, or a screen was
  /// left for another.
  screenChanged,

  /// The tab is visible again (the app came back to the foreground).
  resumed,
}

/// An app left open keeps running the build it was loaded with. This learns
/// which build is live (`/commit.txt`) and, when it is not [mine], reloads
/// the page at a safe moment ([safe]); the app then opens as it does cold,
/// so a seated player lands back in their seat on the same screen.
///
/// Looks: when the app starts, when it is resumed, when something smells
/// like a stale build ([smelled]) and on a slow timer, one small request
/// each, and never more often than [gap] apart except the timer's own
/// ([every]). Never reloads twice for one live build: the build reloaded for
/// is kept on the device ([rememberReload]), so a shell that is still the
/// old one cannot loop.
///
/// Nothing here waits for anything the player can feel, shows anything or
/// says anything.
class NewBuild {
  NewBuild({
    required this.mine,
    required this.fetchLive,
    required this.reload,
    required this.reloadedFor,
    required this.rememberReload,
    required this.safe,
    required this.now,
    this.every = const Duration(minutes: 5),
    this.gap = const Duration(seconds: 10),
  });

  /// The build this app is.
  final String mine;

  /// The live build's commit, or null when it cannot be read.
  final Future<String?> Function() fetchLive;

  /// Reloads the page.
  final Future<void> Function() reload;

  /// The build this device last reloaded for (none yet: null).
  final Future<String?> Function() reloadedFor;
  final Future<void> Function(String build) rememberReload;

  /// The one rule: whether a reload may happen at [place] (what the app
  /// shows) for [moment].
  final bool Function(Object? place, Moment moment) safe;

  final DateTime Function() now;

  /// The slow look.
  final Duration every;

  /// The shortest time between two looks that are not the slow one.
  final Duration gap;

  Timer? _timer;
  Object? _place;
  var _shown = false;
  String? _live;
  String? _reloadedFor;
  var _read = false;
  var _checking = false;
  var _reloading = false;
  var _disposed = false;
  DateTime? _lastLook;

  /// Whether a newer build is known and a reload is waiting for its moment.
  bool get waiting => _live != null;

  /// Starts looking: once now, then on the slow timer.
  void start() {
    if (!BuildId.isReal(mine)) return;
    _timer = Timer.periodic(every, (_) => unawaited(look(slow: true)));
    unawaited(look());
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
  }

  /// The screen now shown ([place]). A change is a moment.
  void seen(Object? place) {
    if (_shown && place == _place) return;
    // The first screen is where the app opened, not a change.
    final moment = _shown ? Moment.screenChanged : Moment.learned;
    _shown = true;
    _place = place;
    // After this frame: the screen is built before anything reads the app.
    Timer.run(() => _consider(moment));
  }

  /// The app is visible again.
  void resumed() {
    if (_live != null) {
      _consider(Moment.resumed);
    } else {
      unawaited(look(moment: Moment.resumed));
    }
  }

  /// Something smells like a stale build.
  void smelled() => unawaited(look());

  /// A hold ended (a player request settled): a reload that waited for it
  /// may go.
  void settled() => Timer.run(() => _consider(Moment.learned));

  /// Reads the live build. [moment] is what a newer one counts as when it is
  /// learned ([Moment.resumed] when the app has just come back); [slow] is
  /// the timer's own look, which no gap holds back.
  Future<void> look({Moment moment = Moment.learned, bool slow = false}) async {
    if (_disposed || _checking || _reloading) return;
    final last = _lastLook;
    final at = now();
    if (!slow && last != null && at.difference(last) < gap) return;
    _lastLook = at;
    _checking = true;
    try {
      final live = await fetchLive();
      if (_disposed || live == null || live.isEmpty) return;
      if (live == mine) {
        _live = null;
        return;
      }
      if (!_read) {
        _reloadedFor = await reloadedFor();
        _read = true;
      }
      // Reloaded for this one already and still not it: the shell is the
      // old one. Never again for this build.
      if (live == _reloadedFor) return;
      _live = live;
    } catch (_) {
      return;
    } finally {
      _checking = false;
    }
    _consider(moment);
  }

  void _consider(Moment moment) {
    final live = _live;
    if (_disposed || live == null || _reloading) return;
    if (!safe(_place, moment)) return;
    _reloading = true;
    unawaited(_reloadFor(live));
  }

  Future<void> _reloadFor(String live) async {
    try {
      await rememberReload(live);
      await reload();
    } catch (_) {
      _reloading = false;
    }
  }
}
