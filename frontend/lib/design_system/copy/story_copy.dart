import 'template.dart';

// Part of the app's words (`copy.dart` exports it; its rules and budgets
// read this file as they read that one): 08's My night, held.

/// 08's My night, held: the one sentence under the night's picture (a name
/// list is joined with ", " and [and]), and what a screen reader hears of
/// each card. Slept, did nothing, the Troublemaker and no Werewolves are the
/// night faces' own lines.
abstract final class StoryCopy {
  static const and = 'and';
  static const seerPlayer = Template("{name}'s card was the {role}.");
  static const seerCenter = 'You saw two center cards.';
  static const robbed = Template("You took {name}'s card, the {role}.");
  static const drunk = Template('You took the {pos} card, unseen.');
  static const now = Template('Your card is now the {role}.');
  static const still = Template('Your card is still the {role}.');
  static const werewolves = Template('You and {names} are the Werewolves.');
  static const onlyWerewolf = 'You are the only Werewolf.';
  static const minion = Template('{names} are the Werewolves.');
  static const minionOne = Template('{names} is the Werewolf.');
  static const masons = Template('You and {names} are the Masons.');
  static const onlyMason = 'You are the only Mason.';

  /// The Doppelganger's: what she copied, then what her copy did at once.
  static const copied = Template('You copied {copied}, the {role}.');
  static const copiedSaw = Template(
    "You copied {copied}, then saw {name}'s card.",
  );
  static const copiedCenter = Template(
    'You copied {copied}, saw 2 center cards.',
  );
  static const copiedTook = Template(
    "You copied {copied}, then took {name}'s card.",
  );
  static const copiedSwapped = Template(
    'You copied {copied}, then swapped {a} and {b}.',
  );
  static const copiedDrunk = Template(
    'You copied {copied}, took the {pos} card.',
  );
  static const copiedMinion = Template(
    'You copied {copied}, then saw the Werewolves.',
  );
  static const copiedNone = Template(
    'You copied {copied}; there were no Werewolves.',
  );
  static const copiedNothing = Template(
    'You copied {copied}, then did nothing.',
  );

  /// A screen reader's picture: each card, by who held it.
  static const cardUp = Template('{who}: {role}.');
  static const cardDown = Template('{who}: face down.');
}
