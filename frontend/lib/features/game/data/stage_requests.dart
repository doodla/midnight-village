import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../design_system/night/choose_prompt.dart';
import '../../../design_system/night/night_pick.dart';

export '../../../design_system/night/night_pick.dart' show ChooseAnswer;

/// What became of any stage-scoped request (choose, ready, vote, the host's
/// advance / end talk / reveal): the same four outcomes as the board's
/// [ChooseAnswer], read the same way ([ChooseAnswer.fromStatus]):
/// - `taken` (2xx);
/// - `stale` (409: `wrong_stage`, `already_chosen`, `vote_locked`): the
///   stage moved on or the server already has it; not an error, the caller
///   fetches `/me/`;
/// - `refused` (any other 4xx): the server took nothing;
/// - `notSent` (no answer, or a 5xx): it may not have arrived.
///
/// Only the server's answer is ever one of these: a phone that declines a
/// tap itself says so differently (`TapOutcome`).
typedef StageAnswer = ChooseAnswer;

/// The answer to a request that failed with [error].
StageAnswer stageAnswerOf(DioException error) {
  final status = error.response?.statusCode;
  return status == null
      ? ChooseAnswer.notSent
      : ChooseAnswer.fromStatus(status);
}

/// A stage request's answer and, when it was taken, the server's body (a
/// pick and a ready echo what they stored).
@immutable
class StageReply {
  const StageReply(this.answer, [this.body]);

  final StageAnswer answer;
  final Map<String, dynamic>? body;
}

/// A request the outbox can hold and send again exactly as it was first
/// made (a "Try again" never changes what was asked).
@immutable
sealed class StageRequest {
  const StageRequest();

  /// The stage it names (null: not stage-bound, the results ack).
  String? get stage;

  Map<String, Object> toJson();
}

/// `POST /onuw/games/<id>/action/` under night protocol 2: one `choose`,
/// built from the prompt it answers so it always names that prompt's stage.
final class ChooseRequest extends StageRequest {
  const ChooseRequest._(this.stage, this.turn, this.chosen, this.picks);

  /// The [picks], in tap order, for [prompt] as the server last sent it.
  factory ChooseRequest.of(ChoosePrompt prompt, List<NightPick> picks) {
    if (picks.length > prompt.maxPicks) {
      throw ArgumentError.value(picks, 'picks', 'more than the prompt takes');
    }
    return ChooseRequest._(
      prompt.stage,
      prompt.turn,
      prompt.chosen,
      List.unmodifiable(picks),
    );
  }

  @override
  final String stage;

  /// Which turn of the stage it is ([ChoosePrompt.turn]).
  final int turn;

  /// The answered prompt's `chosen` (as the server last sent it). Required
  /// by the server: lower than its count, it is a resend of a choose already
  /// taken (answered alike, nothing stored); after a lost answer, a `/me/`
  /// whose prompt says more than this means it landed.
  final int chosen;
  final List<NightPick> picks;

  @override
  Map<String, Object> toJson() => {
    'action_type': 'choose',
    'picks': [for (final pick in picks) pick.toJson()],
    'stage': stage,
    'chosen': chosen,
  };
}

/// `POST .../ready/`: "I've looked at my card" (the look, true only) or
/// "ready to vote" (the talk, a toggle).
final class ReadyRequest extends StageRequest {
  const ReadyRequest(this.stage, {required this.ready});

  @override
  final String stage;
  final bool ready;

  @override
  Map<String, Object> toJson() => {'ready': ready, 'stage': stage};

  @override
  bool operator ==(Object other) =>
      other is ReadyRequest && other.stage == stage && other.ready == ready;

  @override
  int get hashCode => Object.hash(stage, ready);
}

/// `POST .../vote/`: a pick (`lock: false`) or locking in (final). Locking
/// carries the target, so a lost pick can never lock the wrong name.
final class VoteRequest extends StageRequest {
  const VoteRequest(this.stage, {required this.targetId, required this.lock});

  @override
  final String stage;
  final int targetId;
  final bool lock;

  @override
  Map<String, Object> toJson() => {
    'target_player_id': targetId,
    'lock': lock,
    'stage': stage,
  };

  @override
  bool operator ==(Object other) =>
      other is VoteRequest &&
      other.stage == stage &&
      other.targetId == targetId &&
      other.lock == lock;

  @override
  int get hashCode => Object.hash(stage, targetId, lock);
}

/// `POST .../night-results/seen/`: the first [seen] night results were
/// shown (the server keeps the highest count).
final class AckRequest extends StageRequest {
  const AckRequest(this.seen);

  final int seen;

  @override
  String? get stage => null;

  @override
  Map<String, Object> toJson() => {'seen': seen};

  @override
  bool operator ==(Object other) => other is AckRequest && other.seen == seen;

  @override
  int get hashCode => seen.hashCode;
}
