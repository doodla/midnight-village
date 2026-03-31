// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'night_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ActionPrompt _$ActionPromptFromJson(Map<String, dynamic> json) =>
    _ActionPrompt(
      roleActingAs: json['role_acting_as'] as String,
      actionTypes: (json['action_types'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      validTargets: json['valid_targets'] as Map<String, dynamic>,
      wave: (json['wave'] as num).toInt(),
    );

Map<String, dynamic> _$ActionPromptToJson(_ActionPrompt instance) =>
    <String, dynamic>{
      'role_acting_as': instance.roleActingAs,
      'action_types': instance.actionTypes,
      'valid_targets': instance.validTargets,
      'wave': instance.wave,
    };

_ActionResult _$ActionResultFromJson(Map<String, dynamic> json) =>
    _ActionResult(
      wave: (json['wave'] as num).toInt(),
      revealedInfo: json['revealed_info'] as Map<String, dynamic>,
    );

Map<String, dynamic> _$ActionResultToJson(_ActionResult instance) =>
    <String, dynamic>{
      'wave': instance.wave,
      'revealed_info': instance.revealedInfo,
    };

_RoleInGame _$RoleInGameFromJson(Map<String, dynamic> json) => _RoleInGame(
  role: json['role'] as String,
  count: (json['count'] as num).toInt(),
);

Map<String, dynamic> _$RoleInGameToJson(_RoleInGame instance) =>
    <String, dynamic>{'role': instance.role, 'count': instance.count};
