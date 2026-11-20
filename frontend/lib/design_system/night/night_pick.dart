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
