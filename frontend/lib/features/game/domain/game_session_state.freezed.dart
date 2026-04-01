// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'game_session_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GamePlayer {

@JsonKey(name: 'player_id') int get playerId;@JsonKey(name: 'display_name') String get displayName;/// Visible in voting phase only.
@JsonKey(name: 'has_voted') bool get hasVoted;
/// Create a copy of GamePlayer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GamePlayerCopyWith<GamePlayer> get copyWith => _$GamePlayerCopyWithImpl<GamePlayer>(this as GamePlayer, _$identity);

  /// Serializes this GamePlayer to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GamePlayer&&(identical(other.playerId, playerId) || other.playerId == playerId)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.hasVoted, hasVoted) || other.hasVoted == hasVoted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,playerId,displayName,hasVoted);

@override
String toString() {
  return 'GamePlayer(playerId: $playerId, displayName: $displayName, hasVoted: $hasVoted)';
}


}

/// @nodoc
abstract mixin class $GamePlayerCopyWith<$Res>  {
  factory $GamePlayerCopyWith(GamePlayer value, $Res Function(GamePlayer) _then) = _$GamePlayerCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'player_id') int playerId,@JsonKey(name: 'display_name') String displayName,@JsonKey(name: 'has_voted') bool hasVoted
});




}
/// @nodoc
class _$GamePlayerCopyWithImpl<$Res>
    implements $GamePlayerCopyWith<$Res> {
  _$GamePlayerCopyWithImpl(this._self, this._then);

  final GamePlayer _self;
  final $Res Function(GamePlayer) _then;

/// Create a copy of GamePlayer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? playerId = null,Object? displayName = null,Object? hasVoted = null,}) {
  return _then(_self.copyWith(
playerId: null == playerId ? _self.playerId : playerId // ignore: cast_nullable_to_non_nullable
as int,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,hasVoted: null == hasVoted ? _self.hasVoted : hasVoted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [GamePlayer].
extension GamePlayerPatterns on GamePlayer {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GamePlayer value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GamePlayer() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GamePlayer value)  $default,){
final _that = this;
switch (_that) {
case _GamePlayer():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GamePlayer value)?  $default,){
final _that = this;
switch (_that) {
case _GamePlayer() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'player_id')  int playerId, @JsonKey(name: 'display_name')  String displayName, @JsonKey(name: 'has_voted')  bool hasVoted)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GamePlayer() when $default != null:
return $default(_that.playerId,_that.displayName,_that.hasVoted);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'player_id')  int playerId, @JsonKey(name: 'display_name')  String displayName, @JsonKey(name: 'has_voted')  bool hasVoted)  $default,) {final _that = this;
switch (_that) {
case _GamePlayer():
return $default(_that.playerId,_that.displayName,_that.hasVoted);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'player_id')  int playerId, @JsonKey(name: 'display_name')  String displayName, @JsonKey(name: 'has_voted')  bool hasVoted)?  $default,) {final _that = this;
switch (_that) {
case _GamePlayer() when $default != null:
return $default(_that.playerId,_that.displayName,_that.hasVoted);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GamePlayer implements GamePlayer {
  const _GamePlayer({@JsonKey(name: 'player_id') required this.playerId, @JsonKey(name: 'display_name') required this.displayName, @JsonKey(name: 'has_voted') this.hasVoted = false});
  factory _GamePlayer.fromJson(Map<String, dynamic> json) => _$GamePlayerFromJson(json);

@override@JsonKey(name: 'player_id') final  int playerId;
@override@JsonKey(name: 'display_name') final  String displayName;
/// Visible in voting phase only.
@override@JsonKey(name: 'has_voted') final  bool hasVoted;

/// Create a copy of GamePlayer
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GamePlayerCopyWith<_GamePlayer> get copyWith => __$GamePlayerCopyWithImpl<_GamePlayer>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GamePlayerToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GamePlayer&&(identical(other.playerId, playerId) || other.playerId == playerId)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.hasVoted, hasVoted) || other.hasVoted == hasVoted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,playerId,displayName,hasVoted);

@override
String toString() {
  return 'GamePlayer(playerId: $playerId, displayName: $displayName, hasVoted: $hasVoted)';
}


}

/// @nodoc
abstract mixin class _$GamePlayerCopyWith<$Res> implements $GamePlayerCopyWith<$Res> {
  factory _$GamePlayerCopyWith(_GamePlayer value, $Res Function(_GamePlayer) _then) = __$GamePlayerCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'player_id') int playerId,@JsonKey(name: 'display_name') String displayName,@JsonKey(name: 'has_voted') bool hasVoted
});




}
/// @nodoc
class __$GamePlayerCopyWithImpl<$Res>
    implements _$GamePlayerCopyWith<$Res> {
  __$GamePlayerCopyWithImpl(this._self, this._then);

  final _GamePlayer _self;
  final $Res Function(_GamePlayer) _then;

/// Create a copy of GamePlayer
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? playerId = null,Object? displayName = null,Object? hasVoted = null,}) {
  return _then(_GamePlayer(
playerId: null == playerId ? _self.playerId : playerId // ignore: cast_nullable_to_non_nullable
as int,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,hasVoted: null == hasVoted ? _self.hasVoted : hasVoted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$YourRole {

@JsonKey(name: 'original_role') String get originalRole;@JsonKey(name: 'has_acted') bool get hasActed;/// Only available in results phase.
@JsonKey(name: 'current_role') String? get currentRole;
/// Create a copy of YourRole
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$YourRoleCopyWith<YourRole> get copyWith => _$YourRoleCopyWithImpl<YourRole>(this as YourRole, _$identity);

  /// Serializes this YourRole to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is YourRole&&(identical(other.originalRole, originalRole) || other.originalRole == originalRole)&&(identical(other.hasActed, hasActed) || other.hasActed == hasActed)&&(identical(other.currentRole, currentRole) || other.currentRole == currentRole));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,originalRole,hasActed,currentRole);

@override
String toString() {
  return 'YourRole(originalRole: $originalRole, hasActed: $hasActed, currentRole: $currentRole)';
}


}

/// @nodoc
abstract mixin class $YourRoleCopyWith<$Res>  {
  factory $YourRoleCopyWith(YourRole value, $Res Function(YourRole) _then) = _$YourRoleCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'original_role') String originalRole,@JsonKey(name: 'has_acted') bool hasActed,@JsonKey(name: 'current_role') String? currentRole
});




}
/// @nodoc
class _$YourRoleCopyWithImpl<$Res>
    implements $YourRoleCopyWith<$Res> {
  _$YourRoleCopyWithImpl(this._self, this._then);

  final YourRole _self;
  final $Res Function(YourRole) _then;

/// Create a copy of YourRole
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? originalRole = null,Object? hasActed = null,Object? currentRole = freezed,}) {
  return _then(_self.copyWith(
originalRole: null == originalRole ? _self.originalRole : originalRole // ignore: cast_nullable_to_non_nullable
as String,hasActed: null == hasActed ? _self.hasActed : hasActed // ignore: cast_nullable_to_non_nullable
as bool,currentRole: freezed == currentRole ? _self.currentRole : currentRole // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [YourRole].
extension YourRolePatterns on YourRole {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _YourRole value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _YourRole() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _YourRole value)  $default,){
final _that = this;
switch (_that) {
case _YourRole():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _YourRole value)?  $default,){
final _that = this;
switch (_that) {
case _YourRole() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'original_role')  String originalRole, @JsonKey(name: 'has_acted')  bool hasActed, @JsonKey(name: 'current_role')  String? currentRole)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _YourRole() when $default != null:
return $default(_that.originalRole,_that.hasActed,_that.currentRole);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'original_role')  String originalRole, @JsonKey(name: 'has_acted')  bool hasActed, @JsonKey(name: 'current_role')  String? currentRole)  $default,) {final _that = this;
switch (_that) {
case _YourRole():
return $default(_that.originalRole,_that.hasActed,_that.currentRole);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'original_role')  String originalRole, @JsonKey(name: 'has_acted')  bool hasActed, @JsonKey(name: 'current_role')  String? currentRole)?  $default,) {final _that = this;
switch (_that) {
case _YourRole() when $default != null:
return $default(_that.originalRole,_that.hasActed,_that.currentRole);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _YourRole implements YourRole {
  const _YourRole({@JsonKey(name: 'original_role') required this.originalRole, @JsonKey(name: 'has_acted') required this.hasActed, @JsonKey(name: 'current_role') this.currentRole});
  factory _YourRole.fromJson(Map<String, dynamic> json) => _$YourRoleFromJson(json);

@override@JsonKey(name: 'original_role') final  String originalRole;
@override@JsonKey(name: 'has_acted') final  bool hasActed;
/// Only available in results phase.
@override@JsonKey(name: 'current_role') final  String? currentRole;

/// Create a copy of YourRole
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$YourRoleCopyWith<_YourRole> get copyWith => __$YourRoleCopyWithImpl<_YourRole>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$YourRoleToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _YourRole&&(identical(other.originalRole, originalRole) || other.originalRole == originalRole)&&(identical(other.hasActed, hasActed) || other.hasActed == hasActed)&&(identical(other.currentRole, currentRole) || other.currentRole == currentRole));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,originalRole,hasActed,currentRole);

@override
String toString() {
  return 'YourRole(originalRole: $originalRole, hasActed: $hasActed, currentRole: $currentRole)';
}


}

/// @nodoc
abstract mixin class _$YourRoleCopyWith<$Res> implements $YourRoleCopyWith<$Res> {
  factory _$YourRoleCopyWith(_YourRole value, $Res Function(_YourRole) _then) = __$YourRoleCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'original_role') String originalRole,@JsonKey(name: 'has_acted') bool hasActed,@JsonKey(name: 'current_role') String? currentRole
});




}
/// @nodoc
class __$YourRoleCopyWithImpl<$Res>
    implements _$YourRoleCopyWith<$Res> {
  __$YourRoleCopyWithImpl(this._self, this._then);

  final _YourRole _self;
  final $Res Function(_YourRole) _then;

/// Create a copy of YourRole
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? originalRole = null,Object? hasActed = null,Object? currentRole = freezed,}) {
  return _then(_YourRole(
originalRole: null == originalRole ? _self.originalRole : originalRole // ignore: cast_nullable_to_non_nullable
as String,hasActed: null == hasActed ? _self.hasActed : hasActed // ignore: cast_nullable_to_non_nullable
as bool,currentRole: freezed == currentRole ? _self.currentRole : currentRole // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$GameSessionState {

@JsonKey(name: 'game_id') String get gameId; String get phase;@JsonKey(name: 'current_wave') int get currentWave; DateTime? get deadline;@JsonKey(name: 'your_role') YourRole get yourRole; List<GamePlayer> get players;@JsonKey(name: 'has_voted') bool get hasVoted;@JsonKey(name: 'action_prompt') ActionPrompt? get actionPrompt;@JsonKey(name: 'last_action_result') ActionResult? get lastActionResult;/// Frontend-only display state for the night phase sub-view.
@JsonKey(includeFromJson: false, includeToJson: false) NightSubView get nightSubView;/// Roles present in this game with their counts.
@JsonKey(name: 'roles_in_game') List<RoleInGame> get rolesInGame;/// Vote progress tracking during voting phase.
@JsonKey(includeFromJson: false, includeToJson: false) VoteProgress get voteProgress;/// Vote reveal data received after voting completes.
@JsonKey(includeFromJson: false, includeToJson: false) VoteRevealData? get voteRevealData;/// Full game results fetched from REST after game_results event.
@JsonKey(includeFromJson: false, includeToJson: false) GameResult? get results;/// Whether the current player is the game host (from server response).
@JsonKey(name: 'is_host') bool get isHost;
/// Create a copy of GameSessionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GameSessionStateCopyWith<GameSessionState> get copyWith => _$GameSessionStateCopyWithImpl<GameSessionState>(this as GameSessionState, _$identity);

  /// Serializes this GameSessionState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GameSessionState&&(identical(other.gameId, gameId) || other.gameId == gameId)&&(identical(other.phase, phase) || other.phase == phase)&&(identical(other.currentWave, currentWave) || other.currentWave == currentWave)&&(identical(other.deadline, deadline) || other.deadline == deadline)&&(identical(other.yourRole, yourRole) || other.yourRole == yourRole)&&const DeepCollectionEquality().equals(other.players, players)&&(identical(other.hasVoted, hasVoted) || other.hasVoted == hasVoted)&&(identical(other.actionPrompt, actionPrompt) || other.actionPrompt == actionPrompt)&&(identical(other.lastActionResult, lastActionResult) || other.lastActionResult == lastActionResult)&&(identical(other.nightSubView, nightSubView) || other.nightSubView == nightSubView)&&const DeepCollectionEquality().equals(other.rolesInGame, rolesInGame)&&(identical(other.voteProgress, voteProgress) || other.voteProgress == voteProgress)&&(identical(other.voteRevealData, voteRevealData) || other.voteRevealData == voteRevealData)&&(identical(other.results, results) || other.results == results)&&(identical(other.isHost, isHost) || other.isHost == isHost));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,gameId,phase,currentWave,deadline,yourRole,const DeepCollectionEquality().hash(players),hasVoted,actionPrompt,lastActionResult,nightSubView,const DeepCollectionEquality().hash(rolesInGame),voteProgress,voteRevealData,results,isHost);

@override
String toString() {
  return 'GameSessionState(gameId: $gameId, phase: $phase, currentWave: $currentWave, deadline: $deadline, yourRole: $yourRole, players: $players, hasVoted: $hasVoted, actionPrompt: $actionPrompt, lastActionResult: $lastActionResult, nightSubView: $nightSubView, rolesInGame: $rolesInGame, voteProgress: $voteProgress, voteRevealData: $voteRevealData, results: $results, isHost: $isHost)';
}


}

/// @nodoc
abstract mixin class $GameSessionStateCopyWith<$Res>  {
  factory $GameSessionStateCopyWith(GameSessionState value, $Res Function(GameSessionState) _then) = _$GameSessionStateCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'game_id') String gameId, String phase,@JsonKey(name: 'current_wave') int currentWave, DateTime? deadline,@JsonKey(name: 'your_role') YourRole yourRole, List<GamePlayer> players,@JsonKey(name: 'has_voted') bool hasVoted,@JsonKey(name: 'action_prompt') ActionPrompt? actionPrompt,@JsonKey(name: 'last_action_result') ActionResult? lastActionResult,@JsonKey(includeFromJson: false, includeToJson: false) NightSubView nightSubView,@JsonKey(name: 'roles_in_game') List<RoleInGame> rolesInGame,@JsonKey(includeFromJson: false, includeToJson: false) VoteProgress voteProgress,@JsonKey(includeFromJson: false, includeToJson: false) VoteRevealData? voteRevealData,@JsonKey(includeFromJson: false, includeToJson: false) GameResult? results,@JsonKey(name: 'is_host') bool isHost
});


$YourRoleCopyWith<$Res> get yourRole;$ActionPromptCopyWith<$Res>? get actionPrompt;$ActionResultCopyWith<$Res>? get lastActionResult;$VoteProgressCopyWith<$Res> get voteProgress;$VoteRevealDataCopyWith<$Res>? get voteRevealData;$GameResultCopyWith<$Res>? get results;

}
/// @nodoc
class _$GameSessionStateCopyWithImpl<$Res>
    implements $GameSessionStateCopyWith<$Res> {
  _$GameSessionStateCopyWithImpl(this._self, this._then);

  final GameSessionState _self;
  final $Res Function(GameSessionState) _then;

/// Create a copy of GameSessionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? gameId = null,Object? phase = null,Object? currentWave = null,Object? deadline = freezed,Object? yourRole = null,Object? players = null,Object? hasVoted = null,Object? actionPrompt = freezed,Object? lastActionResult = freezed,Object? nightSubView = null,Object? rolesInGame = null,Object? voteProgress = null,Object? voteRevealData = freezed,Object? results = freezed,Object? isHost = null,}) {
  return _then(_self.copyWith(
gameId: null == gameId ? _self.gameId : gameId // ignore: cast_nullable_to_non_nullable
as String,phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as String,currentWave: null == currentWave ? _self.currentWave : currentWave // ignore: cast_nullable_to_non_nullable
as int,deadline: freezed == deadline ? _self.deadline : deadline // ignore: cast_nullable_to_non_nullable
as DateTime?,yourRole: null == yourRole ? _self.yourRole : yourRole // ignore: cast_nullable_to_non_nullable
as YourRole,players: null == players ? _self.players : players // ignore: cast_nullable_to_non_nullable
as List<GamePlayer>,hasVoted: null == hasVoted ? _self.hasVoted : hasVoted // ignore: cast_nullable_to_non_nullable
as bool,actionPrompt: freezed == actionPrompt ? _self.actionPrompt : actionPrompt // ignore: cast_nullable_to_non_nullable
as ActionPrompt?,lastActionResult: freezed == lastActionResult ? _self.lastActionResult : lastActionResult // ignore: cast_nullable_to_non_nullable
as ActionResult?,nightSubView: null == nightSubView ? _self.nightSubView : nightSubView // ignore: cast_nullable_to_non_nullable
as NightSubView,rolesInGame: null == rolesInGame ? _self.rolesInGame : rolesInGame // ignore: cast_nullable_to_non_nullable
as List<RoleInGame>,voteProgress: null == voteProgress ? _self.voteProgress : voteProgress // ignore: cast_nullable_to_non_nullable
as VoteProgress,voteRevealData: freezed == voteRevealData ? _self.voteRevealData : voteRevealData // ignore: cast_nullable_to_non_nullable
as VoteRevealData?,results: freezed == results ? _self.results : results // ignore: cast_nullable_to_non_nullable
as GameResult?,isHost: null == isHost ? _self.isHost : isHost // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of GameSessionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$YourRoleCopyWith<$Res> get yourRole {
  
  return $YourRoleCopyWith<$Res>(_self.yourRole, (value) {
    return _then(_self.copyWith(yourRole: value));
  });
}/// Create a copy of GameSessionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ActionPromptCopyWith<$Res>? get actionPrompt {
    if (_self.actionPrompt == null) {
    return null;
  }

  return $ActionPromptCopyWith<$Res>(_self.actionPrompt!, (value) {
    return _then(_self.copyWith(actionPrompt: value));
  });
}/// Create a copy of GameSessionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ActionResultCopyWith<$Res>? get lastActionResult {
    if (_self.lastActionResult == null) {
    return null;
  }

  return $ActionResultCopyWith<$Res>(_self.lastActionResult!, (value) {
    return _then(_self.copyWith(lastActionResult: value));
  });
}/// Create a copy of GameSessionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VoteProgressCopyWith<$Res> get voteProgress {
  
  return $VoteProgressCopyWith<$Res>(_self.voteProgress, (value) {
    return _then(_self.copyWith(voteProgress: value));
  });
}/// Create a copy of GameSessionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VoteRevealDataCopyWith<$Res>? get voteRevealData {
    if (_self.voteRevealData == null) {
    return null;
  }

  return $VoteRevealDataCopyWith<$Res>(_self.voteRevealData!, (value) {
    return _then(_self.copyWith(voteRevealData: value));
  });
}/// Create a copy of GameSessionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GameResultCopyWith<$Res>? get results {
    if (_self.results == null) {
    return null;
  }

  return $GameResultCopyWith<$Res>(_self.results!, (value) {
    return _then(_self.copyWith(results: value));
  });
}
}


/// Adds pattern-matching-related methods to [GameSessionState].
extension GameSessionStatePatterns on GameSessionState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GameSessionState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GameSessionState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GameSessionState value)  $default,){
final _that = this;
switch (_that) {
case _GameSessionState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GameSessionState value)?  $default,){
final _that = this;
switch (_that) {
case _GameSessionState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'game_id')  String gameId,  String phase, @JsonKey(name: 'current_wave')  int currentWave,  DateTime? deadline, @JsonKey(name: 'your_role')  YourRole yourRole,  List<GamePlayer> players, @JsonKey(name: 'has_voted')  bool hasVoted, @JsonKey(name: 'action_prompt')  ActionPrompt? actionPrompt, @JsonKey(name: 'last_action_result')  ActionResult? lastActionResult, @JsonKey(includeFromJson: false, includeToJson: false)  NightSubView nightSubView, @JsonKey(name: 'roles_in_game')  List<RoleInGame> rolesInGame, @JsonKey(includeFromJson: false, includeToJson: false)  VoteProgress voteProgress, @JsonKey(includeFromJson: false, includeToJson: false)  VoteRevealData? voteRevealData, @JsonKey(includeFromJson: false, includeToJson: false)  GameResult? results, @JsonKey(name: 'is_host')  bool isHost)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GameSessionState() when $default != null:
return $default(_that.gameId,_that.phase,_that.currentWave,_that.deadline,_that.yourRole,_that.players,_that.hasVoted,_that.actionPrompt,_that.lastActionResult,_that.nightSubView,_that.rolesInGame,_that.voteProgress,_that.voteRevealData,_that.results,_that.isHost);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'game_id')  String gameId,  String phase, @JsonKey(name: 'current_wave')  int currentWave,  DateTime? deadline, @JsonKey(name: 'your_role')  YourRole yourRole,  List<GamePlayer> players, @JsonKey(name: 'has_voted')  bool hasVoted, @JsonKey(name: 'action_prompt')  ActionPrompt? actionPrompt, @JsonKey(name: 'last_action_result')  ActionResult? lastActionResult, @JsonKey(includeFromJson: false, includeToJson: false)  NightSubView nightSubView, @JsonKey(name: 'roles_in_game')  List<RoleInGame> rolesInGame, @JsonKey(includeFromJson: false, includeToJson: false)  VoteProgress voteProgress, @JsonKey(includeFromJson: false, includeToJson: false)  VoteRevealData? voteRevealData, @JsonKey(includeFromJson: false, includeToJson: false)  GameResult? results, @JsonKey(name: 'is_host')  bool isHost)  $default,) {final _that = this;
switch (_that) {
case _GameSessionState():
return $default(_that.gameId,_that.phase,_that.currentWave,_that.deadline,_that.yourRole,_that.players,_that.hasVoted,_that.actionPrompt,_that.lastActionResult,_that.nightSubView,_that.rolesInGame,_that.voteProgress,_that.voteRevealData,_that.results,_that.isHost);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'game_id')  String gameId,  String phase, @JsonKey(name: 'current_wave')  int currentWave,  DateTime? deadline, @JsonKey(name: 'your_role')  YourRole yourRole,  List<GamePlayer> players, @JsonKey(name: 'has_voted')  bool hasVoted, @JsonKey(name: 'action_prompt')  ActionPrompt? actionPrompt, @JsonKey(name: 'last_action_result')  ActionResult? lastActionResult, @JsonKey(includeFromJson: false, includeToJson: false)  NightSubView nightSubView, @JsonKey(name: 'roles_in_game')  List<RoleInGame> rolesInGame, @JsonKey(includeFromJson: false, includeToJson: false)  VoteProgress voteProgress, @JsonKey(includeFromJson: false, includeToJson: false)  VoteRevealData? voteRevealData, @JsonKey(includeFromJson: false, includeToJson: false)  GameResult? results, @JsonKey(name: 'is_host')  bool isHost)?  $default,) {final _that = this;
switch (_that) {
case _GameSessionState() when $default != null:
return $default(_that.gameId,_that.phase,_that.currentWave,_that.deadline,_that.yourRole,_that.players,_that.hasVoted,_that.actionPrompt,_that.lastActionResult,_that.nightSubView,_that.rolesInGame,_that.voteProgress,_that.voteRevealData,_that.results,_that.isHost);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GameSessionState implements GameSessionState {
  const _GameSessionState({@JsonKey(name: 'game_id') required this.gameId, required this.phase, @JsonKey(name: 'current_wave') this.currentWave = 0, this.deadline, @JsonKey(name: 'your_role') required this.yourRole, required final  List<GamePlayer> players, @JsonKey(name: 'has_voted') this.hasVoted = false, @JsonKey(name: 'action_prompt') this.actionPrompt, @JsonKey(name: 'last_action_result') this.lastActionResult, @JsonKey(includeFromJson: false, includeToJson: false) this.nightSubView = NightSubView.waiting, @JsonKey(name: 'roles_in_game') final  List<RoleInGame> rolesInGame = const [], @JsonKey(includeFromJson: false, includeToJson: false) this.voteProgress = const VoteProgress(), @JsonKey(includeFromJson: false, includeToJson: false) this.voteRevealData, @JsonKey(includeFromJson: false, includeToJson: false) this.results, @JsonKey(name: 'is_host') this.isHost = false}): _players = players,_rolesInGame = rolesInGame;
  factory _GameSessionState.fromJson(Map<String, dynamic> json) => _$GameSessionStateFromJson(json);

@override@JsonKey(name: 'game_id') final  String gameId;
@override final  String phase;
@override@JsonKey(name: 'current_wave') final  int currentWave;
@override final  DateTime? deadline;
@override@JsonKey(name: 'your_role') final  YourRole yourRole;
 final  List<GamePlayer> _players;
@override List<GamePlayer> get players {
  if (_players is EqualUnmodifiableListView) return _players;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_players);
}

@override@JsonKey(name: 'has_voted') final  bool hasVoted;
@override@JsonKey(name: 'action_prompt') final  ActionPrompt? actionPrompt;
@override@JsonKey(name: 'last_action_result') final  ActionResult? lastActionResult;
/// Frontend-only display state for the night phase sub-view.
@override@JsonKey(includeFromJson: false, includeToJson: false) final  NightSubView nightSubView;
/// Roles present in this game with their counts.
 final  List<RoleInGame> _rolesInGame;
/// Roles present in this game with their counts.
@override@JsonKey(name: 'roles_in_game') List<RoleInGame> get rolesInGame {
  if (_rolesInGame is EqualUnmodifiableListView) return _rolesInGame;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_rolesInGame);
}

/// Vote progress tracking during voting phase.
@override@JsonKey(includeFromJson: false, includeToJson: false) final  VoteProgress voteProgress;
/// Vote reveal data received after voting completes.
@override@JsonKey(includeFromJson: false, includeToJson: false) final  VoteRevealData? voteRevealData;
/// Full game results fetched from REST after game_results event.
@override@JsonKey(includeFromJson: false, includeToJson: false) final  GameResult? results;
/// Whether the current player is the game host (from server response).
@override@JsonKey(name: 'is_host') final  bool isHost;

/// Create a copy of GameSessionState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GameSessionStateCopyWith<_GameSessionState> get copyWith => __$GameSessionStateCopyWithImpl<_GameSessionState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GameSessionStateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GameSessionState&&(identical(other.gameId, gameId) || other.gameId == gameId)&&(identical(other.phase, phase) || other.phase == phase)&&(identical(other.currentWave, currentWave) || other.currentWave == currentWave)&&(identical(other.deadline, deadline) || other.deadline == deadline)&&(identical(other.yourRole, yourRole) || other.yourRole == yourRole)&&const DeepCollectionEquality().equals(other._players, _players)&&(identical(other.hasVoted, hasVoted) || other.hasVoted == hasVoted)&&(identical(other.actionPrompt, actionPrompt) || other.actionPrompt == actionPrompt)&&(identical(other.lastActionResult, lastActionResult) || other.lastActionResult == lastActionResult)&&(identical(other.nightSubView, nightSubView) || other.nightSubView == nightSubView)&&const DeepCollectionEquality().equals(other._rolesInGame, _rolesInGame)&&(identical(other.voteProgress, voteProgress) || other.voteProgress == voteProgress)&&(identical(other.voteRevealData, voteRevealData) || other.voteRevealData == voteRevealData)&&(identical(other.results, results) || other.results == results)&&(identical(other.isHost, isHost) || other.isHost == isHost));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,gameId,phase,currentWave,deadline,yourRole,const DeepCollectionEquality().hash(_players),hasVoted,actionPrompt,lastActionResult,nightSubView,const DeepCollectionEquality().hash(_rolesInGame),voteProgress,voteRevealData,results,isHost);

@override
String toString() {
  return 'GameSessionState(gameId: $gameId, phase: $phase, currentWave: $currentWave, deadline: $deadline, yourRole: $yourRole, players: $players, hasVoted: $hasVoted, actionPrompt: $actionPrompt, lastActionResult: $lastActionResult, nightSubView: $nightSubView, rolesInGame: $rolesInGame, voteProgress: $voteProgress, voteRevealData: $voteRevealData, results: $results, isHost: $isHost)';
}


}

/// @nodoc
abstract mixin class _$GameSessionStateCopyWith<$Res> implements $GameSessionStateCopyWith<$Res> {
  factory _$GameSessionStateCopyWith(_GameSessionState value, $Res Function(_GameSessionState) _then) = __$GameSessionStateCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'game_id') String gameId, String phase,@JsonKey(name: 'current_wave') int currentWave, DateTime? deadline,@JsonKey(name: 'your_role') YourRole yourRole, List<GamePlayer> players,@JsonKey(name: 'has_voted') bool hasVoted,@JsonKey(name: 'action_prompt') ActionPrompt? actionPrompt,@JsonKey(name: 'last_action_result') ActionResult? lastActionResult,@JsonKey(includeFromJson: false, includeToJson: false) NightSubView nightSubView,@JsonKey(name: 'roles_in_game') List<RoleInGame> rolesInGame,@JsonKey(includeFromJson: false, includeToJson: false) VoteProgress voteProgress,@JsonKey(includeFromJson: false, includeToJson: false) VoteRevealData? voteRevealData,@JsonKey(includeFromJson: false, includeToJson: false) GameResult? results,@JsonKey(name: 'is_host') bool isHost
});


@override $YourRoleCopyWith<$Res> get yourRole;@override $ActionPromptCopyWith<$Res>? get actionPrompt;@override $ActionResultCopyWith<$Res>? get lastActionResult;@override $VoteProgressCopyWith<$Res> get voteProgress;@override $VoteRevealDataCopyWith<$Res>? get voteRevealData;@override $GameResultCopyWith<$Res>? get results;

}
/// @nodoc
class __$GameSessionStateCopyWithImpl<$Res>
    implements _$GameSessionStateCopyWith<$Res> {
  __$GameSessionStateCopyWithImpl(this._self, this._then);

  final _GameSessionState _self;
  final $Res Function(_GameSessionState) _then;

/// Create a copy of GameSessionState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? gameId = null,Object? phase = null,Object? currentWave = null,Object? deadline = freezed,Object? yourRole = null,Object? players = null,Object? hasVoted = null,Object? actionPrompt = freezed,Object? lastActionResult = freezed,Object? nightSubView = null,Object? rolesInGame = null,Object? voteProgress = null,Object? voteRevealData = freezed,Object? results = freezed,Object? isHost = null,}) {
  return _then(_GameSessionState(
gameId: null == gameId ? _self.gameId : gameId // ignore: cast_nullable_to_non_nullable
as String,phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as String,currentWave: null == currentWave ? _self.currentWave : currentWave // ignore: cast_nullable_to_non_nullable
as int,deadline: freezed == deadline ? _self.deadline : deadline // ignore: cast_nullable_to_non_nullable
as DateTime?,yourRole: null == yourRole ? _self.yourRole : yourRole // ignore: cast_nullable_to_non_nullable
as YourRole,players: null == players ? _self._players : players // ignore: cast_nullable_to_non_nullable
as List<GamePlayer>,hasVoted: null == hasVoted ? _self.hasVoted : hasVoted // ignore: cast_nullable_to_non_nullable
as bool,actionPrompt: freezed == actionPrompt ? _self.actionPrompt : actionPrompt // ignore: cast_nullable_to_non_nullable
as ActionPrompt?,lastActionResult: freezed == lastActionResult ? _self.lastActionResult : lastActionResult // ignore: cast_nullable_to_non_nullable
as ActionResult?,nightSubView: null == nightSubView ? _self.nightSubView : nightSubView // ignore: cast_nullable_to_non_nullable
as NightSubView,rolesInGame: null == rolesInGame ? _self._rolesInGame : rolesInGame // ignore: cast_nullable_to_non_nullable
as List<RoleInGame>,voteProgress: null == voteProgress ? _self.voteProgress : voteProgress // ignore: cast_nullable_to_non_nullable
as VoteProgress,voteRevealData: freezed == voteRevealData ? _self.voteRevealData : voteRevealData // ignore: cast_nullable_to_non_nullable
as VoteRevealData?,results: freezed == results ? _self.results : results // ignore: cast_nullable_to_non_nullable
as GameResult?,isHost: null == isHost ? _self.isHost : isHost // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of GameSessionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$YourRoleCopyWith<$Res> get yourRole {
  
  return $YourRoleCopyWith<$Res>(_self.yourRole, (value) {
    return _then(_self.copyWith(yourRole: value));
  });
}/// Create a copy of GameSessionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ActionPromptCopyWith<$Res>? get actionPrompt {
    if (_self.actionPrompt == null) {
    return null;
  }

  return $ActionPromptCopyWith<$Res>(_self.actionPrompt!, (value) {
    return _then(_self.copyWith(actionPrompt: value));
  });
}/// Create a copy of GameSessionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ActionResultCopyWith<$Res>? get lastActionResult {
    if (_self.lastActionResult == null) {
    return null;
  }

  return $ActionResultCopyWith<$Res>(_self.lastActionResult!, (value) {
    return _then(_self.copyWith(lastActionResult: value));
  });
}/// Create a copy of GameSessionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VoteProgressCopyWith<$Res> get voteProgress {
  
  return $VoteProgressCopyWith<$Res>(_self.voteProgress, (value) {
    return _then(_self.copyWith(voteProgress: value));
  });
}/// Create a copy of GameSessionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VoteRevealDataCopyWith<$Res>? get voteRevealData {
    if (_self.voteRevealData == null) {
    return null;
  }

  return $VoteRevealDataCopyWith<$Res>(_self.voteRevealData!, (value) {
    return _then(_self.copyWith(voteRevealData: value));
  });
}/// Create a copy of GameSessionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GameResultCopyWith<$Res>? get results {
    if (_self.results == null) {
    return null;
  }

  return $GameResultCopyWith<$Res>(_self.results!, (value) {
    return _then(_self.copyWith(results: value));
  });
}
}

// dart format on
