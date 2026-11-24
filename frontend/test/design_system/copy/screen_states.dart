import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/copy/role_text.dart';
import 'package:midnight_village/design_system/faces/face_content.dart';
import 'package:midnight_village/design_system/models/role.dart';

import 'copy_rules.dart';

// Every state of every screen in docs/specs/frontend/first-time-play.md
// section 3, as the lines visible at once, for the copy rules test. Each
// line is read from lib/design_system/copy/copy.dart. A held face counts
// with the screen under it (copy rule 1). Lines are counted as written, gaps
// unfilled (rule 1 exempts them); the face content
// (lib/design_system/faces/face_content.dart) fills these same templates.

/// A screen's states, by name: the lines visible at once in each.
typedef Screen = ({Map<String, List<Line>> states});

/// Every role text, laid out as the 04 face and 03b show it.
Iterable<(RoleId, List<Line>)> _roleTexts() => [
  for (final role in RoleId.values)
    (role, [for (final line in RoleText.of(role).lines) face(line)]),
];

/// One of every row of the 07 faces table (My night's result pages).
final _saw = <String, List<Object>>{
  'Seer, player': [SawCopy.seerPlayer],
  'Seer, center': [SawCopy.seerCenter],
  'Robber': [SawCopy.robbed],
  'Insomniac': [SawCopy.newCard],
  'Troublemaker': [SawCopy.swapped],
  'Drunk': [SawCopy.drunk],
  'Werewolves': [SawCopy.werewolves],
  'Lone Werewolf': [SawCopy.onlyYou],
  'Lone Werewolf, looked': [SawCopy.onlyYou, SawCopy.centerLook],
  'Minion': [SawCopy.werewolves],
  'Minion, none': [SawCopy.noWerewolves],
  'Masons': [SawCopy.masons],
  'Mason alone': [SawCopy.onlyYou],
  'Slept': [NightCopy.slept],
  'Chose, nothing happened': [SawCopy.didNothing],
};

/// Every window-1 page a phone carries into window 2 and the talk: slept,
/// copied, or copied and then a one-line result.
final _windowOne = <String, List<Object>>{
  'slept': [NightCopy.slept],
  'copied nothing': [SawCopy.didNothing],
  'copied': [NightCopy.copied],
  for (final MapEntry(:key, :value) in _saw.entries)
    if (value.length == 1) 'copied, then $key': [NightCopy.copied, ...value],
};

/// "You" on the board, with the board's title (the prompt's): each prompt's
/// instruction, the Doppelganger's page once her copy is back, and window
/// 2's second page under any prompt's title.
final _you = <String, (NightPrompt, List<Object>)>{
  for (final prompt in NightPrompt.values)
    prompt.name: (prompt, [prompt.instruction]),
  for (final followUp in NightPrompt.values)
    'copied, then ${followUp.name}': (
      followUp,
      [NightCopy.copied, followUp.instruction],
    ),
  for (final prompt in NightPrompt.values)
    for (final MapEntry(:key, :value) in _windowOne.entries)
      'window 2 page 2, $key, ${prompt.name}': (prompt, value),
};

/// The buttons a board of [prompt] shows: waiting for a pick, the picks
/// whole (what will happen), passing, and chosen; a sleeper's is quiet (and
/// carries the plain fallback words no board shows).
List<Object> _buttons(NightPrompt prompt) => [
  if (prompt.instruction == NightCopy.noChoice) ...[
    NightCopy.nothingToDo,
  ] else ...[
    NightCopy.chooseNone,
    NightCopy.chooseMore,
    NightCopy.chosen,
  ],
  prompt.go,
  prompt.pass,
];

/// My night held (08): the picture story's one sentence, each kind (a
/// name list joined with "and"), and what a screen reader hears of a card.
final _myNight = <String, List<Object>>{
  // The held face's last page: still `HoldToReveal`'s face for the note,
  // which shows the story instead (`away`).
  'dealt': [TalkCopy.dealt],
  for (final MapEntry(:key, :value) in _saw.entries) 'face, $key': value,
  for (final line in <Object>[
    NightCopy.slept, SawCopy.didNothing, SawCopy.swapped, //
    SawCopy.noWerewolves, NightStoryCopy.seerPlayer, NightStoryCopy.seerCenter,
    NightStoryCopy.robbed,
    NightStoryCopy.drunk,
    NightStoryCopy.now,
    NightStoryCopy.still,
    NightStoryCopy.onlyWerewolf,
    NightStoryCopy.minionOne,
    NightStoryCopy.onlyMason,
    NightStoryCopy.copied,
    NightStoryCopy.copiedSaw,
    NightStoryCopy.copiedCenter,
    NightStoryCopy.copiedTook,
    NightStoryCopy.copiedSwapped,
    NightStoryCopy.copiedDrunk,
    NightStoryCopy.copiedMinion,
    NightStoryCopy.copiedNone,
    NightStoryCopy.copiedNothing,
  ])
    '$line': [line],
  for (final list in [
    NightStoryCopy.werewolves,
    NightStoryCopy.minion,
    NightStoryCopy.masons,
  ])
    '$list': [list, NightStoryCopy.and],
};

List<Line> _face(List<Object> lines) => [for (final l in lines) face(l)];

/// The set-up page's lengths (the Doppelganger's is the role's name).
const _lengths = [
  DeckCopy.look,
  DeckCopy.lookCaption,
  DeckCopy.night,
  DeckCopy.nightCaption,
  DeckCopy.nightMinimum,
  DeckCopy.nightMinimumCaption,
  DeckCopy.talk,
  DeckCopy.vote,
  DeckCopy.droppedPhone,
  DeckCopy.droppedPhoneCaption,
  DeckCopy.hostAway,
  DeckCopy.hostAwayCaption,
  // The Doppelganger's row (the role's name) and its caption, while the
  // deck holds one.
  DeckCopy.doppelgangerCaption,
];

final screens = <String, Screen>{
  '01 Join': (
    states: {
      for (final last in [JoinCopy.lastWon, JoinCopy.lastLost]) ...{
        'empty name ($last)': [
          headline(JoinCopy.title),
          text(JoinCopy.nameHint),
          button(JoinCopy.startTable),
          button(JoinCopy.joinTable),
          text(JoinCopy.online),
          text(last),
        ],
        // "Join a table" gives way to the code and, until the code is
        // whole, "Join" locked, saying "Code"; "Start a table" the plaque.
        'join a table opened, no code yet ($last)': [
          headline(JoinCopy.title),
          text(JoinCopy.nameHint),
          button(JoinCopy.startTable),
          text(JoinCopy.codeHint),
          button(JoinCopy.codeHint),
          text(JoinCopy.online),
          text(last),
        ],
        // The code whole: "Join" the plaque, "Start a table" a scrap.
        'join a table opened ($last)': [
          headline(JoinCopy.title),
          text(JoinCopy.nameHint),
          button(JoinCopy.startTable),
          text(JoinCopy.codeHint),
          button(JoinCopy.join),
          text(JoinCopy.online),
          text(last),
        ],
      },
      'opened from a link': [
        headline(JoinCopy.title),
        text(JoinCopy.nameHint),
        button(JoinCopy.join),
      ],
      // Only a page in an Android browser: a quiet link under the numbers.
      'in an Android browser, Get the app': [
        headline(JoinCopy.title),
        text(JoinCopy.nameHint),
        button(JoinCopy.startTable),
        button(JoinCopy.joinTable),
        text(JoinCopy.online),
        text(JoinCopy.lastWon),
        button(JoinCopy.getApp),
      ],
    },
  ),
  // The scanner (spec 01b): no words while it looks; one calm line and a
  // way out when the camera cannot be used.
  '01b Scan': (
    states: {
      'looking': [],
      'camera off': [text(ScanCopy.cameraOff), button(ScanCopy.typeCode)],
    },
  ),
  '02 Table': (
    // The host's: the QR code's "Scan to join", the code's "Code", who is
    // here of how many, "Play with {n}" when fewer came, the set-up (the
    // chip, the talk's length, the roles face up: names exempt), "Edit",
    // the deal button's one label and a quiet labelled "Leave"; Share is a
    // glyph, spoken only.
    states: {
      for (final chip in DeckCopy.chips)
        for (final deal in <Object>[
          TableCopy.start,
          TableCopy.needPlayers,
          TableCopy.needMore,
        ])
          'host, $chip: $deal': [
            headline(TableCopy.scan),
            text(JoinCopy.codeHint),
            text(TableCopy.seated),
            button(TableCopy.playWith),
            button(chip),
            text(DeckCopy.talk),
            text(DeckCopy.minutes),
            button(TableCopy.editDeck),
            button(deal),
            button(CommonCopy.leave),
          ],
      // A table whose deck holds the wrong number of cards: the one button
      // says what to add or remove (and opens 03); "Edit" is hidden.
      for (final fix in <Object>[
        DeckCopy.addCard,
        DeckCopy.addCards,
        DeckCopy.removeCard,
        DeckCopy.removeCards,
      ])
        'host, the deck does not fit: $fix': [
          headline(TableCopy.scan),
          text(JoinCopy.codeHint),
          text(TableCopy.seated),
          button(TableCopy.playWith),
          button(DeckCopy.chips.first),
          text(DeckCopy.talk),
          text(DeckCopy.minutes),
          button(fix),
          button(CommonCopy.leave),
        ],
      // The host's "Leave" asks first, in a sheet over the table.
      'host: leave asked': [button(TableCopy.stay), button(CommonCopy.leave)],
      // Practice players seated (the host switched them on with a hold on
      // 03's "Players"): each row tagged "Practice", for host and guests.
      // Set for a number with fewer come: "Play with {n}" beside them (its
      // own allowance, [stateAllowances]).
      'host, set for a number, practice players, Play with {n}': [
        headline(TableCopy.scan),
        text(JoinCopy.codeHint),
        text(TableCopy.seated),
        button(TableCopy.playWith),
        button(DeckCopy.chips.first),
        text(DeckCopy.talk),
        text(DeckCopy.minutes),
        button(TableCopy.editDeck),
        button(TableCopy.start),
        button(CommonCopy.leave),
        text(TableCopy.practice),
      ],
      'host, practice players seated': [
        headline(TableCopy.scan),
        text(JoinCopy.codeHint),
        button(DeckCopy.chips.first),
        text(DeckCopy.talk),
        text(DeckCopy.minutes),
        button(TableCopy.editDeck),
        button(TableCopy.start),
        button(CommonCopy.leave),
        text(TableCopy.practice),
      ],
      'guest, practice players seated': [
        headline(TableCopy.hostDeals),
        text(TableCopy.scan),
        text(JoinCopy.codeHint),
        text(DeckCopy.chips.first),
        text(DeckCopy.talk),
        text(DeckCopy.minutes),
        button(CommonCopy.leave),
        text(TableCopy.practice),
      ],
      'guest': [
        headline(TableCopy.hostDeals),
        text(TableCopy.scan),
        text(JoinCopy.codeHint),
        text(TableCopy.seated),
        text(DeckCopy.chips.first),
        text(DeckCopy.talk),
        text(DeckCopy.minutes),
        button(CommonCopy.leave),
      ],
    },
  ),
  '03 Deck': (
    // The set-up page: the number of players, the deck face up (role names
    // are exempt; the count is digits), every length with its value. The
    // Practice stepper, only for a host who held "Players", has its own
    // allowance ([stateAllowances]).
    states: {
      for (final open in [true, false])
        open ? 'an open table' : 'set for a number': [
          headline(DeckCopy.headline),
          text(DeckCopy.players),
          if (open) text(DeckCopy.any) else text(TableCopy.seated),
          for (final chip in DeckCopy.chips) button(chip),
          for (final length in _lengths) text(length),
          text(CommonCopy.seconds),
          text(DeckCopy.minutes),
          text(DeckCopy.noClock),
          text(DeckCopy.off),
          button(DeckCopy.done),
        ],
      // The deck holds the wrong number of cards: the count's line says what
      // to do about it ([DeckCopy.countFix], its own allowance); "Done" stays.
      for (final name in ['too many', 'too few'])
        'the deck does not fit, $name': [
          headline(DeckCopy.headline),
          text(DeckCopy.players),
          text(TableCopy.seated),
          for (final chip in DeckCopy.chips) button(chip),
          text(DeckCopy.countFix),
          for (final length in _lengths) text(length),
          text(CommonCopy.seconds),
          text(DeckCopy.minutes),
          text(DeckCopy.noClock),
          text(DeckCopy.off),
          button(DeckCopy.done),
        ],
      // Practice players switched on (a hold on "Players"; never shown
      // otherwise): their stepper's name under Players, at a number.
      'practice switched on': [
        headline(DeckCopy.headline),
        text(DeckCopy.players),
        text(TableCopy.seated),
        text(DeckCopy.practice),
        for (final chip in DeckCopy.chips) button(chip),
        for (final length in _lengths) text(length),
        text(CommonCopy.seconds),
        text(DeckCopy.minutes),
        text(DeckCopy.noClock),
        text(DeckCopy.off),
        button(DeckCopy.done),
      ],
    },
  ),
  '03b Role sheet': (
    states: {
      for (final (role, lines) in _roleTexts())
        role.name: [
          headline(role.displayName),
          ...lines,
          button(RoleSheetCopy.close),
        ],
    },
  ),
  '04 Your card': (
    states: {
      // As the spec counts it: the whole role text, with the cue's word.
      for (final (role, lines) in _roleTexts())
        'held, ${role.name}': [
          headline(CardCopy.headline),
          cue(CommonCopy.hold),
          button(CardCopy.ready),
          text(CommonCopy.progress),
          ...lines,
        ],
      'face down, before the hold': [
        headline(CardCopy.headline),
        cue(CommonCopy.hold),
        button(CardCopy.readyLocked),
        text(CommonCopy.progress),
      ],
      'ready': [
        headline(CardCopy.headline),
        button(CommonCopy.readyDone),
        text(CommonCopy.progress),
      ],
    },
  ),
  '05 Night, between': (
    states: {
      'between': [headline(CommonCopy.nightTitle)],
    },
  ),
  '06 Night board': (
    states: {
      for (final MapEntry(key: key, value: (prompt, face)) in _you.entries)
        for (final label in _buttons(prompt))
          '$label, $key': [
            headline(prompt.title),
            // The candle's number in its last minute.
            text(CommonCopy.seconds),
            text(NightCopy.you),
            // The strip's label (the Seer's board adds her two others), and
            // each card's own.
            for (final label in [
              if (prompt.seats case final seats?) ...[
                seats,
                NightCopy.seerOr,
                ?prompt.strip,
              ] else
                NightCopy.centerLabel,
            ])
              text(label),
            for (final side in NightCopy.center) text(side),
            cue(CommonCopy.hold),
            button(label),
            ..._face(face),
          ],
    },
  ),
  '08 Talk': (
    states: {
      // A first game, My night not yet held: the cue's word on it.
      'not held': [
        headline(TalkCopy.headline),
        text(TalkCopy.myNight),
        cue(CommonCopy.hold),
        text(TalkCopy.deckCount),
        text(CommonCopy.progress),
        button(TalkCopy.readyToVote),
      ],
      for (final ready in [TalkCopy.readyToVote, CommonCopy.readyDone])
        for (final MapEntry(:key, :value) in _myNight.entries)
          '$ready, $key': [
            headline(TalkCopy.headline),
            text(TalkCopy.myNight),
            text(TalkCopy.deckCount),
            text(CommonCopy.progress),
            button(ready),
            ..._face(value),
          ],
    },
  ),
  '09 Vote': (
    states: {
      for (final label in <Object>[
        VoteCopy.pickName,
        VoteCopy.lockIn,
        VoteCopy.locked,
      ])
        '$label': [
          headline(VoteCopy.headline),
          button(label),
          text(VoteCopy.progress),
        ],
      // Practice players among the rows, each tagged.
      'practice players at the table': [
        headline(VoteCopy.headline),
        button(VoteCopy.lockIn),
        text(VoteCopy.progress),
        text(TableCopy.practice),
      ],
    },
  ),
  // The end board: the banner's two sentences (the whole line one and line
  // two of each outcome), the foot, and the slip of the Hunter's pick. The
  // names on cards, tags and strips are the players' and the roles', not
  // words.
  '12 End board': (
    states: {
      for (final you in _endYouLines) ...{
        'host, $you': [
          text(EndCopy.hangedToo),
          headline(you),
          text(EndCopy.picked),
          button(EndCopy.whatHappened),
          button(EndCopy.editDeck),
          button(EndCopy.playAgain),
        ],
        'guest, $you': [
          text(EndCopy.hangedToo),
          headline(you),
          text(EndCopy.picked),
          button(EndCopy.whatHappened),
          text(EndCopy.hostDealsNext),
          button(EndCopy.leave),
        ],
      },
      // The reveal at the stamp: the word on the hanged card, the banner
      // just out, the foot live.
      'reveal, the stamp': [
        text(EndCopy.hanged),
        headline(EndCopy.youWinVillage),
        text(EndCopy.hangedStamp),
        button(EndCopy.whatHappened),
        button(EndCopy.editDeck),
        button(EndCopy.playAgain),
      ],
      'nobody hanged, count form': [
        text(EndCopy.nobodyHanged),
        text(EndCopy.hangedCount),
        text(EndCopy.youWinShort),
        headline(EndCopy.youLoseShort),
        button(EndCopy.whatHappened),
        button(EndCopy.editDeck),
        button(EndCopy.playAgain),
      ],
      // What happened: the step's line in the banner, the cue the first
      // time, the scrap that leads back.
      'what happened, the deal': [
        headline(StoryCopy.dealt),
        text(StoryCopy.goOn),
        button(EndCopy.backToResult),
        button(EndCopy.editDeck),
        button(EndCopy.playAgain),
      ],
      for (final line in _storyLines)
        'what happened, $line': [
          headline(line),
          text(StoryCopy.who),
          text(StoryCopy.loneWerewolf),
          button(EndCopy.backToResult),
          button(EndCopy.editDeck),
          button(EndCopy.playAgain),
        ],
      'what happened, two lines': [button(EndCopy.backToResultTwoLines)],
      'one hanged, two hanged': [
        text(EndCopy.hanged),
        text(EndCopy.andThen),
        headline(EndCopy.youWinShort),
        button(EndCopy.whatHappenedTwoLines),
      ],
    },
  ),
};

const _storyLines = [
  StoryCopy.werewolves,
  StoryCopy.masons,
  StoryCopy.alone,
  StoryCopy.peeksMiddle,
  StoryCopy.minion,
  StoryCopy.minionNone,
  StoryCopy.seesPlayer,
  StoryCopy.seesMiddle,
  StoryCopy.takes,
  StoryCopy.swaps,
  StoryCopy.swapsMiddle,
  StoryCopy.still,
  StoryCopy.now,
  StoryCopy.copiesA,
  StoryCopy.copiesAn,
];

const _endYouLines = [
  EndCopy.youWinVillage,
  EndCopy.youWinWerewolves,
  EndCopy.youWinAlone,
  EndCopy.youLoseVillage,
  EndCopy.youLoseWerewolves,
  EndCopy.youLoseTanner,
  EndCopy.nobodyWins,
];

/// Every banner, with its button.
final banners = <(String, String?)>[
  (BannerCopy.lobbyNotFound, null),
  (BannerCopy.lobbyFull, null),
  (BannerCopy.lobbyClosed, null),
  (BannerCopy.alreadyInLobby, BannerCopy.goThere),
  (BannerCopy.tableClosed, BannerCopy.goHome),
  (BannerCopy.notSent, BannerCopy.tryAgain),
  (BannerCopy.cannotLeave, null),
  (BannerCopy.offline, null),
  (BannerCopy.slow, null),
  (BannerCopy.leftGame, BannerCopy.goHome),
  (BannerCopy.copied, null),
  (BannerCopy.deckDoesNotFit, null),
  (BannerCopy.cannotDeal, null),
];

/// Everything a screen reader says that no screen shows.
final spoken = [
  // Words on a card that no state above lists: the caption of the card a
  // step gave you (My night, held), and the Werewolf team's tag.
  NightStoryCopy.nowCard,
  RoleCopy.werewolfTeam,
  // The end board's cards and middle, said by the screen reader.
  EndCopy.cardYou,
  EndCopy.cardPicked,
  EndCopy.wasRole,
  EndCopy.hangedWord,
  EndCopy.diedWord,
  EndCopy.wonWord,
  EndCopy.votes,
  EndCopy.middle,
  SpokenCopy.hidden,
  NightStoryCopy.cardUp,
  NightStoryCopy.cardDown,
  SpokenCopy.working,
  SpokenCopy.pickFirst,
  // A dimmed night card: a tap still switches the pick.
  NightCopy.switchesPick,
  // 01's scan glyph, and the viewfinder's: what it does, Back and the light.
  ScanCopy.scan,
  ScanCopy.looking,
  ScanCopy.back,
  ScanCopy.light,
  // 02's Share glyph.
  TableCopy.share,
  // 03's steppers and the grid card's minus.
  SpokenCopy.lower,
  SpokenCopy.higher,
  SpokenCopy.takeOut,
];
