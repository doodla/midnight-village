import 'package:freezed_annotation/freezed_annotation.dart';

part 'voting_state.freezed.dart';
part 'voting_state.g.dart';

/// Tracks vote submission progress without revealing targets.
///
/// Used during the voting phase to show how many players have voted.
/// Targets are never revealed until the server sends `vote_reveal`.
@freezed
abstract class VoteProgress with _$VoteProgress {
  const factory VoteProgress({
    /// Player ID to has-voted flag.
    @Default({}) Map<int, bool> playerVoted,

    /// Whether the current player has submitted their vote.
    @Default(false) bool currentPlayerVoted,
  }) = _VoteProgress;

  factory VoteProgress.fromJson(Map<String, dynamic> json) =>
      _$VoteProgressFromJson(json);
}

/// Intermediate state between vote_reveal and game_results events.
///
/// Contains the vote mapping and tally received from the server's
/// `vote_reveal` WebSocket event.
@freezed
abstract class VoteRevealData with _$VoteRevealData {
  const factory VoteRevealData({
    /// Voter player ID (as string) to target player ID. Null value means abstain.
    required Map<String, int?> votes,

    /// Player name to vote count.
    required Map<String, int> tally,
  }) = _VoteRevealData;

  factory VoteRevealData.fromJson(Map<String, dynamic> json) =>
      _$VoteRevealDataFromJson(json);
}
