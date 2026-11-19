// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/host/host_change.dart';
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

    /// Whether the player's phone is connected. Public to the whole table.
    /// Not part of `/me/`: merged in from `GET .../players/` and kept up to
    /// date by `player_presence` events.
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(true)
    bool connected,
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
    @JsonKey(name: 'has_voted') @Default(false) bool hasVoted,
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

    /// Whether the current player is the game host (from server response).
    @JsonKey(name: 'is_host') @Default(false) bool isHost,

    /// The effective (current) host's player id, when the server says. When
    /// present, [isHost] follows it, and `host_changed` events update both.
    @JsonKey(name: 'host_id') int? hostId,

    /// The latest host change, for the quiet line everyone sees ("Ben is
    /// hosting while Ana is away").
    @JsonKey(includeFromJson: false, includeToJson: false)
    HostChange? hostNotice,

    /// A plain line about a host action that was refused because the role had
    /// just moved ("You are no longer the host.").
    @JsonKey(includeFromJson: false, includeToJson: false)
    String? hostActionNotice,

    /// Code of the table (lobby) this game belongs to, when the server says.
    @JsonKey(name: 'lobby_code') String? lobbyCode,

    /// This player's own results for night windows that have already closed,
    /// in order (from `night_results`). Parsed by [GameService]; the later
    /// "My night" feature reads it.
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default([])
    List<ActionResult> nightResults,

    /// Night results already put in front of the player (shown, or queued to
    /// be shown), so the same result is never shown twice whether it arrived
    /// by the socket or by a state fetch.
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default([])
    List<ActionResult> shownNightResults,

    /// Missed results waiting behind the one on screen; shown one after
    /// another as the player continues.
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default([])
    List<ActionResult> pendingNightResults,

    /// Set when the server says the table (and with it this game) no longer
    /// exists, because its last member left. The screen says so and goes home.
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(false)
    bool tableClosed,

    /// Set when the table has gone back to waiting for another game (the
    /// `play_again` event, or the host's own play-again call). The screen
    /// navigates to this lobby.
    @JsonKey(includeFromJson: false, includeToJson: false)
    String? playAgainLobbyCode,
  }) = _GameSessionState;

  factory GameSessionState.fromJson(Map<String, dynamic> json) =>
      _$GameSessionStateFromJson(json);
}

/// Who is away, from the public `connected` flag.
extension GamePresence on GameSessionState {
  /// Players whose phone is not connected, in table order.
  List<GamePlayer> get awayPlayers =>
      players.where((p) => !p.connected).toList();

  bool get hasAwayPlayers => players.any((p) => !p.connected);
}
