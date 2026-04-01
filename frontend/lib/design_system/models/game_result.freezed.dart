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

 String get voterId; String get voterName;/// Null for abstaining players.
 String? get targetId;/// Null for abstaining players.
 String? get targetName;
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
 String voterId, String voterName, String? targetId, String? targetName
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
@pragma('vm:prefer-inline') @override $Res call({Object? voterId = null,Object? voterName = null,Object? targetId = freezed,Object? targetName = freezed,}) {
  return _then(_self.copyWith(
voterId: null == voterId ? _self.voterId : voterId // ignore: cast_nullable_to_non_nullable
as String,voterName: null == voterName ? _self.voterName : voterName // ignore: cast_nullable_to_non_nullable
as String,targetId: freezed == targetId ? _self.targetId : targetId // ignore: cast_nullable_to_non_nullable
as String?,targetName: freezed == targetName ? _self.targetName : targetName // ignore: cast_nullable_to_non_nullable
as String?,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String voterId,  String voterName,  String? targetId,  String? targetName)?  $default,{required TResult orElse(),}) {final _that = this;
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String voterId,  String voterName,  String? targetId,  String? targetName)  $default,) {final _that = this;
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String voterId,  String voterName,  String? targetId,  String? targetName)?  $default,) {final _that = this;
switch (_that) {
case _VoteResult() when $default != null:
return $default(_that.voterId,_that.voterName,_that.targetId,_that.targetName);case _:
  return null;

}
}

}

/// @nodoc


class _VoteResult implements VoteResult {
  const _VoteResult({required this.voterId, required this.voterName, this.targetId, this.targetName});
  

@override final  String voterId;
@override final  String voterName;
/// Null for abstaining players.
@override final  String? targetId;
/// Null for abstaining players.
@override final  String? targetName;

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
 String voterId, String voterName, String? targetId, String? targetName
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
@override @pragma('vm:prefer-inline') $Res call({Object? voterId = null,Object? voterName = null,Object? targetId = freezed,Object? targetName = freezed,}) {
  return _then(_VoteResult(
voterId: null == voterId ? _self.voterId : voterId // ignore: cast_nullable_to_non_nullable
as String,voterName: null == voterName ? _self.voterName : voterName // ignore: cast_nullable_to_non_nullable
as String,targetId: freezed == targetId ? _self.targetId : targetId // ignore: cast_nullable_to_non_nullable
as String?,targetName: freezed == targetName ? _self.targetName : targetName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$PlayerResult {

 String get id; String get displayName; RoleId get originalRole; RoleId get finalRole; TeamId get team; bool get isEliminated; bool get isWinner;/// Who this player voted for (null for abstainers).
 String? get voteTargetId;/// Display name of the vote target (null for abstainers).
 String? get voteTargetName;/// How this player was eliminated (null if not eliminated).
 EliminationReason? get eliminationReason;
/// Create a copy of PlayerResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlayerResultCopyWith<PlayerResult> get copyWith => _$PlayerResultCopyWithImpl<PlayerResult>(this as PlayerResult, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlayerResult&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.originalRole, originalRole) || other.originalRole == originalRole)&&(identical(other.finalRole, finalRole) || other.finalRole == finalRole)&&(identical(other.team, team) || other.team == team)&&(identical(other.isEliminated, isEliminated) || other.isEliminated == isEliminated)&&(identical(other.isWinner, isWinner) || other.isWinner == isWinner)&&(identical(other.voteTargetId, voteTargetId) || other.voteTargetId == voteTargetId)&&(identical(other.voteTargetName, voteTargetName) || other.voteTargetName == voteTargetName)&&(identical(other.eliminationReason, eliminationReason) || other.eliminationReason == eliminationReason));
}


@override
int get hashCode => Object.hash(runtimeType,id,displayName,originalRole,finalRole,team,isEliminated,isWinner,voteTargetId,voteTargetName,eliminationReason);

@override
String toString() {
  return 'PlayerResult(id: $id, displayName: $displayName, originalRole: $originalRole, finalRole: $finalRole, team: $team, isEliminated: $isEliminated, isWinner: $isWinner, voteTargetId: $voteTargetId, voteTargetName: $voteTargetName, eliminationReason: $eliminationReason)';
}


}

/// @nodoc
abstract mixin class $PlayerResultCopyWith<$Res>  {
  factory $PlayerResultCopyWith(PlayerResult value, $Res Function(PlayerResult) _then) = _$PlayerResultCopyWithImpl;
@useResult
$Res call({
 String id, String displayName, RoleId originalRole, RoleId finalRole, TeamId team, bool isEliminated, bool isWinner, String? voteTargetId, String? voteTargetName, EliminationReason? eliminationReason
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? displayName = null,Object? originalRole = null,Object? finalRole = null,Object? team = null,Object? isEliminated = null,Object? isWinner = null,Object? voteTargetId = freezed,Object? voteTargetName = freezed,Object? eliminationReason = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,originalRole: null == originalRole ? _self.originalRole : originalRole // ignore: cast_nullable_to_non_nullable
as RoleId,finalRole: null == finalRole ? _self.finalRole : finalRole // ignore: cast_nullable_to_non_nullable
as RoleId,team: null == team ? _self.team : team // ignore: cast_nullable_to_non_nullable
as TeamId,isEliminated: null == isEliminated ? _self.isEliminated : isEliminated // ignore: cast_nullable_to_non_nullable
as bool,isWinner: null == isWinner ? _self.isWinner : isWinner // ignore: cast_nullable_to_non_nullable
as bool,voteTargetId: freezed == voteTargetId ? _self.voteTargetId : voteTargetId // ignore: cast_nullable_to_non_nullable
as String?,voteTargetName: freezed == voteTargetName ? _self.voteTargetName : voteTargetName // ignore: cast_nullable_to_non_nullable
as String?,eliminationReason: freezed == eliminationReason ? _self.eliminationReason : eliminationReason // ignore: cast_nullable_to_non_nullable
as EliminationReason?,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String displayName,  RoleId originalRole,  RoleId finalRole,  TeamId team,  bool isEliminated,  bool isWinner,  String? voteTargetId,  String? voteTargetName,  EliminationReason? eliminationReason)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlayerResult() when $default != null:
return $default(_that.id,_that.displayName,_that.originalRole,_that.finalRole,_that.team,_that.isEliminated,_that.isWinner,_that.voteTargetId,_that.voteTargetName,_that.eliminationReason);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String displayName,  RoleId originalRole,  RoleId finalRole,  TeamId team,  bool isEliminated,  bool isWinner,  String? voteTargetId,  String? voteTargetName,  EliminationReason? eliminationReason)  $default,) {final _that = this;
switch (_that) {
case _PlayerResult():
return $default(_that.id,_that.displayName,_that.originalRole,_that.finalRole,_that.team,_that.isEliminated,_that.isWinner,_that.voteTargetId,_that.voteTargetName,_that.eliminationReason);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String displayName,  RoleId originalRole,  RoleId finalRole,  TeamId team,  bool isEliminated,  bool isWinner,  String? voteTargetId,  String? voteTargetName,  EliminationReason? eliminationReason)?  $default,) {final _that = this;
switch (_that) {
case _PlayerResult() when $default != null:
return $default(_that.id,_that.displayName,_that.originalRole,_that.finalRole,_that.team,_that.isEliminated,_that.isWinner,_that.voteTargetId,_that.voteTargetName,_that.eliminationReason);case _:
  return null;

}
}

}

/// @nodoc


class _PlayerResult implements PlayerResult {
  const _PlayerResult({required this.id, required this.displayName, required this.originalRole, required this.finalRole, required this.team, required this.isEliminated, required this.isWinner, this.voteTargetId, this.voteTargetName, this.eliminationReason});
  

@override final  String id;
@override final  String displayName;
@override final  RoleId originalRole;
@override final  RoleId finalRole;
@override final  TeamId team;
@override final  bool isEliminated;
@override final  bool isWinner;
/// Who this player voted for (null for abstainers).
@override final  String? voteTargetId;
/// Display name of the vote target (null for abstainers).
@override final  String? voteTargetName;
/// How this player was eliminated (null if not eliminated).
@override final  EliminationReason? eliminationReason;

/// Create a copy of PlayerResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlayerResultCopyWith<_PlayerResult> get copyWith => __$PlayerResultCopyWithImpl<_PlayerResult>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlayerResult&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.originalRole, originalRole) || other.originalRole == originalRole)&&(identical(other.finalRole, finalRole) || other.finalRole == finalRole)&&(identical(other.team, team) || other.team == team)&&(identical(other.isEliminated, isEliminated) || other.isEliminated == isEliminated)&&(identical(other.isWinner, isWinner) || other.isWinner == isWinner)&&(identical(other.voteTargetId, voteTargetId) || other.voteTargetId == voteTargetId)&&(identical(other.voteTargetName, voteTargetName) || other.voteTargetName == voteTargetName)&&(identical(other.eliminationReason, eliminationReason) || other.eliminationReason == eliminationReason));
}


@override
int get hashCode => Object.hash(runtimeType,id,displayName,originalRole,finalRole,team,isEliminated,isWinner,voteTargetId,voteTargetName,eliminationReason);

@override
String toString() {
  return 'PlayerResult(id: $id, displayName: $displayName, originalRole: $originalRole, finalRole: $finalRole, team: $team, isEliminated: $isEliminated, isWinner: $isWinner, voteTargetId: $voteTargetId, voteTargetName: $voteTargetName, eliminationReason: $eliminationReason)';
}


}

/// @nodoc
abstract mixin class _$PlayerResultCopyWith<$Res> implements $PlayerResultCopyWith<$Res> {
  factory _$PlayerResultCopyWith(_PlayerResult value, $Res Function(_PlayerResult) _then) = __$PlayerResultCopyWithImpl;
@override @useResult
$Res call({
 String id, String displayName, RoleId originalRole, RoleId finalRole, TeamId team, bool isEliminated, bool isWinner, String? voteTargetId, String? voteTargetName, EliminationReason? eliminationReason
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? displayName = null,Object? originalRole = null,Object? finalRole = null,Object? team = null,Object? isEliminated = null,Object? isWinner = null,Object? voteTargetId = freezed,Object? voteTargetName = freezed,Object? eliminationReason = freezed,}) {
  return _then(_PlayerResult(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,originalRole: null == originalRole ? _self.originalRole : originalRole // ignore: cast_nullable_to_non_nullable
as RoleId,finalRole: null == finalRole ? _self.finalRole : finalRole // ignore: cast_nullable_to_non_nullable
as RoleId,team: null == team ? _self.team : team // ignore: cast_nullable_to_non_nullable
as TeamId,isEliminated: null == isEliminated ? _self.isEliminated : isEliminated // ignore: cast_nullable_to_non_nullable
as bool,isWinner: null == isWinner ? _self.isWinner : isWinner // ignore: cast_nullable_to_non_nullable
as bool,voteTargetId: freezed == voteTargetId ? _self.voteTargetId : voteTargetId // ignore: cast_nullable_to_non_nullable
as String?,voteTargetName: freezed == voteTargetName ? _self.voteTargetName : voteTargetName // ignore: cast_nullable_to_non_nullable
as String?,eliminationReason: freezed == eliminationReason ? _self.eliminationReason : eliminationReason // ignore: cast_nullable_to_non_nullable
as EliminationReason?,
  ));
}


}

/// @nodoc
mixin _$GameResult {

 List<TeamId> get winningTeams; List<PlayerResult> get players;/// Human-readable explanation of why the winning team(s) won.
 String get reason;/// Per-player vote pairs. Uses @Default([]) for backward compat.
 List<VoteResult> get votes;/// Final center card identities. Uses @Default([]) for backward compat.
 List<RoleId> get centerCards;
/// Create a copy of GameResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GameResultCopyWith<GameResult> get copyWith => _$GameResultCopyWithImpl<GameResult>(this as GameResult, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GameResult&&const DeepCollectionEquality().equals(other.winningTeams, winningTeams)&&const DeepCollectionEquality().equals(other.players, players)&&(identical(other.reason, reason) || other.reason == reason)&&const DeepCollectionEquality().equals(other.votes, votes)&&const DeepCollectionEquality().equals(other.centerCards, centerCards));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(winningTeams),const DeepCollectionEquality().hash(players),reason,const DeepCollectionEquality().hash(votes),const DeepCollectionEquality().hash(centerCards));

@override
String toString() {
  return 'GameResult(winningTeams: $winningTeams, players: $players, reason: $reason, votes: $votes, centerCards: $centerCards)';
}


}

/// @nodoc
abstract mixin class $GameResultCopyWith<$Res>  {
  factory $GameResultCopyWith(GameResult value, $Res Function(GameResult) _then) = _$GameResultCopyWithImpl;
@useResult
$Res call({
 List<TeamId> winningTeams, List<PlayerResult> players, String reason, List<VoteResult> votes, List<RoleId> centerCards
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
@pragma('vm:prefer-inline') @override $Res call({Object? winningTeams = null,Object? players = null,Object? reason = null,Object? votes = null,Object? centerCards = null,}) {
  return _then(_self.copyWith(
winningTeams: null == winningTeams ? _self.winningTeams : winningTeams // ignore: cast_nullable_to_non_nullable
as List<TeamId>,players: null == players ? _self.players : players // ignore: cast_nullable_to_non_nullable
as List<PlayerResult>,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,votes: null == votes ? _self.votes : votes // ignore: cast_nullable_to_non_nullable
as List<VoteResult>,centerCards: null == centerCards ? _self.centerCards : centerCards // ignore: cast_nullable_to_non_nullable
as List<RoleId>,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<TeamId> winningTeams,  List<PlayerResult> players,  String reason,  List<VoteResult> votes,  List<RoleId> centerCards)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GameResult() when $default != null:
return $default(_that.winningTeams,_that.players,_that.reason,_that.votes,_that.centerCards);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<TeamId> winningTeams,  List<PlayerResult> players,  String reason,  List<VoteResult> votes,  List<RoleId> centerCards)  $default,) {final _that = this;
switch (_that) {
case _GameResult():
return $default(_that.winningTeams,_that.players,_that.reason,_that.votes,_that.centerCards);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<TeamId> winningTeams,  List<PlayerResult> players,  String reason,  List<VoteResult> votes,  List<RoleId> centerCards)?  $default,) {final _that = this;
switch (_that) {
case _GameResult() when $default != null:
return $default(_that.winningTeams,_that.players,_that.reason,_that.votes,_that.centerCards);case _:
  return null;

}
}

}

/// @nodoc


class _GameResult implements GameResult {
  const _GameResult({required final  List<TeamId> winningTeams, required final  List<PlayerResult> players, this.reason = '', final  List<VoteResult> votes = const [], final  List<RoleId> centerCards = const []}): _winningTeams = winningTeams,_players = players,_votes = votes,_centerCards = centerCards;
  

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

/// Human-readable explanation of why the winning team(s) won.
@override@JsonKey() final  String reason;
/// Per-player vote pairs. Uses @Default([]) for backward compat.
 final  List<VoteResult> _votes;
/// Per-player vote pairs. Uses @Default([]) for backward compat.
@override@JsonKey() List<VoteResult> get votes {
  if (_votes is EqualUnmodifiableListView) return _votes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_votes);
}

/// Final center card identities. Uses @Default([]) for backward compat.
 final  List<RoleId> _centerCards;
/// Final center card identities. Uses @Default([]) for backward compat.
@override@JsonKey() List<RoleId> get centerCards {
  if (_centerCards is EqualUnmodifiableListView) return _centerCards;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_centerCards);
}


/// Create a copy of GameResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GameResultCopyWith<_GameResult> get copyWith => __$GameResultCopyWithImpl<_GameResult>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GameResult&&const DeepCollectionEquality().equals(other._winningTeams, _winningTeams)&&const DeepCollectionEquality().equals(other._players, _players)&&(identical(other.reason, reason) || other.reason == reason)&&const DeepCollectionEquality().equals(other._votes, _votes)&&const DeepCollectionEquality().equals(other._centerCards, _centerCards));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_winningTeams),const DeepCollectionEquality().hash(_players),reason,const DeepCollectionEquality().hash(_votes),const DeepCollectionEquality().hash(_centerCards));

@override
String toString() {
  return 'GameResult(winningTeams: $winningTeams, players: $players, reason: $reason, votes: $votes, centerCards: $centerCards)';
}


}

/// @nodoc
abstract mixin class _$GameResultCopyWith<$Res> implements $GameResultCopyWith<$Res> {
  factory _$GameResultCopyWith(_GameResult value, $Res Function(_GameResult) _then) = __$GameResultCopyWithImpl;
@override @useResult
$Res call({
 List<TeamId> winningTeams, List<PlayerResult> players, String reason, List<VoteResult> votes, List<RoleId> centerCards
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
@override @pragma('vm:prefer-inline') $Res call({Object? winningTeams = null,Object? players = null,Object? reason = null,Object? votes = null,Object? centerCards = null,}) {
  return _then(_GameResult(
winningTeams: null == winningTeams ? _self._winningTeams : winningTeams // ignore: cast_nullable_to_non_nullable
as List<TeamId>,players: null == players ? _self._players : players // ignore: cast_nullable_to_non_nullable
as List<PlayerResult>,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,votes: null == votes ? _self._votes : votes // ignore: cast_nullable_to_non_nullable
as List<VoteResult>,centerCards: null == centerCards ? _self._centerCards : centerCards // ignore: cast_nullable_to_non_nullable
as List<RoleId>,
  ));
}


}

// dart format on
