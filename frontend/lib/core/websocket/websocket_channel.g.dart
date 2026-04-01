// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'websocket_channel.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WebSocketEvent _$WebSocketEventFromJson(Map<String, dynamic> json) =>
    _WebSocketEvent(
      type: json['type'] as String,
      data: json['data'] as Map<String, dynamic>,
    );

Map<String, dynamic> _$WebSocketEventToJson(_WebSocketEvent instance) =>
    <String, dynamic>{'type': instance.type, 'data': instance.data};
