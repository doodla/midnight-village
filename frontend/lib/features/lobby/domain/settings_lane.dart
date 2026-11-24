import 'lobby_state.dart';

/// The host's settings lane (settings and practice in ONE queue) as a value:
/// what is asked and not answered, the one change out, the answered changes
/// still laid over the screen, the changes that got no answer, and the deal
/// that goes behind them. Every transition returns a new lane (and what to
/// send); the requests, the `Future` chain that runs them one after another,
/// the lobby reads and the socket are `LobbyNotifier`'s (`lobby_taps.dart`).
///
/// The rules are the model's (`docs/dev/models/phone/lobby/`,
/// `PhoneLobby.tla`):
/// - one out at a time, the oldest first ([sendNext]); every tap is sent
///   (`NeverOlder`);
/// - the screen is the server's lobby with every change not answered over it,
///   in order ([over]); an answered change stays laid over it too until
///   nothing older can land: no lobby read is out and its own `lobby_update`
///   has been heard or can no longer come ([heard], [readEnded],
///   [socketDropped]), so a read or an update that crossed the answer never
///   shows an older value (`NoFlickerBack`, gap a);
/// - "Not sent." is derived ([notSent]): it shows exactly while a lost change
///   would still be sent by "Try again" (a key no newer change asked for), or
///   the deal did not go; a newer tap on another key cannot take it away
///   (`LostFlagged`, `NoHiddenResend`, gaps b and b2);
/// - "Try again" sends every lost change again, trimmed to the keys no newer
///   change asked for, oldest first ([takeResend]), and then a deal that did
///   not go, behind them; a deal never goes past a lost change; a change
///   before it lost or refused keeps it back ([dealBehind], [dealGoes];
///   `RetryCoversAll`, `DealAsShown`, gap c).
final class SettingsLane {
  const SettingsLane._({
    required this.pending,
    required this.out,
    required int asked,
    required Map<String, int> askedAt,
    required this.unsent,
    required List<_Answered> answered,
    required bool outHeard,
    required bool readOut,
    required this.refusedShown,
    required this.dealHeld,
    required this.dealWaiting,
  }) : _asked = asked,
       _askedAt = askedAt,
       _answered = answered,
       _outHeard = outHeard,
       _readOut = readOut;

  /// Nothing asked yet.
  static const empty = SettingsLane._(
    pending: [],
    out: null,
    asked: 0,
    askedAt: {},
    unsent: [],
    answered: [],
    outHeard: false,
    readOut: false,
    refusedShown: false,
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

  /// The changes sent and answered (taken, laid over the screen) or lost
  /// (not laid: it may have got through) whose `lobby_update` may still come,
  /// or that a read out may be older than; in the order sent.
  final List<_Answered> _answered;

  /// The `lobby_update` of the change [out] has been heard already.
  final bool _outHeard;

  /// A lobby read is out.
  final bool _readOut;

  /// A refused change's value is still on screen (until a lobby from the
  /// server is shown): a deal tapped now would not deal what is shown.
  final bool refusedShown;

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
    List<_Answered>? answered,
    bool? outHeard,
    bool? readOut,
    bool? refusedShown,
    bool? dealHeld,
    bool? dealWaiting,
  }) {
    final lane = SettingsLane._(
      pending: pending ?? this.pending,
      out: out != null ? out() : this.out,
      asked: asked ?? _asked,
      askedAt: askedAt ?? _askedAt,
      unsent: unsent ?? this.unsent,
      answered: answered ?? _answered,
      outHeard: outHeard ?? _outHeard,
      readOut: readOut ?? _readOut,
      refusedShown: refusedShown ?? this.refusedShown,
      dealHeld: dealHeld ?? this.dealHeld,
      dealWaiting: dealWaiting ?? this.dealWaiting,
    );
    return lane._readOut ? lane : lane._pruned();
  }

  /// Drops every answered change nothing older can land over any more (run
  /// only while no read is out: a read asked before an answer may be older,
  /// and the events held meanwhile are not shown yet).
  SettingsLane _pruned() {
    if (!_answered.any((a) => !a.due)) return this;
    return SettingsLane._(
      pending: pending,
      out: out,
      asked: _asked,
      askedAt: _askedAt,
      unsent: unsent,
      answered: List.unmodifiable(_answered.where((a) => a.due)),
      outHeard: _outHeard,
      readOut: _readOut,
      refusedShown: refusedShown,
      dealHeld: dealHeld,
      dealWaiting: dealWaiting,
    );
  }

  /// The keys of every change not answered yet (`LobbyState.settling`).
  Set<String> get pendingKeys => {for (final c in pending) ...c.keys};

  /// "Not sent.": a lost change "Try again" would still send, or the deal
  /// did not go. Derived, never stored: nothing else switches it.
  bool get notSent => dealHeld || unsent.any((c) => _newestOf(c).isNotEmpty);

  /// A tap: the change [make] builds with the next number, at the back of the
  /// queue, the newest ask on its keys. A lost change on the same keys has
  /// nothing left to send ("Not sent." goes with it); one on other keys stays.
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
      ),
      change,
    );
  }

  /// The oldest change, sent now; null while one is out or none waits.
  (SettingsLane, LaneChange?) sendNext() {
    if (out != null || pending.isEmpty) return (this, null);
    final next = pending.first;
    return (_with(out: () => next, outHeard: false), next);
  }

  /// The change out was taken: [answer] is the server's lobby. Its keys, as
  /// the answer has them, stay laid over the screen until nothing older can
  /// land.
  SettingsLane taken(LobbyState answer) => _answer(
    (change) => _with(
      pending: _without(change),
      out: () => null,
      answered: _plus(change.asIn(answer), laid: true),
      refusedShown: false,
    ),
  );

  /// The change out was refused (an answer: the table moved under it):
  /// dropped, never sent again; its value stays on screen until the lobby is
  /// read, and a deal behind it does not go ("Not sent.").
  SettingsLane refused() => _answer(
    (change) => _with(
      pending: _without(change),
      out: () => null,
      refusedShown: true,
      dealHeld: dealHeld || dealWaiting,
      dealWaiting: false,
    ),
  );

  /// The host role moved (403): the change out is dropped, never sent again.
  SettingsLane settle() =>
      _answer((change) => _with(pending: _without(change), out: () => null));

  /// The change out got no answer (offline, 5xx, the time ran out): dropped
  /// from the queue, kept for "Try again" ("Not sent."); it may have got
  /// through, so its `lobby_update` is still told apart from a newer one's.
  /// A deal behind it does not go.
  SettingsLane lose() => _answer(
    (change) => _with(
      pending: _without(change),
      out: () => null,
      unsent: List.unmodifiable([...unsent, change]),
      answered: _plus(change, laid: false),
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

  List<_Answered> _plus(LaneChange change, {required bool laid}) =>
      List.unmodifiable([
        ..._answered,
        _Answered(change, laid: laid, due: !_outHeard),
      ]);

  /// A `lobby_update` arrived (as it arrives, held or not: the socket keeps
  /// the server's order). It is the update of the oldest change still
  /// waiting for one whose values it carries (or of a newer one), so that
  /// change and every one before it has had its update.
  SettingsLane heard(LobbyState update) {
    final waiting = [
      ..._answered,
      if (out case final o?) _Answered(o, due: !_outHeard),
    ];
    final i = waiting.indexWhere((a) => a.due && a.change.heardIn(update));
    if (i < 0) return this;
    return _with(
      answered: List.unmodifiable([
        for (final (j, a) in _answered.indexed) j <= i ? a.heard() : a,
      ]),
      outHeard: _outHeard || i == _answered.length,
    );
  }

  /// A lobby read was asked.
  SettingsLane readAsked() => _with(readOut: true);

  /// The lobby read is done (shown, or failed with the held events shown).
  SettingsLane readEnded() => _with(readOut: false);

  /// The socket dropped: what it had not delivered is lost, so no answered
  /// change waits for its update any more.
  SettingsLane socketDropped() => _with(
    answered: List.unmodifiable([for (final a in _answered) a.heard()]),
  );

  /// A lobby from the server is shown (an answer, a read, a `lobby_update`):
  /// no refused value stays on screen under it.
  SettingsLane serverShown() =>
      refusedShown ? _with(refusedShown: false) : this;

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

  /// Every change before the deal was answered: whether it goes (false: one
  /// was lost or refused, and the deal is held, "Not sent.").
  (SettingsLane, bool) dealGoes() =>
      (_with(dealWaiting: false), dealWaiting && pending.isEmpty);

  /// The deal was taken: the game opens.
  SettingsLane dealTaken() => _with(dealHeld: false, dealWaiting: false);

  /// The deal was refused (an answer, with its own words): not held.
  SettingsLane dealRefused() => _with(dealHeld: false, dealWaiting: false);

  /// The deal got no answer, or was kept back: "Not sent.", and "Try again"
  /// deals.
  SettingsLane dealLost() => _with(dealHeld: true, dealWaiting: false);

  /// What the screen shows: the server's lobby with every answered change
  /// still laid and every pending change over it, in order, as the server
  /// applies them (settings merged shallow, practice folded by
  /// `PracticeAsk.then`), their keys pending only for the changes not
  /// answered, and "Not sent." as the lane says it.
  LobbyState over(LobbyState server) {
    var shown = server;
    PracticeAsk? practice;
    for (final change in [
      for (final a in _answered)
        if (a.laid) a.change,
      ...pending,
    ]) {
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

/// A change sent and answered (or lost), until nothing older can land.
final class _Answered {
  const _Answered(this.change, {this.laid = true, this.due = true});

  final LaneChange change;

  /// Laid over the screen (taken); a lost change is not.
  final bool laid;

  /// Its `lobby_update` may still come.
  final bool due;

  _Answered heard() => _Answered(change, laid: laid, due: false);
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

  /// The same change with the values [lobby] has on its keys (an answer).
  LaneChange asIn(LobbyState lobby);

  /// [lobby] carries this change's values (a `lobby_update` that may be its
  /// own).
  bool heardIn(LobbyState lobby);
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

  @override
  LaneChange asIn(LobbyState lobby) => SettingsChange({
    for (final key in patch.keys)
      // The deck as the lobby holds it (the stored map is JSON's).
      key: key == 'roles' ? lobby.roleConfig : lobby.table.raw[key],
  }, number);

  @override
  bool heardIn(LobbyState lobby) =>
      patch.entries.every((e) => _same(lobby.table.raw[e.key], e.value));

  static bool _same(Object? a, Object? b) => switch ((a, b)) {
    (final Map<Object?, Object?> x, final Map<Object?, Object?> y) =>
      x.length == y.length &&
          x.keys.every((k) => y.containsKey(k) && _same(x[k], y[k])),
    (final List<Object?> x, final List<Object?> y) =>
      x.length == y.length &&
          [
            for (var i = 0; i < x.length; i++) i,
          ].every((i) => _same(x[i], y[i])),
    _ => a == b,
  };
}

/// A `POST /lobbies/<code>/practice/` of [ask].
final class PracticeChange extends LaneChange {
  const PracticeChange(this.ask, super.number);

  final PracticeAsk ask;

  @override
  Set<String> get keys => const {PracticeAsk.key};

  @override
  LaneChange only(Set<String> keep, int number) => PracticeChange(ask, number);

  @override
  LaneChange asIn(LobbyState lobby) => PracticeChange(
    PracticeAsk(on: lobby.practiceOn, count: lobby.practiceSeated),
    number,
  );

  @override
  bool heardIn(LobbyState lobby) =>
      (ask.on == null || lobby.practiceOn == ask.on) &&
      (ask.count == null || lobby.practiceSeated == ask.count);
}
