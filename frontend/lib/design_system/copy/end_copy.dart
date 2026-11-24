part of 'copy.dart';

/// The end board (the end-of-game screen): the banner's two sentences, the foot's words, and the labels.
/// The names are the players', never cut.
abstract final class EndCopy {
  /// Line 1: who was hanged.
  static const nobodyHanged = Words._('No one hanged.');
  static const hanged = Template('{names} hanged.');

  /// With the Hunter: the vote's dead, then the player the Hunter took.
  static const hangedToo = Template('{names} hanged, {chosen} too.');

  /// "Ana, Ben" and "Cleo": the names of a list.
  static const andThen = Template('{first} and {last}');

  /// Between the names of a list, before its last.
  static const listComma = Words._(', ');

  /// A number in place of the names, when the names will not fit.
  static const hangedCount = Template('{n} hanged.');

  /// Line 2 when you won.
  static const youWinVillage = Words._('You and the village win.');
  static const youWinWerewolves = Words._('You and the Werewolves win.');
  static const youWinAlone = Words._('You win alone.');

  /// Line 2 when you lost.
  static const youLoseVillage = Words._('You lose to the village.');
  static const youLoseWerewolves = Words._('You lose to the Werewolves.');
  static const youLoseTanner = Words._('The Tanner wins. You lose.');

  /// Line 2 when nobody won.
  static const nobodyWins = Words._('Nobody wins.');

  /// Line 2 shortened, when the sentence will not fit three lines.
  static const youWinShort = Words._('You win.');
  static const youLoseShort = Words._('You lose.');

  /// The foot.
  static const whatHappened = Words._('What happened');

  /// The same on two lines, where one line leaves no room for the middle cards.
  static const whatHappenedTwoLines = Words._('What\nhappened');

  /// While the night is replayed, the same scrap leads back to the result
  /// (two words; on two lines where one leaves no room).
  static const backToResult = Words._('The result');
  static const backToResultTwoLines = Words._('The\nresult');
  static const editDeck = Words._('Edit deck');
  static const playAgain = Words._('Play again');
  static const leave = CommonCopy.leave;
  static const hostDealsNext = Template('{host} deals next.');

  /// The slip the Hunter's pick hangs on.
  static const picked = Template("{hunter}'s pick");

  /// What a screen reader says for a card and the middle.
  static const cardName = Template('{name}.');
  static const cardRole = Template('{role}.');
  static const cardYou = Template('{name}, you.');
  static const cardPicked = Template("{name}, {hunter}'s pick.");
  static const wasRole = Template('{now}, was {dealt}.');
  static const hangedWord = Words._('Hanged.');

  /// The stamp that slams on the hanged in the reveal (12 pt capitals, the
  /// spec's one).
  static const hangedStamp = Words._('HANGED');
  static const diedWord = Words._('Died.');
  static const wonWord = Words._('Won.');
  static const votes = Template('Votes: {names}.');
  static const middle = Template('Middle cards: {roles}.');
}

/// What a step of What happened did, as its line says it ([StoryCopy.line]).
enum StoryAct {
  /// The cards as dealt, before anyone woke.
  dealt,

  /// The Werewolves, two or more, see each other.
  werewolves,

  /// The Masons, two or more, see each other.
  masons,

  /// A Werewolf or a Mason woke with nobody beside them.
  alone,

  /// A lone Werewolf looked at one middle card.
  peeksMiddle,

  /// The Minion saw the Werewolves ([StoryCopy.line]'s `names` empty: none).
  minion,

  /// The Seer looked at a player's card.
  seesPlayer,

  /// The Seer looked at two middle cards.
  seesMiddle,

  /// The Robber took a player's card.
  takes,

  /// The Troublemaker swapped two other players' cards.
  swaps,

  /// The Drunk swapped with a middle card.
  swapsMiddle,

  /// The Insomniac woke and looked at her own card.
  wakes,

  /// The Doppelganger copied a player's card.
  copies,
}

/// What happened's lines, one a step, shown in the banner while the night
/// is replayed on the end board. Each leads with the role that acted and
/// ends with what came of it; never a bare "Left", "Right" or "Middle".
abstract final class StoryCopy {
  static const dealt = Words._('The cards as dealt.');

  /// The first time only, on the board's lower edge: the board goes on
  /// (a cue, gone at the first step and never shown again on the device).
  static const goOn = Words._('Go on');

  /// The one who acted: their role, then their name.
  static const who = Template('{role} {name}');
  static const loneWerewolf = Words._('Lone Werewolf');
  static const werewolves = Template('Werewolves {names} meet.');
  static const masons = Template('Masons {names} meet.');
  static const alone = Template('{who} is alone.');
  static const peeksMiddle = Template('{who} peeks at a middle card.');
  static const minion = Template('{who} sees the Werewolves.');
  static const minionNone = Template('{who} sees no Werewolves.');
  static const seesPlayer = Template('{who} sees {other}: {seen}.');
  static const seesMiddle = Template('{who} peeks at two middle cards.');
  static const takes = Template("{who} takes {other}'s card.");
  static const swaps = Template('{who} swaps {other} and {third}.');
  static const swapsMiddle = Template('{who} swaps with a middle card.');
  static const still = Template('{who} wakes: still {seen}.');
  static const now = Template('{who} wakes: now the {seen}.');
  static const copiesA = Template('{who} copies {other}: now a {seen}.');
  static const copiesAn = Template('{who} copies {other}: now an {seen}.');

  /// The line of [act]: [role] is the actor's role as it reads (a
  /// Doppelganger's follow-up says "Doppelganger"), [name] the actor's,
  /// [names] a team's, [other] and [third] the players acted on, [seen] the
  /// role looked at or copied; [same] says the Insomniac's card never moved.
  static String line(
    StoryAct act, {
    String role = '',
    String name = '',
    List<String> names = const [],
    String other = '',
    String third = '',
    String seen = '',
    bool same = false,
  }) {
    // Filled in the order of their gaps: no word is written here.
    final w = who.fillIn([role, name]);
    return switch (act) {
      StoryAct.dealt => dealt,
      StoryAct.werewolves => werewolves.fillIn([listOf(names)]),
      StoryAct.masons => masons.fillIn([listOf(names)]),
      StoryAct.alone => alone.fillIn([w]),
      StoryAct.peeksMiddle => peeksMiddle.fillIn([w]),
      StoryAct.minion => (names.isEmpty ? minionNone : minion).fillIn([w]),
      StoryAct.seesPlayer => seesPlayer.fillIn([w, other, seen]),
      StoryAct.seesMiddle => seesMiddle.fillIn([w]),
      StoryAct.takes => takes.fillIn([w, other]),
      StoryAct.swaps => swaps.fillIn([w, other, third]),
      StoryAct.swapsMiddle => swapsMiddle.fillIn([w]),
      StoryAct.wakes => (same ? still : now).fillIn([w, seen]),
      StoryAct.copies =>
        (seen.isNotEmpty && _vowels.contains(seen.codeUnitAt(0))
                ? copiesAn
                : copiesA)
            .fillIn([w, other, seen]),
    };
  }

  /// A, E, I, O, U: "an Insomniac", "a Seer".
  static const _vowels = {0x41, 0x45, 0x49, 0x4F, 0x55};

  /// "Cleo", "Cleo and Esme", "Cleo, Esme and Fin".
  static String listOf(List<String> names) => names.length < 2
      ? names.join()
      : EndCopy.andThen.fillIn([
          names.sublist(0, names.length - 1).join(EndCopy.listComma),
          names.last,
        ]);
}
