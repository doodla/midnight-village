part of 'copy.dart';

/// What a phone saw at night: the result faces, My night's pages on 08 (the
/// spec's "07 faces"; 07 itself is gone, section 7).
///
/// Each line is a fact of the night, said in the past: what this phone saw
/// or did then, never what a card is now (cards move after a look; the
/// playtest read "Cleo's card: Werewolf." at the talk as Cleo's card today).
/// The Insomniac's is the one that is still true: she looks last.
abstract final class SawCopy {
  static const seerPlayer = Template("{name}'s card was: {role}.");

  /// The two center cards, each by its place.
  static const seerCenter = Template(
    '{pos1} was: {role1}. {pos2} was: {role2}.',
  );

  /// The Robber's: whose card it took, and what it was.
  static const robbed = Template("You took {name}'s card: {role}.");

  /// The Insomniac's, at the end of the night: no card moves after it.
  static const newCard = Template('Your card now: {role}.');
  static const swapped = Template('You swapped {a} and {b}.');

  /// Three words at most: a copied Drunk's window-1 page on 08 carries
  /// "You copied {name}." too, and the talk's budget is 15.
  static const drunk = Template('You took {pos}, unseen.');
  static const werewolves = Template('Werewolves were: {names}.');
  static const onlyYou = Words._('Only you.');
  static const centerLook = Template('{pos} was: {role}.');
  static const noWerewolves = Words._('There were no Werewolves.');
  static const masons = Template('Masons were: {names}.');

  /// The player chose, and nothing they picked meant anything for their
  /// role (spec section 3, "Trade-off": "You did nothing.").
  static const didNothing = Words._('You did nothing.');
}
