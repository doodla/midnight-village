// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../design_system/models/game_result.dart';
import 'night_state.dart';
import 'voting_state.dart';

part 'game_session_state.freezed.dart';
part 'game_session_state.g.dart';

/// Public player info visible during gameplay (no role info).
@freezed
abstract class GamePlayer with _$GamePlayer {
  const factory GamePlayer({
    @JsonKey(name: 'player_id') required int playerId,
    @JsonKey(name: 'display_name') required String displayName,

    /// Visible in voting phase only.
    @JsonKey(name: 'has_voted') @Default(false) bool hasVoted,
  }) = _GamePlayer;

  factory GamePlayer.fromJson(Map<String, dynamic> json) =>
      _$GamePlayerFromJson(json);
}

/// The current player's role information.
///
/// `currentRole` is null during play and only populated in the results phase.
@freezed
abstract class YourRole with _$YourRole {
  const factory YourRole({
    @JsonKey(name: 'original_role') required String originalRole,
    @JsonKey(name: 'has_acted') required bool hasActed,

    /// Only available in results phase.
    @JsonKey(name: 'current_role') String? currentRole,
  }) = _YourRole;

  factory YourRole.fromJson(Map<String, dynamic> json) =>
      _$YourRoleFromJson(json);
}

/// The central game state managed by [GameNotifier].
///
/// Combines server-provided state (via REST and WebSocket) with frontend-only
/// display state (nightSubView). The server is the source of truth for all
/// game logic fields.
@freezed
abstract class GameSessionState with _$GameSessionState {
  const factory GameSessionState({
    @JsonKey(name: 'game_id') required String gameId,
    required String phase,
    @JsonKey(name: 'current_wave') @Default(0) int currentWave,
    DateTime? deadline,
    @JsonKey(name: 'your_role') required YourRole yourRole,
    required List<GamePlayer> players,
    @JsonKey(name: 'action_prompt') ActionPrompt? actionPrompt,
    @JsonKey(name: 'last_action_result') ActionResult? lastActionResult,

    /// Frontend-only display state for the night phase sub-view.
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(NightSubView.waiting)
    NightSubView nightSubView,

    /// Roles present in this game with their counts.
    @JsonKey(name: 'roles_in_game') @Default([]) List<RoleInGame> rolesInGame,

    /// Vote progress tracking during voting phase.
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(VoteProgress())
    VoteProgress voteProgress,

    /// Vote reveal data received after voting completes.
    @JsonKey(includeFromJson: false, includeToJson: false)
    VoteRevealData? voteRevealData,

    /// Full game results fetched from REST after game_results event.
    @JsonKey(includeFromJson: false, includeToJson: false) GameResult? results,
  }) = _GameSessionState;

  factory GameSessionState.fromJson(Map<String, dynamic> json) =>
      _$GameSessionStateFromJson(json);
}
