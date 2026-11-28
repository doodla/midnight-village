part of 'live_game.dart';

/// What comes in on the game's socket: this phone's own view, the table's
/// events, the socket's own state, and the seat (`/me/table/`) kept with them:
/// the half of [LiveGameNotifier] that hears (the other halves, in
/// live_game.dart and live_game_taps.dart, read and send). One class in three
/// files, so each can be read whole.
mixin _LiveGameEvents on _$LiveGameNotifier, _LiveGameTaps {
  // What this half uses of the reading half, defined in [LiveGameNotifier]
  // (the sending half's, [_LiveGameTaps], it reaches as its own).
  Future<void>? get _loop;
  abstract bool _wasDisconnected;
  abstract String? _tableAskedAt;
  abstract String? _meAskedAt;
  void _set(LiveGame next);
  void _afterApply(GameMe me, {bool told});
  void _loadOutcomeSoon();
  void _invalidateTable();
  void _clearFetchFailure();
  bool _clockFromView(GameMe me);
  ValueNotifier<int> get clockMoved;

  /// A ready or a vote of this phone's is queued or out, so a count the
  /// table hears may or may not hold it yet.
  bool get _countOnItsWay {
    final box = _game.outbox;
    return [OutboxLane.ready, OutboxLane.vote].any(
      (lane) =>
          box.queued(lane) != null || box.current(lane)?.leg == Leg.inFlight,
    );
  }

  /// This phone's own view as a stage opens ([OwnViewEvent]): the server's
  /// `/me/` itself, so it is applied as a read would be, when it is of a later
  /// stage than the one held (else the held one is as new or newer: a read in
  /// the same stage was made after the stage opened). It answers whatever a
  /// failed read was being tried again for. At the end, the results come with
  /// the table's `game_results`, just after it, so none are asked for.
  void _acceptView(GameMe me) {
    final current = state.requireValue;
    if (me.gameId != gameId) return;
    if (_clockFromView(me)) clockMoved.value++;
    if (me.place <= current.server.place) return;
    _heldProgress = null;
    _viewsApplied++;
    _clearFetchFailure();
    _set(
      current.copyWith(
        server: me,
        outbox: current.outbox.afterFetch(me, 0),
        tableClosed: false,
        fetchFailing: false,
      ),
    );
    _afterApply(me, told: true);
    for (final lane in OutboxLane.values) {
      _next(lane);
    }
  }

  /// The beat's token says where the table is ([BeatEvent]). A frame lost on
  /// a socket that stays alive leaves this phone behind with nothing to heal
  /// it (no deadline at an untimed stage or at the end): the beat then reads
  /// once what it misses. Behind its stage: `/me/` (once per stage told); at
  /// the end without the results: the results; at the end of a table that
  /// moved on (play again, a new deal): where it sits now. The token is only
  /// ever behind the table's events, never ahead of them, so a phone that
  /// heard them reads nothing.
  int? _beatAskedAt;
  bool _beatMovedAsked = false;

  /// The app's resume reopened the socket ([ReconnectingWebSocket.verify]).
  bool _reopenedOnResume = false;
  void _beatSays(BeatEvent beat) {
    final at = beat.place;
    if (at == null || _loop != null) return; // an older server; a read is out
    final current = state.requireValue;
    final server = current.server;
    if (at > server.place) {
      if (_beatAskedAt == at) return;
      _beatAskedAt = at;
      unawaited(refresh());
      return;
    }
    if (beat.phase != GamePhase.results || server.phase != GamePhase.results) {
      return;
    }
    if (current.outcome == null) _loadOutcomeSoon();
    if (beat.movedOn && !_playingAgain && !_beatMovedAsked) {
      _beatMovedAsked = true;
      _invalidateTable();
    }
  }

  /// The table heard the game end: its results with it (`game_results`
  /// carries them), else, at the results with none, they are read.
  void _results(GameOutcome? results) {
    final current = state.requireValue;
    if (current.outcome != null) return;
    if (results != null) {
      _update((s) => s.copyWith(outcome: results, outcomeFailing: false));
    } else if (current.server.phase == GamePhase.results) {
      _loadOutcomeSoon();
    }
  }

  /// `/me/table/` and `/me/` agree on the game's phase. When the table is
  /// ahead, `/me/` is read again (once per mismatch). When `/me/` is ahead (a
  /// stage changed: the server said so), the table is where the game is now,
  /// and nothing is asked ([MyTable.inGameAt]: a game at its results is a
  /// finished table). Unless a read of the seat is out: it was asked because
  /// the seat may have moved on further (the app back, the socket back), so
  /// it is asked again now rather than dropped by a seat put from `/me/`
  /// (`docs/dev/models/phone/seat/`, run `seat_drop`).
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
      final viewer = _viewer;
      if (!_named || viewer == null) return;
      _tableAskedAt = at;
      if (ref.read(myTableProvider).isLoading) return askWhere(ref);
      seatFromServer(ref, viewer, table.inGameAt(own.phase));
    }
  }

  int? get _viewer => switch (ref.read(authProvider)) {
    AuthAuthenticated(:final user) => user.id,
    _ => null,
  };

  /// The socket opening or coming back, and resume: anything may have
  /// happened.
  void _healEverything({bool table = true}) {
    if (table) _invalidateTable();
    unawaited(refresh());
    final lost = state.value?.outbox.current(OutboxLane.ack);
    if (lost?.leg == Leg.unsent) unawaited(retry(OutboxLane.ack));
  }

  void _onConnection(WebSocketConnectionState? connection) {
    ref
        .read(socketHealthProvider)
        .report(
          SocketHealth.game(gameId),
          up: connection == WebSocketConnectionState.connected,
        );
    switch (connection) {
      case WebSocketConnectionState.connected when _wasDisconnected:
        _wasDisconnected = false;
        // Up for the first time too: nothing said before it listened was
        // heard. (After a seat from an event, this read confirms it.) Back
        // from a reopen the app's resume asked for: that resume reads the
        // table itself, so only `/me/` is read here.
        _healEverything(table: !_reopenedOnResume);
        _reopenedOnResume = false;
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
    // Play again says where this phone sits: back at the table, at once.
    if (event is TableMovedEvent && _seatBackAtTable()) return;
    if (state.value == null) {
      // The first fetch is out (or failed): it may predate this. (A beat as
      // the socket opens says nothing that read will not.)
      if (event is! IgnoredEvent && event is! BeatEvent) unawaited(refresh());
      return;
    }
    switch (event) {
      case OwnViewEvent(:final me):
        _acceptView(me);
      case BeatEvent():
        _beatSays(event);
      case ProgressEvent(:final progress):
        final current = state.requireValue.server;
        if (_loop != null || current.progress?.stage != progress.stage) {
          unawaited(refresh());
        } else if (_game.me.progress == current.progress) {
          // Nothing of this phone's own is counted on top: the count is
          // the server's, as it says.
          _update((s) => s.copyWith(server: current.withProgress(progress)));
        } else if (_countOnItsWay) {
          // This phone's own ready or lock is out: whether this count holds
          // it is not known yet. Its answer carries the count it made; the
          // two compared, nothing is read when they agree (its own event).
          _heldProgress = progress;
        } else {
          // Counted here on a tap the server's answer did not confirm.
          unawaited(refresh());
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
      case RefetchEvent(:final type, :final place, :final results):
        // Its own view came first, in the same batch: read only when this
        // phone is behind the stage the table hears of (an older server, or
        // the view lost). The seat is not asked: the table is where it was.
        if (state.requireValue.server.place < place) unawaited(refresh());
        if (type == 'game_results') _results(results);
      case TableMovedEvent() when _playingAgain:
        // This phone's own play again is out: its answer seats it. Should
        // it not come, the table is read then ([playAgain]).
        _movedWhilePlaying = true;
      case TableMovedEvent():
        _invalidateTable();
        unawaited(refresh());
      case IgnoredEvent():
    }
  }

  /// `play_again`: the table is waiting again, and `/me/table/` would say
  /// so (this game still its newest, at its results). That seat is put
  /// ([seatFromServer]: no read) and 02 follows from the event itself; its
  /// lobby is read as it opens. Only where play again comes from: the end
  /// board of this game (`/me/table/` names it, finished). Anywhere else
  /// this phone is behind (it missed the end: read, never guess), and while
  /// its own play again is out its answer seats it, with the lobby: false,
  /// and the table is read as for any event.
  bool _seatBackAtTable() {
    if (_playingAgain || !_named) return false;
    final table = ref.read(myTableProvider).value;
    if (table?.status != TableStatus.finished) return false;
    final viewer = _viewer;
    if (table == null || viewer == null) return false;
    seatFromServer(ref, viewer, table.backToWaiting());
    return true;
  }
}
