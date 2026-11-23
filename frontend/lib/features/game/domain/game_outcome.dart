import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../design_system/faces/face_content.dart' show serverRole;
import '../../../design_system/models/game_result.dart';
import '../../../design_system/models/role.dart';
import '../../../design_system/night/night_pick.dart';
import 'night_timeline.dart';

/// `GET /onuw/games/<id>/results/` (the same under both night protocols):
/// the result as the results screens draw it, the table in seat order, and
/// the night's timeline.
@immutable
class GameOutcome {
  const GameOutcome._({
    required this.result,
    required this.seats,
    required this.timeline,
    required String body,
  }) : _body = body;

  factory GameOutcome.fromJson(Map<String, dynamic> data) {
    final timeline = data['night_timeline'] as Map<String, dynamic>?;
    return GameOutcome._(
      result: gameResultFromServer(data),
      seats: NightSeat.seatsOf(data),
      timeline: timeline == null ? null : NightTimeline.fromJson(timeline),
      body: jsonEncode(data),
    );
  }

  /// The body it was read from: two outcomes are the same when their bodies
  /// are (the same results fetched again change nothing).
  final String _body;

  @override
  bool operator ==(Object other) =>
      other is GameOutcome && other._body == _body;

  @override
  int get hashCode => _body.hashCode;

  final GameResult result;

  /// Everyone who played, in seat order, with their tokens.
  final List<NightSeat> seats;

  /// Null when the server could not build it (an old game): the rest of the
  /// results still show.
  final NightTimeline? timeline;
}

/// The results body as a [GameResult]: the one results parser, used by
/// [GameOutcome]. Vote targets are
/// named from the results' own players list.
GameResult gameResultFromServer(Map<String, dynamic> data) {
  final players = (data['players'] as List).cast<Map<String, dynamic>>();
  final names = {
    for (final p in players) '${p['player_id']}': p['display_name'] as String,
  };
  return GameResult(
    winningTeams: [
      for (final t in data['winning_teams'] as List) teamFromServer(t),
    ],
    players: [
      for (final p in players)
        PlayerResult(
          id: '${p['player_id'] as int}',
          displayName: p['display_name'] as String,
          originalRole: serverRole(p['original_role']),
          finalRole: serverRole(p['final_role']),
          team: teamFromServer(p['team']),
          isEliminated: p['is_eliminated'] as bool,
          isWinner: switch (p['outcome']) {
            'win' => true,
            'lose' => false,
            final other => throw FormatException('Unknown outcome', other),
          },
          voteTargetId: (p['vote_target_id'] as int?)?.toString(),
          voteTargetName: names[(p['vote_target_id'] as int?)?.toString()],
          eliminationReason: _eliminationFromServer(
            p['elimination_reason'] as String?,
          ),
        ),
    ],
    reason: data['reason'] as String,
    centerCards: [for (final r in data['center_cards'] as List) serverRole(r)],
  );
}

/// A player's `team` (`neutral` for the Tanner) or a winning team (`tanner`).
TeamId teamFromServer(Object? team) => switch (team) {
  'werewolf' => TeamId.werewolf,
  'village' => TeamId.village,
  'neutral' || 'tanner' => TeamId.independent,
  _ => throw FormatException('Unknown team', team),
};

/// Null for a player who was not eliminated.
EliminationReason? _eliminationFromServer(String? reason) => switch (reason) {
  null => null,
  'vote' => EliminationReason.vote,
  'hunter_chain' => EliminationReason.hunterChain,
  _ => throw FormatException('Unknown elimination reason', reason),
};
