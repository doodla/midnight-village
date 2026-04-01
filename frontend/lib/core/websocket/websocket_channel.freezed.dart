// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'websocket_channel.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WebSocketEvent {

 String get type; Map<String, dynamic> get data;
/// Create a copy of WebSocketEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WebSocketEventCopyWith<WebSocketEvent> get copyWith => _$WebSocketEventCopyWithImpl<WebSocketEvent>(this as WebSocketEvent, _$identity);

  /// Serializes this WebSocketEvent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WebSocketEvent&&(identical(other.type, type) || other.type == type)&&const DeepCollectionEquality().equals(other.data, data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,const DeepCollectionEquality().hash(data));

@override
String toString() {
  return 'WebSocketEvent(type: $type, data: $data)';
}


}

/// @nodoc
abstract mixin class $WebSocketEventCopyWith<$Res>  {
  factory $WebSocketEventCopyWith(WebSocketEvent value, $Res Function(WebSocketEvent) _then) = _$WebSocketEventCopyWithImpl;
@useResult
$Res call({
 String type, Map<String, dynamic> data
});




}
/// @nodoc
class _$WebSocketEventCopyWithImpl<$Res>
    implements $WebSocketEventCopyWith<$Res> {
  _$WebSocketEventCopyWithImpl(this._self, this._then);

  final WebSocketEvent _self;
  final $Res Function(WebSocketEvent) _then;

/// Create a copy of WebSocketEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? data = null,}) {
  return _then(_self.copyWith(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}

}


/// Adds pattern-matching-related methods to [WebSocketEvent].
extension WebSocketEventPatterns on WebSocketEvent {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WebSocketEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WebSocketEvent() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WebSocketEvent value)  $default,){
final _that = this;
switch (_that) {
case _WebSocketEvent():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WebSocketEvent value)?  $default,){
final _that = this;
switch (_that) {
case _WebSocketEvent() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String type,  Map<String, dynamic> data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WebSocketEvent() when $default != null:
return $default(_that.type,_that.data);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String type,  Map<String, dynamic> data)  $default,) {final _that = this;
switch (_that) {
case _WebSocketEvent():
return $default(_that.type,_that.data);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String type,  Map<String, dynamic> data)?  $default,) {final _that = this;
switch (_that) {
case _WebSocketEvent() when $default != null:
return $default(_that.type,_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WebSocketEvent implements WebSocketEvent {
  const _WebSocketEvent({required this.type, required final  Map<String, dynamic> data}): _data = data;
  factory _WebSocketEvent.fromJson(Map<String, dynamic> json) => _$WebSocketEventFromJson(json);

@override final  String type;
 final  Map<String, dynamic> _data;
@override Map<String, dynamic> get data {
  if (_data is EqualUnmodifiableMapView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_data);
}


/// Create a copy of WebSocketEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WebSocketEventCopyWith<_WebSocketEvent> get copyWith => __$WebSocketEventCopyWithImpl<_WebSocketEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WebSocketEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WebSocketEvent&&(identical(other.type, type) || other.type == type)&&const DeepCollectionEquality().equals(other._data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,const DeepCollectionEquality().hash(_data));

@override
String toString() {
  return 'WebSocketEvent(type: $type, data: $data)';
}


}

/// @nodoc
abstract mixin class _$WebSocketEventCopyWith<$Res> implements $WebSocketEventCopyWith<$Res> {
  factory _$WebSocketEventCopyWith(_WebSocketEvent value, $Res Function(_WebSocketEvent) _then) = __$WebSocketEventCopyWithImpl;
@override @useResult
$Res call({
 String type, Map<String, dynamic> data
});




}
/// @nodoc
class __$WebSocketEventCopyWithImpl<$Res>
    implements _$WebSocketEventCopyWith<$Res> {
  __$WebSocketEventCopyWithImpl(this._self, this._then);

  final _WebSocketEvent _self;
  final $Res Function(_WebSocketEvent) _then;

/// Create a copy of WebSocketEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? data = null,}) {
  return _then(_WebSocketEvent(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}


}

// dart format on
