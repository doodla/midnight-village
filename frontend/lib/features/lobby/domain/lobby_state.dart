import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/host/host_change.dart';
import '../../../design_system/models/role.dart' show RoleId;
import '../../../design_system/skin/art_set.dart' show TokenId;

part 'lobby_state.freezed.dart';

/// A player in a lobby.
///
/// Serialized from the backend's nested player format:
/// ```json
/// { "user": {"id": 1, "display_name": "Alice"}, "token": "moth",
///   "joined_at": "...", "connected": true }
/// ```
@freezed
abstract class LobbyPlayer with _$LobbyPlayer {
  const factory LobbyPlayer({
    required int id,
    required String displayName,
    required DateTime joinedAt,

    /// The seat token (public table identity); null for a token this app
    /// does not know, or the blank one a member past the tenth may have.
    TokenId? token,

    /// Whether the member's phone is at the table (`connected`; still true
    /// during the table's grace period after a drop). False is a dropped
    /// phone: its row is dimmed, with no words.
    required bool connected,
  }) = _LobbyPlayer;

  /// Parses the backend's nested player format. `connected` is always sent:
  /// a missing one is a broken payload, never "unknown".
  factory LobbyPlayer.fromJson(Map<String, dynamic> json) {
    // Backend returns { "user": {"id": ..., "display_name": ...}, "joined_at": ... }
    final user = json['user'] as Map<String, dynamic>;
    return LobbyPlayer(
      id: user['id'] as int,
      displayName: user['display_name'] as String,
      joinedAt: DateTime.parse(json['joined_at'] as String),
      token: TokenId.fromServer(json['token'] as String),
      connected: json['connected'] as bool,
    );
  }
}

/// Whether the table can be dealt now (`deal`): [ok]
/// is exactly what the server's deal would answer; [need] the cards the deal
/// needs, [have] the cards in the deck. The app holds no deck-size rule.
@immutable
class DealReadiness {
  const DealReadiness({
    required this.ok,
    required this.need,
    required this.have,
  });

  factory DealReadiness.fromJson(Map<String, dynamic> json) => DealReadiness(
    ok: json['ok'] as bool,
    need: json['need'] as int,
    have: json['have'] as int,
  );

  final bool ok;
  final int need;
  final int have;

  @override
  bool operator ==(Object other) =>
      other is DealReadiness &&
      other.ok == ok &&
      other.need == need &&
      other.have == have;

  @override
  int get hashCode => Object.hash(ok, need, have);
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

    /// The table's deck choice, look and lengths (see [TableSettings]).
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

    /// The chip the body's [deckPreview] is the deck of (its own
    /// `deck_chip`), so a chip tapped and not answered yet never shows
    /// another chip's cards. Frontend only.
    DeckChip? deckPreviewChip,

    /// Set when the server says the table no longer exists (its last member
    /// left). The screen says so and goes home. Frontend only.
    @Default(false) bool tableClosed,

    /// The automatic deck the deal would build now (`deck_preview`, role name
    /// to count); null for a custom deck or a player count with no automatic
    /// deck.
    Map<String, int>? deckPreview,

    /// Whether the table can be dealt now (`deal`, always sent); null only in
    /// a state built before its first body.
    DealReadiness? deal,
  }) = _LobbyState;

  /// Parses the backend's LobbyResponse format.
  factory LobbyState.fromJson(Map<String, dynamic> json) {
    final host = json['host'] as Map<String, dynamic>;
    final playersJson = json['players'] as List<dynamic>;
    final settings = json['settings'] as Map<String, dynamic>;
    // A table whose host has not chosen a deck yet has no `roles`.
    final roles = settings['roles'] as Map<String, dynamic>?;
    final table = TableSettings.fromSettings(settings);
    // Every table sends `deck_preview` (null for a custom deck) and `deal`:
    // missing is a broken payload, as in `GameMe`.
    if (!json.containsKey('deck_preview')) {
      throw FormatException('No deck_preview in a lobby', json);
    }
    final preview = json['deck_preview'] as Map<String, dynamic>?;
    final deal = json['deal'] as Map<String, dynamic>;

    return LobbyState(
      code: json['code'] as String,
      hostId: host['id'] as int,
      players: playersJson
          .map((p) => LobbyPlayer.fromJson(p as Map<String, dynamic>))
          .toList(),
      status: json['status'] as String,
      maxPlayers: json['max_players'] as int,
      roleConfig: roles?.map((k, v) => MapEntry(k, v as int)) ?? {},
      table: table,
      // `host` is the effective host.
      hostName: host['display_name'] as String,
      originalHostId: json['original_host_id'] as int,
      isActingHost: json['is_acting_host'] as bool,
      deckPreview: preview?.map((k, v) => MapEntry(k, v as int)),
      deckPreviewChip: preview != null && settings['deck_chip'] != null
          ? DeckChip.fromServer(settings['deck_chip'])
          : null,
      deal: DealReadiness.fromJson(deal),
    );
  }
}

/// The cards a chip's deck holds now, face up (02's strip, 03's chips
/// view, where "Edit" starts): the server's `deck_preview` for the chip the
/// table shows. Null for a custom deck, or a count with no automatic deck.
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

/// What a lobby's `settings` say about the deck, the look and the lengths,
/// beyond the card list ([LobbyState.roleConfig]). Every key is optional on
/// the server (a table made without `defaults: "v2"` has none of them); a key
/// that is there must have its type.
@immutable
class TableSettings {
  const TableSettings._({
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

  /// A table that says nothing: a custom deck, no look.
  static const none = TableSettings._(
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

  @override
  bool operator ==(Object other) =>
      other is TableSettings &&
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

/// Whether the host may deal now: the server's own verdict (`deal`), which is
/// exactly what its deal would answer. The phone holds no deck-size rule:
/// when a custom deck is what stands in the way, the cards to add or remove
/// are the server's `need` against its `have`.
@immutable
sealed class DealState {
  const DealState();

  factory DealState.of(LobbyState lobby) {
    final players = lobby.players.length;
    final deal = lobby.deal;
    // No verdict yet (a state built before its first body): the button is
    // offered and the server's answer to the deal judges.
    if (deal == null || deal.ok) return CanDeal(players);
    if (players < minPlayers) return const NeedPlayers();
    if (lobby.table.autoDeck) return const CannotDeal();
    if (deal.have < deal.need) return AddCards(deal.need - deal.have);
    if (deal.have > deal.need) return RemoveCards(deal.have - deal.need);
    return const CannotDeal(deck: true);
  }

  /// The players "Need 3 players" names ([TableCopy.needPlayers]).
  static const minPlayers = 3;
}

/// Refused for another reason: a custom deck of the right size the deal
/// would not take ([deck]: its roles, e.g. one Mason), or anything else.
final class CannotDeal extends DealState {
  const CannotDeal({this.deck = false});
  final bool deck;
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
