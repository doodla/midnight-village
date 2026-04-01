// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_session_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GamePlayer _$GamePlayerFromJson(Map<String, dynamic> json) => _GamePlayer(
  playerId: (json['player_id'] as num).toInt(),
  displayName: json['display_name'] as String,
  hasVoted: json['has_voted'] as bool? ?? false,
);

Map<String, dynamic> _$GamePlayerToJson(_GamePlayer instance) =>
    <String, dynamic>{
      'player_id': instance.playerId,
      'display_name': instance.displayName,
      'has_voted': instance.hasVoted,
    };

_YourRole _$YourRoleFromJson(Map<String, dynamic> json) => _YourRole(
  originalRole: json['original_role'] as String,
  hasActed: json['has_acted'] as bool,
  currentRole: json['current_role'] as String?,
);

Map<String, dynamic> _$YourRoleToJson(_YourRole instance) => <String, dynamic>{
  'original_role': instance.originalRole,
  'has_acted': instance.hasActed,
  'current_role': instance.currentRole,
};

_GameSessionState _$GameSessionStateFromJson(Map<String, dynamic> json) =>
    _GameSessionState(
      gameId: json['game_id'] as String,
      phase: json['phase'] as String,
      currentWave: (json['current_wave'] as num?)?.toInt() ?? 0,
      deadline: json['deadline'] == null
          ? null
          : DateTime.parse(json['deadline'] as String),
      yourRole: YourRole.fromJson(json['your_role'] as Map<String, dynamic>),
      players: (json['players'] as List<dynamic>)
          .map((e) => GamePlayer.fromJson(e as Map<String, dynamic>))
          .toList(),
      hasVoted: json['has_voted'] as bool? ?? false,
      actionPrompt: json['action_prompt'] == null
          ? null
          : ActionPrompt.fromJson(
              json['action_prompt'] as Map<String, dynamic>,
            ),
      lastActionResult: json['last_action_result'] == null
          ? null
          : ActionResult.fromJson(
              json['last_action_result'] as Map<String, dynamic>,
            ),
      rolesInGame:
          (json['roles_in_game'] as List<dynamic>?)
              ?.map((e) => RoleInGame.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$GameSessionStateToJson(_GameSessionState instance) =>
    <String, dynamic>{
      'game_id': instance.gameId,
      'phase': instance.phase,
      'current_wave': instance.currentWave,
      'deadline': instance.deadline?.toIso8601String(),
      'your_role': instance.yourRole,
      'players': instance.players,
      'has_voted': instance.hasVoted,
      'action_prompt': instance.actionPrompt,
      'last_action_result': instance.lastActionResult,
      'roles_in_game': instance.rolesInGame,
    };
