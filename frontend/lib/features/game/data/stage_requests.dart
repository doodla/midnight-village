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
/// - `refused` (any other 4xx): the server took nothing; the caller undoes
///   what it showed;
/// - `notSent` (no answer, or a 5xx): it may not have arrived; the caller
///   keeps what it showed and offers "Try again".
typedef StageAnswer = ChooseAnswer;

/// The answer to a request that failed with [error].
StageAnswer stageAnswerOf(DioException error) {
  final status = error.response?.statusCode;
  return status == null
      ? ChooseAnswer.notSent
      : ChooseAnswer.fromStatus(status);
}

/// `POST /onuw/games/<id>/action/` under night protocol 2: one `choose`,
/// built from the prompt it answers so it always names that prompt's stage.
@immutable
class ChooseRequest {
  const ChooseRequest._(this.stage, this.chosen, this.picks);

  /// The [picks], in tap order, for [prompt] as this phone holds it.
  factory ChooseRequest.of(ChoosePrompt prompt, List<NightPick> picks) {
    if (picks.length > prompt.maxPicks) {
      throw ArgumentError.value(picks, 'picks', 'more than the prompt takes');
    }
    return ChooseRequest._(
      prompt.stage,
      prompt.chosen,
      List.unmodifiable(picks),
    );
  }

  final String stage;

  /// How many chooses the server had from this phone in this stage when the
  /// prompt was read (`chosen`). Carried for the server change that echoes
  /// it (a resend with a lower count is answered alike and stores nothing);
  /// not sent until the samples record it: then add `'chosen': chosen` to
  /// [toJson].
  final int chosen;
  final List<NightPick> picks;

  Map<String, Object> toJson() => {
    'action_type': 'choose',
    'picks': [for (final pick in picks) pick.toJson()],
    'stage': stage,
  };
}
