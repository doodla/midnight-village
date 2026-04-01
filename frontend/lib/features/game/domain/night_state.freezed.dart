// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'night_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ActionPrompt {

/// Display name for the role identity strip (important for Doppelganger).
@JsonKey(name: 'role_acting_as') String get roleActingAs;/// Available action types, e.g. ["peek_player", "peek_center"].
@JsonKey(name: 'action_types') List<String> get actionTypes;/// Valid targets per action type.
@JsonKey(name: 'valid_targets') Map<String, dynamic> get validTargets;/// The wave this prompt belongs to.
 int get wave;
/// Create a copy of ActionPrompt
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ActionPromptCopyWith<ActionPrompt> get copyWith => _$ActionPromptCopyWithImpl<ActionPrompt>(this as ActionPrompt, _$identity);

  /// Serializes this ActionPrompt to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ActionPrompt&&(identical(other.roleActingAs, roleActingAs) || other.roleActingAs == roleActingAs)&&const DeepCollectionEquality().equals(other.actionTypes, actionTypes)&&const DeepCollectionEquality().equals(other.validTargets, validTargets)&&(identical(other.wave, wave) || other.wave == wave));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,roleActingAs,const DeepCollectionEquality().hash(actionTypes),const DeepCollectionEquality().hash(validTargets),wave);

@override
String toString() {
  return 'ActionPrompt(roleActingAs: $roleActingAs, actionTypes: $actionTypes, validTargets: $validTargets, wave: $wave)';
}


}

/// @nodoc
abstract mixin class $ActionPromptCopyWith<$Res>  {
  factory $ActionPromptCopyWith(ActionPrompt value, $Res Function(ActionPrompt) _then) = _$ActionPromptCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'role_acting_as') String roleActingAs,@JsonKey(name: 'action_types') List<String> actionTypes,@JsonKey(name: 'valid_targets') Map<String, dynamic> validTargets, int wave
});




}
/// @nodoc
class _$ActionPromptCopyWithImpl<$Res>
    implements $ActionPromptCopyWith<$Res> {
  _$ActionPromptCopyWithImpl(this._self, this._then);

  final ActionPrompt _self;
  final $Res Function(ActionPrompt) _then;

/// Create a copy of ActionPrompt
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? roleActingAs = null,Object? actionTypes = null,Object? validTargets = null,Object? wave = null,}) {
  return _then(_self.copyWith(
roleActingAs: null == roleActingAs ? _self.roleActingAs : roleActingAs // ignore: cast_nullable_to_non_nullable
as String,actionTypes: null == actionTypes ? _self.actionTypes : actionTypes // ignore: cast_nullable_to_non_nullable
as List<String>,validTargets: null == validTargets ? _self.validTargets : validTargets // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,wave: null == wave ? _self.wave : wave // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ActionPrompt].
extension ActionPromptPatterns on ActionPrompt {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ActionPrompt value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ActionPrompt() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ActionPrompt value)  $default,){
final _that = this;
switch (_that) {
case _ActionPrompt():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ActionPrompt value)?  $default,){
final _that = this;
switch (_that) {
case _ActionPrompt() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'role_acting_as')  String roleActingAs, @JsonKey(name: 'action_types')  List<String> actionTypes, @JsonKey(name: 'valid_targets')  Map<String, dynamic> validTargets,  int wave)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ActionPrompt() when $default != null:
return $default(_that.roleActingAs,_that.actionTypes,_that.validTargets,_that.wave);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'role_acting_as')  String roleActingAs, @JsonKey(name: 'action_types')  List<String> actionTypes, @JsonKey(name: 'valid_targets')  Map<String, dynamic> validTargets,  int wave)  $default,) {final _that = this;
switch (_that) {
case _ActionPrompt():
return $default(_that.roleActingAs,_that.actionTypes,_that.validTargets,_that.wave);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'role_acting_as')  String roleActingAs, @JsonKey(name: 'action_types')  List<String> actionTypes, @JsonKey(name: 'valid_targets')  Map<String, dynamic> validTargets,  int wave)?  $default,) {final _that = this;
switch (_that) {
case _ActionPrompt() when $default != null:
return $default(_that.roleActingAs,_that.actionTypes,_that.validTargets,_that.wave);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ActionPrompt implements ActionPrompt {
  const _ActionPrompt({@JsonKey(name: 'role_acting_as') required this.roleActingAs, @JsonKey(name: 'action_types') required final  List<String> actionTypes, @JsonKey(name: 'valid_targets') required final  Map<String, dynamic> validTargets, required this.wave}): _actionTypes = actionTypes,_validTargets = validTargets;
  factory _ActionPrompt.fromJson(Map<String, dynamic> json) => _$ActionPromptFromJson(json);

/// Display name for the role identity strip (important for Doppelganger).
@override@JsonKey(name: 'role_acting_as') final  String roleActingAs;
/// Available action types, e.g. ["peek_player", "peek_center"].
 final  List<String> _actionTypes;
/// Available action types, e.g. ["peek_player", "peek_center"].
@override@JsonKey(name: 'action_types') List<String> get actionTypes {
  if (_actionTypes is EqualUnmodifiableListView) return _actionTypes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_actionTypes);
}

/// Valid targets per action type.
 final  Map<String, dynamic> _validTargets;
/// Valid targets per action type.
@override@JsonKey(name: 'valid_targets') Map<String, dynamic> get validTargets {
  if (_validTargets is EqualUnmodifiableMapView) return _validTargets;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_validTargets);
}

/// The wave this prompt belongs to.
@override final  int wave;

/// Create a copy of ActionPrompt
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ActionPromptCopyWith<_ActionPrompt> get copyWith => __$ActionPromptCopyWithImpl<_ActionPrompt>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ActionPromptToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ActionPrompt&&(identical(other.roleActingAs, roleActingAs) || other.roleActingAs == roleActingAs)&&const DeepCollectionEquality().equals(other._actionTypes, _actionTypes)&&const DeepCollectionEquality().equals(other._validTargets, _validTargets)&&(identical(other.wave, wave) || other.wave == wave));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,roleActingAs,const DeepCollectionEquality().hash(_actionTypes),const DeepCollectionEquality().hash(_validTargets),wave);

@override
String toString() {
  return 'ActionPrompt(roleActingAs: $roleActingAs, actionTypes: $actionTypes, validTargets: $validTargets, wave: $wave)';
}


}

/// @nodoc
abstract mixin class _$ActionPromptCopyWith<$Res> implements $ActionPromptCopyWith<$Res> {
  factory _$ActionPromptCopyWith(_ActionPrompt value, $Res Function(_ActionPrompt) _then) = __$ActionPromptCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'role_acting_as') String roleActingAs,@JsonKey(name: 'action_types') List<String> actionTypes,@JsonKey(name: 'valid_targets') Map<String, dynamic> validTargets, int wave
});




}
/// @nodoc
class __$ActionPromptCopyWithImpl<$Res>
    implements _$ActionPromptCopyWith<$Res> {
  __$ActionPromptCopyWithImpl(this._self, this._then);

  final _ActionPrompt _self;
  final $Res Function(_ActionPrompt) _then;

/// Create a copy of ActionPrompt
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? roleActingAs = null,Object? actionTypes = null,Object? validTargets = null,Object? wave = null,}) {
  return _then(_ActionPrompt(
roleActingAs: null == roleActingAs ? _self.roleActingAs : roleActingAs // ignore: cast_nullable_to_non_nullable
as String,actionTypes: null == actionTypes ? _self._actionTypes : actionTypes // ignore: cast_nullable_to_non_nullable
as List<String>,validTargets: null == validTargets ? _self._validTargets : validTargets // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,wave: null == wave ? _self.wave : wave // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$ActionResult {

/// The wave this result belongs to.
 int get wave;/// Revealed information -- structure varies by action type.
@JsonKey(name: 'revealed_info') Map<String, dynamic> get revealedInfo;
/// Create a copy of ActionResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ActionResultCopyWith<ActionResult> get copyWith => _$ActionResultCopyWithImpl<ActionResult>(this as ActionResult, _$identity);

  /// Serializes this ActionResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ActionResult&&(identical(other.wave, wave) || other.wave == wave)&&const DeepCollectionEquality().equals(other.revealedInfo, revealedInfo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,wave,const DeepCollectionEquality().hash(revealedInfo));

@override
String toString() {
  return 'ActionResult(wave: $wave, revealedInfo: $revealedInfo)';
}


}

/// @nodoc
abstract mixin class $ActionResultCopyWith<$Res>  {
  factory $ActionResultCopyWith(ActionResult value, $Res Function(ActionResult) _then) = _$ActionResultCopyWithImpl;
@useResult
$Res call({
 int wave,@JsonKey(name: 'revealed_info') Map<String, dynamic> revealedInfo
});




}
/// @nodoc
class _$ActionResultCopyWithImpl<$Res>
    implements $ActionResultCopyWith<$Res> {
  _$ActionResultCopyWithImpl(this._self, this._then);

  final ActionResult _self;
  final $Res Function(ActionResult) _then;

/// Create a copy of ActionResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? wave = null,Object? revealedInfo = null,}) {
  return _then(_self.copyWith(
wave: null == wave ? _self.wave : wave // ignore: cast_nullable_to_non_nullable
as int,revealedInfo: null == revealedInfo ? _self.revealedInfo : revealedInfo // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}

}


/// Adds pattern-matching-related methods to [ActionResult].
extension ActionResultPatterns on ActionResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ActionResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ActionResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ActionResult value)  $default,){
final _that = this;
switch (_that) {
case _ActionResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ActionResult value)?  $default,){
final _that = this;
switch (_that) {
case _ActionResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int wave, @JsonKey(name: 'revealed_info')  Map<String, dynamic> revealedInfo)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ActionResult() when $default != null:
return $default(_that.wave,_that.revealedInfo);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int wave, @JsonKey(name: 'revealed_info')  Map<String, dynamic> revealedInfo)  $default,) {final _that = this;
switch (_that) {
case _ActionResult():
return $default(_that.wave,_that.revealedInfo);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int wave, @JsonKey(name: 'revealed_info')  Map<String, dynamic> revealedInfo)?  $default,) {final _that = this;
switch (_that) {
case _ActionResult() when $default != null:
return $default(_that.wave,_that.revealedInfo);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ActionResult implements ActionResult {
  const _ActionResult({required this.wave, @JsonKey(name: 'revealed_info') required final  Map<String, dynamic> revealedInfo}): _revealedInfo = revealedInfo;
  factory _ActionResult.fromJson(Map<String, dynamic> json) => _$ActionResultFromJson(json);

/// The wave this result belongs to.
@override final  int wave;
/// Revealed information -- structure varies by action type.
 final  Map<String, dynamic> _revealedInfo;
/// Revealed information -- structure varies by action type.
@override@JsonKey(name: 'revealed_info') Map<String, dynamic> get revealedInfo {
  if (_revealedInfo is EqualUnmodifiableMapView) return _revealedInfo;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_revealedInfo);
}


/// Create a copy of ActionResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ActionResultCopyWith<_ActionResult> get copyWith => __$ActionResultCopyWithImpl<_ActionResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ActionResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ActionResult&&(identical(other.wave, wave) || other.wave == wave)&&const DeepCollectionEquality().equals(other._revealedInfo, _revealedInfo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,wave,const DeepCollectionEquality().hash(_revealedInfo));

@override
String toString() {
  return 'ActionResult(wave: $wave, revealedInfo: $revealedInfo)';
}


}

/// @nodoc
abstract mixin class _$ActionResultCopyWith<$Res> implements $ActionResultCopyWith<$Res> {
  factory _$ActionResultCopyWith(_ActionResult value, $Res Function(_ActionResult) _then) = __$ActionResultCopyWithImpl;
@override @useResult
$Res call({
 int wave,@JsonKey(name: 'revealed_info') Map<String, dynamic> revealedInfo
});




}
/// @nodoc
class __$ActionResultCopyWithImpl<$Res>
    implements _$ActionResultCopyWith<$Res> {
  __$ActionResultCopyWithImpl(this._self, this._then);

  final _ActionResult _self;
  final $Res Function(_ActionResult) _then;

/// Create a copy of ActionResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? wave = null,Object? revealedInfo = null,}) {
  return _then(_ActionResult(
wave: null == wave ? _self.wave : wave // ignore: cast_nullable_to_non_nullable
as int,revealedInfo: null == revealedInfo ? _self._revealedInfo : revealedInfo // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}


}


/// @nodoc
mixin _$RoleInGame {

 String get role; int get count;
/// Create a copy of RoleInGame
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RoleInGameCopyWith<RoleInGame> get copyWith => _$RoleInGameCopyWithImpl<RoleInGame>(this as RoleInGame, _$identity);

  /// Serializes this RoleInGame to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RoleInGame&&(identical(other.role, role) || other.role == role)&&(identical(other.count, count) || other.count == count));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,role,count);

@override
String toString() {
  return 'RoleInGame(role: $role, count: $count)';
}


}

/// @nodoc
abstract mixin class $RoleInGameCopyWith<$Res>  {
  factory $RoleInGameCopyWith(RoleInGame value, $Res Function(RoleInGame) _then) = _$RoleInGameCopyWithImpl;
@useResult
$Res call({
 String role, int count
});




}
/// @nodoc
class _$RoleInGameCopyWithImpl<$Res>
    implements $RoleInGameCopyWith<$Res> {
  _$RoleInGameCopyWithImpl(this._self, this._then);

  final RoleInGame _self;
  final $Res Function(RoleInGame) _then;

/// Create a copy of RoleInGame
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? role = null,Object? count = null,}) {
  return _then(_self.copyWith(
role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [RoleInGame].
extension RoleInGamePatterns on RoleInGame {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RoleInGame value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RoleInGame() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RoleInGame value)  $default,){
final _that = this;
switch (_that) {
case _RoleInGame():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RoleInGame value)?  $default,){
final _that = this;
switch (_that) {
case _RoleInGame() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String role,  int count)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RoleInGame() when $default != null:
return $default(_that.role,_that.count);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String role,  int count)  $default,) {final _that = this;
switch (_that) {
case _RoleInGame():
return $default(_that.role,_that.count);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String role,  int count)?  $default,) {final _that = this;
switch (_that) {
case _RoleInGame() when $default != null:
return $default(_that.role,_that.count);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RoleInGame implements RoleInGame {
  const _RoleInGame({required this.role, required this.count});
  factory _RoleInGame.fromJson(Map<String, dynamic> json) => _$RoleInGameFromJson(json);

@override final  String role;
@override final  int count;

/// Create a copy of RoleInGame
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RoleInGameCopyWith<_RoleInGame> get copyWith => __$RoleInGameCopyWithImpl<_RoleInGame>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RoleInGameToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RoleInGame&&(identical(other.role, role) || other.role == role)&&(identical(other.count, count) || other.count == count));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,role,count);

@override
String toString() {
  return 'RoleInGame(role: $role, count: $count)';
}


}

/// @nodoc
abstract mixin class _$RoleInGameCopyWith<$Res> implements $RoleInGameCopyWith<$Res> {
  factory _$RoleInGameCopyWith(_RoleInGame value, $Res Function(_RoleInGame) _then) = __$RoleInGameCopyWithImpl;
@override @useResult
$Res call({
 String role, int count
});




}
/// @nodoc
class __$RoleInGameCopyWithImpl<$Res>
    implements _$RoleInGameCopyWith<$Res> {
  __$RoleInGameCopyWithImpl(this._self, this._then);

  final _RoleInGame _self;
  final $Res Function(_RoleInGame) _then;

/// Create a copy of RoleInGame
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? role = null,Object? count = null,}) {
  return _then(_RoleInGame(
role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
