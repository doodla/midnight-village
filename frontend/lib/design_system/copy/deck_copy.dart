part of 'copy.dart';

/// 03 Tonight's game: the set-up page the host edits before anyone comes.
abstract final class DeckCopy {
  static const headline = Words._("Tonight's game");

  /// The number of players the game is for; "Any": an open table, dealt to
  /// whoever is there.
  static const players = Words._('Players');
  static const any = Words._('Any');

  /// How many practice players sit at the table: a stepper under Players,
  /// shown only once the host has held "Players" (hidden from everyone
  /// else); the same word as their tag ([TableCopy.practice]).
  static const practice = TableCopy.practice;

  /// In the order of the server's chips (`simple`, `classic`, `chaos`).
  static const chips = ['Simple', 'Classic', 'Chaos'];

  /// The lengths, in `Length` order; the Doppelganger's window is named by
  /// the role ([RoleId] names are not words).
  static const look = Words._('Look');
  static const night = Words._('Night');
  static const nightMinimum = Words._('Night minimum');
  static const talk = Words._('Talk');
  static const vote = Words._('Vote');
  static const droppedPhone = Words._('Dropped phone');
  static const hostAway = Words._('Host away');

  /// A length's value: seconds ([CommonCopy.seconds]), whole minutes,
  /// minutes and seconds ("2:30 min"). 0 for the talk or the vote: no clock
  /// (it ends when everyone is ready); for the look, a dropped phone or the
  /// host away: off.
  static const minutes = Template('{n} min');
  static const noClock = Words._('No clock');
  static const off = Words._('Off');

  /// Back to 02: an action, always. With the wrong number of cards the first
  /// "Done" (or Back) stays and nudges the count; the second leaves (the
  /// owner, 23 November 2026, left this page with 12 cards for 8 and found a
  /// button she could not press on the page after it).
  static const done = Words._('Done');

  /// By the count, in the player's words: the cards in the deck of the cards
  /// the deal needs, and what to do about the difference. The same words are
  /// 02's button.
  static const count = Template('{picked} of {need}');
  static const countFix = Template('{picked} of {need} · {fix}');
  static const addCard = Words._('Add 1 card');
  static const addCards = Template('Add {n} cards');
  static const removeCard = Words._('Remove 1 card');
  static const removeCards = Template('Remove {n} cards');

  /// What a timer is, one short line under its name (teach once; Talk and
  /// Vote say it themselves).
  static const lookCaption = Words._('See your card');
  static const nightCaption = Words._('Time to act');
  static const doppelgangerCaption = Words._('Acts first');
  static const nightMinimumCaption = Words._('Shortest night');
  static const droppedPhoneCaption = Words._('Wait before skipping');
  static const hostAwayCaption = Words._('Then another hosts');
}
