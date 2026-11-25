part of 'lobby_notifier.dart';

/// Where the lobby says this phone sits: the half of [LobbyNotifier] that
/// moves the phone on when the table does (the deal's answer or
/// `game_started` seats it in the game; a lobby ahead of the phone asks
/// `/me/table/`). Model: `docs/dev/models/phone/seat/`.
mixin _LobbySeat on _$LobbyNotifier {
  // What this half uses of the other, defined in [LobbyNotifier].
  LobbyState? get _current;
  Future<void> refreshLobby();

  /// The table status `/me/table/` was last asked again for, from a lobby
  /// that said the table had moved on ([_askWhereIfMoved]): once per change.
  String? _askedWhereAt;

  /// THE rule for a lobby that is ahead of this phone: the server says the
  /// table is in a game (or past one) and this phone knows no game of it
  /// (its `game_started` was missed: the socket was down, the phone asleep,
  /// the lobby opened after the deal). Where it sits is asked at once
  /// ([askWhere]; a read already out that says the table moved on answers
  /// it), once per change of the table's status, so a table this player
  /// joined while it played (no game of theirs to name) is not read again
  /// and again.
  void _askWhereIfMoved(LobbyState lobby) {
    if (lobby.status == 'waiting' || lobby.startedGameId != null) {
      _askedWhereAt = null;
      return;
    }
    if (_askedWhereAt == lobby.status) return;
    _askedWhereAt = lobby.status;
    // After the change that said so is applied (never inside a build).
    Timer.run(() {
      if (!ref.mounted) return;
      askWhere(
        ref,
        settledBy: (table) =>
            table == null || table.status != TableStatus.waiting,
      );
    });
  }

  /// Coming back to the app: the lobby is read again (and `/me/table/`,
  /// which listens to the resume itself).
  void _readOnResume() => ref.listen(appResumesProvider, (_, next) {
    if (next.hasValue) unawaited(refreshLobby());
  });

  /// A start this phone's table already names (a second word of the same
  /// deal, a late `game_started` for a game it is in or past) changes
  /// nothing: an event never moves the screen back (the model's `late`).
  bool _alreadyIn(String gameId) =>
      ref.exists(myTableProvider) &&
      ref.read(myTableProvider).value?.gameId == gameId;

  /// Puts this phone in the game [gameId] just started: the deal's answer or
  /// `game_started` is where it sits (a new deal is always at the night), so
  /// `/me/table/` takes that seat with no request ([seatFromServer]) and the
  /// dusk starts at once; the game's `/me/` fills it in. A seat from an
  /// event is built from this phone's own player list, which may be behind
  /// (it left): the game's socket opening reads `/me/table/` behind it, and
  /// a `/me/` refused (not a player) reads it too (`LiveGameNotifier`).
  void _seatIn(String gameId) {
    final lobby = _current;
    final viewer = switch (ref.read(authProvider)) {
      AuthAuthenticated(:final user) => user.id,
      _ => null,
    };
    final seat = lobby == null || viewer == null
        ? null
        : MyTable.seatedAt(
            lobby,
            viewerId: viewer,
            game: (id: gameId, phase: GamePhase.night),
          );
    if (viewer != null && seat != null) {
      seatFromServer(ref, viewer, seat);
    } else {
      askWhere(ref);
    }
  }
}
