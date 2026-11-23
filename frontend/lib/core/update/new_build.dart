import 'dart:async';

import 'build_id.dart';

/// Why the app is looking at whether it may renew itself now. The rule that
/// reads this is `mayReloadNow` (`features/game/domain/reload_rule.dart`).
enum Moment {
  /// A newer build was just learned of, or an earlier hold ended (a request
  /// settled, the slow look).
  learned,

  /// The screen changed: a screen was left for another (the table moved on
  /// to its next phase, a game ended). A running game never reloads for this.
  screenChanged,

  /// The tab is visible again after it was hidden for longer than
  /// `NewBuild.awayFor` (the app came back to the foreground): the one
  /// moment a running game renews itself at.
  resumed,
}

/// An app left open keeps running the build it was loaded with. This learns
/// which build is live (`/commit.txt`) and, when it is not [mine], brings the
/// page's service worker up to date ([renewWorker]: nothing is let go of) and
/// reloads the page at a safe moment ([safe]); the app then opens as it does
/// cold, so a seated player lands back in their seat on the same screen.
/// When the worker cannot be brought up to date (a failed update, no new
/// worker within its bound) nothing is changed and the app is left running
/// as it is; the next look tries again.
///
/// Looks: when the app starts, when it is resumed, when something smells
/// like a stale build ([smelled]) and on a slow timer, one small request
/// each, and never more often than [gap] apart except the timer's own
/// ([every]). Never reloads twice for one live build: the build reloaded for
/// is kept for this tab ([rememberReload]; another tab is its own), so a
/// shell that is still the old one cannot loop.
///
/// Nothing here waits for anything the player can feel, shows anything or
/// says anything.
class NewBuild {
  NewBuild({
    required this.mine,
    required this.fetchLive,
    required this.renewWorker,
    required this.reload,
    required this.reloadedFor,
    required this.rememberReload,
    required this.safe,
    required this.now,
    this.every = const Duration(minutes: 5),
    this.gap = const Duration(seconds: 10),
    this.awayFor = const Duration(seconds: 5),
  });

  /// The build this app is.
  final String mine;

  /// The live build's commit, or null when it cannot be read.
  final Future<String?> Function() fetchLive;

  /// Brings the page's service worker up to date (`renewWorker`); false when
  /// it could not within its bound, with everything left as it was.
  final Future<bool> Function() renewWorker;

  /// Reloads the page.
  final Future<void> Function() reload;

  /// The build this tab last reloaded for (none yet: null).
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

  /// How long the tab must have been hidden for its coming back to be a
  /// [Moment.resumed] (a glance away is not one).
  final Duration awayFor;

  Timer? _timer;
  Object? _place;
  var _shown = false;
  String? _live;
  String? _reloadedFor;
  var _read = false;
  var _checking = false;
  var _reloading = false;

  /// The worker could not be brought up to date: not tried again until the
  /// next look (the slow timer, a come-back, a smell), never in a hurry.
  var _renewFailed = false;
  var _disposed = false;
  DateTime? _lastLook;
  DateTime? _hiddenAt;

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

  /// The tab was hidden (another tab, the screen off).
  void hidden() => _hiddenAt ??= now();

  /// The app is visible again. After more than [awayFor] hidden it is a
  /// [Moment.resumed]; a glance away is not one.
  void resumed() {
    final since = _hiddenAt;
    _hiddenAt = null;
    final away = since != null && now().difference(since) > awayFor;
    final moment = away ? Moment.resumed : Moment.learned;
    _renewFailed = false;
    if (_live != null) {
      _consider(moment);
    } else {
      unawaited(look(moment: moment));
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
      _renewFailed = false;
    } catch (_) {
      return;
    } finally {
      _checking = false;
    }
    _consider(moment);
  }

  void _consider(Moment moment) {
    final live = _live;
    if (_disposed || live == null || _reloading || _renewFailed) return;
    if (!safe(_place, moment)) return;
    _reloading = true;
    unawaited(_reloadFor(live, moment));
  }

  Future<void> _reloadFor(String live, Moment moment) async {
    try {
      // The worker first: if it cannot be brought up to date, leave
      // everything as it is and try again at the next look.
      if (!await renewWorker()) {
        _renewFailed = true;
        _reloading = false;
        return;
      }
      // The player may have tapped or moved on meanwhile: ask again.
      if (_disposed || !safe(_place, moment)) {
        _reloading = false;
        return;
      }
      await rememberReload(live);
      await reload();
    } catch (_) {
      _reloading = false;
    }
  }
}
