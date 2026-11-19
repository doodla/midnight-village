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

/// Builds an [ActionResult] from the shape the server uses for both the
/// `action_result` socket event and the entries of `night_results` in
/// `GET .../me/`: `{"wave": int, "action_type": String?, "revealed_info": {}}`.
///
/// Injects `action_type` into [ActionResult.revealedInfo] so
/// [NightResultView] can pick its layout.
///
/// Throws a [FormatException] when `wave` or `revealed_info` is missing, so a
/// caller can skip a malformed entry.
ActionResult actionResultFromServer(Map<String, dynamic> data) {
  final wave = data['wave'];
  final info = data['revealed_info'];
  if (wave is! num || info is! Map) {
    throw const FormatException('Night result without wave or revealed_info');
  }
  final revealedInfo = Map<String, dynamic>.from(info);
  if (data['action_type'] is String) {
    revealedInfo['action_type'] = data['action_type'];
  }
  return ActionResult(wave: wave.toInt(), revealedInfo: revealedInfo);
}

/// Parses the `night_results` list of `GET .../me/`. Absent or null is empty;
/// an entry that is not in the expected shape is skipped rather than failing
/// the whole state fetch.
List<ActionResult> parseNightResults(Object? raw) {
  if (raw is! List) return const [];
  final results = <ActionResult>[];
  for (final entry in raw) {
    if (entry is! Map) continue;
    try {
      results.add(actionResultFromServer(Map<String, dynamic>.from(entry)));
    } on FormatException {
      continue;
    }
  }
  return results;
}

/// A role present in the current game with its count.
@freezed
abstract class RoleInGame with _$RoleInGame {
  const factory RoleInGame({required String role, required int count}) =
      _RoleInGame;

  factory RoleInGame.fromJson(Map<String, dynamic> json) =>
      _$RoleInGameFromJson(json);
}
