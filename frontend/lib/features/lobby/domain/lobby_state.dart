import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/host/host_change.dart';
import '../../../design_system/skin/art_set.dart' show TokenId;

part 'lobby_state.freezed.dart';

/// A player in a lobby.
///
/// Serialized from the backend's nested player format:
/// ```json
/// { "user": {"id": 1, "display_name": "Alice"}, "is_ready": true,
///   "token": "moth", "joined_at": "..." }
/// ```
@freezed
abstract class LobbyPlayer with _$LobbyPlayer {
  const factory LobbyPlayer({
    required int id,
    required String displayName,
    required bool isReady,
    required DateTime joinedAt,

    /// The seat token (public table identity); null for a token this app
    /// does not know, or the blank one a member past the tenth may have.
    TokenId? token,
  }) = _LobbyPlayer;

  /// Parses the backend's nested player format.
  factory LobbyPlayer.fromJson(Map<String, dynamic> json) {
    // Backend returns { "user": {"id": ..., "display_name": ...}, "is_ready": ..., "joined_at": ... }
    final user = json['user'] as Map<String, dynamic>;
    return LobbyPlayer(
      id: user['id'] as int,
      displayName: user['display_name'] as String,
      isReady: json['is_ready'] as bool,
      joinedAt: DateTime.parse(json['joined_at'] as String),
      token: TokenId.fromServer(json['token'] as String),
    );
  }
}

/// The state of a lobby, including players, settings, and status.
///
/// Serialized from the backend's LobbyResponse format.
@freezed
abstract class LobbyState with _$LobbyState {
  const factory LobbyState({
    required String code,
    required int hostId,
    required List<LobbyPlayer> players,
    required String status,
    required int maxPlayers,
    @Default({}) Map<String, int> roleConfig,

    /// The table's deck choice and night (protocol 2 settings; see
    /// [TableSettings]).
    @Default(TableSettings.none) TableSettings table,

    /// The game this table has just started (from `game_started`, or found in
    /// the player's current game). The screen opens it. A table can run
    /// several games one after another, so each start sets a new id.
    String? startedGameId,

    /// Display name of the effective host (the lobby's `host`).
    required String hostName,

    /// The host who set the table up. [hostId] is the effective host, who may
    /// be someone else while the original host's phone is away.
    required int originalHostId,

    /// True while someone other than the original host is hosting.
    required bool isActingHost,

    /// The "Ana is hosting again" / "Ben is the host now" line, shown for a few
    /// seconds after the role returns or is transferred. Frontend only.
    HostChange? briefHostNotice,

    /// A plain line about a host action refused because the role had moved.
    /// Frontend only.
    String? hostActionNotice,

    /// Set when the server says the table no longer exists (its last member
    /// left). The screen says so and goes home. Frontend only.
    @Default(false) bool tableClosed,
  }) = _LobbyState;

  /// Parses the backend's LobbyResponse format.
  factory LobbyState.fromJson(Map<String, dynamic> json) {
    final host = json['host'] as Map<String, dynamic>;
    final playersJson = json['players'] as List<dynamic>;
    final settings = json['settings'] as Map<String, dynamic>;
    // A table whose host has not chosen a deck yet has no `roles`.
    final roles = settings['roles'] as Map<String, dynamic>?;

    return LobbyState(
      code: json['code'] as String,
      hostId: host['id'] as int,
      players: playersJson
          .map((p) => LobbyPlayer.fromJson(p as Map<String, dynamic>))
          .toList(),
      status: json['status'] as String,
      maxPlayers: json['max_players'] as int,
      roleConfig: roles?.map((k, v) => MapEntry(k, v as int)) ?? {},
      table: TableSettings.fromSettings(settings),
      // `host` is the effective host.
      hostName: host['display_name'] as String,
      originalHostId: json['original_host_id'] as int,
      isActingHost: json['is_acting_host'] as bool,
    );
  }
}

/// The deck chips the server builds a deck from (`deck_chip`).
enum DeckChip {
  simple,
  classic,
  chaos;

  /// The server's name for it.
  String get server => name;

  static DeckChip fromServer(Object? name) =>
      values.where((c) => c.server == name).firstOrNull ??
      (throw FormatException('Unknown deck chip', name));
}

/// What a lobby's `settings` say about the deck and the night, beyond the
/// card list ([LobbyState.roleConfig]). Every key is optional on the server
/// (a table made without `defaults: "v2"` has none of them); a key that is
/// there must have its type.
@immutable
class TableSettings {
  const TableSettings._({
    required this.nightProtocol,
    required this.autoDeck,
    required this.deckChip,
    required this.cardLookSeconds,
  });

  /// A table that says nothing: protocol 1, a custom deck.
  static const none = TableSettings._(
    nightProtocol: 1,
    autoDeck: false,
    deckChip: null,
    cardLookSeconds: null,
  );

  factory TableSettings.fromSettings(Map<String, dynamic> settings) {
    final deck = settings['deck'] as String?;
    if (deck != null && deck != 'auto' && deck != 'custom') {
      throw FormatException('Unknown deck mode', deck);
    }
    final chip = settings['deck_chip'];
    return TableSettings._(
      // Absent means 1 (the server's rule).
      nightProtocol: settings['night_protocol'] as int? ?? 1,
      autoDeck: deck == 'auto',
      deckChip: chip == null ? null : DeckChip.fromServer(chip),
      cardLookSeconds: settings['card_look_seconds'] as int?,
    );
  }

  /// 2: the rebuilt night (stages, one `choose` per window, counts only).
  final int nightProtocol;

  /// The server builds the deck at the deal from [deckChip] (`deck: "auto"`);
  /// otherwise the card list is the deck.
  final bool autoDeck;
  final DeckChip? deckChip;

  /// The look stage's length; null or 0 when off.
  final int? cardLookSeconds;

  bool get isProtocolTwo => nightProtocol == 2;

  @override
  bool operator ==(Object other) =>
      other is TableSettings &&
      other.nightProtocol == nightProtocol &&
      other.autoDeck == autoDeck &&
      other.deckChip == deckChip &&
      other.cardLookSeconds == cardLookSeconds;

  @override
  int get hashCode =>
      Object.hash(nightProtocol, autoDeck, deckChip, cardLookSeconds);
}
