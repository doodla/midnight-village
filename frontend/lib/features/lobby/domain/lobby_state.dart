import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/host/host_change.dart';
import '../../../design_system/models/role.dart' show RoleId;
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

    /// Whether the member's phone is connected (`connected`): false is a
    /// dropped phone, shown dimmed with no words. Null while the server does
    /// not say (FALLBACK until the server branch's per-member `connected`
    /// lands on the base; then make it required and delete this note).
    bool? connected,
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
      connected: json['connected'] as bool?,
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

    /// A change this phone made (a deck, a pace, the deal) did not reach the
    /// server: the screen says "Not sent." with "Try again". Frontend only.
    @Default(false) bool notSent,

    /// The server refused the deal: why, in the player's words
    /// (`LobbyNotifier.dealRefusal`), until the next deal or "Try again".
    /// Frontend only.
    String? dealRefused,

    /// The deck the server would deal now, for a chip's deck
    /// (`deck_preview`), in the server's role names; null while the server
    /// does not send it (FALLBACK until the server branch's `deck_preview`
    /// lands; the phone never computes a chip's cards).
    Map<String, int>? deckPreview,

    /// The chip [deckPreview] is the deck of (the body's own `deck_chip`), so
    /// a chip tapped and not answered yet never shows another chip's cards.
    DeckChip? deckPreviewChip,

    /// The server's verdict on dealing now (`deal`); null while the server
    /// does not send it (FALLBACK: [DealState.of] reads the deck itself until
    /// the server branch's `deal` lands; then delete that fallback).
    ServerDeal? serverDeal,

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
      deckPreview: _preview(json['deck_preview']),
      deckPreviewChip:
          settings['deck'] == 'auto' && settings['deck_chip'] != null
          ? DeckChip.fromServer(settings['deck_chip'])
          : null,
      serverDeal: ServerDeal.fromJson(json['deal']),
    );
  }
}

/// The cards a chip's deck holds now, face up (02's strip, 03's chips
/// view, where "Edit" starts): the server's `deck_preview` for the chip the
/// table shows. Null for a custom deck, or while the server sends no
/// preview (FALLBACK until `deck_preview` lands: nothing extra is shown and
/// "Edit" starts from the last custom deck).
extension ChipCards on LobbyState {
  Map<RoleId, int>? get chipCards {
    final preview = deckPreview;
    if (!table.autoDeck || preview == null) return null;
    if (deckPreviewChip != table.deckChip) return null;
    return {
      for (final MapEntry(:key, :value) in preview.entries)
        if (RoleId.fromServer(key) case final role? when value > 0) role: value,
    };
  }
}

/// `deck_preview` in either form a server may send it: `{role: count}` or
/// `[{"role", "count"}]`. Null when absent.
Map<String, int>? _preview(Object? json) => switch (json) {
  null => null,
  final Map<String, dynamic> m => {
    for (final MapEntry(:key, :value) in m.entries) key: value as int,
  },
  final List<dynamic> l => {
    for (final e in l.cast<Map<String, dynamic>>())
      e['role'] as String: e['count'] as int,
  },
  _ => throw FormatException('Not a deck preview', json),
};

/// The server's `deal`: whether the host may deal now and, when the deck is
/// what stands in the way, the cards it needs and has.
@immutable
class ServerDeal {
  const ServerDeal._({required this.ok, this.need, this.have});

  static ServerDeal? fromJson(Object? json) {
    if (json == null) return null;
    final m = json as Map<String, dynamic>;
    return ServerDeal._(
      ok: m['ok'] as bool,
      need: m['need'] as int?,
      have: m['have'] as int?,
    );
  }

  final bool ok;
  final int? need;
  final int? have;

  @override
  bool operator ==(Object other) =>
      other is ServerDeal &&
      other.ok == ok &&
      other.need == need &&
      other.have == have;

  @override
  int get hashCode => Object.hash(ok, need, have);
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

/// The pace presets (api-contract-v2, section 7): the talk, the vote and a
/// night window, in seconds. The phone writes the numbers; which preset a
/// table is at is read back from the numbers its settings carry. The
/// Doppelganger's window is not a pace knob (first-time play spec, section
/// 7), and neither is the night's minimum window (a hidden-information guard).
enum Pace {
  quick(talk: 180, vote: 45, night: 20),
  normal(talk: 300, vote: 90, night: 30),
  long(talk: 480, vote: 120, night: 45);

  const Pace({required this.talk, required this.vote, required this.night});

  final int talk;
  final int vote;
  final int night;

  /// The settings keys a preset writes.
  Map<String, int> get settings => {
    'discussion_seconds': talk,
    'voting_seconds': vote,
    'night_wave_seconds': night,
  };

  /// The preset the stored numbers are at, if any.
  static Pace? of(Map<String, dynamic> settings) => values
      .where((p) => p.settings.entries.every((e) => settings[e.key] == e.value))
      .firstOrNull;
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
    required this.pace,
    this.talkSeconds,
    this.voteSeconds,
    this.nightSeconds,
    this.copySeconds,
    Map<String, dynamic> raw = const {},
  }) : _raw = raw;

  /// A table that says nothing: protocol 1, a custom deck.
  static const none = TableSettings._(
    nightProtocol: 1,
    autoDeck: false,
    deckChip: null,
    cardLookSeconds: null,
    pace: null,
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
      pace: Pace.of(settings),
      talkSeconds: settings['discussion_seconds'] as int?,
      voteSeconds: settings['voting_seconds'] as int?,
      nightSeconds: settings['night_wave_seconds'] as int?,
      copySeconds: settings['night_doppelganger_window_seconds'] as int?,
      raw: Map.unmodifiable(settings),
    );
  }

  /// These settings with [patch] merged over them as the server merges a
  /// `PATCH /lobbies/<code>/` (shallow: a key given again is replaced
  /// whole), so a change shows before its answer.
  TableSettings merged(Map<String, Object> patch) =>
      TableSettings.fromSettings({..._raw, ...patch});

  final Map<String, dynamic> _raw;

  /// 2: the rebuilt night (stages, one `choose` per window, counts only).
  final int nightProtocol;

  /// The server builds the deck at the deal from [deckChip] (`deck: "auto"`);
  /// otherwise the card list is the deck.
  final bool autoDeck;
  final DeckChip? deckChip;

  /// The look stage's length; null or 0 when off.
  final int? cardLookSeconds;

  /// The pace preset the stored timer lengths are at; null when they are at
  /// none (the server's own defaults, or lengths set some other way).
  final Pace? pace;

  /// The table's own lengths, in seconds, when its settings carry them (a
  /// new table carries none: the server's defaults apply, and the phone
  /// does not assume them).
  final int? talkSeconds;
  final int? voteSeconds;
  final int? nightSeconds;

  /// The Doppelganger's window ("Copy").
  final int? copySeconds;

  bool get isProtocolTwo => nightProtocol == 2;

  @override
  bool operator ==(Object other) =>
      other is TableSettings &&
      other.nightProtocol == nightProtocol &&
      other.autoDeck == autoDeck &&
      other.deckChip == deckChip &&
      other.cardLookSeconds == cardLookSeconds &&
      other.pace == pace &&
      other.talkSeconds == talkSeconds &&
      other.voteSeconds == voteSeconds &&
      other.nightSeconds == nightSeconds &&
      other.copySeconds == copySeconds;

  @override
  int get hashCode => Object.hash(
    nightProtocol,
    autoDeck,
    deckChip,
    cardLookSeconds,
    pace,
    talkSeconds,
    voteSeconds,
    nightSeconds,
    copySeconds,
  );
}

/// Whether the host may deal now, by the server's own rules for the deal
/// (`GameStartView._deal`, `validate_onuw_settings`), read from the lobby
/// body: at least 3 at the table (the server seats at most `max_players`);
/// an automatic deck is built by the server for whoever is there, a custom
/// one must hold a card for every player and three for the middle. (The
/// server also wants every member ready: each phone sets its own flag as it
/// sits down.)
@immutable
sealed class DealState {
  const DealState();

  factory DealState.of(LobbyState lobby) {
    final players = lobby.players.length;
    if (lobby.serverDeal case final deal?) {
      if (deal.ok) return CanDeal(players);
      final (need, have) = (deal.need, deal.have);
      if (players < minPlayers || need == null || have == null) {
        return const NeedPlayers();
      }
      if (have < need) return AddCards(need - have);
      if (have > need) return RemoveCards(have - need);
      return const NeedPlayers();
    }
    // FALLBACK until the server's `deal` lands on the base: the deal's rules
    // read from the lobby body here. Delete from this line to the end of the
    // factory (and [centerCards]) then.
    if (players < minPlayers) return const NeedPlayers();
    if (lobby.table.autoDeck) return CanDeal(players);
    final cards = lobby.roleConfig.values.fold(0, (a, b) => a + b);
    final wanted = players + centerCards;
    if (cards < wanted) return AddCards(wanted - cards);
    if (cards > wanted) return RemoveCards(cards - wanted);
    return CanDeal(players);
  }

  /// The fewest players the server deals to.
  static const minPlayers = 3;

  /// The cards in the middle, beside one for every player.
  static const centerCards = 3;
}

/// Deal to [players].
final class CanDeal extends DealState {
  const CanDeal(this.players);
  final int players;
}

/// Fewer than three at the table.
final class NeedPlayers extends DealState {
  const NeedPlayers();
}

/// A custom deck [count] cards short.
final class AddCards extends DealState {
  const AddCards(this.count);
  final int count;
}

/// A custom deck [count] cards over.
final class RemoveCards extends DealState {
  const RemoveCards(this.count);
  final int count;
}
