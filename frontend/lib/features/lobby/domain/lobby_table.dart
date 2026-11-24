part of 'lobby_state.dart';

// What the table is set to and whether it can be dealt: the deck chips, the
// lengths, the settings a host changes, and the deal's states. Part of
// lobby_state.dart: same library, so everything that imports it is unchanged.

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
    if (ownKeys.contains(length.key)) {
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
/// the elements (the empty seats, the deck's count). The reasons come in the
/// order the host can act on them: the friends first ("Need 3 players",
/// "Need {n} more"), then the deck ("Add 1 card", "Remove 2 cards"), then
/// start.
@immutable
sealed class DealState {
  const DealState();

  factory DealState.of(LobbyState lobby) {
    // Who sits as the host sees it (practice changes on their way included).
    final players = lobby.seatedCount;
    final deal = lobby.deal;
    // No verdict yet (a state built before its first body): the button is
    // offered and the server's answer to the deal judges.
    if (deal == null) return CanDeal(players);
    // The number as the host sees it (a change on its way included).
    final seats = lobby.table.seats;
    // The friends first: nothing else matters to a host alone at a table. The
    // places are the table's own number, or at an open ("Any") table the
    // three a game takes; either way the count shown is the one the phone
    // holds now (who sits, the number set), and the cards needed below are the
    // server's current `need` (it follows the players at an open table).
    if (seats != null && players < seats) return WaitingFor(seats - players);
    if (seats == null && players < minPlayers) return const NeedPlayers();
    // Then the deck: the one other reason the host fixes on this phone.
    final off = lobby.deckOff;
    if (off != null && off != 0) return DeckDoesNotFit(off);
    // A change of this phone's not answered yet: the old verdict is stale,
    // the button waits for the answer.
    if (lobby.settling) return CanDealSoon(seats ?? players);
    if (deal.ok) return CanDeal(seats ?? players);
    return const CannotDeal();
  }

  /// The players "Need 3 players" names ([TableCopy.needPlayers]).
  static const minPlayers = 3;
}

/// The server would refuse for a reason this phone cannot name (the timers,
/// say): the button stays live and the deal's own refusal says why.
final class CannotDeal extends DealState {
  const CannotDeal();
}

/// Start, for [players].
final class CanDeal extends DealState {
  const CanDeal(this.players);
  final int players;
}

/// Ready as soon as this phone's own change on its way is answered.
final class CanDealSoon extends DealState {
  const CanDealSoon(this.players);
  final int players;
}

/// An open table with fewer than three.
final class NeedPlayers extends DealState {
  const NeedPlayers();
}

/// A table set for a number with [missing] places still empty.
final class WaitingFor extends DealState {
  const WaitingFor(this.missing);
  final int missing;
}

/// The deck holds [off] cards over (above 0) or under (below 0) what the
/// deal needs: the button leads to 03, where the count shows.
final class DeckDoesNotFit extends DealState {
  const DeckDoesNotFit(this.off);
  final int off;
}
