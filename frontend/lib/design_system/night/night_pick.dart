import 'package:flutter/foundation.dart';

import '../skin/art_set.dart';

/// One seat at the table, in seat order: what the night board draws a card
/// for. The same list on every phone.
@immutable
class NightSeat {
  const NightSeat({required this.id, required this.name, this.token});

  final int id;
  final String name;
  final TokenId? token;
}

/// One pick on the night board, in the order tapped: another player's card,
/// a center card, or the player's own. The phone never decides what a pick
/// means; the server reads the picks for the player's prompt
/// (first-time play spec, "How the server reads a choose").
@immutable
sealed class NightPick {
  const NightPick();

  /// The pick as `POST .../action/ {"action_type": "choose", "picks": [...]}`
  /// sends it.
  Map<String, Object> toJson();
}

final class PlayerPick extends NightPick {
  const PlayerPick(this.playerId);

  final int playerId;

  @override
  Map<String, Object> toJson() => {'player_id': playerId};

  @override
  bool operator ==(Object other) =>
      other is PlayerPick && other.playerId == playerId;

  @override
  int get hashCode => playerId.hashCode;

  @override
  String toString() => 'PlayerPick($playerId)';
}

final class CenterPick extends NightPick {
  const CenterPick(this.index);

  /// 0 Left, 1 Middle, 2 Right.
  final int index;

  @override
  Map<String, Object> toJson() => {'center_index': index};

  @override
  bool operator ==(Object other) => other is CenterPick && other.index == index;

  @override
  int get hashCode => index.hashCode;

  @override
  String toString() => 'CenterPick($index)';
}

final class SelfPick extends NightPick {
  const SelfPick();

  @override
  Map<String, Object> toJson() => {'self': true};

  @override
  bool operator ==(Object other) => other is SelfPick;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'SelfPick()';
}

/// The night's two windows. Window 1 runs only when the Doppelganger card is
/// in the deck, and every phone may choose twice in it, so her follow-up is
/// not a tell; window 2 takes one choose.
enum NightWindow {
  one(chooses: 2),
  two(chooses: 1);

  const NightWindow({required this.chooses});

  /// How many times every phone chooses in it.
  final int chooses;
}

/// What the board does with a third pick and with a pick tapped again
/// (first-time play spec, "The night, second by second"): at most [maxPicks]
/// picks; a third replaces the oldest; tapping a chosen card unchooses it.
List<NightPick> toggled(List<NightPick> picks, NightPick tapped) {
  if (picks.contains(tapped)) return [...picks]..remove(tapped);
  final kept = picks.length < maxPicks ? picks : picks.sublist(1);
  return [...kept, tapped];
}

/// The most picks a choose sends.
const maxPicks = 2;
