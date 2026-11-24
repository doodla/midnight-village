part of 'copy.dart';

/// The role text (single source for the 04 face, 03b and the role name on
/// faces): a tag; rows of a small label and short lines (at most two, one
/// per case: "Night", the Hunter's "Vote", "Wins"); then the shared line,
/// set apart as a rule of the game (owner, 24 November 2026: "different
/// formatting so it's easier to parse").
abstract final class RoleCopy {
  static const nightLabel = DeckCopy.night;
  static const voteLabel = DeckCopy.vote;
  static const winsLabel = 'Wins';
  static const shared = 'You are your last card.';
  static const villageWins = 'A Werewolf dies.';
  static const villageNoWerewolf = 'No Werewolf player: nobody dies.';

  // Tags. Never a role's own name (owner, 24 November 2026: "a double
  // label"): the Werewolf team's is "Werewolf team" (`RoleCopy.werewolfTeam`).
  static const village = 'Village';
  static const alone = 'Alone';
  static const copies = 'Copies';

  /// The Werewolf team's tag beside the role's name, so it does not read as
  /// the name twice.
  static const werewolfTeam = Template('{role} team');

  static const werewolfNight = 'At dawn, see the other Werewolves.';
  static const werewolfAlone = 'Alone: you may see 1 center card.';
  static const werewolfWins = 'No Werewolf and no Tanner dies.';
  static const minionNight = 'At dawn, see the Werewolves.';
  static const minionUnseen = "They don't see you.";
  static const minionWins = 'With the Werewolves, even if you die.';
  static const minionNoWerewolf =
      'No Werewolf player: another dies, not the Tanner.';
  static const masonNight = 'At dawn, see the other Mason.';
  static const seerNight = "See 1 player's card or 2 center cards.";
  static const robberNight = 'Swap with a player. See your new card.';
  static const troublemakerNight = "Swap 2 other players' cards. Don't look.";
  static const drunkNight = "Swap with a center card. Don't look.";
  static const insomniacNight = 'At dawn, see your own card.';
  static const hunterVote = 'Your pick dies with you.';
  static const sleep = 'Sleep.';
  static const tannerWins = 'You die.';
  static const doppelgangerNight = "Copy a player's role. Act as that role.";
  static const doppelgangerWins = 'As the role you copy.';
}
