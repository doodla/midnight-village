import 'template.dart';

// Every word a player reads, keyed by screen and state: the final copy of
// docs/specs/frontend/first-time-play.md, section 3. Nothing a player reads
// is written anywhere else (role names are the server's, in
// `models/role.dart`). `test/design_system/copy/copy_budget_test.dart`
// holds every line here to the spec's copy rules (section 1): word budgets
// per screen, headlines, buttons, sentences, the one question, the banned
// words, the banners. A `{gap}` is filled where the line is shown
// (`Template.fill`).
//
// Where this differs from the spec's text, the spec broke one of its own
// rules; each change is marked "Spec:" with the line it replaces.

/// Words shared by several screens.
abstract final class CommonCopy {
  /// The teach-once cue's one word (copy rule 6).
  static const hold = 'Hold';

  /// A gate button after the player is ready (04, 08).
  static const readyDone = 'Ready ✓';

  /// A stage or a stepper is finished (03's stepper, 07).
  static const done = 'Done';

  /// Back to the start (02 guest, 11 guest).
  static const leave = 'Leave';

  /// "{d} of {n}" under a stage everyone passes (04).
  static const progress = Template('{d} of {n}');

  /// A custom deck that does not match the table (02, 03).
  static const addCards = Template('Add {n} cards');
  static const removeCards = Template('Remove {n} cards');

  /// Night and dawn share the title (05, 06).
  static const nightTitle = 'The village sleeps';
}

/// 01 Join.
abstract final class JoinCopy {
  /// The hero line (not a word: copy rule 1).
  static const title = 'Midnight Village';
  static const nameHint = 'Your name';

  /// Outlined and of equal weight; locked until a name is typed.
  static const startTable = 'Start a table';
  static const joinTable = 'Join a table';

  /// "Join a table" opened: the code and an amber "Join" in its place.
  static const codeHint = 'Code';
  static const join = 'Join';

  static const online = Template('{n} at tables');
  static const lastWon = 'You won last game';
  static const lastLost = 'You lost last game';
}

/// 02 Table.
abstract final class TableCopy {
  // Host.
  static const scan = 'Scan to join';
  static const share = 'Share';

  /// On the deck strip. Spec: "Edit deck", which puts the host's 02 at 8
  /// words for a budget of 7; the strip it sits on names the deck.
  static const editDeck = 'Edit';
  static const deal = Template('Deal to {n}');
  static const needPlayers = 'Need 3 players';

  // Guest.
  static const hostDeals = Template('{host} deals');
}

/// 03 Deck (the host's, optional).
abstract final class DeckCopy {
  static const headline = "Tonight's deck";
  static const chips = ['Simple', 'Classic', 'Chaos'];
  static const paces = ['Quick', 'Normal', 'Long'];

  /// The pace tiles; "Copy" only when the Doppelganger is in the deck.
  static const talk = 'Talk';
  static const vote = 'Vote';
  static const night = 'Night';
  static const copy = 'Copy';

  static const useDeck = 'Use this deck';
}

/// 03b Role sheet: the role text ([RoleCopy]) and this.
abstract final class RoleSheetCopy {
  static const close = 'Close';
}

/// The role text (single source for the 04 face, 03b and the role name on
/// faces): a tag, a Night line, a Wins line and the shared line.
abstract final class RoleCopy {
  static const nightLabel = 'Night:';
  static const winsLabel = 'Wins:';
  static const shared = 'You are your last card. Anyone may lie.';
  static const villageWins =
      'A Werewolf dies. No Werewolf player: nobody dies.';

  // Tags; the Werewolf team's is the role name.
  static const village = 'Village';
  static const alone = 'Alone';
  static const copies = 'Copies';

  static const werewolfNight =
      'See the other Werewolves. Alone: you may see 1 center card.';
  static const werewolfWins = 'No Werewolf and no Tanner dies.';
  static const minionNight = "See the Werewolves. They don't see you.";
  static const minionWins =
      'With the Werewolves, even if you die. No Werewolf player: someone '
      'else dies, not the Tanner.';
  static const masonNight = 'See the other Mason.';
  static const seerNight = "Look at 1 player's card, or 2 center cards.";
  static const robberNight = 'Swap with a player. See your new card.';
  static const troublemakerNight = "Swap 2 other players' cards. Don't look.";
  static const drunkNight = "Swap with a center card. Don't look.";
  static const insomniacNight = 'At dawn, see your own card.';
  static const hunterNight = 'Sleep. If you die, your pick dies.';
  static const sleep = 'Sleep.';
  static const tannerWins = 'You die.';
  static const doppelgangerNight = "Copy a player's card. Act as that role.";
  static const doppelgangerWins = 'As the role you copy.';
}

/// 04 Your card.
abstract final class CardCopy {
  static const headline = 'Your card';
  static const ready = 'Ready';
}

/// 06 Night board, and the face of "You" (the night instructions).
abstract final class NightCopy {
  static const you = 'You';
  static const left = 'Left';
  static const middle = 'Middle';
  static const right = 'Right';

  /// The center cards, by index.
  static const center = [left, middle, right];

  // The button, by state (spec section 8).
  static const chooseNone = 'Choose a card';
  static const chooseMore = 'Choose 1 more';
  static const choose = Template('Choose {cards}');
  static const keep = 'Keep my card';
  static const chosen = 'Chosen';

  // The face of "You": what this prompt asks of the player.
  /// Names a gesture against copy rule 6; kept by the product owner
  /// (spec section 8): it tells a sleeper how to take a turn at all.
  static const noChoice = 'Nothing to choose. Tap any card.';
  static const seer = 'Look at 1 card, or 2 center cards.';
  static const robber = 'Swap with 1 player. See your new card.';
  static const troublemaker = "Swap 2 other players' cards.";
  static const drunk = "Swap with 1 center card. Don't look.";
  static const loneWerewolf = 'You may see 1 center card.';
  static const doppelgangerLook = "Copy 1 player's card.";

  // The window-1 page.
  static const copied = Template('You copied {name}.');
  static const slept = 'You slept.';
}

/// What a phone saw at night: the result faces, My night's pages on 08 (the
/// spec's "07 faces"; 07 itself is gone, section 7).
abstract final class SawCopy {
  static const seerPlayer = Template("{name}'s card: {role}.");
  static const seerCenter = Template('{pos1}: {role1}. {pos2}: {role2}.');
  static const newCard = Template('Your card now: {role}.');
  static const swapped = Template('You swapped {a} and {b}.');

  /// Spec: "{pos} is yours now. Unseen." A copied Drunk's window-1 page on
  /// 08 then made 16 words for a budget of 15.
  static const drunk = Template('{pos} is yours. Unseen.');
  static const werewolves = Template('Werewolves: {names}.');
  static const onlyYou = 'Only you.';
  static const centerLook = Template('{pos}: {role}.');
  static const noWerewolves = 'No Werewolves.';
  static const masons = Template('Masons: {names}.');
  static const didNothing = 'You did nothing.';
}

/// 08 Talk.
abstract final class TalkCopy {
  static const headline = 'The village wakes';
  static const myNight = 'My night';
  static const progress = Template('{d} of {n} ready');
  static const readyToVote = 'Ready to vote';

  /// My night's first page.
  static const dealt = Template('Dealt: {role}');
}

/// 09 Vote.
abstract final class VoteCopy {
  /// The only question in the app.
  static const headline = 'Who dies today?';
  static const pickName = 'Pick a name';
  static const lockIn = Template('Lock in {name}');
  static const locked = 'Locked';
  static const progress = Template('{d} of {n} locked');
}

/// 10 The count.
abstract final class CountCopy {
  static const dies = Template('{name} dies.');
  static const die = Template('{names} die.');
  static const nobodyDies = 'Nobody dies.';
  static const diesToo = Template('{name} dies too.');
  static const nobodyGotTwo = 'Nobody got 2 or more votes.';
  static const noVote = Template('No vote: {names}');
  static const now = 'Now';
  static const dealt = 'Dealt';
  static const seeWhoWon = 'See who won';
}

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
}

/// 11's timeline rows, each after a "{role}:" prefix (a Doppelganger's
/// follow-up: "Doppelganger · {copied}:").
abstract final class TimelineCopy {
  static const prefix = Template('{role}:');
  static const followUpPrefix = Template('Doppelganger · {copied}:');
  static const copies = Template('{a} copies {b}.');
  static const seeEachOther = Template('{names} see each other.');
  static const wakesAlone = Template('{name} wakes alone.');
  static const minionSees = Template('{a} sees {names}.');
  static const minionSeesNone = Template('{a} sees no Werewolf.');
  static const seerPlayer = Template("{a} sees {b}'s card.");
  static const seerCenter = Template('{a} sees {pos1}, {pos2}.');
  static const loneWerewolf = Template('{a} sees {pos}.');
  static const robber = Template("{a} takes {b}'s card.");
  static const troublemaker = Template('{a} swaps {b} and {c}.');
  static const drunk = Template('{a} takes {pos}.');
  static const insomniac = Template('{a} sees own card.');
  static const skip = Template('{a} does nothing.');
}

/// System banners (their own budget: 6 words with the button).
abstract final class BannerCopy {
  static const lobbyNotFound = 'No table with that code.';
  static const lobbyFull = 'That table is full.';
  static const lobbyClosed = 'That table is playing now.';
  static const alreadyInLobby = "You're at another table.";
  static const goThere = 'Go there';
  static const tableClosed = 'This table has closed.';
  static const goHome = 'Go home';
  static const notSent = 'Not sent.';
  static const tryAgain = 'Try again';
  static const offline = 'One moment';
  static const leftGame = 'You left this game.';
}

/// What a screen reader says (8 words at most; not in the budgets).
abstract final class SpokenCopy {
  /// A face before it is shown.
  static const hidden = Template('{target}, hidden. Activate to show.');
}
