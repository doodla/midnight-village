part of 'live_game.dart';

/// The taps this phone sends, through the outbox: the half of
/// [LiveGameNotifier] that goes out (the other half, in live_game.dart, is
/// what comes in: fetches, events, healing). One class in two files, so each
/// can be read whole.
mixin _LiveGameTaps on _$LiveGameNotifier {
  // What this half uses of the other, defined in [LiveGameNotifier].
  GameService get _service;
  HealTiming get _timing;
  LiveGame get _game;
  bool get _named;
  void _update(LiveGame Function(LiveGame) change);
  void _setOutbox(Outbox outbox);
  Future<void> refresh();
  abstract Timer? _healTimer;
  abstract Timer? _retryTimer;
  abstract Timer? _ackTimer;
  abstract int _failedAcks;
  abstract int _sentFetches;
  abstract int _ids;
  abstract int? _acked;

  /// This phone's own play again is on its way: its answer seats the phone
  /// with the table's lobby ([playAgain]), so the `play_again` event that
  /// may come first reads `/me/table/` as before instead of seating it.
  bool _playingAgain = false;

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
    final reply = await playerRequest(
      (door) => _service.send(door, gameId, item.request),
    );
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
        // `chosen` and `chooses_left` (contract, section 5): the same
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

  /// Why a pick or a lock is declined right now (the vote is over, or this
  /// phone has locked), or null when it would be taken. Read on the tap, so
  /// a tap that is declined makes no tick and no knock.
  DeclineReason? get voteDeclined {
    final server = _game.server;
    if (server.phase != GamePhase.voting || server.stage == null) {
      return DeclineReason.notThisStage;
    }
    if (_game.me.myVote?.locked ?? false) return DeclineReason.locked;
    return null;
  }

  Future<TapOutcome> _vote(int targetId, {required bool lock}) async {
    final declined = voteDeclined;
    if (declined != null) return Declined(declined);
    final stage = _game.server.stage!;
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

  /// Host, at the results: the table goes back to waiting. A table that is
  /// gone (404) is closed, as a fetch answered 404 closes it; a refusal
  /// ([serverAnswered]) says why ([RequestRefused]), never "Not sent."; no
  /// answer reaches the caller as it is. The answer is the table's lobby,
  /// waiting, with this game still its newest: 02 shows it ([LobbySeed]) and
  /// `/me/table/` takes it ([seatFromServer]), so nothing is asked after the
  /// tap.
  Future<void> playAgain() => _atTable((door) async {
    final LobbyState lobby;
    _playingAgain = true;
    try {
      lobby = await ref
          .read(lobbyServiceProvider)
          .playAgain(door, _game.server.lobbyCode);
    } catch (e) {
      throw _refused(e, BannerCopy.cannotDeal) ?? e;
    } finally {
      _playingAgain = false;
    }
    if (!ref.mounted) return true;
    // Others may leave before 02's socket listens: read once more then.
    ref.read(lobbySeedProvider).put(lobby, settled: false);
    if (ref.read(authProvider) case AuthAuthenticated(:final user)) {
      final seat = MyTable.seatedAt(
        lobby,
        viewerId: user.id,
        game: (id: gameId, phase: GamePhase.results),
      );
      if (seat != null) {
        seatFromServer(ref, user.id, seat);
        return true;
      }
    }
    return false;
  });

  /// Leaves the table this game was played at (a table already gone: the
  /// same, with "This table has closed." on 01; a phone already off it
  /// counts as left, as at 02).
  Future<void> leaveTable() => _atTable((door) async {
    try {
      await ref
          .read(lobbyServiceProvider)
          .leaveLobby(door, _game.server.lobbyCode);
    } catch (e) {
      if (e is ValidationException && e.code == 'not_in_lobby') return false;
      throw _refused(e, BannerCopy.cannotLeave) ?? e;
    }
    return false;
  });

  /// [error] as the server's refusal with [words] to say (the table's 404
  /// is not one: the table is gone), or null when the phone does not know it
  /// got there.
  static RequestRefused? _refused(Object error, String words) =>
      error is! NotFoundException && serverAnswered(error)
      ? RequestRefused(words)
      : null;

  /// Runs a tap at the game's table. [call] says whether its answer already
  /// put the phone where it sits ([seatFromServer]); else `/me/table/` is
  /// read after it. Read again after a seat was put, it would be asked for
  /// all the same whenever the seat had been taken in between.
  Future<void> _atTable(Future<bool> Function(Door door) call) async {
    try {
      final seated = await playerRequest(call);
      // The tap worked. A screen that has already moved on (the server said
      // so first: this notifier went with it) has nothing left to read, and
      // is no failure.
      if (!ref.mounted || seated) return;
      ref.invalidate(myTableProvider);
    } on NotFoundException {
      if (ref.mounted) _tableGone(tapped: true);
    }
  }

  /// The game's table is gone (404): `/me/table/` is read again, 01
  /// follows (the table screen) and says why. For a game `/me/table/` does
  /// not name ([_named]) and no tap of this phone's: nothing (it stops).
  void _tableGone({bool tapped = false}) {
    if (!tapped && !_named) {
      _retryTimer?.cancel();
      _healTimer?.cancel();
      return;
    }
    ref.invalidate(myTableProvider);
    _update((s) => s.copyWith(tableClosed: true));
    ref.read(joinFlowProvider.notifier).tableClosed();
  }
}
