part of 'copy.dart';

/// 11 Results.
abstract final class ResultsCopy {
  static const villageWins = 'The village wins';
  static const werewolvesWin = 'The Werewolves win';
  static const tannerWins = 'The Tanner wins';
  static const villageAndTanner = 'The village and the Tanner win';
  static const werewolvesAndTanner = 'The Werewolves and the Tanner win';
  static const nobodyWins = 'Nobody wins';

  static const youWon = 'You won.';
  static const youLost = 'You lost.';

  /// The timeline's last row, under each player.
  static const won = 'Won';
  static const died = 'Died';
  static const center = Template('Center: {roles}');

  static const playAgain = 'Play again';
  static const editDeck = 'Edit deck';
  static const hostDealsNext = Template('{host} deals next.');

  /// A Doppelganger's card at the end, as the role she copied.
  static const copiedAs = Template('{role} · {copied}');

  /// What a screen reader says for the folded night, which opens on a tap.
  static const nightSpoken = 'The night, in order';
}
