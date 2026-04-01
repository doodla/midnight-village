// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'voting_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$VoteProgress {

/// Player ID to has-voted flag.
 Map<int, bool> get playerVoted;/// Whether the current player has submitted their vote.
 bool get currentPlayerVoted;
/// Create a copy of VoteProgress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VoteProgressCopyWith<VoteProgress> get copyWith => _$VoteProgressCopyWithImpl<VoteProgress>(this as VoteProgress, _$identity);

  /// Serializes this VoteProgress to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VoteProgress&&const DeepCollectionEquality().equals(other.playerVoted, playerVoted)&&(identical(other.currentPlayerVoted, currentPlayerVoted) || other.currentPlayerVoted == currentPlayerVoted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(playerVoted),currentPlayerVoted);

@override
String toString() {
  return 'VoteProgress(playerVoted: $playerVoted, currentPlayerVoted: $currentPlayerVoted)';
}


}

/// @nodoc
abstract mixin class $VoteProgressCopyWith<$Res>  {
  factory $VoteProgressCopyWith(VoteProgress value, $Res Function(VoteProgress) _then) = _$VoteProgressCopyWithImpl;
@useResult
$Res call({
 Map<int, bool> playerVoted, bool currentPlayerVoted
});




}
/// @nodoc
class _$VoteProgressCopyWithImpl<$Res>
    implements $VoteProgressCopyWith<$Res> {
  _$VoteProgressCopyWithImpl(this._self, this._then);

  final VoteProgress _self;
  final $Res Function(VoteProgress) _then;

/// Create a copy of VoteProgress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? playerVoted = null,Object? currentPlayerVoted = null,}) {
  return _then(_self.copyWith(
playerVoted: null == playerVoted ? _self.playerVoted : playerVoted // ignore: cast_nullable_to_non_nullable
as Map<int, bool>,currentPlayerVoted: null == currentPlayerVoted ? _self.currentPlayerVoted : currentPlayerVoted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [VoteProgress].
extension VoteProgressPatterns on VoteProgress {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VoteProgress value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VoteProgress() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VoteProgress value)  $default,){
final _that = this;
switch (_that) {
case _VoteProgress():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VoteProgress value)?  $default,){
final _that = this;
switch (_that) {
case _VoteProgress() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Map<int, bool> playerVoted,  bool currentPlayerVoted)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VoteProgress() when $default != null:
return $default(_that.playerVoted,_that.currentPlayerVoted);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Map<int, bool> playerVoted,  bool currentPlayerVoted)  $default,) {final _that = this;
switch (_that) {
case _VoteProgress():
return $default(_that.playerVoted,_that.currentPlayerVoted);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Map<int, bool> playerVoted,  bool currentPlayerVoted)?  $default,) {final _that = this;
switch (_that) {
case _VoteProgress() when $default != null:
return $default(_that.playerVoted,_that.currentPlayerVoted);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VoteProgress implements VoteProgress {
  const _VoteProgress({final  Map<int, bool> playerVoted = const {}, this.currentPlayerVoted = false}): _playerVoted = playerVoted;
  factory _VoteProgress.fromJson(Map<String, dynamic> json) => _$VoteProgressFromJson(json);

/// Player ID to has-voted flag.
 final  Map<int, bool> _playerVoted;
/// Player ID to has-voted flag.
@override@JsonKey() Map<int, bool> get playerVoted {
  if (_playerVoted is EqualUnmodifiableMapView) return _playerVoted;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_playerVoted);
}

/// Whether the current player has submitted their vote.
@override@JsonKey() final  bool currentPlayerVoted;

/// Create a copy of VoteProgress
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VoteProgressCopyWith<_VoteProgress> get copyWith => __$VoteProgressCopyWithImpl<_VoteProgress>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VoteProgressToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VoteProgress&&const DeepCollectionEquality().equals(other._playerVoted, _playerVoted)&&(identical(other.currentPlayerVoted, currentPlayerVoted) || other.currentPlayerVoted == currentPlayerVoted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_playerVoted),currentPlayerVoted);

@override
String toString() {
  return 'VoteProgress(playerVoted: $playerVoted, currentPlayerVoted: $currentPlayerVoted)';
}


}

/// @nodoc
abstract mixin class _$VoteProgressCopyWith<$Res> implements $VoteProgressCopyWith<$Res> {
  factory _$VoteProgressCopyWith(_VoteProgress value, $Res Function(_VoteProgress) _then) = __$VoteProgressCopyWithImpl;
@override @useResult
$Res call({
 Map<int, bool> playerVoted, bool currentPlayerVoted
});




}
/// @nodoc
class __$VoteProgressCopyWithImpl<$Res>
    implements _$VoteProgressCopyWith<$Res> {
  __$VoteProgressCopyWithImpl(this._self, this._then);

  final _VoteProgress _self;
  final $Res Function(_VoteProgress) _then;

/// Create a copy of VoteProgress
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? playerVoted = null,Object? currentPlayerVoted = null,}) {
  return _then(_VoteProgress(
playerVoted: null == playerVoted ? _self._playerVoted : playerVoted // ignore: cast_nullable_to_non_nullable
as Map<int, bool>,currentPlayerVoted: null == currentPlayerVoted ? _self.currentPlayerVoted : currentPlayerVoted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$VoteRevealData {

/// Voter player ID (as string) to target player ID. Null value means abstain.
 Map<String, int?> get votes;/// Player name to vote count.
 Map<String, int> get tally;
/// Create a copy of VoteRevealData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VoteRevealDataCopyWith<VoteRevealData> get copyWith => _$VoteRevealDataCopyWithImpl<VoteRevealData>(this as VoteRevealData, _$identity);

  /// Serializes this VoteRevealData to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VoteRevealData&&const DeepCollectionEquality().equals(other.votes, votes)&&const DeepCollectionEquality().equals(other.tally, tally));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(votes),const DeepCollectionEquality().hash(tally));

@override
String toString() {
  return 'VoteRevealData(votes: $votes, tally: $tally)';
}


}

/// @nodoc
abstract mixin class $VoteRevealDataCopyWith<$Res>  {
  factory $VoteRevealDataCopyWith(VoteRevealData value, $Res Function(VoteRevealData) _then) = _$VoteRevealDataCopyWithImpl;
@useResult
$Res call({
 Map<String, int?> votes, Map<String, int> tally
});




}
/// @nodoc
class _$VoteRevealDataCopyWithImpl<$Res>
    implements $VoteRevealDataCopyWith<$Res> {
  _$VoteRevealDataCopyWithImpl(this._self, this._then);

  final VoteRevealData _self;
  final $Res Function(VoteRevealData) _then;

/// Create a copy of VoteRevealData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? votes = null,Object? tally = null,}) {
  return _then(_self.copyWith(
votes: null == votes ? _self.votes : votes // ignore: cast_nullable_to_non_nullable
as Map<String, int?>,tally: null == tally ? _self.tally : tally // ignore: cast_nullable_to_non_nullable
as Map<String, int>,
  ));
}

}


/// Adds pattern-matching-related methods to [VoteRevealData].
extension VoteRevealDataPatterns on VoteRevealData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VoteRevealData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VoteRevealData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VoteRevealData value)  $default,){
final _that = this;
switch (_that) {
case _VoteRevealData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VoteRevealData value)?  $default,){
final _that = this;
switch (_that) {
case _VoteRevealData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Map<String, int?> votes,  Map<String, int> tally)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VoteRevealData() when $default != null:
return $default(_that.votes,_that.tally);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Map<String, int?> votes,  Map<String, int> tally)  $default,) {final _that = this;
switch (_that) {
case _VoteRevealData():
return $default(_that.votes,_that.tally);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Map<String, int?> votes,  Map<String, int> tally)?  $default,) {final _that = this;
switch (_that) {
case _VoteRevealData() when $default != null:
return $default(_that.votes,_that.tally);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VoteRevealData implements VoteRevealData {
  const _VoteRevealData({required final  Map<String, int?> votes, required final  Map<String, int> tally}): _votes = votes,_tally = tally;
  factory _VoteRevealData.fromJson(Map<String, dynamic> json) => _$VoteRevealDataFromJson(json);

/// Voter player ID (as string) to target player ID. Null value means abstain.
 final  Map<String, int?> _votes;
/// Voter player ID (as string) to target player ID. Null value means abstain.
@override Map<String, int?> get votes {
  if (_votes is EqualUnmodifiableMapView) return _votes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_votes);
}

/// Player name to vote count.
 final  Map<String, int> _tally;
/// Player name to vote count.
@override Map<String, int> get tally {
  if (_tally is EqualUnmodifiableMapView) return _tally;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_tally);
}


/// Create a copy of VoteRevealData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VoteRevealDataCopyWith<_VoteRevealData> get copyWith => __$VoteRevealDataCopyWithImpl<_VoteRevealData>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VoteRevealDataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VoteRevealData&&const DeepCollectionEquality().equals(other._votes, _votes)&&const DeepCollectionEquality().equals(other._tally, _tally));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_votes),const DeepCollectionEquality().hash(_tally));

@override
String toString() {
  return 'VoteRevealData(votes: $votes, tally: $tally)';
}


}

/// @nodoc
abstract mixin class _$VoteRevealDataCopyWith<$Res> implements $VoteRevealDataCopyWith<$Res> {
  factory _$VoteRevealDataCopyWith(_VoteRevealData value, $Res Function(_VoteRevealData) _then) = __$VoteRevealDataCopyWithImpl;
@override @useResult
$Res call({
 Map<String, int?> votes, Map<String, int> tally
});




}
/// @nodoc
class __$VoteRevealDataCopyWithImpl<$Res>
    implements _$VoteRevealDataCopyWith<$Res> {
  __$VoteRevealDataCopyWithImpl(this._self, this._then);

  final _VoteRevealData _self;
  final $Res Function(_VoteRevealData) _then;

/// Create a copy of VoteRevealData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? votes = null,Object? tally = null,}) {
  return _then(_VoteRevealData(
votes: null == votes ? _self._votes : votes // ignore: cast_nullable_to_non_nullable
as Map<String, int?>,tally: null == tally ? _self._tally : tally // ignore: cast_nullable_to_non_nullable
as Map<String, int>,
  ));
}


}

// dart format on
