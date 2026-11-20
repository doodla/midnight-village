import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/host/host_change.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/websocket/websocket_channel.dart';
import '../../../design_system/night/night_pick.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../lobby/presentation/lobby_notifier.dart';
import '../../lobby/presentation/where_am_i_provider.dart';
import '../data/game_service.dart';
import '../domain/game_event.dart';
import '../domain/game_me.dart';
import '../domain/game_outcome.dart';
import '../domain/screen_table.dart';
import 'game_notifier.dart'
    show gameConnectionStateProvider, gameWebSocketStreamProvider;

part 'protocol_two_game.g.dart';

/// How long after a stage's deadline this phone asks `/me/` again when it
/// has heard nothing (a close event it missed). From the spec's "Drops and
/// missed closes" table; it never delays what a player sees: the screen
/// moves the moment the server's event or answer arrives.
const missedCloseGrace = Duration(seconds: 2);

/// A request whose answer never came: its state stays as tapped, and the
/// screen offers "Try again" ([ProtocolTwoGameNotifier.retry]). The night
/// board keeps its own (`ChooseAnswer.notSent`).
enum UnsentRequest { ready, pick, lock }

/// A night protocol 2 game as this phone holds it: the server's last `/me/`
/// with what this phone has tapped since laid over it, and the results once
/// the game is over.
@immutable
class ProtocolTwoGame {
  const ProtocolTwoGame._({
    required this.server,
    required this.overlay,
    this.outcome,
    this.presence = const {},
    this.hostNotice,
    this.unsent,
    this.countSeen = false,
    this.tableClosed = false,
  });

  /// The last `/me/` the server sent.
  final GameMe server;

  final Overlay overlay;

  /// `GET .../results/`, fetched once the game is in the results.
  final GameOutcome? outcome;

  /// Who has a phone connected (public), from `player_presence`.
  final Map<int, bool> presence;

  /// The latest host change, for the quiet line about it.
  final HostChange? hostNotice;

  /// A request that may not have arrived.
  final UnsentRequest? unsent;

  /// "See who won" was tapped (10 -> 11). Local; lost on a restart.
  final bool countSeen;

  /// The game (its table) is gone.
  final bool tableClosed;

  /// What the screens show: the server's `/me/` with this phone's taps on it
  /// (see [Overlay]). Everything the rest of the table can see on this phone
  /// changes on the tap, never on the answer.
  GameMe get me => overlay.on(server);

  /// The screen for this game, given where `/me/table/` says the player is.
  AppScreen screenAt(TableView table) => screenFor(
    table,
    me: me,
    local: LocalSteps(countSeen: countSeen),
  );

  ProtocolTwoGame copyWith({
    GameMe? server,
    Overlay? overlay,
    GameOutcome? outcome,
    Map<int, bool>? presence,
    HostChange? hostNotice,
    UnsentRequest? unsent,
    bool clearUnsent = false,
    bool? countSeen,
    bool? tableClosed,
  }) => ProtocolTwoGame._(
    server: server ?? this.server,
    overlay: (overlay ?? this.overlay).forStage((server ?? this.server).stage),
    outcome: outcome ?? this.outcome,
    presence: presence ?? this.presence,
    hostNotice: hostNotice ?? this.hostNotice,
    unsent: clearUnsent ? null : unsent ?? this.unsent,
    countSeen: countSeen ?? this.countSeen,
    tableClosed: tableClosed ?? this.tableClosed,
  );
}

/// This phone's taps the server may not have answered yet (or answered
/// before a fetch that left earlier came back), laid over `/me/`. Each is
/// for one stage: a new stage drops them (the new `/me/` is the truth).
@immutable
class Overlay {
  const Overlay({
    this.stage,
    this.chosen = false,
    this.ready,
    this.vote,
    this.seen,
  });

  static const empty = Overlay();

  /// The stage the taps were made in.
  final String? stage;

  /// This turn's choose was sent.
  final bool chosen;
  final bool? ready;
  final MyVote? vote;

  /// Night results acknowledged (not stage-bound: the count only goes up).
  final int? seen;

  /// The overlay for a `/me/` in [next]: the taps of another stage are gone.
  Overlay forStage(String? next) =>
      next == stage ? this : Overlay(stage: next, seen: seen);

  GameMe on(GameMe me) {
    var shown = me;
    if (seen != null) shown = shown.withSeen(seen!);
    if (stage != me.stage) return shown;
    if (chosen) shown = shown.withChosen();
    if (ready != null) shown = shown.withReady(ready!);
    if (vote != null) shown = shown.withVote(vote!);
    return shown;
  }

  Overlay copyWith({
    bool? chosen,
    bool? ready,
    bool clearReady = false,
    MyVote? vote,
    bool clearVote = false,
    int? seen,
    bool clearSeen = false,
  }) => Overlay(
    stage: stage,
    chosen: chosen ?? this.chosen,
    ready: clearReady ? null : ready ?? this.ready,
    vote: clearVote ? null : vote ?? this.vote,
    seen: clearSeen ? null : seen ?? this.seen,
  );
}

/// A night protocol 2 game for the rebuilt screens, keyed by game id (the
/// old screens keep [GameNotifier] on protocol 1).
///
/// The one rule: the screen is a function of fetched state. Socket events
/// only ask for `/me/` again or update a value `/me/` holds in the same form
/// ([GameEvent]); a missed event is healed by the next fetch (reconnect, the
/// stage's deadline, the next event), so events in any order, repeated or
/// dropped, then a fetch, end in the same state as a cold start.
@riverpod
class ProtocolTwoGameNotifier extends _$ProtocolTwoGameNotifier {
  StreamSubscription<dynamic>? _events;
  Timer? _deadlineTimer;
  String? _deadlineKey;
  bool _wasDisconnected = false;

  /// True while a fetch of `/me/` is in flight: an event meanwhile asks for
  /// one more fetch after it, so an older snapshot never has the last word.
  bool _fetching = false;
  bool _fetchAgain = false;
  Future<void>? _refreshing;

  /// Which vote tap is the latest: an answer to an older one changes nothing.
  int _voteTaps = 0;
  Future<void> Function()? _retry;

  GameService get _service => ref.read(gameServiceProvider);

  @override
  Future<ProtocolTwoGame> build(String gameId) async {
    ref.onDispose(() {
      _events?.cancel();
      _deadlineTimer?.cancel();
    });
    // Listen first, so nothing said while the first fetch is out is missed.
    _events = ref
        .read(gameWebSocketStreamProvider(gameId))
        ?.listen(
          _onMessage,
          onError: (Object e) => logger.w('ProtocolTwoGame: socket', error: e),
        );
    // Closed with the provider.
    ref.listen(
      gameConnectionStateProvider(gameId),
      (_, next) => _onConnection(next.value),
    );
    _fetching = true;
    try {
      final me = await _service.fetchMe(gameId);
      final first = ProtocolTwoGame._(
        server: me,
        overlay: Overlay(stage: me.stage),
        outcome: await _outcomeFor(me, null),
      );
      _afterFetch(first);
      return first;
    } finally {
      _fetching = false;
      if (_fetchAgain) {
        // After the state is set (the event loop's next turn), not before.
        _fetchAgain = false;
        Timer.run(() => unawaited(refresh()));
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Server state in
  // ---------------------------------------------------------------------------

  /// Fetches `/me/` (and the results, once over). Calls made while one is
  /// out run once more after it.
  Future<void> refresh() {
    if (!ref.mounted || state.value == null) {
      _fetchAgain = _fetchAgain || _fetching;
      return Future.value();
    }
    final running = _refreshing;
    if (running != null) {
      _fetchAgain = true;
      return running;
    }
    return _refreshing = _refreshLoop().whenComplete(() => _refreshing = null);
  }

  Future<void> _refreshLoop() async {
    do {
      _fetchAgain = false;
      await _fetchOnce();
    } while (_fetchAgain && ref.mounted);
  }

  Future<void> _fetchOnce() async {
    _fetching = true;
    try {
      final me = await _service.fetchMe(gameId);
      if (!ref.mounted) return;
      final outcome = await _outcomeFor(me, state.value?.outcome);
      if (!ref.mounted) return;
      final next = state.requireValue.copyWith(server: me, outcome: outcome);
      state = AsyncData(next);
      _afterFetch(next);
    } on NotFoundException {
      _update((s) => s.copyWith(tableClosed: true));
    } catch (e) {
      logger.w('ProtocolTwoGame: fetch failed', error: e);
    } finally {
      _fetching = false;
    }
  }

  Future<GameOutcome?> _outcomeFor(GameMe me, GameOutcome? known) async {
    if (me.phase != GamePhase.results || known != null) return known;
    try {
      return await _service.fetchOutcome(gameId);
    } catch (e) {
      logger.w('ProtocolTwoGame: results not fetched', error: e);
      return null;
    }
  }

  /// Arms one fetch [missedCloseGrace] after the stage's deadline, once per
  /// stage and deadline: a close this phone did not hear about still moves
  /// it on. The countdown itself is read from the deadline by the screen.
  void _afterFetch(ProtocolTwoGame game) {
    final deadline = game.server.deadline;
    final key = '${game.server.stage}@$deadline';
    if (deadline == null || key == _deadlineKey) return;
    _deadlineKey = key;
    _deadlineTimer?.cancel();
    final now = ref.read(clockProvider)();
    final wait = deadline.add(missedCloseGrace).difference(now);
    _deadlineTimer = Timer(wait.isNegative ? Duration.zero : wait, refresh);
  }

  void _onConnection(WebSocketConnectionState? connection) {
    switch (connection) {
      case WebSocketConnectionState.connected when _wasDisconnected:
        _wasDisconnected = false;
        unawaited(refresh());
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
      // The first fetch is out: it may predate this, so fetch once more.
      if (event is! IgnoredEvent) _fetchAgain = true;
      return;
    }
    switch (event) {
      case ProgressEvent(:final progress):
        final current = state.requireValue.server;
        if (_fetching || current.progress?.stage != progress.stage) {
          unawaited(refresh());
        } else {
          _update((s) => s.copyWith(server: current.withProgress(progress)));
        }
      case PresenceEvent(:final playerId, :final connected):
        _update(
          (s) => s.copyWith(presence: {...s.presence, playerId: connected}),
        );
      case HostEvent(:final change):
        final viewer = _viewerId();
        _update(
          (s) => s.copyWith(
            server: s.server.withHost(
              change.hostId,
              isHost: viewer == null
                  ? s.server.isHost
                  : viewer == change.hostId,
            ),
            hostNotice: change,
          ),
        );
        if (_fetching) unawaited(refresh());
      case RefetchEvent():
        unawaited(refresh());
      case TableMovedEvent():
        ref.invalidate(myTableProvider);
        unawaited(refresh());
      case IgnoredEvent():
    }
  }

  int? _viewerId() {
    final auth = ref.read(authProvider);
    return auth is AuthAuthenticated ? auth.user.id : null;
  }

  void _update(ProtocolTwoGame Function(ProtocolTwoGame) change) {
    final current = state.value;
    if (current != null && ref.mounted) state = AsyncData(change(current));
  }

  ProtocolTwoGame get _game => state.requireValue;

  // ---------------------------------------------------------------------------
  // Taps out. Each shows its result at once; the answer only ever undoes it
  // (refused), fetches (stale) or offers "Try again" (not sent).
  // ---------------------------------------------------------------------------

  /// The night board's Choose ([NightBoard.onChoose]): sends [picks] for the
  /// prompt of [stage]. The board shows "Chosen" itself; this keeps the
  /// prompt chosen across fetches until the answer says otherwise.
  Future<ChooseAnswer> choose(String stage, List<NightPick> picks) async {
    final prompt = _game.server.prompt;
    if (prompt == null || prompt.stage != stage || prompt.used) {
      // The window moved on, or the server has this turn already.
      unawaited(refresh());
      return ChooseAnswer.stale;
    }
    _update((s) => s.copyWith(overlay: s.overlay.copyWith(chosen: true)));
    final answer = await _service.choose(
      gameId,
      ChooseRequest.of(prompt, picks),
    );
    if (!ref.mounted) return answer;
    switch (answer) {
      case ChooseAnswer.taken || ChooseAnswer.notSent:
        break;
      case ChooseAnswer.stale:
        unawaited(refresh());
      case ChooseAnswer.refused:
        if (_game.overlay.stage == stage) {
          _update(
            (s) => s.copyWith(overlay: s.overlay.copyWith(chosen: false)),
          );
        }
    }
    return answer;
  }

  /// 04's "Ready" (`true` only: looking is one way) and 08's "Ready to vote"
  /// (a toggle). The button and its tick change on the tap.
  Future<StageAnswer> setReady(bool ready) async {
    final me = _game.me;
    final stage = me.stage;
    if (stage == null || me.ready == null) return ChooseAnswer.stale;
    if (me.inLook && !ready) return ChooseAnswer.refused;
    _update(
      (s) => s.copyWith(
        overlay: s.overlay.copyWith(ready: ready),
        clearUnsent: true,
      ),
    );
    final answer = await _service.setReady(gameId, stage: stage, ready: ready);
    _settle(
      answer,
      stage: stage,
      kind: UnsentRequest.ready,
      undo: (o) => o.copyWith(clearReady: true),
      retry: () => setReady(ready),
    );
    return answer;
  }

  /// 09: a tap on a row picks it (nobody else hears of it); it can change
  /// until locked.
  Future<StageAnswer> pickVote(int targetId) =>
      _vote(targetId, lock: false, kind: UnsentRequest.pick);

  /// 09: "Lock in {name}": final. It carries the target, so a lost pick can
  /// never lock the wrong name.
  Future<StageAnswer> lockVote(int targetId) =>
      _vote(targetId, lock: true, kind: UnsentRequest.lock);

  Future<StageAnswer> _vote(
    int targetId, {
    required bool lock,
    required UnsentRequest kind,
  }) async {
    final me = _game.me;
    final stage = me.stage;
    if (me.phase != GamePhase.voting || stage == null) {
      return ChooseAnswer.stale;
    }
    if (me.myVote?.locked ?? false) return ChooseAnswer.stale;
    final tap = ++_voteTaps;
    _update(
      (s) => s.copyWith(
        overlay: s.overlay.copyWith(vote: MyVote.local(targetId, locked: lock)),
        clearUnsent: true,
      ),
    );
    final answer = await _service.vote(
      gameId,
      stage: stage,
      targetId: targetId,
      lock: lock,
    );
    if (tap == _voteTaps) {
      _settle(
        answer,
        stage: stage,
        kind: kind,
        undo: (o) => o.copyWith(clearVote: true),
        retry: () => _vote(targetId, lock: lock, kind: kind),
      );
    }
    return answer;
  }

  void _settle(
    StageAnswer answer, {
    required String stage,
    required UnsentRequest kind,
    required Overlay Function(Overlay) undo,
    required Future<void> Function() retry,
  }) {
    if (!ref.mounted) return;
    switch (answer) {
      case ChooseAnswer.taken:
        break;
      case ChooseAnswer.stale:
        if (_game.overlay.stage == stage) {
          _update((s) => s.copyWith(overlay: undo(s.overlay)));
        }
        unawaited(refresh());
      case ChooseAnswer.refused:
        if (_game.overlay.stage == stage) {
          _update((s) => s.copyWith(overlay: undo(s.overlay)));
        }
      case ChooseAnswer.notSent:
        _retry = retry;
        _update((s) => s.copyWith(unsent: kind));
    }
  }

  /// "Try again" after [ProtocolTwoGame.unsent].
  Future<void> retry() async {
    final again = _retry;
    _retry = null;
    _update((s) => s.copyWith(clearUnsent: true));
    if (again != null) await again();
  }

  /// My night has been held for the first time this game: acknowledge every
  /// night result `/me/` lists, so a restart does not offer them as new.
  /// Every phone sends it alike, results or not.
  Future<void> acknowledgeNightResults() async {
    final count = _game.me.nightResultCount;
    if (_game.overlay.seen == count) return; // sent already
    _update((s) => s.copyWith(overlay: s.overlay.copyWith(seen: count)));
    try {
      await _service.acknowledgeNightResults(gameId, count);
    } catch (e) {
      logger.w('ProtocolTwoGame: results ack not sent', error: e);
      if (ref.mounted) {
        _update(
          (s) => s.copyWith(overlay: s.overlay.copyWith(clearSeen: true)),
        );
      }
    }
  }

  /// 10 -> 11.
  void seeWhoWon() => _update((s) => s.copyWith(countSeen: true));

  /// Host, at the results: the table goes back to waiting (02 for everyone,
  /// by `/me/table/`). Errors reach the caller.
  Future<void> playAgain() async {
    await ref.read(lobbyServiceProvider).playAgain(_game.server.lobbyCode);
    ref.invalidate(myTableProvider);
  }

  /// Leaves the table this game was played at.
  Future<void> leaveTable() async {
    await ref.read(lobbyServiceProvider).leaveLobby(_game.server.lobbyCode);
    ref.invalidate(myTableProvider);
  }
}

/// The screen for game [gameId] (night protocol 2), from `/me/table/` and the
/// game's `/me/`: loading until both are in.
@riverpod
AsyncValue<AppScreen> protocolTwoScreen(Ref ref, String gameId) {
  final table = ref.watch(myTableProvider);
  final game = ref.watch(protocolTwoGameProvider(gameId));
  return switch ((table, game)) {
    (AsyncData(value: final t), AsyncData(value: final g)) => AsyncData(
      g.screenAt(TableView.fromMyTable(t)),
    ),
    (AsyncError(:final error, :final stackTrace), _) ||
    (
      _,
      AsyncError(:final error, :final stackTrace),
    ) => AsyncError(error, stackTrace),
    _ => const AsyncLoading(),
  };
}
