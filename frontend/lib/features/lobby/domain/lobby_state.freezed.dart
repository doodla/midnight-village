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
 bool get connected;/// A practice player (`practice`): a seat the server plays, tagged
/// "Practice" for everyone; always `connected`. An older server sends
/// no key: a person.
 bool get practice;
/// Create a copy of LobbyPlayer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LobbyPlayerCopyWith<LobbyPlayer> get copyWith => _$LobbyPlayerCopyWithImpl<LobbyPlayer>(this as LobbyPlayer, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LobbyPlayer&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt)&&(identical(other.token, token) || other.token == token)&&(identical(other.connected, connected) || other.connected == connected)&&(identical(other.practice, practice) || other.practice == practice));
}


@override
int get hashCode => Object.hash(runtimeType,id,displayName,joinedAt,token,connected,practice);

@override
String toString() {
  return 'LobbyPlayer(id: $id, displayName: $displayName, joinedAt: $joinedAt, token: $token, connected: $connected, practice: $practice)';
}


}

/// @nodoc
abstract mixin class $LobbyPlayerCopyWith<$Res>  {
  factory $LobbyPlayerCopyWith(LobbyPlayer value, $Res Function(LobbyPlayer) _then) = _$LobbyPlayerCopyWithImpl;
@useResult
$Res call({
 int id, String displayName, DateTime joinedAt, TokenId? token, bool connected, bool practice
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? displayName = null,Object? joinedAt = null,Object? token = freezed,Object? connected = null,Object? practice = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,joinedAt: null == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as DateTime,token: freezed == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as TokenId?,connected: null == connected ? _self.connected : connected // ignore: cast_nullable_to_non_nullable
as bool,practice: null == practice ? _self.practice : practice // ignore: cast_nullable_to_non_nullable
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String displayName,  DateTime joinedAt,  TokenId? token,  bool connected,  bool practice)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LobbyPlayer() when $default != null:
return $default(_that.id,_that.displayName,_that.joinedAt,_that.token,_that.connected,_that.practice);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String displayName,  DateTime joinedAt,  TokenId? token,  bool connected,  bool practice)  $default,) {final _that = this;
switch (_that) {
case _LobbyPlayer():
return $default(_that.id,_that.displayName,_that.joinedAt,_that.token,_that.connected,_that.practice);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String displayName,  DateTime joinedAt,  TokenId? token,  bool connected,  bool practice)?  $default,) {final _that = this;
switch (_that) {
case _LobbyPlayer() when $default != null:
return $default(_that.id,_that.displayName,_that.joinedAt,_that.token,_that.connected,_that.practice);case _:
  return null;

}
}

}

/// @nodoc


class _LobbyPlayer implements LobbyPlayer {
  const _LobbyPlayer({required this.id, required this.displayName, required this.joinedAt, this.token, required this.connected, this.practice = false});
  

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
/// A practice player (`practice`): a seat the server plays, tagged
/// "Practice" for everyone; always `connected`. An older server sends
/// no key: a person.
@override@JsonKey() final  bool practice;

/// Create a copy of LobbyPlayer
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LobbyPlayerCopyWith<_LobbyPlayer> get copyWith => __$LobbyPlayerCopyWithImpl<_LobbyPlayer>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LobbyPlayer&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt)&&(identical(other.token, token) || other.token == token)&&(identical(other.connected, connected) || other.connected == connected)&&(identical(other.practice, practice) || other.practice == practice));
}


@override
int get hashCode => Object.hash(runtimeType,id,displayName,joinedAt,token,connected,practice);

@override
String toString() {
  return 'LobbyPlayer(id: $id, displayName: $displayName, joinedAt: $joinedAt, token: $token, connected: $connected, practice: $practice)';
}


}

/// @nodoc
abstract mixin class _$LobbyPlayerCopyWith<$Res> implements $LobbyPlayerCopyWith<$Res> {
  factory _$LobbyPlayerCopyWith(_LobbyPlayer value, $Res Function(_LobbyPlayer) _then) = __$LobbyPlayerCopyWithImpl;
@override @useResult
$Res call({
 int id, String displayName, DateTime joinedAt, TokenId? token, bool connected, bool practice
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? displayName = null,Object? joinedAt = null,Object? token = freezed,Object? connected = null,Object? practice = null,}) {
  return _then(_LobbyPlayer(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,joinedAt: null == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as DateTime,token: freezed == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as TokenId?,connected: null == connected ? _self.connected : connected // ignore: cast_nullable_to_non_nullable
as bool,practice: null == practice ? _self.practice : practice // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$LobbyState {

 String get code; int get hostId; List<LobbyPlayer> get players; String get status;/// The game the table plays (`game_type`, e.g. `onuw`).
 String get gameType; int get maxPlayers; Map<String, int> get roleConfig;/// The table's deck choice, look and lengths (see [TableSettings]).
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
 String? get hostActionNotice;/// A setting this phone changed did not reach the server and "Try
/// again" would still send it: the set-up page and the table say "Not
/// sent." with "Try again". Frontend only.
 bool get changesNotSent;/// The deal did not go: the table says "Not sent." with "Try again"
/// (never the set-up page, whose "Try again" never deals). Frontend only.
 bool get dealNotSent;/// The server refused the deal: why, in the player's words
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
 Set<String> get pendingKeys;/// The settings keys this phone lays over the server's lobby: the
/// pending ones, a lost change "Try again" would still send, a refused
/// value until the next lobby. The screen shows them as this phone has
/// them and judges the deck and the lengths from them, never from the
/// server's numbers for an older value. Frontend only.
 Set<String> get ownKeys;/// Practice players switched on for this table (`practice`, sent only
/// then): the most that may sit at it now. Null: switched off (the
/// table shows nothing of them).
 int? get practiceMost;/// This phone's practice change not answered yet. Frontend only.
 PracticeAsk? get practiceAsk;/// The server's revision of this lobby (`rev`): it rises with every
/// change the server tells anyone, so a lobby older than one already
/// shown is never shown (`SettingsLane.admit`). Null: a server from
/// before it (shown as it comes).
 int? get rev;/// When the table was opened (`created_at`): with [code], which table
/// this is (a code can be used again by a new table, whose [rev] starts
/// again).
 String? get createdAt;
/// Create a copy of LobbyState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LobbyStateCopyWith<LobbyState> get copyWith => _$LobbyStateCopyWithImpl<LobbyState>(this as LobbyState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LobbyState&&(identical(other.code, code) || other.code == code)&&(identical(other.hostId, hostId) || other.hostId == hostId)&&const DeepCollectionEquality().equals(other.players, players)&&(identical(other.status, status) || other.status == status)&&(identical(other.gameType, gameType) || other.gameType == gameType)&&(identical(other.maxPlayers, maxPlayers) || other.maxPlayers == maxPlayers)&&const DeepCollectionEquality().equals(other.roleConfig, roleConfig)&&(identical(other.table, table) || other.table == table)&&(identical(other.startedGameId, startedGameId) || other.startedGameId == startedGameId)&&(identical(other.hostName, hostName) || other.hostName == hostName)&&(identical(other.originalHostId, originalHostId) || other.originalHostId == originalHostId)&&(identical(other.isActingHost, isActingHost) || other.isActingHost == isActingHost)&&(identical(other.briefHostNotice, briefHostNotice) || other.briefHostNotice == briefHostNotice)&&(identical(other.hostActionNotice, hostActionNotice) || other.hostActionNotice == hostActionNotice)&&(identical(other.changesNotSent, changesNotSent) || other.changesNotSent == changesNotSent)&&(identical(other.dealNotSent, dealNotSent) || other.dealNotSent == dealNotSent)&&(identical(other.dealRefused, dealRefused) || other.dealRefused == dealRefused)&&(identical(other.deckPreviewChip, deckPreviewChip) || other.deckPreviewChip == deckPreviewChip)&&(identical(other.tableClosed, tableClosed) || other.tableClosed == tableClosed)&&const DeepCollectionEquality().equals(other.deckPreview, deckPreview)&&(identical(other.deal, deal) || other.deal == deal)&&const DeepCollectionEquality().equals(other.deckCards, deckCards)&&const DeepCollectionEquality().equals(other.lengths, lengths)&&const DeepCollectionEquality().equals(other.lengthRanges, lengthRanges)&&const DeepCollectionEquality().equals(other.seatsRange, seatsRange)&&const DeepCollectionEquality().equals(other.pendingKeys, pendingKeys)&&const DeepCollectionEquality().equals(other.ownKeys, ownKeys)&&(identical(other.practiceMost, practiceMost) || other.practiceMost == practiceMost)&&(identical(other.practiceAsk, practiceAsk) || other.practiceAsk == practiceAsk)&&(identical(other.rev, rev) || other.rev == rev)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hashAll([runtimeType,code,hostId,const DeepCollectionEquality().hash(players),status,gameType,maxPlayers,const DeepCollectionEquality().hash(roleConfig),table,startedGameId,hostName,originalHostId,isActingHost,briefHostNotice,hostActionNotice,changesNotSent,dealNotSent,dealRefused,deckPreviewChip,tableClosed,const DeepCollectionEquality().hash(deckPreview),deal,const DeepCollectionEquality().hash(deckCards),const DeepCollectionEquality().hash(lengths),const DeepCollectionEquality().hash(lengthRanges),const DeepCollectionEquality().hash(seatsRange),const DeepCollectionEquality().hash(pendingKeys),const DeepCollectionEquality().hash(ownKeys),practiceMost,practiceAsk,rev,createdAt]);

@override
String toString() {
  return 'LobbyState(code: $code, hostId: $hostId, players: $players, status: $status, gameType: $gameType, maxPlayers: $maxPlayers, roleConfig: $roleConfig, table: $table, startedGameId: $startedGameId, hostName: $hostName, originalHostId: $originalHostId, isActingHost: $isActingHost, briefHostNotice: $briefHostNotice, hostActionNotice: $hostActionNotice, changesNotSent: $changesNotSent, dealNotSent: $dealNotSent, dealRefused: $dealRefused, deckPreviewChip: $deckPreviewChip, tableClosed: $tableClosed, deckPreview: $deckPreview, deal: $deal, deckCards: $deckCards, lengths: $lengths, lengthRanges: $lengthRanges, seatsRange: $seatsRange, pendingKeys: $pendingKeys, ownKeys: $ownKeys, practiceMost: $practiceMost, practiceAsk: $practiceAsk, rev: $rev, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $LobbyStateCopyWith<$Res>  {
  factory $LobbyStateCopyWith(LobbyState value, $Res Function(LobbyState) _then) = _$LobbyStateCopyWithImpl;
@useResult
$Res call({
 String code, int hostId, List<LobbyPlayer> players, String status, String gameType, int maxPlayers, Map<String, int> roleConfig, TableSettings table, String? startedGameId, String hostName, int originalHostId, bool isActingHost, HostChange? briefHostNotice, String? hostActionNotice, bool changesNotSent, bool dealNotSent, String? dealRefused, DeckChip? deckPreviewChip, bool tableClosed, Map<String, int>? deckPreview, DealReadiness? deal, Map<String, int> deckCards, Map<String, int> lengths, Map<String, List<int>> lengthRanges, List<int>? seatsRange, Set<String> pendingKeys, Set<String> ownKeys, int? practiceMost, PracticeAsk? practiceAsk, int? rev, String? createdAt
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
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? hostId = null,Object? players = null,Object? status = null,Object? gameType = null,Object? maxPlayers = null,Object? roleConfig = null,Object? table = null,Object? startedGameId = freezed,Object? hostName = null,Object? originalHostId = null,Object? isActingHost = null,Object? briefHostNotice = freezed,Object? hostActionNotice = freezed,Object? changesNotSent = null,Object? dealNotSent = null,Object? dealRefused = freezed,Object? deckPreviewChip = freezed,Object? tableClosed = null,Object? deckPreview = freezed,Object? deal = freezed,Object? deckCards = null,Object? lengths = null,Object? lengthRanges = null,Object? seatsRange = freezed,Object? pendingKeys = null,Object? ownKeys = null,Object? practiceMost = freezed,Object? practiceAsk = freezed,Object? rev = freezed,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,hostId: null == hostId ? _self.hostId : hostId // ignore: cast_nullable_to_non_nullable
as int,players: null == players ? _self.players : players // ignore: cast_nullable_to_non_nullable
as List<LobbyPlayer>,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,gameType: null == gameType ? _self.gameType : gameType // ignore: cast_nullable_to_non_nullable
as String,maxPlayers: null == maxPlayers ? _self.maxPlayers : maxPlayers // ignore: cast_nullable_to_non_nullable
as int,roleConfig: null == roleConfig ? _self.roleConfig : roleConfig // ignore: cast_nullable_to_non_nullable
as Map<String, int>,table: null == table ? _self.table : table // ignore: cast_nullable_to_non_nullable
as TableSettings,startedGameId: freezed == startedGameId ? _self.startedGameId : startedGameId // ignore: cast_nullable_to_non_nullable
as String?,hostName: null == hostName ? _self.hostName : hostName // ignore: cast_nullable_to_non_nullable
as String,originalHostId: null == originalHostId ? _self.originalHostId : originalHostId // ignore: cast_nullable_to_non_nullable
as int,isActingHost: null == isActingHost ? _self.isActingHost : isActingHost // ignore: cast_nullable_to_non_nullable
as bool,briefHostNotice: freezed == briefHostNotice ? _self.briefHostNotice : briefHostNotice // ignore: cast_nullable_to_non_nullable
as HostChange?,hostActionNotice: freezed == hostActionNotice ? _self.hostActionNotice : hostActionNotice // ignore: cast_nullable_to_non_nullable
as String?,changesNotSent: null == changesNotSent ? _self.changesNotSent : changesNotSent // ignore: cast_nullable_to_non_nullable
as bool,dealNotSent: null == dealNotSent ? _self.dealNotSent : dealNotSent // ignore: cast_nullable_to_non_nullable
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
as Set<String>,ownKeys: null == ownKeys ? _self.ownKeys : ownKeys // ignore: cast_nullable_to_non_nullable
as Set<String>,practiceMost: freezed == practiceMost ? _self.practiceMost : practiceMost // ignore: cast_nullable_to_non_nullable
as int?,practiceAsk: freezed == practiceAsk ? _self.practiceAsk : practiceAsk // ignore: cast_nullable_to_non_nullable
as PracticeAsk?,rev: freezed == rev ? _self.rev : rev // ignore: cast_nullable_to_non_nullable
as int?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String code,  int hostId,  List<LobbyPlayer> players,  String status,  String gameType,  int maxPlayers,  Map<String, int> roleConfig,  TableSettings table,  String? startedGameId,  String hostName,  int originalHostId,  bool isActingHost,  HostChange? briefHostNotice,  String? hostActionNotice,  bool changesNotSent,  bool dealNotSent,  String? dealRefused,  DeckChip? deckPreviewChip,  bool tableClosed,  Map<String, int>? deckPreview,  DealReadiness? deal,  Map<String, int> deckCards,  Map<String, int> lengths,  Map<String, List<int>> lengthRanges,  List<int>? seatsRange,  Set<String> pendingKeys,  Set<String> ownKeys,  int? practiceMost,  PracticeAsk? practiceAsk,  int? rev,  String? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LobbyState() when $default != null:
return $default(_that.code,_that.hostId,_that.players,_that.status,_that.gameType,_that.maxPlayers,_that.roleConfig,_that.table,_that.startedGameId,_that.hostName,_that.originalHostId,_that.isActingHost,_that.briefHostNotice,_that.hostActionNotice,_that.changesNotSent,_that.dealNotSent,_that.dealRefused,_that.deckPreviewChip,_that.tableClosed,_that.deckPreview,_that.deal,_that.deckCards,_that.lengths,_that.lengthRanges,_that.seatsRange,_that.pendingKeys,_that.ownKeys,_that.practiceMost,_that.practiceAsk,_that.rev,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String code,  int hostId,  List<LobbyPlayer> players,  String status,  String gameType,  int maxPlayers,  Map<String, int> roleConfig,  TableSettings table,  String? startedGameId,  String hostName,  int originalHostId,  bool isActingHost,  HostChange? briefHostNotice,  String? hostActionNotice,  bool changesNotSent,  bool dealNotSent,  String? dealRefused,  DeckChip? deckPreviewChip,  bool tableClosed,  Map<String, int>? deckPreview,  DealReadiness? deal,  Map<String, int> deckCards,  Map<String, int> lengths,  Map<String, List<int>> lengthRanges,  List<int>? seatsRange,  Set<String> pendingKeys,  Set<String> ownKeys,  int? practiceMost,  PracticeAsk? practiceAsk,  int? rev,  String? createdAt)  $default,) {final _that = this;
switch (_that) {
case _LobbyState():
return $default(_that.code,_that.hostId,_that.players,_that.status,_that.gameType,_that.maxPlayers,_that.roleConfig,_that.table,_that.startedGameId,_that.hostName,_that.originalHostId,_that.isActingHost,_that.briefHostNotice,_that.hostActionNotice,_that.changesNotSent,_that.dealNotSent,_that.dealRefused,_that.deckPreviewChip,_that.tableClosed,_that.deckPreview,_that.deal,_that.deckCards,_that.lengths,_that.lengthRanges,_that.seatsRange,_that.pendingKeys,_that.ownKeys,_that.practiceMost,_that.practiceAsk,_that.rev,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String code,  int hostId,  List<LobbyPlayer> players,  String status,  String gameType,  int maxPlayers,  Map<String, int> roleConfig,  TableSettings table,  String? startedGameId,  String hostName,  int originalHostId,  bool isActingHost,  HostChange? briefHostNotice,  String? hostActionNotice,  bool changesNotSent,  bool dealNotSent,  String? dealRefused,  DeckChip? deckPreviewChip,  bool tableClosed,  Map<String, int>? deckPreview,  DealReadiness? deal,  Map<String, int> deckCards,  Map<String, int> lengths,  Map<String, List<int>> lengthRanges,  List<int>? seatsRange,  Set<String> pendingKeys,  Set<String> ownKeys,  int? practiceMost,  PracticeAsk? practiceAsk,  int? rev,  String? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _LobbyState() when $default != null:
return $default(_that.code,_that.hostId,_that.players,_that.status,_that.gameType,_that.maxPlayers,_that.roleConfig,_that.table,_that.startedGameId,_that.hostName,_that.originalHostId,_that.isActingHost,_that.briefHostNotice,_that.hostActionNotice,_that.changesNotSent,_that.dealNotSent,_that.dealRefused,_that.deckPreviewChip,_that.tableClosed,_that.deckPreview,_that.deal,_that.deckCards,_that.lengths,_that.lengthRanges,_that.seatsRange,_that.pendingKeys,_that.ownKeys,_that.practiceMost,_that.practiceAsk,_that.rev,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc


class _LobbyState implements LobbyState {
  const _LobbyState({required this.code, required this.hostId, required final  List<LobbyPlayer> players, required this.status, required this.gameType, required this.maxPlayers, final  Map<String, int> roleConfig = const {}, this.table = TableSettings.none, this.startedGameId, required this.hostName, required this.originalHostId, required this.isActingHost, this.briefHostNotice, this.hostActionNotice, this.changesNotSent = false, this.dealNotSent = false, this.dealRefused, this.deckPreviewChip, this.tableClosed = false, final  Map<String, int>? deckPreview, this.deal, final  Map<String, int> deckCards = const {}, final  Map<String, int> lengths = const {}, final  Map<String, List<int>> lengthRanges = const {}, final  List<int>? seatsRange, final  Set<String> pendingKeys = const {}, final  Set<String> ownKeys = const {}, this.practiceMost, this.practiceAsk, this.rev, this.createdAt}): _players = players,_roleConfig = roleConfig,_deckPreview = deckPreview,_deckCards = deckCards,_lengths = lengths,_lengthRanges = lengthRanges,_seatsRange = seatsRange,_pendingKeys = pendingKeys,_ownKeys = ownKeys;
  

@override final  String code;
@override final  int hostId;
 final  List<LobbyPlayer> _players;
@override List<LobbyPlayer> get players {
  if (_players is EqualUnmodifiableListView) return _players;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_players);
}

@override final  String status;
/// The game the table plays (`game_type`, e.g. `onuw`).
@override final  String gameType;
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
/// A setting this phone changed did not reach the server and "Try
/// again" would still send it: the set-up page and the table say "Not
/// sent." with "Try again". Frontend only.
@override@JsonKey() final  bool changesNotSent;
/// The deal did not go: the table says "Not sent." with "Try again"
/// (never the set-up page, whose "Try again" never deals). Frontend only.
@override@JsonKey() final  bool dealNotSent;
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

/// The settings keys this phone lays over the server's lobby: the
/// pending ones, a lost change "Try again" would still send, a refused
/// value until the next lobby. The screen shows them as this phone has
/// them and judges the deck and the lengths from them, never from the
/// server's numbers for an older value. Frontend only.
 final  Set<String> _ownKeys;
/// The settings keys this phone lays over the server's lobby: the
/// pending ones, a lost change "Try again" would still send, a refused
/// value until the next lobby. The screen shows them as this phone has
/// them and judges the deck and the lengths from them, never from the
/// server's numbers for an older value. Frontend only.
@override@JsonKey() Set<String> get ownKeys {
  if (_ownKeys is EqualUnmodifiableSetView) return _ownKeys;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_ownKeys);
}

/// Practice players switched on for this table (`practice`, sent only
/// then): the most that may sit at it now. Null: switched off (the
/// table shows nothing of them).
@override final  int? practiceMost;
/// This phone's practice change not answered yet. Frontend only.
@override final  PracticeAsk? practiceAsk;
/// The server's revision of this lobby (`rev`): it rises with every
/// change the server tells anyone, so a lobby older than one already
/// shown is never shown (`SettingsLane.admit`). Null: a server from
/// before it (shown as it comes).
@override final  int? rev;
/// When the table was opened (`created_at`): with [code], which table
/// this is (a code can be used again by a new table, whose [rev] starts
/// again).
@override final  String? createdAt;

/// Create a copy of LobbyState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LobbyStateCopyWith<_LobbyState> get copyWith => __$LobbyStateCopyWithImpl<_LobbyState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LobbyState&&(identical(other.code, code) || other.code == code)&&(identical(other.hostId, hostId) || other.hostId == hostId)&&const DeepCollectionEquality().equals(other._players, _players)&&(identical(other.status, status) || other.status == status)&&(identical(other.gameType, gameType) || other.gameType == gameType)&&(identical(other.maxPlayers, maxPlayers) || other.maxPlayers == maxPlayers)&&const DeepCollectionEquality().equals(other._roleConfig, _roleConfig)&&(identical(other.table, table) || other.table == table)&&(identical(other.startedGameId, startedGameId) || other.startedGameId == startedGameId)&&(identical(other.hostName, hostName) || other.hostName == hostName)&&(identical(other.originalHostId, originalHostId) || other.originalHostId == originalHostId)&&(identical(other.isActingHost, isActingHost) || other.isActingHost == isActingHost)&&(identical(other.briefHostNotice, briefHostNotice) || other.briefHostNotice == briefHostNotice)&&(identical(other.hostActionNotice, hostActionNotice) || other.hostActionNotice == hostActionNotice)&&(identical(other.changesNotSent, changesNotSent) || other.changesNotSent == changesNotSent)&&(identical(other.dealNotSent, dealNotSent) || other.dealNotSent == dealNotSent)&&(identical(other.dealRefused, dealRefused) || other.dealRefused == dealRefused)&&(identical(other.deckPreviewChip, deckPreviewChip) || other.deckPreviewChip == deckPreviewChip)&&(identical(other.tableClosed, tableClosed) || other.tableClosed == tableClosed)&&const DeepCollectionEquality().equals(other._deckPreview, _deckPreview)&&(identical(other.deal, deal) || other.deal == deal)&&const DeepCollectionEquality().equals(other._deckCards, _deckCards)&&const DeepCollectionEquality().equals(other._lengths, _lengths)&&const DeepCollectionEquality().equals(other._lengthRanges, _lengthRanges)&&const DeepCollectionEquality().equals(other._seatsRange, _seatsRange)&&const DeepCollectionEquality().equals(other._pendingKeys, _pendingKeys)&&const DeepCollectionEquality().equals(other._ownKeys, _ownKeys)&&(identical(other.practiceMost, practiceMost) || other.practiceMost == practiceMost)&&(identical(other.practiceAsk, practiceAsk) || other.practiceAsk == practiceAsk)&&(identical(other.rev, rev) || other.rev == rev)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hashAll([runtimeType,code,hostId,const DeepCollectionEquality().hash(_players),status,gameType,maxPlayers,const DeepCollectionEquality().hash(_roleConfig),table,startedGameId,hostName,originalHostId,isActingHost,briefHostNotice,hostActionNotice,changesNotSent,dealNotSent,dealRefused,deckPreviewChip,tableClosed,const DeepCollectionEquality().hash(_deckPreview),deal,const DeepCollectionEquality().hash(_deckCards),const DeepCollectionEquality().hash(_lengths),const DeepCollectionEquality().hash(_lengthRanges),const DeepCollectionEquality().hash(_seatsRange),const DeepCollectionEquality().hash(_pendingKeys),const DeepCollectionEquality().hash(_ownKeys),practiceMost,practiceAsk,rev,createdAt]);

@override
String toString() {
  return 'LobbyState(code: $code, hostId: $hostId, players: $players, status: $status, gameType: $gameType, maxPlayers: $maxPlayers, roleConfig: $roleConfig, table: $table, startedGameId: $startedGameId, hostName: $hostName, originalHostId: $originalHostId, isActingHost: $isActingHost, briefHostNotice: $briefHostNotice, hostActionNotice: $hostActionNotice, changesNotSent: $changesNotSent, dealNotSent: $dealNotSent, dealRefused: $dealRefused, deckPreviewChip: $deckPreviewChip, tableClosed: $tableClosed, deckPreview: $deckPreview, deal: $deal, deckCards: $deckCards, lengths: $lengths, lengthRanges: $lengthRanges, seatsRange: $seatsRange, pendingKeys: $pendingKeys, ownKeys: $ownKeys, practiceMost: $practiceMost, practiceAsk: $practiceAsk, rev: $rev, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$LobbyStateCopyWith<$Res> implements $LobbyStateCopyWith<$Res> {
  factory _$LobbyStateCopyWith(_LobbyState value, $Res Function(_LobbyState) _then) = __$LobbyStateCopyWithImpl;
@override @useResult
$Res call({
 String code, int hostId, List<LobbyPlayer> players, String status, String gameType, int maxPlayers, Map<String, int> roleConfig, TableSettings table, String? startedGameId, String hostName, int originalHostId, bool isActingHost, HostChange? briefHostNotice, String? hostActionNotice, bool changesNotSent, bool dealNotSent, String? dealRefused, DeckChip? deckPreviewChip, bool tableClosed, Map<String, int>? deckPreview, DealReadiness? deal, Map<String, int> deckCards, Map<String, int> lengths, Map<String, List<int>> lengthRanges, List<int>? seatsRange, Set<String> pendingKeys, Set<String> ownKeys, int? practiceMost, PracticeAsk? practiceAsk, int? rev, String? createdAt
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
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? hostId = null,Object? players = null,Object? status = null,Object? gameType = null,Object? maxPlayers = null,Object? roleConfig = null,Object? table = null,Object? startedGameId = freezed,Object? hostName = null,Object? originalHostId = null,Object? isActingHost = null,Object? briefHostNotice = freezed,Object? hostActionNotice = freezed,Object? changesNotSent = null,Object? dealNotSent = null,Object? dealRefused = freezed,Object? deckPreviewChip = freezed,Object? tableClosed = null,Object? deckPreview = freezed,Object? deal = freezed,Object? deckCards = null,Object? lengths = null,Object? lengthRanges = null,Object? seatsRange = freezed,Object? pendingKeys = null,Object? ownKeys = null,Object? practiceMost = freezed,Object? practiceAsk = freezed,Object? rev = freezed,Object? createdAt = freezed,}) {
  return _then(_LobbyState(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,hostId: null == hostId ? _self.hostId : hostId // ignore: cast_nullable_to_non_nullable
as int,players: null == players ? _self._players : players // ignore: cast_nullable_to_non_nullable
as List<LobbyPlayer>,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,gameType: null == gameType ? _self.gameType : gameType // ignore: cast_nullable_to_non_nullable
as String,maxPlayers: null == maxPlayers ? _self.maxPlayers : maxPlayers // ignore: cast_nullable_to_non_nullable
as int,roleConfig: null == roleConfig ? _self._roleConfig : roleConfig // ignore: cast_nullable_to_non_nullable
as Map<String, int>,table: null == table ? _self.table : table // ignore: cast_nullable_to_non_nullable
as TableSettings,startedGameId: freezed == startedGameId ? _self.startedGameId : startedGameId // ignore: cast_nullable_to_non_nullable
as String?,hostName: null == hostName ? _self.hostName : hostName // ignore: cast_nullable_to_non_nullable
as String,originalHostId: null == originalHostId ? _self.originalHostId : originalHostId // ignore: cast_nullable_to_non_nullable
as int,isActingHost: null == isActingHost ? _self.isActingHost : isActingHost // ignore: cast_nullable_to_non_nullable
as bool,briefHostNotice: freezed == briefHostNotice ? _self.briefHostNotice : briefHostNotice // ignore: cast_nullable_to_non_nullable
as HostChange?,hostActionNotice: freezed == hostActionNotice ? _self.hostActionNotice : hostActionNotice // ignore: cast_nullable_to_non_nullable
as String?,changesNotSent: null == changesNotSent ? _self.changesNotSent : changesNotSent // ignore: cast_nullable_to_non_nullable
as bool,dealNotSent: null == dealNotSent ? _self.dealNotSent : dealNotSent // ignore: cast_nullable_to_non_nullable
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
as Set<String>,ownKeys: null == ownKeys ? _self._ownKeys : ownKeys // ignore: cast_nullable_to_non_nullable
as Set<String>,practiceMost: freezed == practiceMost ? _self.practiceMost : practiceMost // ignore: cast_nullable_to_non_nullable
as int?,practiceAsk: freezed == practiceAsk ? _self.practiceAsk : practiceAsk // ignore: cast_nullable_to_non_nullable
as PracticeAsk?,rev: freezed == rev ? _self.rev : rev // ignore: cast_nullable_to_non_nullable
as int?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
