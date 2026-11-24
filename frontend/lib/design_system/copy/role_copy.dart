part of 'copy.dart';

/// The role text (single source for the 04 face, 03b and the role name on
/// faces): a tag; rows of a small label and short lines (at most two, one
/// per case: "Night", the Hunter's "Vote", "Wins"); then the shared line,
/// set apart as a rule of the game (owner, 24 November 2026: "different
/// formatting so it's easier to parse").
abstract final class RoleCopy {
  static const nightLabel = DeckCopy.night;
  static const voteLabel = DeckCopy.vote;
  static const winsLabel = Words._('Wins');
  static const shared = Words._('You are your last card.');
  static const villageWins = Words._('A Werewolf dies.');
  static const villageNoWerewolf = Words._('No Werewolf player: nobody dies.');

  // Tags. Never a role's own name (owner, 24 November 2026: "a double
  // label"): the Werewolf team's is "Werewolf team" (`RoleCopy.werewolfTeam`).
  static const village = Words._('Village');
  static const alone = Words._('Alone');
  static const copies = Words._('Copies');

  /// The Werewolf team's tag beside the role's name, so it does not read as
  /// the name twice.
  static const werewolfTeam = Template('{role} team');

  static const werewolfNight = Words._('At dawn, see the other Werewolves.');
  static const werewolfAlone = Words._('Alone: you may see 1 center card.');
  static const werewolfWins = Words._('No Werewolf and no Tanner dies.');
  static const minionNight = Words._('At dawn, see the Werewolves.');
  static const minionUnseen = Words._("They don't see you.");
  static const minionWins = Words._('With the Werewolves, even if you die.');
  static const minionNoWerewolf = Words._(
    'No Werewolf player: another dies, not the Tanner.',
  );
  static const masonNight = Words._('At dawn, see the other Mason.');
  static const seerNight = Words._("See 1 player's card or 2 center cards.");
  static const robberNight = Words._('Swap with a player. See your new card.');
  static const troublemakerNight = Words._(
    "Swap 2 other players' cards. Don't look.",
  );
  static const drunkNight = Words._("Swap with a center card. Don't look.");
  static const insomniacNight = Words._('At dawn, see your own card.');
  static const hunterVote = Words._('Your pick dies with you.');
  static const sleep = Words._('Sleep.');
  static const tannerWins = Words._('You die.');
  static const doppelgangerNight = Words._(
    "Copy a player's role. Act as that role.",
  );
  static const doppelgangerWins = Words._('As the role you copy.');
}
