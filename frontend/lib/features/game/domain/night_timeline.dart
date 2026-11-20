import 'package:flutter/foundation.dart';

import '../../../design_system/faces/face_content.dart' show serverRole;
import '../../../design_system/models/role.dart';

/// Where a card lies: a player's seat or a center slot (0 Left, 1 Middle,
/// 2 Right).
@immutable
sealed class CardPlace {
  const CardPlace();

  /// `{"player_id": n}` or `{"center_index": n}`.
  factory CardPlace.fromJson(Map<String, dynamic> json) => switch (json) {
    {'player_id': final int id} => PlayerPlace(id),
    {'center_index': final int index} => CenterPlace(index),
    _ => throw FormatException('Not a card place', json),
  };
}

final class PlayerPlace extends CardPlace {
  const PlayerPlace(this.playerId);

  final int playerId;

  @override
  bool operator ==(Object other) =>
      other is PlayerPlace && other.playerId == playerId;

  @override
  int get hashCode => playerId.hashCode;
}

final class CenterPlace extends CardPlace {
  const CenterPlace(this.index);

  final int index;

  @override
  bool operator ==(Object other) =>
      other is CenterPlace && other.index == index;

  @override
  int get hashCode => index.hashCode;
}

/// One physical card of the night (`cards[]`).
@immutable
class TimelineCard {
  const TimelineCard._(this.id, this.role, {required this.werewolf});

  factory TimelineCard.fromJson(Map<String, dynamic> json) => TimelineCard._(
    json['card_id'] as String,
    serverRole(json['role']),
    werewolf: json['werewolf'] as bool,
  );

  /// `k0`, `k1`, ...: stable through the night.
  final String id;
  final RoleId role;

  /// A werewolf card for whoever ends holding it (the server decides, a
  /// Doppelganger who copied a Werewolf included); the client only colours.
  final bool werewolf;
}

/// Where every card is: each player's (by player id) and the center's.
@immutable
class CardPositions {
  const CardPositions._(this.players, this.center);

  factory CardPositions.fromJson(Map<String, dynamic> json) => CardPositions._({
    for (final e in (json['players'] as Map).entries)
      int.parse(e.key as String): e.value as String,
  }, (json['center'] as List).cast<String>());

  /// Player id -> card id.
  final Map<int, String> players;

  /// Card ids, Left to Right.
  final List<String> center;
}

/// What a step did, by the server's `action` (one to one).
enum TimelineAction {
  copy,
  seeTeam('see_team'),
  peekPlayer('peek_player'),
  peekCenter('peek_center'),
  swapWithPlayer('swap_with_player'),
  swapOthers('swap_others'),
  swapWithCenter('swap_with_center'),
  lookOwn('look_own'),
  skip;

  const TimelineAction([this._server]);

  final String? _server;

  String get server => _server ?? name;

  static TimelineAction fromServer(Object? name) =>
      values.where((a) => a.server == name).firstOrNull ??
      (throw FormatException('Unknown timeline action', name));
}

/// A card that moved in a step.
@immutable
class CardMove {
  const CardMove._(this.cardId, this.from, this.to);

  factory CardMove.fromJson(Map<String, dynamic> json) => CardMove._(
    json['card_id'] as String,
    CardPlace.fromJson(json['from'] as Map<String, dynamic>),
    CardPlace.fromJson(json['to'] as Map<String, dynamic>),
  );

  final String cardId;
  final CardPlace from;
  final CardPlace to;
}

/// One step of the night, in the order of the rules.
@immutable
class TimelineStep {
  const TimelineStep._({
    required this.step,
    required this.window,
    required this.orderGroup,
    required this.role,
    required this.actors,
    required this.doppelgangerActors,
    required this.action,
    required this.madeByServer,
    required this.lookedAt,
    required this.team,
    required this.copiedRole,
    required this.moves,
    required this.positionsAfter,
  });

  factory TimelineStep.fromJson(Map<String, dynamic> json) {
    final copied = json['copied_role'] as String?;
    List<int> ids(String key) => (json[key] as List).cast<int>();
    return TimelineStep._(
      step: json['step'] as int,
      window: json['window'] as int,
      orderGroup: json['order_group'] as int,
      role: serverRole(json['role']),
      actors: ids('actors'),
      doppelgangerActors: ids('doppelganger_actors'),
      action: TimelineAction.fromServer(json['action']),
      madeByServer: json['made_by_server'] as bool,
      lookedAt: [
        for (final look
            in (json['looked_at'] as List).cast<Map<String, dynamic>>())
          (place: CardPlace.fromJson(look), cardId: look['card_id'] as String),
      ],
      team: ids('team'),
      copiedRole: copied == null ? null : serverRole(copied),
      moves: [
        for (final move in (json['moves'] as List).cast<Map>())
          CardMove.fromJson(move.cast<String, dynamic>()),
      ],
      positionsAfter: CardPositions.fromJson(
        json['positions_after'] as Map<String, dynamic>,
      ),
    );
  }

  final int step;
  final int window;
  final int orderGroup;

  /// The role acting (`role_acting_as`).
  final RoleId role;
  final List<int> actors;

  /// Which of [actors] is the Doppelganger.
  final List<int> doppelgangerActors;
  final TimelineAction action;

  /// The server chose (a Drunk's seeded swap).
  final bool madeByServer;
  final List<({CardPlace place, String cardId})> lookedAt;

  /// Everyone shown together in a team view.
  final List<int> team;
  final RoleId? copiedRole;
  final List<CardMove> moves;
  final CardPositions positionsAfter;
}

/// The results' `night_timeline`: the night in order and how the cards
/// moved, built by the server so the phone only draws.
@immutable
class NightTimeline {
  const NightTimeline._({
    required this.seats,
    required this.cards,
    required this.dealt,
    required this.steps,
    required this.finalPositions,
    required this.centerMoved,
  });

  factory NightTimeline.fromJson(Map<String, dynamic> json) => NightTimeline._(
    seats: (json['seats'] as List).cast<int>(),
    cards: {
      for (final card in (json['cards'] as List).cast<Map<String, dynamic>>())
        card['card_id'] as String: TimelineCard.fromJson(card),
    },
    dealt: CardPositions.fromJson(json['dealt'] as Map<String, dynamic>),
    steps: [
      for (final step in (json['steps'] as List).cast<Map<String, dynamic>>())
        TimelineStep.fromJson(step),
    ],
    finalPositions: CardPositions.fromJson(
      json['final'] as Map<String, dynamic>,
    ),
    centerMoved: (json['center_moved'] as List).cast<bool>(),
  );

  /// Player ids in seat order.
  final List<int> seats;

  /// Every card by id.
  final Map<String, TimelineCard> cards;
  final CardPositions dealt;
  final List<TimelineStep> steps;
  final CardPositions finalPositions;

  /// Per center slot: whether its card is not the one dealt there.
  final List<bool> centerMoved;
}
