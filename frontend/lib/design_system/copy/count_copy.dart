part of 'copy.dart';

/// 10 The count.
abstract final class CountCopy {
  static const dies = Template('{name} dies.');
  static const die = Template('{names} die.');
  static const nobodyDies = 'Nobody dies.';

  /// The Hunter's pick (the server's `hunter_chain`), and why.
  /// Spec: "{name} dies too." (review: say whose pick, so a pick with one
  /// vote does not look voted out).
  static const huntersPick = Template("{name}, {hunter}'s pick, dies too.");
  static const nobodyGotTwo = 'Nobody got 2 or more votes.';
  static const noVote = Template('No vote: {names}');
  static const now = 'Now';
  static const dealt = 'Dealt';

  /// The Werewolf team's tag beside the role's name (S10's "Werewolf
  /// team"), so it does not read as the name twice.
  static const werewolfTeam = Template('{role} team');
  static const seeWhoWon = 'See who won';
}
