// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'player_display.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PlayerDisplay {

 String get id; String get displayName; bool get isCurrentPlayer; bool get isSelectable; bool get isSelected; PlayerStatus get status;
/// Create a copy of PlayerDisplay
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlayerDisplayCopyWith<PlayerDisplay> get copyWith => _$PlayerDisplayCopyWithImpl<PlayerDisplay>(this as PlayerDisplay, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlayerDisplay&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.isCurrentPlayer, isCurrentPlayer) || other.isCurrentPlayer == isCurrentPlayer)&&(identical(other.isSelectable, isSelectable) || other.isSelectable == isSelectable)&&(identical(other.isSelected, isSelected) || other.isSelected == isSelected)&&(identical(other.status, status) || other.status == status));
}


@override
int get hashCode => Object.hash(runtimeType,id,displayName,isCurrentPlayer,isSelectable,isSelected,status);

@override
String toString() {
  return 'PlayerDisplay(id: $id, displayName: $displayName, isCurrentPlayer: $isCurrentPlayer, isSelectable: $isSelectable, isSelected: $isSelected, status: $status)';
}


}

/// @nodoc
abstract mixin class $PlayerDisplayCopyWith<$Res>  {
  factory $PlayerDisplayCopyWith(PlayerDisplay value, $Res Function(PlayerDisplay) _then) = _$PlayerDisplayCopyWithImpl;
@useResult
$Res call({
 String id, String displayName, bool isCurrentPlayer, bool isSelectable, bool isSelected, PlayerStatus status
});




}
/// @nodoc
class _$PlayerDisplayCopyWithImpl<$Res>
    implements $PlayerDisplayCopyWith<$Res> {
  _$PlayerDisplayCopyWithImpl(this._self, this._then);

  final PlayerDisplay _self;
  final $Res Function(PlayerDisplay) _then;

/// Create a copy of PlayerDisplay
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? displayName = null,Object? isCurrentPlayer = null,Object? isSelectable = null,Object? isSelected = null,Object? status = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,isCurrentPlayer: null == isCurrentPlayer ? _self.isCurrentPlayer : isCurrentPlayer // ignore: cast_nullable_to_non_nullable
as bool,isSelectable: null == isSelectable ? _self.isSelectable : isSelectable // ignore: cast_nullable_to_non_nullable
as bool,isSelected: null == isSelected ? _self.isSelected : isSelected // ignore: cast_nullable_to_non_nullable
as bool,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as PlayerStatus,
  ));
}

}


/// Adds pattern-matching-related methods to [PlayerDisplay].
extension PlayerDisplayPatterns on PlayerDisplay {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlayerDisplay value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlayerDisplay() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlayerDisplay value)  $default,){
final _that = this;
switch (_that) {
case _PlayerDisplay():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlayerDisplay value)?  $default,){
final _that = this;
switch (_that) {
case _PlayerDisplay() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String displayName,  bool isCurrentPlayer,  bool isSelectable,  bool isSelected,  PlayerStatus status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlayerDisplay() when $default != null:
return $default(_that.id,_that.displayName,_that.isCurrentPlayer,_that.isSelectable,_that.isSelected,_that.status);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String displayName,  bool isCurrentPlayer,  bool isSelectable,  bool isSelected,  PlayerStatus status)  $default,) {final _that = this;
switch (_that) {
case _PlayerDisplay():
return $default(_that.id,_that.displayName,_that.isCurrentPlayer,_that.isSelectable,_that.isSelected,_that.status);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String displayName,  bool isCurrentPlayer,  bool isSelectable,  bool isSelected,  PlayerStatus status)?  $default,) {final _that = this;
switch (_that) {
case _PlayerDisplay() when $default != null:
return $default(_that.id,_that.displayName,_that.isCurrentPlayer,_that.isSelectable,_that.isSelected,_that.status);case _:
  return null;

}
}

}

/// @nodoc


class _PlayerDisplay implements PlayerDisplay {
  const _PlayerDisplay({required this.id, required this.displayName, this.isCurrentPlayer = false, this.isSelectable = true, this.isSelected = false, this.status = PlayerStatus.active});
  

@override final  String id;
@override final  String displayName;
@override@JsonKey() final  bool isCurrentPlayer;
@override@JsonKey() final  bool isSelectable;
@override@JsonKey() final  bool isSelected;
@override@JsonKey() final  PlayerStatus status;

/// Create a copy of PlayerDisplay
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlayerDisplayCopyWith<_PlayerDisplay> get copyWith => __$PlayerDisplayCopyWithImpl<_PlayerDisplay>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlayerDisplay&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.isCurrentPlayer, isCurrentPlayer) || other.isCurrentPlayer == isCurrentPlayer)&&(identical(other.isSelectable, isSelectable) || other.isSelectable == isSelectable)&&(identical(other.isSelected, isSelected) || other.isSelected == isSelected)&&(identical(other.status, status) || other.status == status));
}


@override
int get hashCode => Object.hash(runtimeType,id,displayName,isCurrentPlayer,isSelectable,isSelected,status);

@override
String toString() {
  return 'PlayerDisplay(id: $id, displayName: $displayName, isCurrentPlayer: $isCurrentPlayer, isSelectable: $isSelectable, isSelected: $isSelected, status: $status)';
}


}

/// @nodoc
abstract mixin class _$PlayerDisplayCopyWith<$Res> implements $PlayerDisplayCopyWith<$Res> {
  factory _$PlayerDisplayCopyWith(_PlayerDisplay value, $Res Function(_PlayerDisplay) _then) = __$PlayerDisplayCopyWithImpl;
@override @useResult
$Res call({
 String id, String displayName, bool isCurrentPlayer, bool isSelectable, bool isSelected, PlayerStatus status
});




}
/// @nodoc
class __$PlayerDisplayCopyWithImpl<$Res>
    implements _$PlayerDisplayCopyWith<$Res> {
  __$PlayerDisplayCopyWithImpl(this._self, this._then);

  final _PlayerDisplay _self;
  final $Res Function(_PlayerDisplay) _then;

/// Create a copy of PlayerDisplay
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? displayName = null,Object? isCurrentPlayer = null,Object? isSelectable = null,Object? isSelected = null,Object? status = null,}) {
  return _then(_PlayerDisplay(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,isCurrentPlayer: null == isCurrentPlayer ? _self.isCurrentPlayer : isCurrentPlayer // ignore: cast_nullable_to_non_nullable
as bool,isSelectable: null == isSelectable ? _self.isSelectable : isSelectable // ignore: cast_nullable_to_non_nullable
as bool,isSelected: null == isSelected ? _self.isSelected : isSelected // ignore: cast_nullable_to_non_nullable
as bool,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as PlayerStatus,
  ));
}


}

// dart format on
