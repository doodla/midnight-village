import 'package:flutter/foundation.dart';

import '../data/stage_requests.dart';
import '../domain/game_me.dart';

/// The kinds of tap this phone sends during a game. Each is a lane of the
/// [Outbox]: at most one request of a kind in flight, in tap order.
///
/// A pick and a lock share the vote lane, so a lock always goes out after
/// the picks before it.
enum OutboxLane { choose, vote, ready, ack }

/// Where a request is.
enum Leg {
  /// Waiting behind the one in flight (the latest tap of its kind).
  queued,

  /// Sent, no answer yet.
  inFlight,

  /// No answer came: it may not have arrived ("Try again").
  unsent,

  /// Answered (taken, or 409 stale): still shown until a `/me/` fetched
  /// after the answer comes back, so an older `/me/` cannot undo the tap.
  confirming,
}

/// One tap's request in the [Outbox].
@immutable
class OutboxItem {
  const OutboxItem({
    required this.id,
    required this.lane,
    required this.key,
    required this.request,
    required this.leg,
    this.confirmAfter = 0,
  });

  final int id;
  final OutboxLane lane;

  /// The stage (and, for a choose, the turn) it belongs to: when `/me/` is
  /// past it, the item is gone, whatever its leg ([Outbox.afterFetch]).
  final String key;

  /// The request as first made: a "Try again" sends exactly this.
  final StageRequest request;
  final Leg leg;

  /// While [Leg.confirming]: the first `/me/` fetch number sent after the
  /// answer. A fetch from then on shows the server's own state.
  final int confirmAfter;

  OutboxItem copyWith({Leg? leg, int? confirmAfter}) => OutboxItem(
    id: id,
    lane: lane,
    key: key,
    request: request,
    leg: leg ?? this.leg,
    confirmAfter: confirmAfter ?? this.confirmAfter,
  );
}

/// The key a [lane]'s taps belong to in [me]: the stage; for a choose, the
/// stage and the prompt's turn (the Doppelganger's follow-up is a new turn
/// of the same stage); for the results ack, the game.
String? laneKey(OutboxLane lane, GameMe me) => switch (lane) {
  OutboxLane.choose => switch (me.prompt) {
    null => null,
    final prompt => '${prompt.stage}#${prompt.turn}',
  },
  OutboxLane.vote || OutboxLane.ready => me.stage,
  OutboxLane.ack => me.gameId,
};

/// What this phone has tapped that `/me/` may not show yet, by lane: the
/// one request per lane in flight, unsent or confirming, and the latest tap
/// queued behind it. What the screens show of this phone's taps is derived
/// from it ([on]); nothing else holds tap state.
@immutable
class Outbox {
  const Outbox._(this._current, this._queued);

  static const empty = Outbox._({}, {});

  final Map<OutboxLane, OutboxItem> _current;
  final Map<OutboxLane, OutboxItem> _queued;

  /// The request in flight, unsent or confirming.
  OutboxItem? current(OutboxLane lane) => _current[lane];

  /// The latest tap waiting behind it.
  OutboxItem? queued(OutboxLane lane) => _queued[lane];

  /// The tap shown for [lane]: the latest one.
  OutboxItem? shown(OutboxLane lane) => _queued[lane] ?? _current[lane];

  /// Lanes whose request got no answer.
  Set<OutboxLane> get unsent => {
    for (final item in _current.values)
      if (item.leg == Leg.unsent) item.lane,
  };

  Outbox withCurrent(OutboxItem item) =>
      Outbox._({..._current, item.lane: item}, _queued);

  Outbox withQueued(OutboxItem item) =>
      Outbox._(_current, {..._queued, item.lane: item});

  Outbox withoutCurrent(OutboxLane lane) =>
      Outbox._({..._current}..remove(lane), _queued);

  Outbox withoutQueued(OutboxLane lane) =>
      Outbox._(_current, {..._queued}..remove(lane));

  /// After the `/me/` [me] of fetch number [fetch] is applied: a tap of a
  /// stage or turn that has ended is gone (queued, in flight or unsent: a
  /// "Try again" dies with its stage), and a confirming one is gone once a
  /// fetch sent after its answer shows the server's own state.
  Outbox afterFetch(GameMe me, int fetch) {
    bool keep(OutboxItem item) =>
        item.key == laneKey(item.lane, me) &&
        !(item.leg == Leg.confirming && fetch >= item.confirmAfter);
    return Outbox._(
      {
        for (final e in _current.entries)
          if (keep(e.value)) e.key: e.value,
      },
      {
        for (final e in _queued.entries)
          if (keep(e.value)) e.key: e.value,
      },
    );
  }

  /// [server] with this phone's taps on it, each only for its own stage
  /// (and turn).
  GameMe on(GameMe server) {
    var me = server;
    for (final lane in OutboxLane.values) {
      final item = shown(lane);
      if (item == null || item.key != laneKey(lane, server)) continue;
      me = switch (item.request) {
        ChooseRequest() => me.withChosen(),
        ReadyRequest(:final ready) => me.withReady(ready),
        VoteRequest(:final targetId, :final lock) => me.withVote(
          MyVote.local(targetId, locked: lock),
        ),
        AckRequest(:final seen) => me.withSeen(seen),
      };
    }
    return me;
  }
}

/// What became of a tap.
@immutable
sealed class TapOutcome {
  const TapOutcome();

  /// For the night board's `onChoose`, which reads a [ChooseAnswer]: the
  /// server's answer as it is; a tap this phone did not send changes
  /// nothing on the board (`stale`'s meaning there); a choose found to have
  /// landed is `taken`.
  ChooseAnswer get forBoard => switch (this) {
    Answered(:final answer) => answer,
    Landed() => ChooseAnswer.taken,
    Queued() || Declined() => ChooseAnswer.stale,
  };
}

/// The server answered.
final class Answered extends TapOutcome {
  const Answered(this.answer);

  final StageAnswer answer;
}

/// "Try again" found, by fetching `/me/` first, that the lost request had
/// landed: nothing was sent again.
final class Landed extends TapOutcome {
  const Landed();
}

/// Waiting behind the request of its kind in flight; goes out after it.
final class Queued extends TapOutcome {
  const Queued();
}

/// Not sent: this phone has nothing to send for it (nothing went out).
final class Declined extends TapOutcome {
  const Declined(this.reason);

  final DeclineReason reason;
}

enum DeclineReason {
  /// This turn's choose is in flight or chosen: never twice.
  alreadyChosen,

  /// The tap names a stage `/me/` is not in, or one that takes no such tap.
  notThisStage,

  /// The vote is locked in.
  locked,

  /// Looking at your card cannot be taken back.
  lookIsFinal,

  /// It asks for what is already shown.
  unchanged,

  /// "Try again" with nothing unsent.
  nothingToRetry,
}
