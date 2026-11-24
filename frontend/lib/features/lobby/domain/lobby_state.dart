import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart' show mapEquals;

import '../../../core/host/host_change.dart';
import '../../../design_system/models/role.dart' show RoleId, RoleIdX;
import '../../../design_system/skin/art_set.dart' show TokenId;

part 'lobby_state.freezed.dart';
part 'lobby_table.dart';

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

    /// A practice player (`practice`): a seat the server plays, tagged
    /// "Practice" for everyone; always `connected`. An older server sends
    /// no key: a person.
    @Default(false) bool practice,
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
      practice: json['practice'] as bool? ?? false,
    );
  }
}

/// A practice change of this phone's not answered yet (`POST
/// /lobbies/<code>/practice/`): shown at once, the server's word once it
/// answers. [on] the switch asked for, [count] how many asked to sit; null:
/// as the server has it. Several on their way are [then]-folded, oldest
/// first, so the screen shows them all as the server will apply them.
@immutable
class PracticeAsk {
  const PracticeAsk({this.on, this.count});

  final bool? on;
  final int? count;

  /// The settings key a practice change holds on the settings lane (only the
  /// practice endpoint writes it).
  static const key = 'practice';

  /// [next] applied after this, as the server applies them: off takes every
  /// one away; on keeps who sits; a count above 0 switches them on.
  PracticeAsk then(PracticeAsk next) {
    if (next.on == false) return const PracticeAsk(on: false, count: 0);
    return PracticeAsk(
      on: next.on ?? ((next.count ?? 0) > 0 ? true : on),
      count: next.count ?? (next.on == true && on == false ? 0 : count),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PracticeAsk && other.on == on && other.count == count;

  @override
  int get hashCode => Object.hash(on, count);
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

    /// The game the table plays (`game_type`, e.g. `onuw`).
    required String gameType,
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

    /// A setting this phone changed did not reach the server and "Try
    /// again" would still send it: the set-up page and the table say "Not
    /// sent." with "Try again". Frontend only.
    @Default(false) bool changesNotSent,

    /// The deal did not go: the table says "Not sent." with "Try again"
    /// (never the set-up page, whose "Try again" never deals). Frontend only.
    @Default(false) bool dealNotSent,

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

    /// The settings keys this phone lays over the server's lobby: the
    /// pending ones, a lost change "Try again" would still send, a refused
    /// value until the next lobby. The screen shows them as this phone has
    /// them and judges the deck and the lengths from them, never from the
    /// server's numbers for an older value. Frontend only.
    @Default({}) Set<String> ownKeys,

    /// Practice players switched on for this table (`practice`, sent only
    /// then): the most that may sit at it now. Null: switched off (the
    /// table shows nothing of them).
    int? practiceMost,

    /// This phone's practice change not answered yet. Frontend only.
    PracticeAsk? practiceAsk,

    /// The server's revision of this lobby (`rev`): it rises with every
    /// change the server tells anyone, so a lobby older than one already
    /// shown is never shown (`SettingsLane.admit`). Null: a server from
    /// before it (shown as it comes).
    int? rev,

    /// When the table was opened (`created_at`): with [code], which table
    /// this is (a code can be used again by a new table, whose [rev] starts
    /// again).
    String? createdAt,
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
      gameType: json['game_type'] as String,
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
      practiceMost:
          (json['practice'] as Map<String, dynamic>?)?['most'] as int?,
      rev: json['rev'] as int?,
      createdAt: json['created_at'] as String?,
    );
  }
}

/// Practice players as this phone shows them (03's Practice row): the
/// server's, with this phone's change not answered yet taken over it.
extension PracticeSeats on LobbyState {
  /// The practice players seated, as the server says.
  int get practiceSeated => players.where((p) => p.practice).length;

  /// The host has switched them on (the changes on their way included).
  bool get practiceOn => practiceAsk?.on ?? practiceMost != null;

  /// How many sit at the table, as this phone shows it.
  int get practiceCount =>
      practiceAsk?.on == false ? 0 : practiceAsk?.count ?? practiceSeated;

  /// Who sits at the table as this phone shows it: the people, and the
  /// practice players with the changes on their way.
  int get seatedCount => players.length - practiceSeated + practiceCount;

  /// The most that may sit: the server's, or, before it has said (the switch
  /// on its way) or while a new number is on its way, every seat no person
  /// holds at the number shown.
  int get practiceLimit {
    final most = practiceMost;
    if (most != null && !ownKeys.contains('seats')) return most;
    final people = players.length - practiceSeated;
    final seats = table.seats ?? maxPlayers;
    return (seats - people).clamp(0, maxPlayers);
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

  /// "Not sent." on the table (02): a setting or the deal.
  bool get notSent => changesNotSent || dealNotSent;

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
      ownKeys.intersection({'seats', 'deck', 'deck_chip'}).isNotEmpty;

  /// The cards the deal needs for the table as this phone shows it: the
  /// server's `deal.need`, or, while a new number is on its way, that number
  /// and the centre. Null before the first body, or at an open table.
  int? get cardsNeeded {
    final seats = table.seats;
    // An open table's automatic deck is built for whoever is here: never
    // short. A deck of the host's own is judged against the server's need.
    if (seats == null) return table.autoDeck ? null : deal?.need;
    if (ownKeys.contains('seats')) return seats + centreCards;
    return deal?.need;
  }

  /// How far the deck is from the cards the deal needs: above 0 too many,
  /// below 0 too few, 0 it fits; null when nothing says what is needed. The
  /// server's `deal.need` and `deal.have` are the rule (cards = players + 3);
  /// the phone only shows the distance.
  int? get deckOff {
    final need = cardsNeeded;
    return need == null ? null : pickedCards - need;
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
