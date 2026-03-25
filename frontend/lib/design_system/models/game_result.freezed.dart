// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'game_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$VoteResult {

 String get voterId; String get voterName; String get targetId; String get targetName;
/// Create a copy of VoteResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VoteResultCopyWith<VoteResult> get copyWith => _$VoteResultCopyWithImpl<VoteResult>(this as VoteResult, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VoteResult&&(identical(other.voterId, voterId) || other.voterId == voterId)&&(identical(other.voterName, voterName) || other.voterName == voterName)&&(identical(other.targetId, targetId) || other.targetId == targetId)&&(identical(other.targetName, targetName) || other.targetName == targetName));
}


@override
int get hashCode => Object.hash(runtimeType,voterId,voterName,targetId,targetName);

@override
String toString() {
  return 'VoteResult(voterId: $voterId, voterName: $voterName, targetId: $targetId, targetName: $targetName)';
}


}

/// @nodoc
abstract mixin class $VoteResultCopyWith<$Res>  {
  factory $VoteResultCopyWith(VoteResult value, $Res Function(VoteResult) _then) = _$VoteResultCopyWithImpl;
@useResult
$Res call({
 String voterId, String voterName, String targetId, String targetName
});




}
/// @nodoc
class _$VoteResultCopyWithImpl<$Res>
    implements $VoteResultCopyWith<$Res> {
  _$VoteResultCopyWithImpl(this._self, this._then);

  final VoteResult _self;
  final $Res Function(VoteResult) _then;

/// Create a copy of VoteResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? voterId = null,Object? voterName = null,Object? targetId = null,Object? targetName = null,}) {
  return _then(_self.copyWith(
voterId: null == voterId ? _self.voterId : voterId // ignore: cast_nullable_to_non_nullable
as String,voterName: null == voterName ? _self.voterName : voterName // ignore: cast_nullable_to_non_nullable
as String,targetId: null == targetId ? _self.targetId : targetId // ignore: cast_nullable_to_non_nullable
as String,targetName: null == targetName ? _self.targetName : targetName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [VoteResult].
extension VoteResultPatterns on VoteResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VoteResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VoteResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VoteResult value)  $default,){
final _that = this;
switch (_that) {
case _VoteResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VoteResult value)?  $default,){
final _that = this;
switch (_that) {
case _VoteResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String voterId,  String voterName,  String targetId,  String targetName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VoteResult() when $default != null:
return $default(_that.voterId,_that.voterName,_that.targetId,_that.targetName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String voterId,  String voterName,  String targetId,  String targetName)  $default,) {final _that = this;
switch (_that) {
case _VoteResult():
return $default(_that.voterId,_that.voterName,_that.targetId,_that.targetName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String voterId,  String voterName,  String targetId,  String targetName)?  $default,) {final _that = this;
switch (_that) {
case _VoteResult() when $default != null:
return $default(_that.voterId,_that.voterName,_that.targetId,_that.targetName);case _:
  return null;

}
}

}

/// @nodoc


class _VoteResult implements VoteResult {
  const _VoteResult({required this.voterId, required this.voterName, required this.targetId, required this.targetName});
  

@override final  String voterId;
@override final  String voterName;
@override final  String targetId;
@override final  String targetName;

/// Create a copy of VoteResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VoteResultCopyWith<_VoteResult> get copyWith => __$VoteResultCopyWithImpl<_VoteResult>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VoteResult&&(identical(other.voterId, voterId) || other.voterId == voterId)&&(identical(other.voterName, voterName) || other.voterName == voterName)&&(identical(other.targetId, targetId) || other.targetId == targetId)&&(identical(other.targetName, targetName) || other.targetName == targetName));
}


@override
int get hashCode => Object.hash(runtimeType,voterId,voterName,targetId,targetName);

@override
String toString() {
  return 'VoteResult(voterId: $voterId, voterName: $voterName, targetId: $targetId, targetName: $targetName)';
}


}

/// @nodoc
abstract mixin class _$VoteResultCopyWith<$Res> implements $VoteResultCopyWith<$Res> {
  factory _$VoteResultCopyWith(_VoteResult value, $Res Function(_VoteResult) _then) = __$VoteResultCopyWithImpl;
@override @useResult
$Res call({
 String voterId, String voterName, String targetId, String targetName
});




}
/// @nodoc
class __$VoteResultCopyWithImpl<$Res>
    implements _$VoteResultCopyWith<$Res> {
  __$VoteResultCopyWithImpl(this._self, this._then);

  final _VoteResult _self;
  final $Res Function(_VoteResult) _then;

/// Create a copy of VoteResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? voterId = null,Object? voterName = null,Object? targetId = null,Object? targetName = null,}) {
  return _then(_VoteResult(
voterId: null == voterId ? _self.voterId : voterId // ignore: cast_nullable_to_non_nullable
as String,voterName: null == voterName ? _self.voterName : voterName // ignore: cast_nullable_to_non_nullable
as String,targetId: null == targetId ? _self.targetId : targetId // ignore: cast_nullable_to_non_nullable
as String,targetName: null == targetName ? _self.targetName : targetName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$PlayerResult {

 String get id; String get displayName; RoleId get originalRole; RoleId get finalRole; TeamId get team; bool get isEliminated; bool get isWinner;
/// Create a copy of PlayerResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlayerResultCopyWith<PlayerResult> get copyWith => _$PlayerResultCopyWithImpl<PlayerResult>(this as PlayerResult, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlayerResult&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.originalRole, originalRole) || other.originalRole == originalRole)&&(identical(other.finalRole, finalRole) || other.finalRole == finalRole)&&(identical(other.team, team) || other.team == team)&&(identical(other.isEliminated, isEliminated) || other.isEliminated == isEliminated)&&(identical(other.isWinner, isWinner) || other.isWinner == isWinner));
}


@override
int get hashCode => Object.hash(runtimeType,id,displayName,originalRole,finalRole,team,isEliminated,isWinner);

@override
String toString() {
  return 'PlayerResult(id: $id, displayName: $displayName, originalRole: $originalRole, finalRole: $finalRole, team: $team, isEliminated: $isEliminated, isWinner: $isWinner)';
}


}

/// @nodoc
abstract mixin class $PlayerResultCopyWith<$Res>  {
  factory $PlayerResultCopyWith(PlayerResult value, $Res Function(PlayerResult) _then) = _$PlayerResultCopyWithImpl;
@useResult
$Res call({
 String id, String displayName, RoleId originalRole, RoleId finalRole, TeamId team, bool isEliminated, bool isWinner
});




}
/// @nodoc
class _$PlayerResultCopyWithImpl<$Res>
    implements $PlayerResultCopyWith<$Res> {
  _$PlayerResultCopyWithImpl(this._self, this._then);

  final PlayerResult _self;
  final $Res Function(PlayerResult) _then;

/// Create a copy of PlayerResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? displayName = null,Object? originalRole = null,Object? finalRole = null,Object? team = null,Object? isEliminated = null,Object? isWinner = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,originalRole: null == originalRole ? _self.originalRole : originalRole // ignore: cast_nullable_to_non_nullable
as RoleId,finalRole: null == finalRole ? _self.finalRole : finalRole // ignore: cast_nullable_to_non_nullable
as RoleId,team: null == team ? _self.team : team // ignore: cast_nullable_to_non_nullable
as TeamId,isEliminated: null == isEliminated ? _self.isEliminated : isEliminated // ignore: cast_nullable_to_non_nullable
as bool,isWinner: null == isWinner ? _self.isWinner : isWinner // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [PlayerResult].
extension PlayerResultPatterns on PlayerResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlayerResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlayerResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlayerResult value)  $default,){
final _that = this;
switch (_that) {
case _PlayerResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlayerResult value)?  $default,){
final _that = this;
switch (_that) {
case _PlayerResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String displayName,  RoleId originalRole,  RoleId finalRole,  TeamId team,  bool isEliminated,  bool isWinner)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlayerResult() when $default != null:
return $default(_that.id,_that.displayName,_that.originalRole,_that.finalRole,_that.team,_that.isEliminated,_that.isWinner);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String displayName,  RoleId originalRole,  RoleId finalRole,  TeamId team,  bool isEliminated,  bool isWinner)  $default,) {final _that = this;
switch (_that) {
case _PlayerResult():
return $default(_that.id,_that.displayName,_that.originalRole,_that.finalRole,_that.team,_that.isEliminated,_that.isWinner);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String displayName,  RoleId originalRole,  RoleId finalRole,  TeamId team,  bool isEliminated,  bool isWinner)?  $default,) {final _that = this;
switch (_that) {
case _PlayerResult() when $default != null:
return $default(_that.id,_that.displayName,_that.originalRole,_that.finalRole,_that.team,_that.isEliminated,_that.isWinner);case _:
  return null;

}
}

}

/// @nodoc


class _PlayerResult implements PlayerResult {
  const _PlayerResult({required this.id, required this.displayName, required this.originalRole, required this.finalRole, required this.team, required this.isEliminated, required this.isWinner});
  

@override final  String id;
@override final  String displayName;
@override final  RoleId originalRole;
@override final  RoleId finalRole;
@override final  TeamId team;
@override final  bool isEliminated;
@override final  bool isWinner;

/// Create a copy of PlayerResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlayerResultCopyWith<_PlayerResult> get copyWith => __$PlayerResultCopyWithImpl<_PlayerResult>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlayerResult&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.originalRole, originalRole) || other.originalRole == originalRole)&&(identical(other.finalRole, finalRole) || other.finalRole == finalRole)&&(identical(other.team, team) || other.team == team)&&(identical(other.isEliminated, isEliminated) || other.isEliminated == isEliminated)&&(identical(other.isWinner, isWinner) || other.isWinner == isWinner));
}


@override
int get hashCode => Object.hash(runtimeType,id,displayName,originalRole,finalRole,team,isEliminated,isWinner);

@override
String toString() {
  return 'PlayerResult(id: $id, displayName: $displayName, originalRole: $originalRole, finalRole: $finalRole, team: $team, isEliminated: $isEliminated, isWinner: $isWinner)';
}


}

/// @nodoc
abstract mixin class _$PlayerResultCopyWith<$Res> implements $PlayerResultCopyWith<$Res> {
  factory _$PlayerResultCopyWith(_PlayerResult value, $Res Function(_PlayerResult) _then) = __$PlayerResultCopyWithImpl;
@override @useResult
$Res call({
 String id, String displayName, RoleId originalRole, RoleId finalRole, TeamId team, bool isEliminated, bool isWinner
});




}
/// @nodoc
class __$PlayerResultCopyWithImpl<$Res>
    implements _$PlayerResultCopyWith<$Res> {
  __$PlayerResultCopyWithImpl(this._self, this._then);

  final _PlayerResult _self;
  final $Res Function(_PlayerResult) _then;

/// Create a copy of PlayerResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? displayName = null,Object? originalRole = null,Object? finalRole = null,Object? team = null,Object? isEliminated = null,Object? isWinner = null,}) {
  return _then(_PlayerResult(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,originalRole: null == originalRole ? _self.originalRole : originalRole // ignore: cast_nullable_to_non_nullable
as RoleId,finalRole: null == finalRole ? _self.finalRole : finalRole // ignore: cast_nullable_to_non_nullable
as RoleId,team: null == team ? _self.team : team // ignore: cast_nullable_to_non_nullable
as TeamId,isEliminated: null == isEliminated ? _self.isEliminated : isEliminated // ignore: cast_nullable_to_non_nullable
as bool,isWinner: null == isWinner ? _self.isWinner : isWinner // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$GameResult {

 List<TeamId> get winningTeams; List<PlayerResult> get players;
/// Create a copy of GameResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GameResultCopyWith<GameResult> get copyWith => _$GameResultCopyWithImpl<GameResult>(this as GameResult, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GameResult&&const DeepCollectionEquality().equals(other.winningTeams, winningTeams)&&const DeepCollectionEquality().equals(other.players, players));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(winningTeams),const DeepCollectionEquality().hash(players));

@override
String toString() {
  return 'GameResult(winningTeams: $winningTeams, players: $players)';
}


}

/// @nodoc
abstract mixin class $GameResultCopyWith<$Res>  {
  factory $GameResultCopyWith(GameResult value, $Res Function(GameResult) _then) = _$GameResultCopyWithImpl;
@useResult
$Res call({
 List<TeamId> winningTeams, List<PlayerResult> players
});




}
/// @nodoc
class _$GameResultCopyWithImpl<$Res>
    implements $GameResultCopyWith<$Res> {
  _$GameResultCopyWithImpl(this._self, this._then);

  final GameResult _self;
  final $Res Function(GameResult) _then;

/// Create a copy of GameResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? winningTeams = null,Object? players = null,}) {
  return _then(_self.copyWith(
winningTeams: null == winningTeams ? _self.winningTeams : winningTeams // ignore: cast_nullable_to_non_nullable
as List<TeamId>,players: null == players ? _self.players : players // ignore: cast_nullable_to_non_nullable
as List<PlayerResult>,
  ));
}

}


/// Adds pattern-matching-related methods to [GameResult].
extension GameResultPatterns on GameResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GameResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GameResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GameResult value)  $default,){
final _that = this;
switch (_that) {
case _GameResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GameResult value)?  $default,){
final _that = this;
switch (_that) {
case _GameResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<TeamId> winningTeams,  List<PlayerResult> players)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GameResult() when $default != null:
return $default(_that.winningTeams,_that.players);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<TeamId> winningTeams,  List<PlayerResult> players)  $default,) {final _that = this;
switch (_that) {
case _GameResult():
return $default(_that.winningTeams,_that.players);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<TeamId> winningTeams,  List<PlayerResult> players)?  $default,) {final _that = this;
switch (_that) {
case _GameResult() when $default != null:
return $default(_that.winningTeams,_that.players);case _:
  return null;

}
}

}

/// @nodoc


class _GameResult implements GameResult {
  const _GameResult({required final  List<TeamId> winningTeams, required final  List<PlayerResult> players}): _winningTeams = winningTeams,_players = players;
  

 final  List<TeamId> _winningTeams;
@override List<TeamId> get winningTeams {
  if (_winningTeams is EqualUnmodifiableListView) return _winningTeams;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_winningTeams);
}

 final  List<PlayerResult> _players;
@override List<PlayerResult> get players {
  if (_players is EqualUnmodifiableListView) return _players;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_players);
}


/// Create a copy of GameResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GameResultCopyWith<_GameResult> get copyWith => __$GameResultCopyWithImpl<_GameResult>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GameResult&&const DeepCollectionEquality().equals(other._winningTeams, _winningTeams)&&const DeepCollectionEquality().equals(other._players, _players));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_winningTeams),const DeepCollectionEquality().hash(_players));

@override
String toString() {
  return 'GameResult(winningTeams: $winningTeams, players: $players)';
}


}

/// @nodoc
abstract mixin class _$GameResultCopyWith<$Res> implements $GameResultCopyWith<$Res> {
  factory _$GameResultCopyWith(_GameResult value, $Res Function(_GameResult) _then) = __$GameResultCopyWithImpl;
@override @useResult
$Res call({
 List<TeamId> winningTeams, List<PlayerResult> players
});




}
/// @nodoc
class __$GameResultCopyWithImpl<$Res>
    implements _$GameResultCopyWith<$Res> {
  __$GameResultCopyWithImpl(this._self, this._then);

  final _GameResult _self;
  final $Res Function(_GameResult) _then;

/// Create a copy of GameResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? winningTeams = null,Object? players = null,}) {
  return _then(_GameResult(
winningTeams: null == winningTeams ? _self._winningTeams : winningTeams // ignore: cast_nullable_to_non_nullable
as List<TeamId>,players: null == players ? _self._players : players // ignore: cast_nullable_to_non_nullable
as List<PlayerResult>,
  ));
}


}

// dart format on
