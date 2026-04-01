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

  /// Lone werewolf may optionally peek at one center card.
  loneWerewolfPeek,

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

/// A role present in the current game with its count.
@freezed
abstract class RoleInGame with _$RoleInGame {
  const factory RoleInGame({required String role, required int count}) =
      _RoleInGame;

  factory RoleInGame.fromJson(Map<String, dynamic> json) =>
      _$RoleInGameFromJson(json);
}
