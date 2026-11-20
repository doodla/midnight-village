// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'night_state.freezed.dart';
part 'night_state.g.dart';

/// Sub-view state machine for the night phase.
///
/// This enum is frontend-only -- derived from WebSocket events, not from the
/// server response directly. The [GameNotifier] sets the active sub-view based
/// on which WS event was last received.
enum NightSubView {
  /// "The village sleeps..." -- player has no action this wave or is waiting.
  waiting,

  /// Seer (or Doppelganger-as-Seer) chooses between peek_player and peek_center.
  seerChoice,

  /// The NightActionPrompt widget is shown for action submission.
  actionPrompt,

  /// Peek/swap result display after submitting an action.
  actionResult,

  /// Role reveal screen shown at the start of night before any actions.
  roleReveal,
}

/// Action prompt received via WebSocket `action_prompt` event or from
/// the GameMe REST response.
@freezed
abstract class ActionPrompt with _$ActionPrompt {
  const factory ActionPrompt({
    /// Display name for the role identity strip (important for Doppelganger).
    @JsonKey(name: 'role_acting_as') required String roleActingAs,

    /// Available action types, e.g. ["peek_player", "peek_center"].
    @JsonKey(name: 'action_types') required List<String> actionTypes,

    /// Valid targets per action type.
    @JsonKey(name: 'valid_targets') required Map<String, dynamic> validTargets,

    /// The wave this prompt belongs to.
    required int wave,
  }) = _ActionPrompt;

  factory ActionPrompt.fromJson(Map<String, dynamic> json) =>
      _$ActionPromptFromJson(json);
}

/// Display helpers over what the server advertised in an [ActionPrompt].
///
/// These only read the prompt's `action_types`; they never decide what a player
/// may do. The server lists `skip` (an explicit "do nothing") last, after the
/// real choices, for the roles that may decline (Seer, Robber, Troublemaker).
extension ActionPromptChoices on ActionPrompt {
  /// The explicit "do nothing" action type the server offers on some prompts.
  static const String skipType = 'skip';

  /// True when the server offers `skip` for this prompt.
  bool get canSkip => actionTypes.contains(skipType);

  /// The real action types, without `skip`.
  List<String> get choiceTypes =>
      actionTypes.where((t) => t != skipType).toList();

  /// True when the player must first pick between several actions (the Seer's
  /// player peek or center peek). A lone action plus `skip` is NOT a choice:
  /// it goes straight to the action prompt with a "do nothing" control.
  bool get needsActionChoice => choiceTypes.length > 1;

  /// The action type the prompt screen is built for (the first real choice).
  String get primaryType =>
      choiceTypes.isNotEmpty ? choiceTypes.first : actionTypes.first;
}

/// Action result received via WebSocket `action_result` event.
@freezed
abstract class ActionResult with _$ActionResult {
  const factory ActionResult({
    /// The wave this result belongs to.
    required int wave,

    /// Revealed information -- structure varies by action type.
    @JsonKey(name: 'revealed_info') required Map<String, dynamic> revealedInfo,
  }) = _ActionResult;

  factory ActionResult.fromJson(Map<String, dynamic> json) =>
      _$ActionResultFromJson(json);
}

/// A night result as the server sends it (the `action_result` event, or an
/// entry of `/me/`'s `night_results`): `action_type` goes into
/// [ActionResult.revealedInfo] so the result view knows what it shows.
ActionResult actionResultFromServer(Map<String, dynamic> data) => ActionResult(
  wave: data['wave'] as int,
  revealedInfo: {
    ...(data['revealed_info'] as Map).cast<String, dynamic>(),
    'action_type': data['action_type'] as String,
  },
);

/// `/me/`'s `night_results`: the player's results of closed windows, in order.
List<ActionResult> parseNightResults(List<dynamic> raw) => [
  for (final entry in raw)
    actionResultFromServer((entry as Map).cast<String, dynamic>()),
];

@freezed
abstract class RoleInGame with _$RoleInGame {
  const factory RoleInGame({required String role, required int count}) =
      _RoleInGame;

  factory RoleInGame.fromJson(Map<String, dynamic> json) =>
      _$RoleInGameFromJson(json);
}
