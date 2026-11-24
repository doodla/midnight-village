part of 'copy.dart';

/// 06 Night board, and the face of "You" (the night instructions).
abstract final class NightCopy {
  static const you = Words._('You');
  static const left = Words._('Left');
  static const middle = Words._('Middle');
  static const right = Words._('Right');

  /// The center cards, by index.
  static const center = [left, middle, right];

  /// The label on the table's three cards as a group (the titles say
  /// "center cards"; a word a title uses is on the board).
  static const centerLabel = Words._('Center');

  /// The Seer's board names her two kinds of pick where the cards are (the
  /// owner chose this on 22 November 2026, knowing hers is the one board
  /// that carries labels the others do not): above the seats, on a rule
  /// between them and the table's cards, and on the strip in place of
  /// "Center".
  static const seerSeats = Words._('1 player');
  static const seerOr = Words._('or');
  static const seerCenter = Words._('2 center cards');

  // The button says what will happen, by the prompt's kind (spec section 8
  // and the "which, how many, where" test): the verb and the cards picked.
  static const chooseNone = Words._('Choose a card');
  static const chooseMore = Words._('Choose 1 more');
  static const see = Template('See {cards}');
  static const swapWith = Template('Swap with {cards}');
  static const swap = Template('Swap {cards}');
  static const copyCard = Template('Copy {cards}');

  // Picking "You" alone is passing, and the button says what passing is for
  // this role. The Robber alone keeps a card; the Drunk who passes is still
  // swapped (the server's seeded swap), so he asks the server to choose.
  static const skip = Words._('Skip');

  /// The fallback button words, for a prompt with nothing to say better
  /// (`NightPrompt.noChoice` carries them; a sleeper never shows them).
  static const choose = Template('Choose {cards}');

  /// Said after a dimmed card's name: dimmed here is not switched off, a tap
  /// still switches the pick (a vote row dimmed once locked is switched off).
  static const switchesPick = Words._('Switches your pick');
  static const keep = Words._('Keep my card');
  static const chooseForMe = Words._('Choose for me');
  static const chosen = Words._('Chosen');

  /// In the button's place on a board with nothing to choose (a sleeper's:
  /// spec section 8); quiet, with the done tick, never a thing to press.
  static const nothingToDo = Words._('Nothing to do');

  // The face of "You": what this prompt asks of the player.
  static const noChoice = Words._('Nothing to do tonight.');

  /// Spec: "Look at 1 player's card, or 2 center cards." (cold read on the
  /// real screens: whose card?) The role text's own words.
  static const seer = RoleCopy.seerNight;
  static const robber = Words._('Swap with 1 player. See your new card.');
  static const troublemaker = Words._("Swap 2 other players' cards.");
  static const drunk = Words._("Swap with 1 center card. Don't look.");
  static const loneWerewolf = Words._('You may see 1 center card.');
  static const doppelgangerLook = Words._("Copy 1 player's role.");

  // The board's title on a phone with a choice: the role's night line
  // (RoleText) in a few words (a headline; the board's budget of 20 leaves
  // it 3 or 4 beside a copied Seer's face). A sleeper's
  // board keeps "The village sleeps". A tell to a glance, accepted: the
  // playtest read "The village sleeps" as wrong while acting.
  //
  // A title passes the "which, how many, where" test (spec section 1): read
  // with the face covered, it says which cards, how many and from where, in
  // words a card or label on the board also carries.
  static const seerTitle = Words._('Look at cards');
  static const robberTitle = Words._('Swap with 1 player');
  static const troublemakerTitle = Words._("Swap 2 other players' cards");
  static const drunkTitle = Words._('Swap with a center card');
  static const loneWerewolfTitle = Words._('See 1 center card');
  static const doppelgangerTitle = Words._("Copy a player's role");

  // The window-1 page.
  static const copied = Template('You copied {name}.');
  static const slept = Words._('You slept.');
}
