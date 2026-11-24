import 'lobby_state.dart';

/// The host's settings lane (settings and practice in ONE queue) as a value:
/// what is asked and not answered, the one change out, the changes that got
/// no answer, a refused value still on screen, the deal that goes behind
/// them, and the revision of the newest server lobby shown. Every transition
/// returns a new lane (and what to send); the requests, the `Future` chain
/// that runs them one after another, the lobby reads and the socket are
/// `LobbyNotifier`'s (`lobby_taps.dart`).
///
/// The rules are the model's (`docs/dev/models/phone/lobby/`,
/// `PhoneLobby.tla`):
/// - one out at a time, the oldest first ([sendNext]); every tap is sent
///   (`NeverOlder`);
/// - a server lobby older than the newest shown is never shown ([admit]: the
///   server's `rev`; equal is shown; a lobby with no `rev` is shown), so a
///   read, an answer or a `lobby_update` that crossed a newer one never
///   shows an older value (`NoFlickerBack`);
/// - the screen is the server's lobby with every change still to go over it,
///   the newest ask winning on each key ([over]): the pending changes, the
///   lost changes "Try again" or Deal would still send (so the screen shows
///   what will go), and a refused value until the next server lobby;
/// - "Not sent." is derived ([notSent]): it shows exactly while a lost change
///   would still be sent by "Try again" (a key no newer change asked for), or
///   the deal did not go; a newer tap on another key cannot take it away
///   (`LostFlagged`, `NoHiddenResend`);
/// - "Try again" sends every lost change again, trimmed to the keys no newer
///   change asked for, oldest first ([takeResend]), and then a deal that did
///   not go, behind them; a deal never goes past a lost change; a change
///   before it lost or refused, or a tap while it waits, keeps it back, and
///   the lane always says so ([dealBehind], [dealGoes]; `RetryCoversAll`,
///   `DealAsShown`);
/// - a 403 (the host role moved) forgets what would be sent again and any
///   held deal: no "Not sent." on a guest's phone ([settle], `GuestQuiet`).
final class SettingsLane {
  const SettingsLane._({
    required this.pending,
    required this.out,
    required int asked,
    required Map<String, int> askedAt,
    required this.unsent,
    required LaneChange? refused,
    required int? shownRev,
    required this.dealHeld,
    required this.dealWaiting,
  }) : _asked = asked,
       _askedAt = askedAt,
       _refused = refused,
       _shownRev = shownRev;

  /// Nothing asked yet.
  static const empty = SettingsLane._(
    pending: [],
    out: null,
    asked: 0,
    askedAt: {},
    unsent: [],
    refused: null,
    shownRev: null,
    dealHeld: false,
    dealWaiting: false,
  );

  /// The changes asked and not answered, oldest first (the one [out] first).
  final List<LaneChange> pending;

  /// The change sent and not answered yet: never more than one.
  final LaneChange? out;

  /// The number of the newest change asked.
  final int _asked;

  /// Per key, the number of the newest change that asked for it.
  final Map<String, int> _askedAt;

  /// The changes that got no answer, oldest first ("Try again").
  final List<LaneChange> unsent;

  /// The refused change whose value is still on screen (until a server
  /// lobby is shown).
  final LaneChange? _refused;

  /// The `rev` of the newest server lobby shown (null: none with one yet).
  final int? _shownRev;

  /// The deal did not go (no answer, or kept back): "Not sent.", and "Try
  /// again" deals.
  final bool dealHeld;

  /// A deal waits behind the changes on the lane.
  final bool dealWaiting;

  SettingsLane _with({
    List<LaneChange>? pending,
    LaneChange? Function()? out,
    int? asked,
    Map<String, int>? askedAt,
    List<LaneChange>? unsent,
    LaneChange? Function()? refused,
    int? Function()? shownRev,
    bool? dealHeld,
    bool? dealWaiting,
  }) => SettingsLane._(
    pending: pending ?? this.pending,
    out: out != null ? out() : this.out,
    asked: asked ?? _asked,
    askedAt: askedAt ?? _askedAt,
    unsent: unsent ?? this.unsent,
    refused: refused != null ? refused() : _refused,
    shownRev: shownRev != null ? shownRev() : _shownRev,
    dealHeld: dealHeld ?? this.dealHeld,
    dealWaiting: dealWaiting ?? this.dealWaiting,
  );

  /// The keys of every change not answered yet (`LobbyState.settling`).
  Set<String> get pendingKeys => {for (final c in pending) ...c.keys};

  /// A refused change's value is still on screen (until a server lobby is
  /// shown): a deal tapped now would not deal what is shown.
  bool get refusedShown => _refused != null;

  /// "Not sent.": a lost change "Try again" would still send, or the deal
  /// did not go. Derived, never stored: nothing else switches it.
  bool get notSent => dealHeld || unsent.any((c) => _newestOf(c).isNotEmpty);

  /// Whether a server lobby numbered [rev] would be shown: not older than
  /// the newest shown. Equal is shown (at an equal number who is present may
  /// differ, and a read that crosses a write can carry newer members with
  /// the older number); a lobby with no number (a server from before `rev`)
  /// is shown.
  bool admits(int? rev) {
    final newest = _shownRev;
    return rev == null || newest == null || rev >= newest;
  }

  /// A server lobby numbered [rev] arrived (an answer, a read, a
  /// `lobby_update`): whether to show it ([admits]). Shown, it is the newest,
  /// and no refused value stays on screen over it.
  (SettingsLane, bool) admit(int? rev) {
    if (!admits(rev)) return (this, false);
    return (_with(shownRev: () => rev ?? _shownRev, refused: () => null), true);
  }

  /// A tap: the change [make] builds with the next number, at the back of the
  /// queue, the newest ask on its keys. A lost change on the same keys has
  /// nothing left to send ("Not sent." goes with it); one on other keys stays.
  /// A deal waiting behind the lane is kept back ("Not sent."): it would not
  /// deal what was shown when it was tapped.
  (SettingsLane, LaneChange) ask(LaneChange Function(int number) make) {
    final change = make(_asked + 1);
    return (
      _with(
        pending: List.unmodifiable([...pending, change]),
        asked: _asked + 1,
        askedAt: Map.unmodifiable({
          ..._askedAt,
          for (final key in change.keys) key: change.number,
        }),
        dealHeld: dealHeld || dealWaiting,
        dealWaiting: false,
      ),
      change,
    );
  }

  /// The oldest change, sent now; null while one is out or none waits.
  (SettingsLane, LaneChange?) sendNext() {
    if (out != null || pending.isEmpty) return (this, null);
    final next = pending.first;
    return (_with(out: () => next), next);
  }

  /// The change out was taken (its answer, the server's lobby, is shown as
  /// [admit] says).
  SettingsLane taken() =>
      _answer((change) => _with(pending: _without(change), out: () => null));

  /// The change out was refused (an answer: the table moved under it):
  /// dropped, never sent again; its value stays on screen until a server
  /// lobby is shown, and a deal behind it does not go ("Not sent.").
  SettingsLane refused() => _answer(
    (change) => _with(
      pending: _without(change),
      out: () => null,
      refused: () => change,
      dealHeld: dealHeld || dealWaiting,
      dealWaiting: false,
    ),
  );

  /// The host role moved (403, on a change or the deal): this phone is a
  /// guest's now. The change out and every one waiting are dropped (each
  /// would meet its own 403), and nothing is kept to send again or to deal:
  /// no "Not sent." on a guest's phone.
  SettingsLane settle() => _with(
    pending: const [],
    out: () => null,
    unsent: const [],
    dealHeld: false,
    dealWaiting: false,
  );

  /// The change out got no answer (offline, 5xx, the time ran out): dropped
  /// from the queue, kept for "Try again" ("Not sent."), its value on screen
  /// while it would still be sent. A deal behind it does not go.
  SettingsLane lose() => _answer(
    (change) => _with(
      pending: _without(change),
      out: () => null,
      unsent: List.unmodifiable([...unsent, change]),
      dealHeld: dealHeld || dealWaiting,
      dealWaiting: false,
    ),
  );

  /// An answer comes only for the change out: with none out it is a bug
  /// (asserted in development); in release nothing changes.
  SettingsLane _answer(SettingsLane Function(LaneChange change) then) {
    final change = out;
    assert(change != null, 'an answer with no change out');
    return change == null ? this : then(change);
  }

  List<LaneChange> _without(LaneChange change) => List.unmodifiable([
    for (final c in pending)
      if (!identical(c, change)) c,
  ]);

  /// "Try again", and a deal: the lost changes to ask again, oldest first,
  /// each with only the keys no newer change has asked for since (so a newer
  /// value on the same key, answered or on its way, is never undone); a
  /// change left with no key is not sent. The lane keeps none of them.
  (SettingsLane, List<LaneChange Function(int number)>) takeResend() => (
    _with(unsent: const []),
    [
      for (final change in unsent)
        if (_newestOf(change) case final keep when keep.isNotEmpty)
          (int n) => change.only(keep, n),
    ],
  );

  Set<String> _newestOf(LaneChange change) => {
    for (final key in change.keys)
      if (_askedAt[key] == change.number) key,
  };

  /// The deal waits behind the changes on the lane (asked just before it):
  /// no longer "Not sent.".
  SettingsLane dealBehind() => _with(dealWaiting: true, dealHeld: false);

  /// The deal's turn: whether it goes (it waits and nothing is pending).
  /// When it does not, the lane says so ("Not sent."), unless it was not
  /// waiting at all (a 403 settled it, or it is held already): a deal never
  /// ends silently.
  (SettingsLane, bool) dealGoes() {
    final go = dealWaiting && pending.isEmpty;
    return (
      _with(dealWaiting: false, dealHeld: dealHeld || (dealWaiting && !go)),
      go,
    );
  }

  /// The deal was taken: the game opens.
  SettingsLane dealTaken() => _with(dealHeld: false, dealWaiting: false);

  /// The deal was refused (an answer, with its own words): not held.
  SettingsLane dealRefused() => _with(dealHeld: false, dealWaiting: false);

  /// The deal got no answer, or was kept back: "Not sent.", and "Try again"
  /// deals.
  SettingsLane dealLost() => _with(dealHeld: true, dealWaiting: false);

  /// What the screen shows: the server's lobby with every change still to
  /// go over it, oldest first, as the server applies them (settings merged
  /// shallow, practice folded by `PracticeAsk.then`): a refused value (until
  /// a server lobby), the lost changes "Try again" would still send, the
  /// pending changes; a lost or refused change only on the keys no newer
  /// change asked for. Their keys are pending only for the changes not
  /// answered, and "Not sent." is as the lane says it.
  LobbyState over(LobbyState server) {
    final layers = <LaneChange>[
      for (final c in [?_refused, ...unsent])
        if (_newestOf(c) case final keep when keep.isNotEmpty)
          c.only(keep, c.number),
      ...pending,
    ]..sort((a, b) => a.number.compareTo(b.number));
    var shown = server;
    PracticeAsk? practice;
    for (final change in layers) {
      switch (change) {
        case SettingsChange(:final patch):
          shown = _merged(shown, patch);
        case PracticeChange(:final ask):
          practice = (practice ?? const PracticeAsk()).then(ask);
      }
    }
    return shown.copyWith(
      pendingKeys: pendingKeys,
      practiceAsk: practice,
      notSent: notSent,
    );
  }

  static LobbyState _merged(LobbyState lobby, Map<String, Object?> p) =>
      lobby.copyWith(
        table: lobby.table.merged(p),
        roleConfig: p['roles'] is Map<String, int>
            ? p['roles']! as Map<String, int>
            : lobby.roleConfig,
      );
}

/// One change of the host's on the settings lane, numbered in the order
/// asked ([number]).
sealed class LaneChange {
  const LaneChange(this.number);

  final int number;

  /// The settings keys it changes.
  Set<String> get keys;

  /// The same change with only [keep] of its keys (never empty), numbered
  /// [number].
  LaneChange only(Set<String> keep, int number);
}

/// A `PATCH /lobbies/<code>/` of [patch].
final class SettingsChange extends LaneChange {
  const SettingsChange(this.patch, super.number);

  final Map<String, Object?> patch;

  @override
  Set<String> get keys => patch.keys.toSet();

  @override
  LaneChange only(Set<String> keep, int number) => SettingsChange({
    for (final MapEntry(:key, :value) in patch.entries)
      if (keep.contains(key)) key: value,
  }, number);
}

/// A `POST /lobbies/<code>/practice/` of [ask].
final class PracticeChange extends LaneChange {
  const PracticeChange(this.ask, super.number);

  final PracticeAsk ask;

  @override
  Set<String> get keys => const {PracticeAsk.key};

  @override
  LaneChange only(Set<String> keep, int number) => PracticeChange(ask, number);
}
