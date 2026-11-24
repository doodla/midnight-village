import 'package:flutter/foundation.dart';

import '../../../design_system/models/game_result.dart';
import '../../../design_system/models/role.dart';
import '../../../design_system/night/night_pick.dart';
import 'game_outcome.dart';
import 'night_timeline.dart';

// What the end board shows of each player, read from the results body
// ([GameOutcome]) and nothing else: who they voted for, whether they died and
// why, their card at the deal and at the end, their team and outcome. Every
// fact is the server's; nothing here applies a rule of the game.

/// One player at the end of the game, as the results name them.
@immutable
class EndSeat {
  const EndSeat._({
    required this.seat,
    required this.dealt,
    required this.now,
    required this.copied,
    required this.team,
    required this.won,
    required this.diedBy,
    required this.votedFor,
  });

  final NightSeat seat;

  /// The card dealt to them (`original_role`).
  final RoleId dealt;

  /// The card in front of them at the end (`final_role`): the one that
  /// counts.
  final RoleId now;

  /// When [now] is the Doppelganger: the role she copied (the timeline's
  /// `copy` step), which the card is for the rest of the game.
  final RoleId? copied;

  /// Their team at the end, as the server says (`team`).
  final TeamId team;

  /// The server's `outcome`.
  final bool won;

  /// Null: alive.
  final EliminationReason? diedBy;

  /// Whom they voted for (null: no vote).
  final int? votedFor;

  bool get died => diedBy != null;

  /// The card moved in the night.
  bool get moved => dealt != now;

  /// The role the [now] card plays: the copied role for a Doppelganger.
  RoleId get plays => copied ?? now;
}

/// Everyone at the end, in seat order (the results' `players`, with the
/// tokens and seats of its players list).
List<EndSeat> endSeatsOf(GameOutcome outcome) {
  final byId = {for (final p in outcome.result.players) p.id: p};
  final timeline = outcome.timeline;
  final copied = timeline?.steps
      .where((s) => s.action == TimelineAction.copy)
      .firstOrNull
      ?.copiedRole;
  return [
    for (final seat in outcome.seats)
      if (byId['${seat.id}'] case final p?)
        EndSeat._(
          seat: seat,
          dealt: p.originalRole,
          now: p.finalRole,
          copied: p.finalRole == RoleId.doppelganger ? copied : null,
          team: p.team,
          won: p.isWinner,
          diedBy: p.isEliminated
              ? p.eliminationReason ??
                    (throw FormatException('A death with no reason', p.id))
              : null,
          votedFor: p.voteTargetId == null ? null : int.parse(p.voteTargetId!),
        ),
  ];
}
