part of 'lobby_notifier.dart';

/// What the host's phone sends from the lobby: the half of [LobbyNotifier]
/// that goes out (the setting taps on the settings lane, "Try again", the
/// deal, leaving). The other half, in lobby_notifier.dart, is what comes in:
/// the reads, the socket, the host moving. One class in two files, so each
/// can be read whole.
mixin _LobbyTaps on _$LobbyNotifier {
  // What this half uses of the other, defined in [LobbyNotifier].
  abstract SettingsLane _lane;
  void _show(LobbyState server);
  LobbyState _adopt(LobbyState fresh);
  Future<T> _hostAction<T>(Future<T> Function() call);
  void _applyStartedGame(String id);
  Future<void> refreshLobby();

  /// The settings lane's requests, one after another: each change's send
  /// runs when the one before it is done.
  Future<void> _settingsQueue = Future.value();

  /// The host picks a deck chip: the server builds that deck at the deal.
  Future<void> chooseChip(DeckChip chip) =>
      _changeSettings(LobbyService.deckChip(chip));

  /// The host's own card list (the server's `deal` says whether it fits).
  Future<void> useCustomDeck(Map<String, int> roles) =>
      _changeSettings(LobbyService.customDeck(roles));

  /// The host sets how many players the game is for (3 to 10), or opens the
  /// table to whoever comes (null; offered only with an automatic deck, so a
  /// deck of the host's own is never quietly dropped).
  Future<void> setSeats(int? seats) => _changeSettings({'seats': seats});

  /// The host starts a custom deck from [roles] (the deck shown), for
  /// [seats] players when the table is open (a custom deck is built for a
  /// number).
  Future<void> startCustomDeck(Map<String, int> roles, {int? seats}) =>
      _changeSettings({...LobbyService.customDeck(roles), 'seats': ?seats});

  /// One tap on the grid: the custom deck as it now stands, stored at once
  /// (the server's `deal` says whether it fits).
  Future<void> setRoles(Map<String, int> roles) =>
      _changeSettings({'roles': roles});

  /// One length on the set-up page (a settings key, in seconds).
  Future<void> setLength(String key, int seconds) =>
      _changeSettings({key: seconds});

  /// The host's hold on 03's word "Players", the hidden switch: practice
  /// players on for this table; once on, with none seated, off again (the row
  /// goes). With some seated a hold does nothing: they are taken away one by
  /// one with the minus, so a thumb resting on the word never removes
  /// everyone.
  Future<void> togglePractice() {
    final lobby = state.value;
    if (lobby == null) return Future.value();
    if (!lobby.practiceOn) {
      return _change((n) => PracticeChange(const PracticeAsk(on: true), n));
    }
    if (lobby.practiceCount > 0) return Future.value();
    return _change((n) => PracticeChange(const PracticeAsk(on: false), n));
  }

  /// How many practice players sit at the table (03's Practice stepper).
  Future<void> setPracticeCount(int count) =>
      _change((n) => PracticeChange(PracticeAsk(count: count), n));

  /// Sends [patch] on the settings lane ([_change]).
  Future<void> _changeSettings(Map<String, Object?> patch) =>
      _change((n) => SettingsChange(patch, n));

  /// Shows a change at once (over the server's lobby, with every change
  /// before it) and sends it after them, one at a time, in the order tapped.
  /// The answer is the server's lobby; a refusal drops it and reads the lobby
  /// again (nothing to send again); no answer says "Not sent." with "Try
  /// again" ([_resendUnsent]). [make] takes the change's number.
  Future<void> _change(LaneChange Function(int number) make) {
    final lobby = state.value;
    if (lobby == null) return Future.value();
    final (lane, _) = _lane.ask(make);
    _lane = lane;
    _show(lobby.copyWith(notSent: _lane.notSent));
    return _settingsQueue = _settingsQueue.then((_) => _send());
  }

  /// Sends the lane's next change: its turn has come (the one before it is
  /// done, and after a refusal or a loss the lobby read too).
  Future<void> _send() async {
    // The table was left while this waited its turn: nothing to send.
    if (!ref.mounted) return;
    final (lane, change) = _lane.sendNext();
    if (change == null) return;
    _lane = lane;
    final service = ref.read(lobbyServiceProvider);
    try {
      final answer = await _hostAction(
        () => playerRequest(
          (door) => switch (change) {
            SettingsChange(:final patch) => service.patchSettings(
              door,
              code,
              patch,
            ),
            PracticeChange(:final ask) => service.setPractice(
              door,
              code,
              on: ask.on,
              count: ask.count,
            ),
          },
        ),
      );
      if (!ref.mounted) return;
      _lane = _lane.settle();
      // The answer is the server's lobby with this change; what is still on
      // its way goes over it.
      _show(_adopt(answer));
    } on NoLongerHostException {
      // The role moved: the lobby was read again and this phone is a guest
      // now, which its screen shows with no words.
      _lane = _lane.settle();
      if (ref.mounted) await refreshLobby();
    } catch (e) {
      if (!ref.mounted) return;
      if (serverAnswered(e)) {
        // An answer, not a loss: the server refused this change (the table
        // moved under it: someone joined, another length changed first, the
        // seats filled). It is dropped and the lobby read again.
        _lane = _lane.settle();
        logger.d('Change refused ($e)');
        await refreshLobby();
        return;
      }
      logger.d('Change not sent ($e)');
      _lane = _lane.lose();
      final now = state.value;
      if (now != null) {
        state = AsyncData(_lane.over(now).copyWith(notSent: _lane.notSent));
      }
      await refreshLobby();
    }
  }

  /// "Try again" for changes not sent: each sent again with only the keys no
  /// newer change has asked for since ([SettingsLane.takeResend]), so a
  /// newer value on the same key, answered or on its way, is never undone; a
  /// change with nothing left is not sent.
  Future<void> _resendUnsent() async {
    final (lane, again) = _lane.takeResend();
    _lane = lane;
    Future<void> last = Future.value();
    for (final make in again) {
      last = _change(make);
    }
    await last;
  }

  /// "Try again" after "Not sent.": the change (or the deal) that failed.
  Future<void> retry() async {
    final (lane, again) = _lane.takeRetry();
    _lane = lane;
    final now = state.value;
    if (now != null) {
      state = AsyncData(
        now.copyWith(notSent: _lane.notSent, dealRefused: null),
      );
    }
    switch (again) {
      case TryAgain.resend:
        await _resendUnsent();
      case TryAgain.deal:
        await deal();
      case null:
        break;
    }
  }

  /// Deals (host only): the game id, or null when the deal did not happen.
  /// No answer: "Not sent." with "Try again". A refusal: why, in the
  /// player's words ([LobbyNotifier.dealRefusal]), never a bare "Not
  /// sent.". A host role that moved meanwhile says nothing: the screen is a
  /// guest's now.
  Future<String?> deal() async {
    final before = state.value;
    if (before != null && before.dealRefused != null) {
      state = AsyncData(before.copyWith(dealRefused: null));
    }
    try {
      final id = await startGame();
      _lane = _lane.dealTaken();
      // The deal worked. 02's Deal stays busy (the caller's busy lasts as
      // long as this call) until `/me/table/` names the next screen, so the
      // button is never live again in the gap between the answer and the
      // dusk. (`startGame` has made the table's game known, which has the
      // table read again; a phone that listens to no table, or a read that
      // is not wanted, waits for nothing.)
      // A read that is failing frees the button all the same (the screen
      // says "One moment" over the table while it is).
      if (ref.mounted && ref.exists(myTableProvider)) {
        await readAnswered(ref, myTableProvider);
      }
      return id;
    } on NoLongerHostException {
      return null;
    } catch (e) {
      if (!ref.mounted) return null;
      final now = state.value;
      final refusal = LobbyNotifier.dealRefusal(e);
      _lane = refusal.answered ? _lane.dealRefused() : _lane.dealLost();
      if (now != null) {
        state = AsyncData(
          now.copyWith(notSent: _lane.notSent, dealRefused: refusal.why),
        );
      }
      // The table's new verdict sets the button (the screen keeps it busy
      // until it is read).
      if (refusal.answered) await refreshLobby();
      return null;
    }
  }

  /// Starts the game (host only).
  ///
  /// Returns the game ID on success.
  Future<String> startGame() async {
    try {
      final service = ref.read(lobbyServiceProvider);
      final id = await _hostAction(
        () => playerRequest((door) => service.startGame(door, code)),
      );
      // The host does not have to wait for the lobby event to open the game.
      if (ref.mounted) _applyStartedGame(id);
      return id;
    } catch (e, stack) {
      logger.e('Error starting game', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Leaves the table. Done when the server says so, and also when it says
  /// this phone is not at the table (an earlier tap reached it: a slow answer
  /// and "Try again", a second tap) or that the table is gone (the last one
  /// out closed it). With no answer at all, where the server says this phone
  /// sits decides: off this table is done. Throws [LeaveRefused] with the
  /// words to show for a refusal (the table started playing), and the error
  /// only when this phone is still at the table and the server could not be
  /// asked ("Not sent.").
  Future<void> leave() async {
    final service = ref.read(lobbyServiceProvider);
    try {
      await playerRequest((door) => service.leaveLobby(door, code));
    } catch (e) {
      // Already off the table: an earlier leave got there, or the table is
      // gone (the last one out closed it).
      if (e is NotFoundException ||
          (e is ValidationException && e.code == _notAMember)) {
        return;
      }
      if (serverAnswered(e)) {
        logger.w('Leave refused: $e');
        throw LeaveRefused(
          e is UnhandledHttpException && e.statusCode == 409
              ? BannerCopy.lobbyClosed
              : BannerCopy.cannotLeave,
        );
      }
      // No answer: did it get there anyway? The server says where we sit.
      logger.w('Leave not answered: $e');
      final where = await service.fetchMyTable();
      if (where?.lobbyCode != code) return;
      rethrow;
    }
  }

  /// The server's code for a leave from a table this player is not at.
  static const _notAMember = 'not_in_lobby';
}
