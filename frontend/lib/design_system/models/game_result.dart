import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:midnight_village/design_system/models/role.dart';

part 'game_result.freezed.dart';

@freezed
abstract class VoteResult with _$VoteResult {
  const factory VoteResult({
    required String voterId,
    required String voterName,
    required String targetId,
    required String targetName,
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
  }) = _PlayerResult;
}

@freezed
abstract class GameResult with _$GameResult {
  const factory GameResult({
    required List<TeamId> winningTeams,
    required List<PlayerResult> players,
  }) = _GameResult;
}
