// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'lobby_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LobbyPlayer {

 int get id; String get displayName; bool get isReady; DateTime get joinedAt;
/// Create a copy of LobbyPlayer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LobbyPlayerCopyWith<LobbyPlayer> get copyWith => _$LobbyPlayerCopyWithImpl<LobbyPlayer>(this as LobbyPlayer, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LobbyPlayer&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.isReady, isReady) || other.isReady == isReady)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,displayName,isReady,joinedAt);

@override
String toString() {
  return 'LobbyPlayer(id: $id, displayName: $displayName, isReady: $isReady, joinedAt: $joinedAt)';
}


}

/// @nodoc
abstract mixin class $LobbyPlayerCopyWith<$Res>  {
  factory $LobbyPlayerCopyWith(LobbyPlayer value, $Res Function(LobbyPlayer) _then) = _$LobbyPlayerCopyWithImpl;
@useResult
$Res call({
 int id, String displayName, bool isReady, DateTime joinedAt
});




}
/// @nodoc
class _$LobbyPlayerCopyWithImpl<$Res>
    implements $LobbyPlayerCopyWith<$Res> {
  _$LobbyPlayerCopyWithImpl(this._self, this._then);

  final LobbyPlayer _self;
  final $Res Function(LobbyPlayer) _then;

/// Create a copy of LobbyPlayer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? displayName = null,Object? isReady = null,Object? joinedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,isReady: null == isReady ? _self.isReady : isReady // ignore: cast_nullable_to_non_nullable
as bool,joinedAt: null == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [LobbyPlayer].
extension LobbyPlayerPatterns on LobbyPlayer {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LobbyPlayer value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LobbyPlayer() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LobbyPlayer value)  $default,){
final _that = this;
switch (_that) {
case _LobbyPlayer():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LobbyPlayer value)?  $default,){
final _that = this;
switch (_that) {
case _LobbyPlayer() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String displayName,  bool isReady,  DateTime joinedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LobbyPlayer() when $default != null:
return $default(_that.id,_that.displayName,_that.isReady,_that.joinedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String displayName,  bool isReady,  DateTime joinedAt)  $default,) {final _that = this;
switch (_that) {
case _LobbyPlayer():
return $default(_that.id,_that.displayName,_that.isReady,_that.joinedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String displayName,  bool isReady,  DateTime joinedAt)?  $default,) {final _that = this;
switch (_that) {
case _LobbyPlayer() when $default != null:
return $default(_that.id,_that.displayName,_that.isReady,_that.joinedAt);case _:
  return null;

}
}

}

/// @nodoc


class _LobbyPlayer implements LobbyPlayer {
  const _LobbyPlayer({required this.id, required this.displayName, required this.isReady, required this.joinedAt});
  

@override final  int id;
@override final  String displayName;
@override final  bool isReady;
@override final  DateTime joinedAt;

/// Create a copy of LobbyPlayer
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LobbyPlayerCopyWith<_LobbyPlayer> get copyWith => __$LobbyPlayerCopyWithImpl<_LobbyPlayer>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LobbyPlayer&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.isReady, isReady) || other.isReady == isReady)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,displayName,isReady,joinedAt);

@override
String toString() {
  return 'LobbyPlayer(id: $id, displayName: $displayName, isReady: $isReady, joinedAt: $joinedAt)';
}


}

/// @nodoc
abstract mixin class _$LobbyPlayerCopyWith<$Res> implements $LobbyPlayerCopyWith<$Res> {
  factory _$LobbyPlayerCopyWith(_LobbyPlayer value, $Res Function(_LobbyPlayer) _then) = __$LobbyPlayerCopyWithImpl;
@override @useResult
$Res call({
 int id, String displayName, bool isReady, DateTime joinedAt
});




}
/// @nodoc
class __$LobbyPlayerCopyWithImpl<$Res>
    implements _$LobbyPlayerCopyWith<$Res> {
  __$LobbyPlayerCopyWithImpl(this._self, this._then);

  final _LobbyPlayer _self;
  final $Res Function(_LobbyPlayer) _then;

/// Create a copy of LobbyPlayer
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? displayName = null,Object? isReady = null,Object? joinedAt = null,}) {
  return _then(_LobbyPlayer(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,isReady: null == isReady ? _self.isReady : isReady // ignore: cast_nullable_to_non_nullable
as bool,joinedAt: null == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

/// @nodoc
mixin _$LobbyState {

 String get code; int get hostId; List<LobbyPlayer> get players; String get status; int get maxPlayers; Map<String, int> get roleConfig;/// The game this table has just started (from `game_started`, or found in
/// the player's current game). The screen opens it. A table can run
/// several games one after another, so each start sets a new id.
 String? get startedGameId;
/// Create a copy of LobbyState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LobbyStateCopyWith<LobbyState> get copyWith => _$LobbyStateCopyWithImpl<LobbyState>(this as LobbyState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LobbyState&&(identical(other.code, code) || other.code == code)&&(identical(other.hostId, hostId) || other.hostId == hostId)&&const DeepCollectionEquality().equals(other.players, players)&&(identical(other.status, status) || other.status == status)&&(identical(other.maxPlayers, maxPlayers) || other.maxPlayers == maxPlayers)&&const DeepCollectionEquality().equals(other.roleConfig, roleConfig)&&(identical(other.startedGameId, startedGameId) || other.startedGameId == startedGameId));
}


@override
int get hashCode => Object.hash(runtimeType,code,hostId,const DeepCollectionEquality().hash(players),status,maxPlayers,const DeepCollectionEquality().hash(roleConfig),startedGameId);

@override
String toString() {
  return 'LobbyState(code: $code, hostId: $hostId, players: $players, status: $status, maxPlayers: $maxPlayers, roleConfig: $roleConfig, startedGameId: $startedGameId)';
}


}

/// @nodoc
abstract mixin class $LobbyStateCopyWith<$Res>  {
  factory $LobbyStateCopyWith(LobbyState value, $Res Function(LobbyState) _then) = _$LobbyStateCopyWithImpl;
@useResult
$Res call({
 String code, int hostId, List<LobbyPlayer> players, String status, int maxPlayers, Map<String, int> roleConfig, String? startedGameId
});




}
/// @nodoc
class _$LobbyStateCopyWithImpl<$Res>
    implements $LobbyStateCopyWith<$Res> {
  _$LobbyStateCopyWithImpl(this._self, this._then);

  final LobbyState _self;
  final $Res Function(LobbyState) _then;

/// Create a copy of LobbyState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? hostId = null,Object? players = null,Object? status = null,Object? maxPlayers = null,Object? roleConfig = null,Object? startedGameId = freezed,}) {
  return _then(_self.copyWith(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,hostId: null == hostId ? _self.hostId : hostId // ignore: cast_nullable_to_non_nullable
as int,players: null == players ? _self.players : players // ignore: cast_nullable_to_non_nullable
as List<LobbyPlayer>,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,maxPlayers: null == maxPlayers ? _self.maxPlayers : maxPlayers // ignore: cast_nullable_to_non_nullable
as int,roleConfig: null == roleConfig ? _self.roleConfig : roleConfig // ignore: cast_nullable_to_non_nullable
as Map<String, int>,startedGameId: freezed == startedGameId ? _self.startedGameId : startedGameId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [LobbyState].
extension LobbyStatePatterns on LobbyState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LobbyState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LobbyState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LobbyState value)  $default,){
final _that = this;
switch (_that) {
case _LobbyState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LobbyState value)?  $default,){
final _that = this;
switch (_that) {
case _LobbyState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String code,  int hostId,  List<LobbyPlayer> players,  String status,  int maxPlayers,  Map<String, int> roleConfig,  String? startedGameId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LobbyState() when $default != null:
return $default(_that.code,_that.hostId,_that.players,_that.status,_that.maxPlayers,_that.roleConfig,_that.startedGameId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String code,  int hostId,  List<LobbyPlayer> players,  String status,  int maxPlayers,  Map<String, int> roleConfig,  String? startedGameId)  $default,) {final _that = this;
switch (_that) {
case _LobbyState():
return $default(_that.code,_that.hostId,_that.players,_that.status,_that.maxPlayers,_that.roleConfig,_that.startedGameId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String code,  int hostId,  List<LobbyPlayer> players,  String status,  int maxPlayers,  Map<String, int> roleConfig,  String? startedGameId)?  $default,) {final _that = this;
switch (_that) {
case _LobbyState() when $default != null:
return $default(_that.code,_that.hostId,_that.players,_that.status,_that.maxPlayers,_that.roleConfig,_that.startedGameId);case _:
  return null;

}
}

}

/// @nodoc


class _LobbyState implements LobbyState {
  const _LobbyState({required this.code, required this.hostId, required final  List<LobbyPlayer> players, required this.status, required this.maxPlayers, final  Map<String, int> roleConfig = const {}, this.startedGameId}): _players = players,_roleConfig = roleConfig;
  

@override final  String code;
@override final  int hostId;
 final  List<LobbyPlayer> _players;
@override List<LobbyPlayer> get players {
  if (_players is EqualUnmodifiableListView) return _players;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_players);
}

@override final  String status;
@override final  int maxPlayers;
 final  Map<String, int> _roleConfig;
@override@JsonKey() Map<String, int> get roleConfig {
  if (_roleConfig is EqualUnmodifiableMapView) return _roleConfig;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_roleConfig);
}

/// The game this table has just started (from `game_started`, or found in
/// the player's current game). The screen opens it. A table can run
/// several games one after another, so each start sets a new id.
@override final  String? startedGameId;

/// Create a copy of LobbyState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LobbyStateCopyWith<_LobbyState> get copyWith => __$LobbyStateCopyWithImpl<_LobbyState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LobbyState&&(identical(other.code, code) || other.code == code)&&(identical(other.hostId, hostId) || other.hostId == hostId)&&const DeepCollectionEquality().equals(other._players, _players)&&(identical(other.status, status) || other.status == status)&&(identical(other.maxPlayers, maxPlayers) || other.maxPlayers == maxPlayers)&&const DeepCollectionEquality().equals(other._roleConfig, _roleConfig)&&(identical(other.startedGameId, startedGameId) || other.startedGameId == startedGameId));
}


@override
int get hashCode => Object.hash(runtimeType,code,hostId,const DeepCollectionEquality().hash(_players),status,maxPlayers,const DeepCollectionEquality().hash(_roleConfig),startedGameId);

@override
String toString() {
  return 'LobbyState(code: $code, hostId: $hostId, players: $players, status: $status, maxPlayers: $maxPlayers, roleConfig: $roleConfig, startedGameId: $startedGameId)';
}


}

/// @nodoc
abstract mixin class _$LobbyStateCopyWith<$Res> implements $LobbyStateCopyWith<$Res> {
  factory _$LobbyStateCopyWith(_LobbyState value, $Res Function(_LobbyState) _then) = __$LobbyStateCopyWithImpl;
@override @useResult
$Res call({
 String code, int hostId, List<LobbyPlayer> players, String status, int maxPlayers, Map<String, int> roleConfig, String? startedGameId
});




}
/// @nodoc
class __$LobbyStateCopyWithImpl<$Res>
    implements _$LobbyStateCopyWith<$Res> {
  __$LobbyStateCopyWithImpl(this._self, this._then);

  final _LobbyState _self;
  final $Res Function(_LobbyState) _then;

/// Create a copy of LobbyState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? hostId = null,Object? players = null,Object? status = null,Object? maxPlayers = null,Object? roleConfig = null,Object? startedGameId = freezed,}) {
  return _then(_LobbyState(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,hostId: null == hostId ? _self.hostId : hostId // ignore: cast_nullable_to_non_nullable
as int,players: null == players ? _self._players : players // ignore: cast_nullable_to_non_nullable
as List<LobbyPlayer>,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,maxPlayers: null == maxPlayers ? _self.maxPlayers : maxPlayers // ignore: cast_nullable_to_non_nullable
as int,roleConfig: null == roleConfig ? _self._roleConfig : roleConfig // ignore: cast_nullable_to_non_nullable
as Map<String, int>,startedGameId: freezed == startedGameId ? _self.startedGameId : startedGameId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
