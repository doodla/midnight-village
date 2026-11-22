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

  /// Back to the start (02 guest, 11 guest).
  static const leave = 'Leave';

  /// How many are ready, under 04's card and on 08 (playtest: a bare
  /// "1 of 5" on 04 read as cards, not players).
  static const progress = Template('{d} of {n} ready');

  /// A custom deck that does not match the table (02, 03); one card is
  /// singular.
  static const addCards = Template('Add {n} cards');
  static const removeCards = Template('Remove {n} cards');
  static const addCard = 'Add 1 card';
  static const removeCard = 'Remove 1 card';

  /// Night and dawn share the title (05, 06).
  static const nightTitle = 'The village sleeps';

  /// A clock under a minute (05, 06, 08, 09, the deck's lengths): a bare
  /// "14" was not read as seconds (cold read on the real screens). From a
  /// minute it is "4:12", which reads as a clock.
  static const seconds = Template('{n} s');
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

  /// Spoken only: Share is a glyph beside "Scan to join", since the deck's
  /// chip name ("Simple") takes its word in the host's 7.
  static const share = 'Share';

  /// On the deck strip. Spec: "Edit deck", which puts the host's 02 at 8
  /// words for a budget of 7; the strip it sits on names the deck.
  static const editDeck = 'Edit';
  static const deal = Template('Deal to {n}');
  static const needPlayers = 'Need 3 players';

  /// The host's way out, quiet and labelled, behind a confirm ([stay]
  /// keeps the table): one stray tap must not hand the table away.
  static const stay = 'Stay';

  // Guest.
  static const hostDeals = Template('{host} deals');
}

/// 03 Deck (the host's, optional).
abstract final class DeckCopy {
  static const headline = "Tonight's deck";

  /// In the order of the server's chips (`simple`, `classic`, `chaos`).
  static const chips = ['Simple', 'Classic', 'Chaos'];

  /// In the order of the contract's presets (`quick`, `normal`, `long`).
  static const paces = ['Quick', 'Normal', 'Long'];

  /// A pace chip: its name and the talk it gives ("Normal 5:00"; playtest:
  /// "Long of what?").
  static const paceChip = Template('{pace} {talk}');

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
  static const shared = 'You are your last card.';
  static const villageWins =
      'A Werewolf dies. No Werewolf player: nobody dies.';

  // Tags; the Werewolf team's is the role name.
  static const village = 'Village';
  static const alone = 'Alone';
  static const copies = 'Copies';

  static const werewolfNight =
      'At dawn, see the other Werewolves. Alone at night: you may see 1 center card.';
  static const werewolfWins = 'No Werewolf and no Tanner dies.';
  static const minionNight = "At dawn, see the Werewolves. They don't see you.";
  static const minionWins =
      'With the Werewolves, even if you die. No Werewolf player: someone '
      'else dies, not the Tanner.';
  static const masonNight = 'At dawn, see the other Mason.';
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

  /// The label on the table's three cards as a group (the titles say
  /// "center cards"; a word a title uses is on the board).
  static const centerLabel = 'Center';

  // The button says what will happen, by the prompt's kind (spec section 8
  // and the "which, how many, where" test): the verb and the cards picked.
  static const chooseNone = 'Choose a card';
  static const chooseMore = 'Choose 1 more';
  static const see = Template('See {cards}');
  static const swapWith = Template('Swap with {cards}');
  static const swap = Template('Swap {cards}');
  static const copyCard = Template('Copy {cards}');

  // Picking "You" alone is passing, and the button says what passing is for
  // this role. The Robber alone keeps a card; the Drunk who passes is still
  // swapped (the server's seeded swap), so he asks the server to choose.
  static const skip = 'Skip';

  /// The fallback button words, for a prompt with nothing to say better
  /// (`NightPrompt.noChoice` carries them; a sleeper never shows them).
  static const choose = Template('Choose {cards}');

  /// Said after a dimmed card's name: dimmed here is not switched off, a tap
  /// still switches the pick (a vote row dimmed once locked is switched off).
  static const switchesPick = 'Switches your pick';
  static const keep = 'Keep my card';
  static const chooseForMe = 'Choose for me';
  static const chosen = 'Chosen';

  /// In the button's place on a board with nothing to choose (a sleeper's:
  /// spec section 8); quiet, with the done tick, never a thing to press.
  static const nothingToDo = 'Nothing to do';

  // The face of "You": what this prompt asks of the player.
  static const noChoice = 'Nothing to do tonight.';

  /// Spec: "Look at 1 player's card, or 2 center cards." (cold read on the
  /// real screens: whose card?) The role text's own words.
  static const seer = RoleCopy.seerNight;
  static const robber = 'Swap with 1 player. See your new card.';
  static const troublemaker = "Swap 2 other players' cards.";
  static const drunk = "Swap with 1 center card. Don't look.";
  static const loneWerewolf = 'You may see 1 center card.';
  static const doppelgangerLook = "Copy 1 player's role.";

  // The board's title on a phone with a choice: the role's night line
  // (RoleText) in a few words (a headline; the board's budget of 20 leaves
  // it 3 or 4 beside a copied Seer's face). A sleeper's
  // board keeps "The village sleeps". A tell to a glance, accepted: the
  // playtest read "The village sleeps" as wrong while acting.
  //
  // A title passes the "which, how many, where" test (spec section 1): read
  // with the face covered, it says which cards, how many and from where, in
  // words a card or label on the board also carries.
  static const seerTitle = '1 player or 2 center cards';
  static const robberTitle = 'Swap with 1 player';
  static const troublemakerTitle = "Swap 2 other players' cards";
  static const drunkTitle = 'Swap with a center card';
  static const loneWerewolfTitle = 'See 1 center card';
  static const doppelgangerTitle = "Copy a player's role";

  // The window-1 page.
  static const copied = Template('You copied {name}.');
  static const slept = 'You slept.';
}

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
  static const onlyYou = 'Only you.';
  static const centerLook = Template('{pos} was: {role}.');
  static const noWerewolves = 'There were no Werewolves.';
  static const masons = Template('Masons were: {names}.');

  /// The player chose, and nothing they picked meant anything for their
  /// role (spec section 3, "Trade-off": "You did nothing.").
  static const didNothing = 'You did nothing.';
}

/// 08 Talk.
abstract final class TalkCopy {
  static const headline = 'The village wakes';
  static const myNight = 'My night';
  static const readyToVote = 'Ready to vote';

  /// My night's first page.
  static const dealt = Template('Dealt: {role}');

  /// Tonight's deck on 08: a role with more than one
  /// card in it ("3 Villagers").
  static const deckCount = Template('{n} {roles}');
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

  /// 02's Share copied the link (no share sheet on this device).
  static const copied = 'Copied';

  /// Why the deal cannot happen (the server's `deal` or its refusal): the
  /// deck does not fit the table; any other reason.
  static const deckDoesNotFit = 'The deck does not fit.';
  static const cannotDeal = "Can't deal yet.";
}

/// What a screen reader says (8 words at most; not in the budgets).
abstract final class SpokenCopy {
  /// A face before it is shown.
  static const hidden = Template('{target}, hidden. Activate to show.');

  /// A button whose action is on its way.
  static const working = 'Working';
}
