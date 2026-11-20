import 'package:flutter/foundation.dart';

import '../skin/art_set.dart';

/// One seat at the table: what the night board draws a card for. The same
/// list on every phone, read from the server's `players`. It is the app's
/// player model (`GameMe.seats`): public table identity only.
@immutable
class NightSeat {
  const NightSeat._({
    required this.id,
    required this.name,
    required this.seat,
    this.token,
  });

  /// One entry of `/me/`'s `players` (every players list carries
  /// `token` and `seat`; a token this app does not know is drawn plain).
  factory NightSeat.fromPlayer(Map<String, dynamic> player) => NightSeat._(
    id: player['player_id'] as int,
    name: player['display_name'] as String,
    seat: player['seat'] as int,
    token: TokenId.fromServer(player['token'] as String),
  );

  /// Everyone at the table in `/me/` [me], in seat order.
  static List<NightSeat> seatsOf(Map<String, dynamic> me) {
    final players = (me['players'] as List).cast<Map<String, dynamic>>()
      ..sort((a, b) => (a['seat'] as int).compareTo(b['seat'] as int));
    return [for (final player in players) NightSeat.fromPlayer(player)];
  }

  final int id;
  final String name;

  /// The seat number (join order, from 0).
  final int seat;
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

/// What became of a choose, from the server's answer (or its absence).
enum ChooseAnswer {
  /// `200`: the server has the picks.
  taken,

  /// A `409` (`wrong_stage`, `already_chosen`): the stage has moved on or
  /// the server already has this phone's choose. Nothing to retry; the
  /// caller fetches `/me/` again.
  stale,

  /// Any other `4xx`: the server took nothing. The board is armed again,
  /// the picks still lifted.
  refused,

  /// No answer (the network failed, or the server did): the picks may not
  /// have arrived, so the board offers "Try again".
  notSent;

  /// The answer to a choose that came back with [status].
  static ChooseAnswer fromStatus(int status) => switch (status) {
    >= 200 && < 300 => taken,
    409 => stale,
    >= 400 && < 500 => refused,
    _ => notSent,
  };
}
