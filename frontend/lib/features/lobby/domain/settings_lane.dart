import 'lobby_state.dart';

/// What "Try again" does: the changes not sent, or the deal.
enum TryAgain { resend, deal }

/// The host's settings lane (settings and practice in ONE queue) as a value:
/// what is asked and not answered, the one change out, the changes that got
/// no answer, and the one "Try again" slot it shares with the deal, with
/// "Not sent." beside it. Every transition returns a new lane (and what to
/// send); the requests, the `Future` chain that runs them one after another
/// and the lobby reads are `LobbyNotifier`'s (`lobby_taps.dart`).
///
/// The rules are the model's (`docs/dev/models/phone/lobby/`,
/// `PhoneLobby.tla`), known gaps included:
/// - one out at a time, the oldest first ([sendNext]); every tap is sent;
/// - the screen is the server's lobby with every pending change over it, in
///   order ([over]); an answered change is dropped at once (gap a);
/// - a change with no answer is kept for "Try again", which resends each one
///   with only the keys no newer change asked for, oldest first
///   ([takeResend]);
/// - a new tap takes "Not sent." away but not the lost change (gap b); a lost
///   deal takes the slot from the lost changes (gap c).
final class SettingsLane {
  const SettingsLane._({
    required this.pending,
    required this.out,
    required int asked,
    required Map<String, int> askedAt,
    required this.unsent,
    required this.tryAgain,
    required this.notSent,
  }) : _asked = asked,
       _askedAt = askedAt;

  /// Nothing asked yet.
  static const empty = SettingsLane._(
    pending: [],
    out: null,
    asked: 0,
    askedAt: {},
    unsent: [],
    tryAgain: null,
    notSent: false,
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

  /// What "Try again" does now; null: nothing.
  final TryAgain? tryAgain;

  /// "Not sent." as the lane last said it.
  final bool notSent;

  SettingsLane _with({
    List<LaneChange>? pending,
    LaneChange? Function()? out,
    int? asked,
    Map<String, int>? askedAt,
    List<LaneChange>? unsent,
    TryAgain? Function()? tryAgain,
    bool? notSent,
  }) => SettingsLane._(
    pending: pending ?? this.pending,
    out: out != null ? out() : this.out,
    asked: asked ?? _asked,
    askedAt: askedAt ?? _askedAt,
    unsent: unsent ?? this.unsent,
    tryAgain: tryAgain != null ? tryAgain() : this.tryAgain,
    notSent: notSent ?? this.notSent,
  );

  /// The keys of every change not answered yet (`LobbyState.settling`).
  Set<String> get pendingKeys => {for (final c in pending) ...c.keys};

  /// A tap: the change [make] builds with the next number, at the back of the
  /// queue, the newest ask on its keys. "Not sent." goes; a lost change and
  /// the slot stay (gap b).
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
        notSent: false,
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

  /// The change out was answered: taken, refused, or the host role moved
  /// (403). Dropped from the lane; never sent again.
  SettingsLane settle() {
    final change = out;
    if (change == null) return this;
    return _with(pending: _without(change), out: () => null);
  }

  /// The change out got no answer (offline, 5xx, the time ran out): dropped
  /// from the queue, kept for "Try again", "Not sent.".
  SettingsLane lose() {
    final change = out;
    if (change == null) return this;
    return _with(
      pending: _without(change),
      out: () => null,
      unsent: List.unmodifiable([...unsent, change]),
      tryAgain: () => TryAgain.resend,
      notSent: true,
    );
  }

  List<LaneChange> _without(LaneChange change) => List.unmodifiable([
    for (final c in pending)
      if (!identical(c, change)) c,
  ]);

  /// "Try again" tapped: what the slot held, the slot emptied, "Not sent."
  /// gone.
  (SettingsLane, TryAgain?) takeRetry() =>
      (_with(tryAgain: () => null, notSent: false), tryAgain);

  /// The lost changes to ask again, oldest first, each with only the keys no
  /// newer change has asked for since (so a newer value on the same key,
  /// answered or on its way, is never undone); a change left with no key is
  /// not sent. The lane keeps none of them.
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

  /// The deal was taken: the slot is empty; "Not sent." stays as it was (the
  /// game opens over it).
  SettingsLane dealTaken() => _with(tryAgain: () => null);

  /// The deal was refused (an answer): the slot is empty, no "Not sent.".
  SettingsLane dealRefused() => _with(tryAgain: () => null, notSent: false);

  /// The deal got no answer: "Not sent.", and "Try again" is the deal.
  SettingsLane dealLost() =>
      _with(tryAgain: () => TryAgain.deal, notSent: true);

  /// What the screen shows: the server's lobby with every pending change over
  /// it, in order, as the server will apply them (settings merged shallow,
  /// practice folded by `PracticeAsk.then`), and their keys pending.
  LobbyState over(LobbyState server) {
    var shown = server;
    PracticeAsk? practice;
    for (final change in pending) {
      switch (change) {
        case SettingsChange(:final patch):
          shown = _merged(shown, patch);
        case PracticeChange(:final ask):
          practice = (practice ?? const PracticeAsk()).then(ask);
      }
    }
    return shown.copyWith(pendingKeys: pendingKeys, practiceAsk: practice);
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
