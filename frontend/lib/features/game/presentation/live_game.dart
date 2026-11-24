import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/healing/healing.dart';
import '../../../core/host/host_change.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/requests/player_request.dart';
import '../../../design_system/copy/copy.dart';
import '../../../design_system/primitives/pending.dart' show RequestRefused;
import '../../../core/websocket/websocket_channel.dart';
import '../../../design_system/night/night_pick.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../lobby/domain/lobby_state.dart';
import '../../lobby/domain/where_am_i.dart';
import '../../lobby/presentation/join_flow.dart';
import '../../lobby/presentation/lobby_notifier.dart';
import '../../lobby/presentation/where_am_i_provider.dart';
import '../data/game_service.dart';
import '../domain/game_event.dart';
import '../domain/game_me.dart';
import '../domain/game_outcome.dart';
import 'game_socket.dart';
import 'outbox.dart';

export 'outbox.dart';

part 'live_game.g.dart';
part 'live_game_state.dart';
part 'live_game_taps.dart';

/// A game for the shell's screens, keyed by game id. The game id comes from
/// `/me/table/` (`tableScreenProvider`), so a new deal replaces this game.
///
/// Server state in: `/me/` fetches go out one at a time (a request made
/// while one is out runs once after it), so a reply can never overtake a
/// newer one. A failed fetch is made again with backoff until one succeeds;
/// socket events only ask for a fetch or update a value `/me/` holds in the
/// same form ([GameEvent]); reconnect, resume and the stage's deadline fetch
/// too. The screen is a function of fetched state alone.
///
/// Taps out: through the [Outbox], one request per kind in flight, later
/// taps coalescing to the latest, each keyed to its stage (and turn) and
/// dropped when that ends. The shown state is derived from it.
///
/// Known and accepted: a request whose answer was lost but which the server
/// processes later can land after a newer tap of the same lane (the latest
/// is resent only after a fetch, but the server orders what it receives);
/// closing that needs a per-phone sequence number on the server.
///
/// Riverpod's own retry is off ([noRetry]): this notifier retries its
/// fetches itself, and a Riverpod rebuild would drop the taps in flight.
@Riverpod(retry: noRetry)
class LiveGameNotifier extends _$LiveGameNotifier with _LiveGameTaps {
  StreamSubscription<dynamic>? _events;
  @override
  Timer? _healTimer;
  @override
  Timer? _retryTimer;
  int _failedFetches = 0;
  Timer? _outcomeTimer;
  int _failedOutcomes = 0;
  @override
  Timer? _ackTimer;
  @override
  int _failedAcks = 0;
  bool _wasDisconnected = false;

  bool _building = false;
  Future<void>? _loop;
  bool _again = false;

  /// `/me/` fetches sent: a confirming tap waits for one sent after its
  /// answer.
  @override
  int _sentFetches = 0;

  /// The server's clock at the last applied fetch, and the time since.
  DateTime? _serverDate;
  final _sinceFetch = Stopwatch();

  /// The stage and deadline whose deadline has passed (polling).
  String? _passedKey;

  /// Asked once per mismatch: the table behind `/me/`, `/me/` behind it.
  String? _tableAskedAt;
  String? _meAskedAt;

  @override
  int _ids = 0;

  /// The results count this phone has acknowledged in this session.
  @override
  int? _acked;

  @override
  GameService get _service => ref.read(gameServiceProvider);
  @override
  HealTiming get _timing => ref.read(healTimingProvider);

  @override
  Future<LiveGame> build(String gameId) async {
    ref.onDispose(() {
      _events?.cancel();
      _healTimer?.cancel();
      _retryTimer?.cancel();
      _outcomeTimer?.cancel();
      _ackTimer?.cancel();
    });
    // Listen first, so nothing said while the first fetch is out is missed.
    _events = ref
        .watch(gameWebSocketStreamProvider(gameId))
        ?.listen(
          _onMessage,
          onError: (Object e) => logger.w('LiveGame: socket', error: e),
        );
    ref.listen(
      gameConnectionStateProvider(gameId),
      (_, next) => _onConnection(next.value),
    );
    ref.listen(appResumesProvider, (_, next) {
      if (next.hasValue) _healEverything();
    });
    ref.listen(myTableProvider, (_, next) => _compareTable(next.value));

    _building = true;
    _sentFetches++;
    try {
      final fetched = await _service.fetchMeTimed(gameId);
      _clockFrom(fetched);
      _failedFetches = 0;
      _afterApply(fetched.me);
      return LiveGame._(server: fetched.me, outbox: Outbox.empty);
    } catch (e) {
      // A game `/me/table/` does not name that answers "gone" is let go
      // quietly (a read ahead of the table's); anything else is read again.
      if (e is! NotFoundException || _named) _scheduleRetry();
      rethrow;
    } finally {
      _building = false;
      if (_again) {
        // After the state is set (the event loop's next turn), not before.
        _again = false;
        Timer.run(() => unawaited(refresh()));
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Server state in
  // ---------------------------------------------------------------------------

  /// Fetches `/me/` now, or once more after the fetch that is out. Works
  /// before the first load succeeded too (it then is the first load).
  @override
  Future<void> refresh() {
    if (!ref.mounted) return Future.value();
    if (_building) {
      _again = true;
      return Future.value();
    }
    final running = _loop;
    if (running != null) {
      _again = true;
      return running;
    }
    return _loop = _runLoop().whenComplete(() => _loop = null);
  }

  Future<void> _runLoop() async {
    do {
      _again = false;
      await _fetchOnce();
    } while (_again && ref.mounted);
  }

  Future<void> _fetchOnce() async {
    final seq = ++_sentFetches;
    try {
      final fetched = await _service.fetchMeTimed(gameId);
      if (ref.mounted) _accept(seq, fetched);
    } on NotFoundException {
      if (ref.mounted) _tableGone();
    } catch (e, stack) {
      if (!ref.mounted) return;
      logger.w('LiveGame: fetch failed', error: e);
      final current = state.value;
      if (current == null) {
        state = AsyncError(e, stack);
      } else {
        _update((s) => s.copyWith(fetchFailing: true));
        _armHealing(current.server);
      }
      // Whatever asked for this fetch (a taken choose, an event, a "Try
      // again") still needs it: again, with backoff, until one succeeds.
      _scheduleRetry();
    }
  }

  /// Applies the `/me/` of fetch number [seq].
  void _accept(int seq, FetchedMe fetched) {
    final current = state.value;
    final me = fetched.me;
    _clockFrom(fetched);
    _failedFetches = 0;
    _retryTimer?.cancel();
    final outbox = (current?.outbox ?? Outbox.empty).afterFetch(me, seq);
    state = AsyncData(
      current == null
          ? LiveGame._(server: me, outbox: outbox)
          : current.copyWith(
              server: me,
              outbox: outbox,
              tableClosed: false,
              fetchFailing: false,
            ),
    );
    _afterApply(me);
    // A queued tap whose lane was waiting on a dropped request goes now.
    for (final lane in OutboxLane.values) {
      _next(lane);
    }
  }

  void _afterApply(GameMe me) {
    _armHealing(me);
    final table = ref.exists(myTableProvider)
        ? ref.read(myTableProvider).value
        : null;
    _compareTable(table, me: me);
    if (me.phase == GamePhase.results && state.value?.outcome == null) {
      _outcomeTimer ??= Timer(Duration.zero, _loadOutcome);
    }
  }

  /// The results, fetched until they load (or the game is no longer at the
  /// results), with backoff.
  Future<void> _loadOutcome() async {
    _outcomeTimer = null;
    if (!ref.mounted) return;
    try {
      final outcome = await _service.fetchOutcome(gameId);
      _failedOutcomes = 0;
      _update((s) => s.copyWith(outcome: outcome, outcomeFailing: false));
    } catch (e) {
      logger.w('LiveGame: results not fetched', error: e);
      if (!ref.mounted) return;
      final atResults = state.value?.server.phase == GamePhase.results;
      if (atResults && state.value?.outcome == null) {
        _update((s) => s.copyWith(outcomeFailing: true));
        _outcomeTimer = Timer(
          _timing.retryAfter(_failedOutcomes++),
          _loadOutcome,
        );
      }
    }
  }

  void _clockFrom(FetchedMe fetched) {
    _serverDate = fetched.serverDate;
    _sinceFetch
      ..reset()
      ..start();
  }

  /// How long until [time] on the server's clock: from the last answer's
  /// `Date` and the time since it arrived, so the phone's own clock is never
  /// compared with the server's. Without a readable `Date`, the phone's
  /// clock times the fetch (and only the fetch: what it shows decides).
  Duration _untilServer(DateTime time) {
    final date = _serverDate;
    if (date != null) return time.difference(date) - _sinceFetch.elapsed;
    return time.difference(ref.read(clockProvider)());
  }

  /// How long until [time] on the server's clock, as the stage's countdown
  /// reads it (the same clock the deadline fetch is timed by).
  Duration untilServer(DateTime time) => _untilServer(time);

  /// One fetch after the stage's deadline; while a fetch past it still
  /// shows the same stage, one every [HealTiming.poll] until it changes. A
  /// stage with no deadline heals on reconnect and resume.
  void _armHealing(GameMe me) {
    _healTimer?.cancel();
    final deadline = me.deadline;
    if (deadline == null) return;
    final key = '${me.stage}@$deadline';
    if (key == _passedKey) {
      _healTimer = Timer(_timing.poll, refresh);
      return;
    }
    final wait = _untilServer(deadline) + _timing.afterDeadline;
    _healTimer = Timer(wait.isNegative ? Duration.zero : wait, () {
      _passedKey = key;
      unawaited(refresh());
    });
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(
      _timing.retryAfter(_failedFetches++),
      () => unawaited(refresh()),
    );
  }

  /// `/me/table/` and `/me/` agree on the game's phase; when one is behind,
  /// it is fetched again (once per mismatch).
  void _compareTable(MyTable? table, {GameMe? me}) {
    final own = me ?? state.value?.server;
    if (table == null || own == null || table.gameId != gameId) return;
    final phase = table.gamePhase;
    if (phase == null) return;
    final at = '${own.stage}|${phase.server}';
    if (phase.index > own.phase.index && _meAskedAt != at) {
      _meAskedAt = at;
      unawaited(refresh());
    } else if (own.phase.index > phase.index && _tableAskedAt != at) {
      _tableAskedAt = at;
      _invalidateTable();
    }
  }

  /// Asks for `/me/table/` again, only for a game it names ([_named]).
  void _invalidateTable() {
    if (_named) ref.invalidate(myTableProvider);
  }

  /// Whether `/me/table/` names this game. Until it does (a game read beside
  /// the table's as the app opens, or from a deal's answer), this notifier
  /// only reads: it closes nothing, says nothing and never asks for the
  /// table again; only what `/me/table/` names can.
  @override
  bool get _named {
    if (!ref.exists(myTableProvider)) return false;
    final table = ref.read(myTableProvider).value;
    return table != null &&
        table.gameId == gameId &&
        table.status != TableStatus.waiting;
  }

  /// Reconnect and resume: anything may have happened.
  void _healEverything() {
    _invalidateTable();
    unawaited(refresh());
    final lost = state.value?.outbox.current(OutboxLane.ack);
    if (lost?.leg == Leg.unsent) unawaited(retry(OutboxLane.ack));
  }

  void _onConnection(WebSocketConnectionState? connection) {
    switch (connection) {
      case WebSocketConnectionState.connected when _wasDisconnected:
        _wasDisconnected = false;
        _healEverything();
      case WebSocketConnectionState.disconnected ||
          WebSocketConnectionState.reconnecting:
        _wasDisconnected = readOnDrop(connection!, _healEverything);
      default:
    }
  }

  void _onMessage(dynamic message) {
    final GameEvent event;
    try {
      event = GameEvent.parse(message);
    } catch (e) {
      // A malformed event: the next fetch is the truth.
      logger.w('LiveGame: unreadable event', error: e);
      unawaited(refresh());
      return;
    }
    apply(event);
  }

  /// One socket event (public for tests that drive events directly).
  void apply(GameEvent event) {
    if (state.value == null) {
      // The first fetch is out (or failed): it may predate this.
      if (event is! IgnoredEvent) unawaited(refresh());
      return;
    }
    switch (event) {
      case ProgressEvent(:final progress):
        final current = state.requireValue.server;
        // While this phone's own ready or vote is not confirmed by a `/me/`,
        // the screens count it themselves (`GameMe.withReady`, `withVote`)
        // against the `/me/` they have; a count from elsewhere may already
        // hold it, so the count and the flag are fetched together instead.
        final own = _game.outbox;
        final unconfirmed =
            own.shown(OutboxLane.ready) != null ||
            own.shown(OutboxLane.vote) != null;
        if (_loop != null ||
            unconfirmed ||
            current.progress?.stage != progress.stage) {
          unawaited(refresh());
        } else {
          _update((s) => s.copyWith(server: current.withProgress(progress)));
        }
      case PresenceEvent(:final playerId, :final connected):
        _update(
          (s) => s.copyWith(presence: {...s.presence, playerId: connected}),
        );
      case HostEvent(:final change):
        _update(
          (s) => s.copyWith(
            server: s.server.withHost(change.hostId),
            hostNotice: change,
          ),
        );
        _invalidateTable(); // its is_host
        if (_loop != null) unawaited(refresh());
      case RefetchEvent():
        _invalidateTable();
        unawaited(refresh());
      case TableMovedEvent():
        _invalidateTable();
        unawaited(refresh());
      case IgnoredEvent():
    }
  }

  @override
  void _update(LiveGame Function(LiveGame) change) {
    if (!ref.mounted) return;
    final current = state.value;
    if (current != null) state = AsyncData(change(current));
  }

  @override
  LiveGame get _game => state.requireValue;

  @override
  void _setOutbox(Outbox outbox) => _update((s) => s.copyWith(outbox: outbox));

  /// The quiet host line has been shown.
  void clearHostNotice() => _update((s) => s.copyWith(clearHostNotice: true));
}
