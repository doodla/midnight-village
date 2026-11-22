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

 int get id; String get displayName; DateTime get joinedAt;/// The seat token (public table identity); null for a token this app
/// does not know, or the blank one a member past the tenth may have.
 TokenId? get token;/// Whether the member's phone is at the table (`connected`; still true
/// during the table's grace period after a drop). False is a dropped
/// phone: its row is dimmed, with no words.
 bool get connected;
/// Create a copy of LobbyPlayer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LobbyPlayerCopyWith<LobbyPlayer> get copyWith => _$LobbyPlayerCopyWithImpl<LobbyPlayer>(this as LobbyPlayer, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LobbyPlayer&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt)&&(identical(other.token, token) || other.token == token)&&(identical(other.connected, connected) || other.connected == connected));
}


@override
int get hashCode => Object.hash(runtimeType,id,displayName,joinedAt,token,connected);

@override
String toString() {
  return 'LobbyPlayer(id: $id, displayName: $displayName, joinedAt: $joinedAt, token: $token, connected: $connected)';
}


}

/// @nodoc
abstract mixin class $LobbyPlayerCopyWith<$Res>  {
  factory $LobbyPlayerCopyWith(LobbyPlayer value, $Res Function(LobbyPlayer) _then) = _$LobbyPlayerCopyWithImpl;
@useResult
$Res call({
 int id, String displayName, DateTime joinedAt, TokenId? token, bool connected
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? displayName = null,Object? joinedAt = null,Object? token = freezed,Object? connected = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,joinedAt: null == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as DateTime,token: freezed == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as TokenId?,connected: null == connected ? _self.connected : connected // ignore: cast_nullable_to_non_nullable
as bool,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String displayName,  DateTime joinedAt,  TokenId? token,  bool connected)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LobbyPlayer() when $default != null:
return $default(_that.id,_that.displayName,_that.joinedAt,_that.token,_that.connected);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String displayName,  DateTime joinedAt,  TokenId? token,  bool connected)  $default,) {final _that = this;
switch (_that) {
case _LobbyPlayer():
return $default(_that.id,_that.displayName,_that.joinedAt,_that.token,_that.connected);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String displayName,  DateTime joinedAt,  TokenId? token,  bool connected)?  $default,) {final _that = this;
switch (_that) {
case _LobbyPlayer() when $default != null:
return $default(_that.id,_that.displayName,_that.joinedAt,_that.token,_that.connected);case _:
  return null;

}
}

}

/// @nodoc


class _LobbyPlayer implements LobbyPlayer {
  const _LobbyPlayer({required this.id, required this.displayName, required this.joinedAt, this.token, required this.connected});
  

@override final  int id;
@override final  String displayName;
@override final  DateTime joinedAt;
/// The seat token (public table identity); null for a token this app
/// does not know, or the blank one a member past the tenth may have.
@override final  TokenId? token;
/// Whether the member's phone is at the table (`connected`; still true
/// during the table's grace period after a drop). False is a dropped
/// phone: its row is dimmed, with no words.
@override final  bool connected;

/// Create a copy of LobbyPlayer
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LobbyPlayerCopyWith<_LobbyPlayer> get copyWith => __$LobbyPlayerCopyWithImpl<_LobbyPlayer>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LobbyPlayer&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt)&&(identical(other.token, token) || other.token == token)&&(identical(other.connected, connected) || other.connected == connected));
}


@override
int get hashCode => Object.hash(runtimeType,id,displayName,joinedAt,token,connected);

@override
String toString() {
  return 'LobbyPlayer(id: $id, displayName: $displayName, joinedAt: $joinedAt, token: $token, connected: $connected)';
}


}

/// @nodoc
abstract mixin class _$LobbyPlayerCopyWith<$Res> implements $LobbyPlayerCopyWith<$Res> {
  factory _$LobbyPlayerCopyWith(_LobbyPlayer value, $Res Function(_LobbyPlayer) _then) = __$LobbyPlayerCopyWithImpl;
@override @useResult
$Res call({
 int id, String displayName, DateTime joinedAt, TokenId? token, bool connected
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? displayName = null,Object? joinedAt = null,Object? token = freezed,Object? connected = null,}) {
  return _then(_LobbyPlayer(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,joinedAt: null == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as DateTime,token: freezed == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as TokenId?,connected: null == connected ? _self.connected : connected // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$LobbyState {

 String get code; int get hostId; List<LobbyPlayer> get players; String get status; int get maxPlayers; Map<String, int> get roleConfig;/// The table's deck choice, look and lengths (see [TableSettings]).
 TableSettings get table;/// The game this table has just started (from `game_started`, or found in
/// the player's current game). The screen opens it. A table can run
/// several games one after another, so each start sets a new id.
 String? get startedGameId;/// Display name of the effective host (the lobby's `host`).
 String get hostName;/// The host who set the table up. [hostId] is the effective host, who may
/// be someone else while the original host's phone is away.
 int get originalHostId;/// True while someone other than the original host is hosting.
 bool get isActingHost;/// The "Ana is hosting again" / "Ben is the host now" line, shown for a few
/// seconds after the role returns or is transferred. Frontend only.
 HostChange? get briefHostNotice;/// A plain line about a host action refused because the role had moved.
/// Frontend only.
 String? get hostActionNotice;/// A change this phone made (a deck, a pace, the deal) did not reach the
/// server: the screen says "Not sent." with "Try again". Frontend only.
 bool get notSent;/// The server refused the deal: why, in the player's words
/// (`LobbyNotifier.dealRefusal`), until the next deal or "Try again".
/// Frontend only.
 String? get dealRefused;/// The chip the body's [deckPreview] is the deck of (its own
/// `deck_chip`), so a chip tapped and not answered yet never shows
/// another chip's cards. Frontend only.
 DeckChip? get deckPreviewChip;/// Set when the server says the table no longer exists (its last member
/// left). The screen says so and goes home. Frontend only.
 bool get tableClosed;/// The automatic deck the deal would build now (`deck_preview`, role name
/// to count); null for a custom deck or a player count with no automatic
/// deck.
 Map<String, int>? get deckPreview;/// Whether the table can be dealt now (`deal`, always sent); null only in
/// a state built before its first body.
 DealReadiness? get deal;/// The roles the table would deal (`deck_cards`, role name to count),
/// face up for everyone at the table: a custom deck as picked so far, an
/// automatic deck for the table's size (for an open table of fewer than
/// 3, the smallest game's).
 Map<String, int> get deckCards;/// Every length the game would run with if dealt now (`lengths`, the
/// settings key to seconds): the table's own, else the game's default.
 Map<String, int> get lengths;/// The range a PATCH of each length takes now (`length_ranges`, the
/// settings key to `[least, most]` seconds).
 Map<String, List<int>> get lengthRanges;/// The number of players the table may be set to now (`seats_range`,
/// `[least, most]`): never below who is here, never above what it holds.
 List<int>? get seatsRange;/// The settings keys of this phone's changes not answered yet: the
/// screen shows those keys as changed at once and everything else as the
/// server has it; the server's numbers (`deal`) judge only once
/// answered. Frontend only.
 Set<String> get pendingKeys;
/// Create a copy of LobbyState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LobbyStateCopyWith<LobbyState> get copyWith => _$LobbyStateCopyWithImpl<LobbyState>(this as LobbyState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LobbyState&&(identical(other.code, code) || other.code == code)&&(identical(other.hostId, hostId) || other.hostId == hostId)&&const DeepCollectionEquality().equals(other.players, players)&&(identical(other.status, status) || other.status == status)&&(identical(other.maxPlayers, maxPlayers) || other.maxPlayers == maxPlayers)&&const DeepCollectionEquality().equals(other.roleConfig, roleConfig)&&(identical(other.table, table) || other.table == table)&&(identical(other.startedGameId, startedGameId) || other.startedGameId == startedGameId)&&(identical(other.hostName, hostName) || other.hostName == hostName)&&(identical(other.originalHostId, originalHostId) || other.originalHostId == originalHostId)&&(identical(other.isActingHost, isActingHost) || other.isActingHost == isActingHost)&&(identical(other.briefHostNotice, briefHostNotice) || other.briefHostNotice == briefHostNotice)&&(identical(other.hostActionNotice, hostActionNotice) || other.hostActionNotice == hostActionNotice)&&(identical(other.notSent, notSent) || other.notSent == notSent)&&(identical(other.dealRefused, dealRefused) || other.dealRefused == dealRefused)&&(identical(other.deckPreviewChip, deckPreviewChip) || other.deckPreviewChip == deckPreviewChip)&&(identical(other.tableClosed, tableClosed) || other.tableClosed == tableClosed)&&const DeepCollectionEquality().equals(other.deckPreview, deckPreview)&&(identical(other.deal, deal) || other.deal == deal)&&const DeepCollectionEquality().equals(other.deckCards, deckCards)&&const DeepCollectionEquality().equals(other.lengths, lengths)&&const DeepCollectionEquality().equals(other.lengthRanges, lengthRanges)&&const DeepCollectionEquality().equals(other.seatsRange, seatsRange)&&const DeepCollectionEquality().equals(other.pendingKeys, pendingKeys));
}


@override
int get hashCode => Object.hashAll([runtimeType,code,hostId,const DeepCollectionEquality().hash(players),status,maxPlayers,const DeepCollectionEquality().hash(roleConfig),table,startedGameId,hostName,originalHostId,isActingHost,briefHostNotice,hostActionNotice,notSent,dealRefused,deckPreviewChip,tableClosed,const DeepCollectionEquality().hash(deckPreview),deal,const DeepCollectionEquality().hash(deckCards),const DeepCollectionEquality().hash(lengths),const DeepCollectionEquality().hash(lengthRanges),const DeepCollectionEquality().hash(seatsRange),const DeepCollectionEquality().hash(pendingKeys)]);

@override
String toString() {
  return 'LobbyState(code: $code, hostId: $hostId, players: $players, status: $status, maxPlayers: $maxPlayers, roleConfig: $roleConfig, table: $table, startedGameId: $startedGameId, hostName: $hostName, originalHostId: $originalHostId, isActingHost: $isActingHost, briefHostNotice: $briefHostNotice, hostActionNotice: $hostActionNotice, notSent: $notSent, dealRefused: $dealRefused, deckPreviewChip: $deckPreviewChip, tableClosed: $tableClosed, deckPreview: $deckPreview, deal: $deal, deckCards: $deckCards, lengths: $lengths, lengthRanges: $lengthRanges, seatsRange: $seatsRange, pendingKeys: $pendingKeys)';
}


}

/// @nodoc
abstract mixin class $LobbyStateCopyWith<$Res>  {
  factory $LobbyStateCopyWith(LobbyState value, $Res Function(LobbyState) _then) = _$LobbyStateCopyWithImpl;
@useResult
$Res call({
 String code, int hostId, List<LobbyPlayer> players, String status, int maxPlayers, Map<String, int> roleConfig, TableSettings table, String? startedGameId, String hostName, int originalHostId, bool isActingHost, HostChange? briefHostNotice, String? hostActionNotice, bool notSent, String? dealRefused, DeckChip? deckPreviewChip, bool tableClosed, Map<String, int>? deckPreview, DealReadiness? deal, Map<String, int> deckCards, Map<String, int> lengths, Map<String, List<int>> lengthRanges, List<int>? seatsRange, Set<String> pendingKeys
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
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? hostId = null,Object? players = null,Object? status = null,Object? maxPlayers = null,Object? roleConfig = null,Object? table = null,Object? startedGameId = freezed,Object? hostName = null,Object? originalHostId = null,Object? isActingHost = null,Object? briefHostNotice = freezed,Object? hostActionNotice = freezed,Object? notSent = null,Object? dealRefused = freezed,Object? deckPreviewChip = freezed,Object? tableClosed = null,Object? deckPreview = freezed,Object? deal = freezed,Object? deckCards = null,Object? lengths = null,Object? lengthRanges = null,Object? seatsRange = freezed,Object? pendingKeys = null,}) {
  return _then(_self.copyWith(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,hostId: null == hostId ? _self.hostId : hostId // ignore: cast_nullable_to_non_nullable
as int,players: null == players ? _self.players : players // ignore: cast_nullable_to_non_nullable
as List<LobbyPlayer>,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,maxPlayers: null == maxPlayers ? _self.maxPlayers : maxPlayers // ignore: cast_nullable_to_non_nullable
as int,roleConfig: null == roleConfig ? _self.roleConfig : roleConfig // ignore: cast_nullable_to_non_nullable
as Map<String, int>,table: null == table ? _self.table : table // ignore: cast_nullable_to_non_nullable
as TableSettings,startedGameId: freezed == startedGameId ? _self.startedGameId : startedGameId // ignore: cast_nullable_to_non_nullable
as String?,hostName: null == hostName ? _self.hostName : hostName // ignore: cast_nullable_to_non_nullable
as String,originalHostId: null == originalHostId ? _self.originalHostId : originalHostId // ignore: cast_nullable_to_non_nullable
as int,isActingHost: null == isActingHost ? _self.isActingHost : isActingHost // ignore: cast_nullable_to_non_nullable
as bool,briefHostNotice: freezed == briefHostNotice ? _self.briefHostNotice : briefHostNotice // ignore: cast_nullable_to_non_nullable
as HostChange?,hostActionNotice: freezed == hostActionNotice ? _self.hostActionNotice : hostActionNotice // ignore: cast_nullable_to_non_nullable
as String?,notSent: null == notSent ? _self.notSent : notSent // ignore: cast_nullable_to_non_nullable
as bool,dealRefused: freezed == dealRefused ? _self.dealRefused : dealRefused // ignore: cast_nullable_to_non_nullable
as String?,deckPreviewChip: freezed == deckPreviewChip ? _self.deckPreviewChip : deckPreviewChip // ignore: cast_nullable_to_non_nullable
as DeckChip?,tableClosed: null == tableClosed ? _self.tableClosed : tableClosed // ignore: cast_nullable_to_non_nullable
as bool,deckPreview: freezed == deckPreview ? _self.deckPreview : deckPreview // ignore: cast_nullable_to_non_nullable
as Map<String, int>?,deal: freezed == deal ? _self.deal : deal // ignore: cast_nullable_to_non_nullable
as DealReadiness?,deckCards: null == deckCards ? _self.deckCards : deckCards // ignore: cast_nullable_to_non_nullable
as Map<String, int>,lengths: null == lengths ? _self.lengths : lengths // ignore: cast_nullable_to_non_nullable
as Map<String, int>,lengthRanges: null == lengthRanges ? _self.lengthRanges : lengthRanges // ignore: cast_nullable_to_non_nullable
as Map<String, List<int>>,seatsRange: freezed == seatsRange ? _self.seatsRange : seatsRange // ignore: cast_nullable_to_non_nullable
as List<int>?,pendingKeys: null == pendingKeys ? _self.pendingKeys : pendingKeys // ignore: cast_nullable_to_non_nullable
as Set<String>,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String code,  int hostId,  List<LobbyPlayer> players,  String status,  int maxPlayers,  Map<String, int> roleConfig,  TableSettings table,  String? startedGameId,  String hostName,  int originalHostId,  bool isActingHost,  HostChange? briefHostNotice,  String? hostActionNotice,  bool notSent,  String? dealRefused,  DeckChip? deckPreviewChip,  bool tableClosed,  Map<String, int>? deckPreview,  DealReadiness? deal,  Map<String, int> deckCards,  Map<String, int> lengths,  Map<String, List<int>> lengthRanges,  List<int>? seatsRange,  Set<String> pendingKeys)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LobbyState() when $default != null:
return $default(_that.code,_that.hostId,_that.players,_that.status,_that.maxPlayers,_that.roleConfig,_that.table,_that.startedGameId,_that.hostName,_that.originalHostId,_that.isActingHost,_that.briefHostNotice,_that.hostActionNotice,_that.notSent,_that.dealRefused,_that.deckPreviewChip,_that.tableClosed,_that.deckPreview,_that.deal,_that.deckCards,_that.lengths,_that.lengthRanges,_that.seatsRange,_that.pendingKeys);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String code,  int hostId,  List<LobbyPlayer> players,  String status,  int maxPlayers,  Map<String, int> roleConfig,  TableSettings table,  String? startedGameId,  String hostName,  int originalHostId,  bool isActingHost,  HostChange? briefHostNotice,  String? hostActionNotice,  bool notSent,  String? dealRefused,  DeckChip? deckPreviewChip,  bool tableClosed,  Map<String, int>? deckPreview,  DealReadiness? deal,  Map<String, int> deckCards,  Map<String, int> lengths,  Map<String, List<int>> lengthRanges,  List<int>? seatsRange,  Set<String> pendingKeys)  $default,) {final _that = this;
switch (_that) {
case _LobbyState():
return $default(_that.code,_that.hostId,_that.players,_that.status,_that.maxPlayers,_that.roleConfig,_that.table,_that.startedGameId,_that.hostName,_that.originalHostId,_that.isActingHost,_that.briefHostNotice,_that.hostActionNotice,_that.notSent,_that.dealRefused,_that.deckPreviewChip,_that.tableClosed,_that.deckPreview,_that.deal,_that.deckCards,_that.lengths,_that.lengthRanges,_that.seatsRange,_that.pendingKeys);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String code,  int hostId,  List<LobbyPlayer> players,  String status,  int maxPlayers,  Map<String, int> roleConfig,  TableSettings table,  String? startedGameId,  String hostName,  int originalHostId,  bool isActingHost,  HostChange? briefHostNotice,  String? hostActionNotice,  bool notSent,  String? dealRefused,  DeckChip? deckPreviewChip,  bool tableClosed,  Map<String, int>? deckPreview,  DealReadiness? deal,  Map<String, int> deckCards,  Map<String, int> lengths,  Map<String, List<int>> lengthRanges,  List<int>? seatsRange,  Set<String> pendingKeys)?  $default,) {final _that = this;
switch (_that) {
case _LobbyState() when $default != null:
return $default(_that.code,_that.hostId,_that.players,_that.status,_that.maxPlayers,_that.roleConfig,_that.table,_that.startedGameId,_that.hostName,_that.originalHostId,_that.isActingHost,_that.briefHostNotice,_that.hostActionNotice,_that.notSent,_that.dealRefused,_that.deckPreviewChip,_that.tableClosed,_that.deckPreview,_that.deal,_that.deckCards,_that.lengths,_that.lengthRanges,_that.seatsRange,_that.pendingKeys);case _:
  return null;

}
}

}

/// @nodoc


class _LobbyState implements LobbyState {
  const _LobbyState({required this.code, required this.hostId, required final  List<LobbyPlayer> players, required this.status, required this.maxPlayers, final  Map<String, int> roleConfig = const {}, this.table = TableSettings.none, this.startedGameId, required this.hostName, required this.originalHostId, required this.isActingHost, this.briefHostNotice, this.hostActionNotice, this.notSent = false, this.dealRefused, this.deckPreviewChip, this.tableClosed = false, final  Map<String, int>? deckPreview, this.deal, final  Map<String, int> deckCards = const {}, final  Map<String, int> lengths = const {}, final  Map<String, List<int>> lengthRanges = const {}, final  List<int>? seatsRange, final  Set<String> pendingKeys = const {}}): _players = players,_roleConfig = roleConfig,_deckPreview = deckPreview,_deckCards = deckCards,_lengths = lengths,_lengthRanges = lengthRanges,_seatsRange = seatsRange,_pendingKeys = pendingKeys;
  

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

/// The table's deck choice, look and lengths (see [TableSettings]).
@override@JsonKey() final  TableSettings table;
/// The game this table has just started (from `game_started`, or found in
/// the player's current game). The screen opens it. A table can run
/// several games one after another, so each start sets a new id.
@override final  String? startedGameId;
/// Display name of the effective host (the lobby's `host`).
@override final  String hostName;
/// The host who set the table up. [hostId] is the effective host, who may
/// be someone else while the original host's phone is away.
@override final  int originalHostId;
/// True while someone other than the original host is hosting.
@override final  bool isActingHost;
/// The "Ana is hosting again" / "Ben is the host now" line, shown for a few
/// seconds after the role returns or is transferred. Frontend only.
@override final  HostChange? briefHostNotice;
/// A plain line about a host action refused because the role had moved.
/// Frontend only.
@override final  String? hostActionNotice;
/// A change this phone made (a deck, a pace, the deal) did not reach the
/// server: the screen says "Not sent." with "Try again". Frontend only.
@override@JsonKey() final  bool notSent;
/// The server refused the deal: why, in the player's words
/// (`LobbyNotifier.dealRefusal`), until the next deal or "Try again".
/// Frontend only.
@override final  String? dealRefused;
/// The chip the body's [deckPreview] is the deck of (its own
/// `deck_chip`), so a chip tapped and not answered yet never shows
/// another chip's cards. Frontend only.
@override final  DeckChip? deckPreviewChip;
/// Set when the server says the table no longer exists (its last member
/// left). The screen says so and goes home. Frontend only.
@override@JsonKey() final  bool tableClosed;
/// The automatic deck the deal would build now (`deck_preview`, role name
/// to count); null for a custom deck or a player count with no automatic
/// deck.
 final  Map<String, int>? _deckPreview;
/// The automatic deck the deal would build now (`deck_preview`, role name
/// to count); null for a custom deck or a player count with no automatic
/// deck.
@override Map<String, int>? get deckPreview {
  final value = _deckPreview;
  if (value == null) return null;
  if (_deckPreview is EqualUnmodifiableMapView) return _deckPreview;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

/// Whether the table can be dealt now (`deal`, always sent); null only in
/// a state built before its first body.
@override final  DealReadiness? deal;
/// The roles the table would deal (`deck_cards`, role name to count),
/// face up for everyone at the table: a custom deck as picked so far, an
/// automatic deck for the table's size (for an open table of fewer than
/// 3, the smallest game's).
 final  Map<String, int> _deckCards;
/// The roles the table would deal (`deck_cards`, role name to count),
/// face up for everyone at the table: a custom deck as picked so far, an
/// automatic deck for the table's size (for an open table of fewer than
/// 3, the smallest game's).
@override@JsonKey() Map<String, int> get deckCards {
  if (_deckCards is EqualUnmodifiableMapView) return _deckCards;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_deckCards);
}

/// Every length the game would run with if dealt now (`lengths`, the
/// settings key to seconds): the table's own, else the game's default.
 final  Map<String, int> _lengths;
/// Every length the game would run with if dealt now (`lengths`, the
/// settings key to seconds): the table's own, else the game's default.
@override@JsonKey() Map<String, int> get lengths {
  if (_lengths is EqualUnmodifiableMapView) return _lengths;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_lengths);
}

/// The range a PATCH of each length takes now (`length_ranges`, the
/// settings key to `[least, most]` seconds).
 final  Map<String, List<int>> _lengthRanges;
/// The range a PATCH of each length takes now (`length_ranges`, the
/// settings key to `[least, most]` seconds).
@override@JsonKey() Map<String, List<int>> get lengthRanges {
  if (_lengthRanges is EqualUnmodifiableMapView) return _lengthRanges;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_lengthRanges);
}

/// The number of players the table may be set to now (`seats_range`,
/// `[least, most]`): never below who is here, never above what it holds.
 final  List<int>? _seatsRange;
/// The number of players the table may be set to now (`seats_range`,
/// `[least, most]`): never below who is here, never above what it holds.
@override List<int>? get seatsRange {
  final value = _seatsRange;
  if (value == null) return null;
  if (_seatsRange is EqualUnmodifiableListView) return _seatsRange;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

/// The settings keys of this phone's changes not answered yet: the
/// screen shows those keys as changed at once and everything else as the
/// server has it; the server's numbers (`deal`) judge only once
/// answered. Frontend only.
 final  Set<String> _pendingKeys;
/// The settings keys of this phone's changes not answered yet: the
/// screen shows those keys as changed at once and everything else as the
/// server has it; the server's numbers (`deal`) judge only once
/// answered. Frontend only.
@override@JsonKey() Set<String> get pendingKeys {
  if (_pendingKeys is EqualUnmodifiableSetView) return _pendingKeys;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_pendingKeys);
}


/// Create a copy of LobbyState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LobbyStateCopyWith<_LobbyState> get copyWith => __$LobbyStateCopyWithImpl<_LobbyState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LobbyState&&(identical(other.code, code) || other.code == code)&&(identical(other.hostId, hostId) || other.hostId == hostId)&&const DeepCollectionEquality().equals(other._players, _players)&&(identical(other.status, status) || other.status == status)&&(identical(other.maxPlayers, maxPlayers) || other.maxPlayers == maxPlayers)&&const DeepCollectionEquality().equals(other._roleConfig, _roleConfig)&&(identical(other.table, table) || other.table == table)&&(identical(other.startedGameId, startedGameId) || other.startedGameId == startedGameId)&&(identical(other.hostName, hostName) || other.hostName == hostName)&&(identical(other.originalHostId, originalHostId) || other.originalHostId == originalHostId)&&(identical(other.isActingHost, isActingHost) || other.isActingHost == isActingHost)&&(identical(other.briefHostNotice, briefHostNotice) || other.briefHostNotice == briefHostNotice)&&(identical(other.hostActionNotice, hostActionNotice) || other.hostActionNotice == hostActionNotice)&&(identical(other.notSent, notSent) || other.notSent == notSent)&&(identical(other.dealRefused, dealRefused) || other.dealRefused == dealRefused)&&(identical(other.deckPreviewChip, deckPreviewChip) || other.deckPreviewChip == deckPreviewChip)&&(identical(other.tableClosed, tableClosed) || other.tableClosed == tableClosed)&&const DeepCollectionEquality().equals(other._deckPreview, _deckPreview)&&(identical(other.deal, deal) || other.deal == deal)&&const DeepCollectionEquality().equals(other._deckCards, _deckCards)&&const DeepCollectionEquality().equals(other._lengths, _lengths)&&const DeepCollectionEquality().equals(other._lengthRanges, _lengthRanges)&&const DeepCollectionEquality().equals(other._seatsRange, _seatsRange)&&const DeepCollectionEquality().equals(other._pendingKeys, _pendingKeys));
}


@override
int get hashCode => Object.hashAll([runtimeType,code,hostId,const DeepCollectionEquality().hash(_players),status,maxPlayers,const DeepCollectionEquality().hash(_roleConfig),table,startedGameId,hostName,originalHostId,isActingHost,briefHostNotice,hostActionNotice,notSent,dealRefused,deckPreviewChip,tableClosed,const DeepCollectionEquality().hash(_deckPreview),deal,const DeepCollectionEquality().hash(_deckCards),const DeepCollectionEquality().hash(_lengths),const DeepCollectionEquality().hash(_lengthRanges),const DeepCollectionEquality().hash(_seatsRange),const DeepCollectionEquality().hash(_pendingKeys)]);

@override
String toString() {
  return 'LobbyState(code: $code, hostId: $hostId, players: $players, status: $status, maxPlayers: $maxPlayers, roleConfig: $roleConfig, table: $table, startedGameId: $startedGameId, hostName: $hostName, originalHostId: $originalHostId, isActingHost: $isActingHost, briefHostNotice: $briefHostNotice, hostActionNotice: $hostActionNotice, notSent: $notSent, dealRefused: $dealRefused, deckPreviewChip: $deckPreviewChip, tableClosed: $tableClosed, deckPreview: $deckPreview, deal: $deal, deckCards: $deckCards, lengths: $lengths, lengthRanges: $lengthRanges, seatsRange: $seatsRange, pendingKeys: $pendingKeys)';
}


}

/// @nodoc
abstract mixin class _$LobbyStateCopyWith<$Res> implements $LobbyStateCopyWith<$Res> {
  factory _$LobbyStateCopyWith(_LobbyState value, $Res Function(_LobbyState) _then) = __$LobbyStateCopyWithImpl;
@override @useResult
$Res call({
 String code, int hostId, List<LobbyPlayer> players, String status, int maxPlayers, Map<String, int> roleConfig, TableSettings table, String? startedGameId, String hostName, int originalHostId, bool isActingHost, HostChange? briefHostNotice, String? hostActionNotice, bool notSent, String? dealRefused, DeckChip? deckPreviewChip, bool tableClosed, Map<String, int>? deckPreview, DealReadiness? deal, Map<String, int> deckCards, Map<String, int> lengths, Map<String, List<int>> lengthRanges, List<int>? seatsRange, Set<String> pendingKeys
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
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? hostId = null,Object? players = null,Object? status = null,Object? maxPlayers = null,Object? roleConfig = null,Object? table = null,Object? startedGameId = freezed,Object? hostName = null,Object? originalHostId = null,Object? isActingHost = null,Object? briefHostNotice = freezed,Object? hostActionNotice = freezed,Object? notSent = null,Object? dealRefused = freezed,Object? deckPreviewChip = freezed,Object? tableClosed = null,Object? deckPreview = freezed,Object? deal = freezed,Object? deckCards = null,Object? lengths = null,Object? lengthRanges = null,Object? seatsRange = freezed,Object? pendingKeys = null,}) {
  return _then(_LobbyState(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,hostId: null == hostId ? _self.hostId : hostId // ignore: cast_nullable_to_non_nullable
as int,players: null == players ? _self._players : players // ignore: cast_nullable_to_non_nullable
as List<LobbyPlayer>,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,maxPlayers: null == maxPlayers ? _self.maxPlayers : maxPlayers // ignore: cast_nullable_to_non_nullable
as int,roleConfig: null == roleConfig ? _self._roleConfig : roleConfig // ignore: cast_nullable_to_non_nullable
as Map<String, int>,table: null == table ? _self.table : table // ignore: cast_nullable_to_non_nullable
as TableSettings,startedGameId: freezed == startedGameId ? _self.startedGameId : startedGameId // ignore: cast_nullable_to_non_nullable
as String?,hostName: null == hostName ? _self.hostName : hostName // ignore: cast_nullable_to_non_nullable
as String,originalHostId: null == originalHostId ? _self.originalHostId : originalHostId // ignore: cast_nullable_to_non_nullable
as int,isActingHost: null == isActingHost ? _self.isActingHost : isActingHost // ignore: cast_nullable_to_non_nullable
as bool,briefHostNotice: freezed == briefHostNotice ? _self.briefHostNotice : briefHostNotice // ignore: cast_nullable_to_non_nullable
as HostChange?,hostActionNotice: freezed == hostActionNotice ? _self.hostActionNotice : hostActionNotice // ignore: cast_nullable_to_non_nullable
as String?,notSent: null == notSent ? _self.notSent : notSent // ignore: cast_nullable_to_non_nullable
as bool,dealRefused: freezed == dealRefused ? _self.dealRefused : dealRefused // ignore: cast_nullable_to_non_nullable
as String?,deckPreviewChip: freezed == deckPreviewChip ? _self.deckPreviewChip : deckPreviewChip // ignore: cast_nullable_to_non_nullable
as DeckChip?,tableClosed: null == tableClosed ? _self.tableClosed : tableClosed // ignore: cast_nullable_to_non_nullable
as bool,deckPreview: freezed == deckPreview ? _self._deckPreview : deckPreview // ignore: cast_nullable_to_non_nullable
as Map<String, int>?,deal: freezed == deal ? _self.deal : deal // ignore: cast_nullable_to_non_nullable
as DealReadiness?,deckCards: null == deckCards ? _self._deckCards : deckCards // ignore: cast_nullable_to_non_nullable
as Map<String, int>,lengths: null == lengths ? _self._lengths : lengths // ignore: cast_nullable_to_non_nullable
as Map<String, int>,lengthRanges: null == lengthRanges ? _self._lengthRanges : lengthRanges // ignore: cast_nullable_to_non_nullable
as Map<String, List<int>>,seatsRange: freezed == seatsRange ? _self._seatsRange : seatsRange // ignore: cast_nullable_to_non_nullable
as List<int>?,pendingKeys: null == pendingKeys ? _self._pendingKeys : pendingKeys // ignore: cast_nullable_to_non_nullable
as Set<String>,
  ));
}


}

// dart format on
