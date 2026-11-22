import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart' show mapEquals;

import '../../../core/host/host_change.dart';
import '../../../design_system/models/role.dart' show RoleId, RoleIdX;
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
/// needs, [have] the cards in the deck; [seats] the number of players the
/// table is set for (null: an open table, dealt to whoever is there). The
/// app holds no deck-size rule.
@immutable
class DealReadiness {
  const DealReadiness({
    required this.ok,
    required this.need,
    required this.have,
    this.seats,
  });

  factory DealReadiness.fromJson(Map<String, dynamic> json) => DealReadiness(
    ok: json['ok'] as bool,
    need: json['need'] as int,
    have: json['have'] as int,
    // A server from before the number of players sends none: open.
    seats: json['seats'] as int?,
  );

  final bool ok;
  final int need;
  final int have;
  final int? seats;

  /// The deck holds the cards the deal needs (the server's two numbers).
  bool get deckFits => have == need;

  @override
  bool operator ==(Object other) =>
      other is DealReadiness &&
      other.ok == ok &&
      other.need == need &&
      other.have == have &&
      other.seats == seats;

  @override
  int get hashCode => Object.hash(ok, need, have, seats);
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

    /// The roles the table would deal (`deck_cards`, role name to count),
    /// face up for everyone at the table: a custom deck as picked so far, an
    /// automatic deck for the table's size (for an open table of fewer than
    /// 3, the smallest game's).
    @Default({}) Map<String, int> deckCards,

    /// Every length the game would run with if dealt now (`lengths`, the
    /// settings key to seconds): the table's own, else the game's default.
    @Default({}) Map<String, int> lengths,

    /// The range a PATCH of each length takes now (`length_ranges`, the
    /// settings key to `[least, most]` seconds).
    @Default({}) Map<String, List<int>> lengthRanges,

    /// The number of players the table may be set to now (`seats_range`,
    /// `[least, most]`): never below who is here, never above what it holds.
    List<int>? seatsRange,

    /// The settings keys of this phone's changes not answered yet: the
    /// screen shows those keys as changed at once and everything else as the
    /// server has it; the server's numbers (`deal`) judge only once
    /// answered. Frontend only.
    @Default({}) Set<String> pendingKeys,
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
      // A server from before these keys sends neither (a deploy in flight).
      deckCards: _counts(json['deck_cards']),
      lengths: _counts(json['lengths']),
      lengthRanges: json['length_ranges'] is Map<String, dynamic>
          ? (json['length_ranges'] as Map<String, dynamic>).map(
              (k, v) => MapEntry(k, (v as List).cast<int>()),
            )
          : const {},
      seatsRange: (json['seats_range'] as List?)?.cast<int>(),
    );
  }
}

Map<String, int> _counts(Object? json) => json is Map<String, dynamic>
    ? json.map((k, v) => MapEntry(k, v as int))
    : const {};

/// The roles in the one order every deck is shown in (02's strip, 03's
/// grid).
const deckOrder = [
  RoleId.werewolf,
  RoleId.minion,
  RoleId.mason,
  RoleId.seer,
  RoleId.robber,
  RoleId.troublemaker,
  RoleId.drunk,
  RoleId.insomniac,
  RoleId.hunter,
  RoleId.tanner,
  RoleId.doppelganger,
  RoleId.villager,
];

/// The cards in the middle of the table in every game: the deal needs one
/// per player and these. Used only while a change of the number is on its
/// way; otherwise the server's `deal.need` is the need.
const centreCards = 3;

/// What the host sees while a change is on its way: the server's state with
/// only the pending keys ([LobbyState.pendingKeys]) taken from this phone.
extension TableCards on LobbyState {
  /// A change of this phone's is on its way.
  bool get settling => pendingKeys.isNotEmpty;

  /// The table's deck face up (02 for host and guests, 03), in [deckOrder]:
  /// the host's own deck as it stands on this phone (its taps shown at
  /// once), else the server's `deck_cards`.
  Map<RoleId, int> get tableCards {
    final source = table.autoDeck ? deckCards : roleConfig;
    return {
      for (final role in deckOrder)
        if ((source[role.displayName] ?? 0) case final n when n > 0) role: n,
    };
  }

  /// The automatic deck is being rebuilt by the server for a change on its
  /// way (the number, the chip): its cards are the server's to say.
  bool get _autoDeckPending =>
      table.autoDeck &&
      pendingKeys.intersection({'seats', 'deck', 'deck_chip'}).isNotEmpty;

  /// The cards the deal needs for the table as this phone shows it: the
  /// server's `deal.need`, or, while a new number is on its way, that number
  /// and the centre. Null before the first body, or at an open table.
  int? get cardsNeeded {
    final seats = table.seats;
    if (seats == null) return null;
    if (pendingKeys.contains('seats')) return seats + centreCards;
    return deal?.need;
  }

  /// The cards in the deck as this phone shows it (an automatic deck being
  /// rebuilt holds what it needs, by construction).
  int get pickedCards => _autoDeckPending && cardsNeeded != null
      ? cardsNeeded!
      : tableCards.values.fold(0, (a, b) => a + b);
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

/// The lengths a host sets on the set-up page (03), in its order: the
/// server's timer settings, every one it reads. Each shows the value the game
/// would run with (the table's own, else the server's default: `lengths`)
/// and moves within the range the server takes now (`length_ranges`).
enum Length {
  talk('discussion_seconds'),
  vote('voting_seconds'),
  night('night_wave_seconds'),
  doppelganger('night_doppelganger_window_seconds'),
  look('card_look_seconds'),
  nightMinimum('night_min_window_seconds'),
  droppedPhone('disconnect_grace_seconds'),
  hostAway('host_handover_seconds');

  const Length(this.key);

  /// The settings key.
  final String key;

  /// The stepper's step at [seconds]: fine where a few seconds matter,
  /// whole minutes from five on.
  static int stepAt(int seconds) => seconds < 60
      ? 5
      : seconds < 300
      ? 15
      : 60;

  /// Whether 0 means no clock at all for this length (the talk and the vote
  /// then end when everyone is ready), rather than the thing being off.
  bool get zeroIsNoClock => this == talk || this == vote;

  /// One step up from [seconds] (to the next whole step), at most [most].
  static int up(int seconds, int most) {
    final step = stepAt(seconds);
    return (((seconds ~/ step) + 1) * step).clamp(seconds, most);
  }

  /// One step down from [seconds] (to the step below), at least [least].
  static int down(int seconds, int least) {
    if (seconds <= least) return least;
    final step = stepAt(seconds - 1);
    final next = ((seconds - 1) ~/ step) * step;
    return next < least ? least : next;
  }
}

/// The set-up page's lengths, as this phone shows them.
extension TableLengths on LobbyState {
  /// The seconds [length] runs for: this phone's change not answered yet,
  /// else the server's `lengths` (the table's own or the default). Null
  /// from a server that sends no `lengths`.
  int? secondsOf(Length length) {
    if (pendingKeys.contains(length.key)) {
      if (table.raw[length.key] case final int mine) return mine;
    }
    return lengths[length.key];
  }

  /// The range a PATCH of [length] takes now (`length_ranges`); a server
  /// that sends none: 0 to an hour.
  (int, int) rangeOf(Length length) => switch (lengthRanges[length.key]) {
    [final least, final most] => (least, most),
    _ => (0, 3600),
  };
}

/// What a lobby's `settings` say about the deck, the look and the number of
/// players, beyond the card list ([LobbyState.roleConfig]). Every key is
/// optional on the server (a table made without `defaults: "v2"` has none of
/// them); a key that is there must have its type.
@immutable
class TableSettings {
  const TableSettings._({
    required this.autoDeck,
    required this.deckChip,
    required this.cardLookSeconds,
    this.seats,
    Map<String, dynamic> raw = const {},
  }) : _raw = raw;

  /// A table that says nothing: a custom deck, no look.
  static const none = TableSettings._(
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
      autoDeck: deck == 'auto',
      deckChip: chip == null ? null : DeckChip.fromServer(chip),
      cardLookSeconds: settings['card_look_seconds'] as int?,
      seats: settings['seats'] as int?,
      raw: Map.unmodifiable(settings),
    );
  }

  /// These settings with [patch] merged over them as the server merges a
  /// `PATCH /lobbies/<code>/` (shallow: a key given again is replaced
  /// whole), so a change shows before its answer.
  TableSettings merged(Map<String, Object?> patch) =>
      TableSettings.fromSettings({..._raw, ...patch});

  final Map<String, dynamic> _raw;

  /// The settings as stored (with this phone's changes merged over them).
  Map<String, dynamic> get raw => _raw;

  /// The server builds the deck at the deal from [deckChip] (`deck: "auto"`);
  /// otherwise the card list is the deck.
  final bool autoDeck;
  final DeckChip? deckChip;

  /// The look stage's length; null or 0 when off.
  final int? cardLookSeconds;

  /// The number of players the game is for (`seats`, 3 to 10); null: open.
  final int? seats;

  @override
  bool operator ==(Object other) =>
      other is TableSettings &&
      other.autoDeck == autoDeck &&
      other.deckChip == deckChip &&
      other.cardLookSeconds == cardLookSeconds &&
      other.seats == seats &&
      mapEquals(other._raw, _raw);

  @override
  int get hashCode => Object.hash(autoDeck, deckChip, cardLookSeconds, seats);
}

/// Whether the host may deal now: the server's own verdict (`deal`), which is
/// exactly what its deal would answer. The phone holds no deck-size rule and
/// never says the deck in card arithmetic: what stands in the way is shown by
/// the elements (the empty seats, the deck's count); the button keeps one
/// label.
@immutable
sealed class DealState {
  const DealState();

  factory DealState.of(LobbyState lobby) {
    final players = lobby.players.length;
    final deal = lobby.deal;
    // No verdict yet (a state built before its first body): the button is
    // offered and the server's answer to the deal judges.
    if (deal == null) return CanDeal(players);
    // The number as the host sees it (a change on its way included).
    final seats = lobby.table.seats;
    // A change of this phone's not answered yet: the old verdict is stale.
    if (deal.ok && !lobby.settling) return CanDeal(seats ?? players);
    // A table set for a number waits for it: "Deal to 8", locked.
    if (seats != null) return WaitingFor(seats);
    if (players < minPlayers) return const NeedPlayers();
    if (!lobby.table.autoDeck) return const DeckDoesNotFit();
    return const CannotDeal();
  }

  /// The players "Need 3 players" names ([TableCopy.needPlayers]).
  static const minPlayers = 3;
}

/// Refused for another reason (anything but the players or the deck).
final class CannotDeal extends DealState {
  const CannotDeal();
}

/// Deal to [players].
final class CanDeal extends DealState {
  const CanDeal(this.players);
  final int players;
}

/// An open table with fewer than three.
final class NeedPlayers extends DealState {
  const NeedPlayers();
}

/// A table set for [seats] players that cannot be dealt yet (not all here,
/// or the deck does not fit them): the button keeps "Deal to {seats}".
final class WaitingFor extends DealState {
  const WaitingFor(this.seats);
  final int seats;
}

/// An open table's custom deck the deal would not take.
final class DeckDoesNotFit extends DealState {
  const DeckDoesNotFit();
}
