import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/healing/healing.dart';
import '../../../core/host/host_change.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/websocket/websocket_channel.dart';
import '../../../design_system/night/night_pick.dart';
import '../../lobby/domain/where_am_i.dart';
import '../../lobby/presentation/lobby_notifier.dart';
import '../../lobby/presentation/where_am_i_provider.dart';
import '../data/game_service.dart';
import '../domain/game_event.dart';
import '../domain/game_me.dart';
import '../domain/game_outcome.dart';
import 'game_notifier.dart'
    show gameConnectionStateProvider, gameWebSocketStreamProvider;
import 'outbox.dart';

export 'outbox.dart';

part 'protocol_two_game.g.dart';

/// A night protocol 2 game as this phone holds it: the server's last `/me/`,
/// the taps it has not seen yet ([outbox]), and the results once over.
@immutable
class ProtocolTwoGame {
  const ProtocolTwoGame._({
    required this.server,
    required this.outbox,
    this.outcome,
    this.presence = const {},
    this.hostNotice,
    this.tableClosed = false,
  });

  /// The last `/me/` the server sent.
  final GameMe server;

  /// This phone's taps in flight, unsent or confirming.
  final Outbox outbox;

  /// `GET .../results/`, fetched (and fetched again until it loads) once the
  /// game is in the results.
  final GameOutcome? outcome;

  /// Who has a phone connected (public), from `player_presence`.
  final Map<int, bool> presence;

  /// The latest host change, for the quiet line about it (until cleared).
  final HostChange? hostNotice;

  /// The game (its table) is gone: the last fetch was answered 404.
  final bool tableClosed;

  /// What the screens show: `/me/` with this phone's taps on it. Everything
  /// the table can see on this phone changes on the tap, never on the
  /// answer.
  GameMe get me => outbox.on(server);

  /// The taps whose answer never came and that wait for "Try again"
  /// ([ProtocolTwoGameNotifier.retry]); the board shows its own for a
  /// choose. The results ack is retried by itself and is not listed.
  Set<OutboxLane> get unsent =>
      outbox.unsent.difference(const {OutboxLane.ack});

  ProtocolTwoGame copyWith({
    GameMe? server,
    Outbox? outbox,
    GameOutcome? outcome,
    Map<int, bool>? presence,
    HostChange? hostNotice,
    bool clearHostNotice = false,
    bool? tableClosed,
  }) => ProtocolTwoGame._(
    server: server ?? this.server,
    outbox: outbox ?? this.outbox,
    outcome: outcome ?? this.outcome,
    presence: presence ?? this.presence,
    hostNotice: clearHostNotice ? null : hostNotice ?? this.hostNotice,
    tableClosed: tableClosed ?? this.tableClosed,
  );
}

/// A night protocol 2 game for the rebuilt screens, keyed by game id (the
/// old screens keep [GameNotifier] on protocol 1). The game id comes from
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
class ProtocolTwoGameNotifier extends _$ProtocolTwoGameNotifier {
  StreamSubscription<dynamic>? _events;
  Timer? _healTimer;
  Timer? _retryTimer;
  int _failedFetches = 0;
  Timer? _outcomeTimer;
  int _failedOutcomes = 0;
  Timer? _ackTimer;
  int _failedAcks = 0;
  bool _wasDisconnected = false;

  bool _building = false;
  Future<void>? _loop;
  bool _again = false;

  /// `/me/` fetches sent: a confirming tap waits for one sent after its
  /// answer.
  int _sentFetches = 0;

  /// The server's clock at the last applied fetch, and the time since.
  DateTime? _serverDate;
  final _sinceFetch = Stopwatch();

  /// The stage and deadline whose deadline has passed (polling).
  String? _passedKey;

  /// Asked once per mismatch: the table behind `/me/`, `/me/` behind it.
  String? _tableAskedAt;
  String? _meAskedAt;

  int _ids = 0;

  /// The results count this phone has acknowledged in this session.
  int? _acked;

  GameService get _service => ref.read(gameServiceProvider);
  HealTiming get _timing => ref.read(healTimingProvider);

  @override
  Future<ProtocolTwoGame> build(String gameId) async {
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
          onError: (Object e) => logger.w('ProtocolTwoGame: socket', error: e),
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
      return ProtocolTwoGame._(server: fetched.me, outbox: Outbox.empty);
    } catch (e) {
      _scheduleRetry();
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
      if (!ref.mounted) return;
      _invalidateTable();
      _update((s) => s.copyWith(tableClosed: true));
    } catch (e, stack) {
      if (!ref.mounted) return;
      logger.w('ProtocolTwoGame: fetch failed', error: e);
      final current = state.value;
      if (current == null) {
        state = AsyncError(e, stack);
      } else {
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
          ? ProtocolTwoGame._(server: me, outbox: outbox)
          : current.copyWith(server: me, outbox: outbox, tableClosed: false),
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
      _update((s) => s.copyWith(outcome: outcome));
    } catch (e) {
      logger.w('ProtocolTwoGame: results not fetched', error: e);
      if (!ref.mounted) return;
      final atResults = state.value?.server.phase == GamePhase.results;
      if (atResults && state.value?.outcome == null) {
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

  void _invalidateTable() => ref.invalidate(myTableProvider);

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
        _wasDisconnected = true;
      default:
    }
  }

  void _onMessage(dynamic message) {
    final GameEvent event;
    try {
      event = GameEvent.parse(message);
    } catch (e) {
      // A malformed event: the next fetch is the truth.
      logger.w('ProtocolTwoGame: unreadable event', error: e);
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
        if (_loop != null || current.progress?.stage != progress.stage) {
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

  void _update(ProtocolTwoGame Function(ProtocolTwoGame) change) {
    if (!ref.mounted) return;
    final current = state.value;
    if (current != null) state = AsyncData(change(current));
  }

  ProtocolTwoGame get _game => state.requireValue;

  void _setOutbox(Outbox outbox) => _update((s) => s.copyWith(outbox: outbox));

  /// The quiet host line has been shown.
  void clearHostNotice() => _update((s) => s.copyWith(clearHostNotice: true));

  // ---------------------------------------------------------------------------
  // Taps out, through the outbox.
  // ---------------------------------------------------------------------------

  /// Sends [request] for [lane] now, or queues it as the latest behind the
  /// one in flight (replacing an older queued tap). A new tap supersedes an
  /// unsent or confirming one of its lane.
  Future<TapOutcome> _submit(
    OutboxLane lane,
    String key,
    StageRequest request,
  ) async {
    final box = _game.outbox;
    if (box.current(lane)?.leg == Leg.inFlight) {
      _setOutbox(
        box.withQueued(
          OutboxItem(
            id: ++_ids,
            lane: lane,
            key: key,
            request: request,
            leg: Leg.queued,
          ),
        ),
      );
      return const Queued();
    }
    final item = OutboxItem(
      id: ++_ids,
      lane: lane,
      key: key,
      request: request,
      leg: Leg.inFlight,
    );
    _setOutbox(box.withCurrent(item).withoutQueued(lane));
    return Answered(await _send(item));
  }

  Future<StageAnswer> _send(OutboxItem item) async {
    final reply = await _service.send(gameId, item.request);
    if (!ref.mounted) return reply.answer;
    final box = _game.outbox;
    if (box.current(item.lane)?.id != item.id) {
      // Its stage or turn ended while it was out: the answer changes nothing.
      _next(item.lane);
      return reply.answer;
    }
    switch (reply.answer) {
      case ChooseAnswer.taken:
        _setOutbox(box.withCurrent(_confirming(item)));
        // After ANY taken choose the phone reads `/me/` and trusts its
        // `chosen` and `chooses_left` (contract, third amendment): the same
        // on the wire for every role, and how the Doppelganger's follow-up
        // turn arrives. A ready or a pick whose echo differs fetches too.
        if (item.lane == OutboxLane.choose ||
            _echoDiffers(item.request, reply.body)) {
          unawaited(refresh());
        }
      case ChooseAnswer.stale:
        // Shown until the fetch lands, so the tap does not flicker off first.
        _setOutbox(box.withCurrent(_confirming(item)));
        unawaited(refresh());
      case ChooseAnswer.refused:
        _setOutbox(box.withoutCurrent(item.lane));
      case ChooseAnswer.notSent:
        _setOutbox(box.withCurrent(item.copyWith(leg: Leg.unsent)));
        // The ack has no "Try again": it is sent again by itself.
        if (item.lane == OutboxLane.ack) {
          _ackTimer?.cancel();
          _ackTimer = Timer(
            _timing.retryAfter(_failedAcks++),
            () => unawaited(retry(OutboxLane.ack)),
          );
        }
    }
    if (item.request case AckRequest(
      :final seen,
    ) when reply.answer == ChooseAnswer.taken) {
      _acked = math.max(_acked ?? 0, seen);
      _failedAcks = 0;
    }
    _next(item.lane);
    return reply.answer;
  }

  OutboxItem _confirming(OutboxItem item) =>
      item.copyWith(leg: Leg.confirming, confirmAfter: _sentFetches + 1);

  /// The queued tap of [lane] goes out once nothing of its lane is in
  /// flight; one asking for what was just confirmed is not sent again.
  void _next(OutboxLane lane) {
    if (!ref.mounted || state.value == null) return;
    final box = _game.outbox;
    final queued = box.queued(lane);
    final current = box.current(lane);
    if (queued == null || current?.leg == Leg.inFlight) return;
    if (current?.leg == Leg.confirming && current!.request == queued.request) {
      _setOutbox(box.withoutQueued(lane));
      return;
    }
    final item = queued.copyWith(leg: Leg.inFlight);
    _setOutbox(box.withCurrent(item).withoutQueued(lane));
    unawaited(_send(item));
  }

  static bool _echoDiffers(StageRequest request, Map<String, dynamic>? body) =>
      switch (request) {
        ReadyRequest(:final ready) =>
          body != null && body.containsKey('ready') && body['ready'] != ready,
        VoteRequest(:final targetId) =>
          body != null &&
              body.containsKey('target_player_id') &&
              body['target_player_id'] != targetId,
        _ => false,
      };

  /// Whether `/me/` [server] shows [request] already stored.
  static bool _landed(StageRequest request, GameMe server) => switch (request) {
    ChooseRequest(:final stage, :final chosen) =>
      server.prompt?.stage == stage && server.prompt!.chosen > chosen,
    ReadyRequest(:final ready) => server.ready == ready,
    VoteRequest(:final targetId, :final lock) =>
      server.myVote == MyVote.local(targetId, locked: lock),
    AckRequest(:final seen) => server.nightResultsSeen >= seen,
  };

  /// "Try again" for [lane]: `/me/` first; if it shows the lost request
  /// stored, it landed and nothing is sent; otherwise the ORIGINAL request
  /// goes again, unchanged. An unsent tap of an ended stage is gone.
  Future<TapOutcome> retry(OutboxLane lane) async {
    final item = state.value?.outbox.current(lane);
    if (item == null || item.leg != Leg.unsent) {
      return const Declined(DeclineReason.nothingToRetry);
    }
    await refresh();
    if (!ref.mounted || state.value == null) {
      return const Declined(DeclineReason.nothingToRetry);
    }
    final now = _game.outbox.current(lane);
    if (now?.id != item.id || now!.leg != Leg.unsent) {
      return const Declined(DeclineReason.notThisStage);
    }
    if (_landed(item.request, _game.server)) {
      _setOutbox(_game.outbox.withCurrent(_confirming(item)));
      return const Landed();
    }
    final again = item.copyWith(leg: Leg.inFlight);
    _setOutbox(_game.outbox.withCurrent(again));
    return Answered(await _send(again));
  }

  /// The night board's Choose ([NightBoard.onChoose]; give it
  /// `TapOutcome.forBoard`): sends [picks] for the prompt of [stage], once
  /// per turn. A second press while that choose is out or chosen is
  /// declined; after a lost answer it is the board's "Try again".
  Future<TapOutcome> choose(String stage, List<NightPick> picks) async {
    final server = _game.server;
    final prompt = server.prompt;
    if (prompt == null || prompt.stage != stage) {
      unawaited(refresh());
      return const Declined(DeclineReason.notThisStage);
    }
    final key = laneKey(OutboxLane.choose, server)!;
    final current = _game.outbox.current(OutboxLane.choose);
    if (current != null && current.key == key) {
      return current.leg == Leg.unsent
          ? retry(OutboxLane.choose)
          : const Declined(DeclineReason.alreadyChosen);
    }
    if (prompt.used) return const Declined(DeclineReason.alreadyChosen);
    return _submit(OutboxLane.choose, key, ChooseRequest.of(prompt, picks));
  }

  /// 04's "Ready" (true only: looking is one way) and 08's "Ready to vote"
  /// (a toggle; taps in a row go out in order, the latest last).
  Future<TapOutcome> setReady(bool ready) async {
    final server = _game.server;
    final stage = server.stage;
    if (stage == null || server.ready == null) {
      return const Declined(DeclineReason.notThisStage);
    }
    if (server.inLook && !ready) {
      return const Declined(DeclineReason.lookIsFinal);
    }
    if (_game.me.ready == ready) return const Declined(DeclineReason.unchanged);
    return _submit(OutboxLane.ready, stage, ReadyRequest(stage, ready: ready));
  }

  /// 09: a tap on a row picks it (nobody else hears of it).
  Future<TapOutcome> pickVote(int targetId) => _vote(targetId, lock: false);

  /// 09: "Lock in {name}": final, after any pick still on its way.
  Future<TapOutcome> lockVote(int targetId) => _vote(targetId, lock: true);

  Future<TapOutcome> _vote(int targetId, {required bool lock}) async {
    final server = _game.server;
    final stage = server.stage;
    if (server.phase != GamePhase.voting || stage == null) {
      return const Declined(DeclineReason.notThisStage);
    }
    if (_game.me.myVote?.locked ?? false) {
      return const Declined(DeclineReason.locked);
    }
    return _submit(
      OutboxLane.vote,
      stage,
      VoteRequest(stage, targetId: targetId, lock: lock),
    );
  }

  /// My night held for the first time this game: acknowledge every night
  /// result `/me/` lists. Every phone sends it once, results or not; whether
  /// it is done is read from `/me/` (`night_results_seen`), so a restart does
  /// not send it again once the server has it. A lost one is sent again by
  /// itself, with backoff.
  Future<TapOutcome> acknowledgeNightResults() async {
    final server = _game.server;
    final count = server.nightResultCount;
    final shown = _game.outbox.shown(OutboxLane.ack)?.request;
    final done =
        (count > 0 && server.nightResultsSeen >= count) ||
        (_acked != null && _acked! >= count) ||
        (shown is AckRequest && shown.seen >= count);
    if (done) return const Declined(DeclineReason.unchanged);
    return _submit(OutboxLane.ack, gameId, AckRequest(count));
  }

  /// Host, at the results: the table goes back to waiting. Errors reach the
  /// caller.
  Future<void> playAgain() async {
    await ref.read(lobbyServiceProvider).playAgain(_game.server.lobbyCode);
    _invalidateTable();
  }

  /// Leaves the table this game was played at.
  Future<void> leaveTable() async {
    await ref.read(lobbyServiceProvider).leaveLobby(_game.server.lobbyCode);
    _invalidateTable();
  }
}
