import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:midnight_village/design_system/models/role.dart';

part 'game_result.freezed.dart';

/// Why a player was eliminated.
enum EliminationReason { vote, hunterChain }

@freezed
abstract class VoteResult with _$VoteResult {
  const factory VoteResult({
    required String voterId,
    required String voterName,

    /// Null for abstaining players.
    String? targetId,

    /// Null for abstaining players.
    String? targetName,
  }) = _VoteResult;
}

@freezed
abstract class PlayerResult with _$PlayerResult {
  const factory PlayerResult({
    required String id,
    required String displayName,
    required RoleId originalRole,
    required RoleId finalRole,
    required TeamId team,
    required bool isEliminated,
    required bool isWinner,

    /// Who this player voted for (null for abstainers).
    String? voteTargetId,

    /// Display name of the vote target (null for abstainers).
    String? voteTargetName,

    /// How this player was eliminated (null if not eliminated).
    EliminationReason? eliminationReason,
  }) = _PlayerResult;
}

@freezed
abstract class GameResult with _$GameResult {
  const factory GameResult({
    required List<TeamId> winningTeams,
    required List<PlayerResult> players,

    /// Human-readable explanation of why the winning team(s) won.
    @Default('') String reason,

    /// Per-player vote pairs. Uses @Default([]) for backward compat.
    @Default([]) List<VoteResult> votes,

    /// Final center card identities. Uses @Default([]) for backward compat.
    @Default([]) List<RoleId> centerCards,
  }) = _GameResult;
}
