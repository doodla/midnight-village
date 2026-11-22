import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/copy/role_text.dart';
import 'package:midnight_village/design_system/faces/face_content.dart';
import 'package:midnight_village/design_system/models/role.dart';

import 'copy_rules.dart';

// Every state of every screen in docs/specs/frontend/first-time-play.md
// section 3, as the lines visible at once, for the copy budget test. Each
// line is read from lib/design_system/copy/copy.dart. A held face counts
// with the screen under it (copy rule 1). Lines are counted as written, gaps
// unfilled (rule 1 exempts them); the face content
// (lib/design_system/faces/face_content.dart) fills these same templates.

/// A screen's budget (copy rule 2) and its states, by name.
typedef Screen = ({int budget, Map<String, List<Line>> states});

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
final _you = <String, (String, List<Object>)>{
  for (final prompt in NightPrompt.values)
    prompt.name: (prompt.title, [prompt.instruction]),
  for (final followUp in NightPrompt.values)
    'copied, then ${followUp.name}': (
      followUp.title,
      [NightCopy.copied, followUp.instruction],
    ),
  for (final prompt in NightPrompt.values)
    for (final MapEntry(:key, :value) in _windowOne.entries)
      'window 2 page 2, $key, ${prompt.name}': (prompt.title, value),
};

/// My night's pages (08).
final _myNight = <String, List<Object>>{
  'dealt': [TalkCopy.dealt],
  for (final MapEntry(:key, :value) in _windowOne.entries)
    'window 1, $key': value,
  for (final MapEntry(:key, :value) in _saw.entries) 'saw, $key': value,
};

List<Line> _face(List<Object> lines) => [for (final l in lines) face(l)];

/// The set-up page's lengths (the Doppelganger's is the role's name).
const _lengths = [
  DeckCopy.look,
  DeckCopy.night,
  DeckCopy.nightMinimum,
  DeckCopy.talk,
  DeckCopy.vote,
  DeckCopy.droppedPhone,
  DeckCopy.hostAway,
];

const _winners = [
  ResultsCopy.villageWins,
  ResultsCopy.werewolvesWin,
  ResultsCopy.tannerWins,
  ResultsCopy.villageAndTanner,
  ResultsCopy.werewolvesAndTanner,
  ResultsCopy.nobodyWins,
];

final screens = <String, Screen>{
  '01 Join': (
    budget: 14,
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
        // "Join a table" gives way to the code and "Join".
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
    },
  ),
  '02 Table': (
    // The host's: the QR code's "Scan to join", the code's "Code", who is
    // here of how many, "Play with {n}" when fewer came, the set-up (the
    // chip, the talk's length, the roles face up: names exempt), "Edit",
    // the deal button's one label and a quiet labelled "Leave"; Share is a
    // glyph, spoken only.
    budget: 13,
    states: {
      for (final chip in DeckCopy.chips)
        for (final deal in <Object>[TableCopy.deal, TableCopy.needPlayers])
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
      // The host's "Leave" asks first, in a sheet over the table.
      'host: leave asked': [button(TableCopy.stay), button(CommonCopy.leave)],
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
    // are exempt; the count is digits), every length with its value.
    budget: 22,
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
    },
  ),
  '03b Role sheet': (
    budget: 30,
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
    budget: 34,
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
      'ready': [
        headline(CardCopy.headline),
        button(CommonCopy.readyDone),
        text(CommonCopy.progress),
      ],
    },
  ),
  '05 Night, between': (
    budget: 3,
    states: {
      'between': [headline(CommonCopy.nightTitle)],
    },
  ),
  '06 Night board': (
    budget: 20,
    states: {
      for (final label in <Object>[
        NightCopy.chooseNone,
        NightCopy.chooseMore,
        NightCopy.choose,
        NightCopy.keep,
        NightCopy.chosen,
        NightCopy.nothingToDo,
      ])
        for (final MapEntry(key: key, value: (title, face)) in _you.entries)
          '$label, $key': [
            headline(title),
            // The candle's number in its last minute.
            text(CommonCopy.seconds),
            text(NightCopy.you),
            for (final side in NightCopy.center) text(side),
            cue(CommonCopy.hold),
            button(label),
            ..._face(face),
          ],
    },
  ),
  '08 Talk': (
    budget: 15,
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
    budget: 8,
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
    },
  ),
  '10 The count': (
    budget: 16,
    states: {
      'nobody dies': [
        headline(CountCopy.nobodyDies),
        text(CountCopy.nobodyGotTwo),
        text(CountCopy.noVote),
        button(CountCopy.seeWhoWon),
      ],
      // One, two (a tie) or three (a tie and the Hunter's pick) dead
      // cards, each on any team.
      for (final dies in [CountCopy.dies, CountCopy.die])
        for (final hunter in [false, true])
          for (final team in TeamId.values)
            '$dies${hunter ? ' + Hunter' : ''}, ${team.name}': [
              headline(dies),
              if (hunter) text(CountCopy.huntersPick),
              text(CountCopy.noVote),
              ..._deadCards([
                for (var i = 0; i < (dies == CountCopy.die ? 2 : 1); i++) team,
                if (hunter) team,
              ]),
              button(CountCopy.seeWhoWon),
            ],
    },
  ),
  '11 Results': (
    budget: 13,
    states: {
      for (final winner in _winners)
        for (final you in [ResultsCopy.youWon, ResultsCopy.youLost]) ...{
          'host: $winner, $you': [
            ..._results(winner, you),
            button(ResultsCopy.playAgain),
            button(ResultsCopy.editDeck),
          ],
          'guest: $winner, $you': [
            ..._results(winner, you),
            text(ResultsCopy.hostDealsNext),
            button(CommonCopy.leave),
          ],
        },
    },
  ),
};

/// The dead players' cards on 10, every one moved: "Now" and "Dealt" are
/// said on the first card only (the others show the same arrow), and each
/// card has its team tag (a Doppelganger's caption is her role's name).
List<Line> _deadCards(List<TeamId> teams) => [
  text(CountCopy.now),
  text(CountCopy.dealt),
  for (final team in teams)
    text(
      team == TeamId.werewolf
          ? '${CountCopy.werewolfTeam}'
          : RoleText.teamTag(team),
    ),
];

/// 11 above its buttons. The timeline's last row counts once ("Won" or
/// "Died" under every player); its other rows are capped on their own
/// ([timelineRows]).
List<Line> _results(String winner, String you) => [
  headline(winner),
  text(you),
  text(ResultsCopy.won),
  text(ResultsCopy.copiedAs),
  text(ResultsCopy.center),
];

/// 11's timeline rows, each capped at 3 words (copy rule 2).
const timelineRowMax = 3;
final timelineRows = <Object>[
  TimelineCopy.copies,
  TimelineCopy.seeEachOther,
  TimelineCopy.wakesAlone,
  TimelineCopy.minionSees,
  TimelineCopy.minionSeesNone,
  TimelineCopy.seerPlayer,
  TimelineCopy.seerCenter,
  TimelineCopy.loneWerewolf,
  TimelineCopy.robber,
  TimelineCopy.troublemaker,
  TimelineCopy.drunk,
  TimelineCopy.insomniac,
  TimelineCopy.skip,
  ResultsCopy.died,
];

/// The prefixes before a timeline row: role names only.
final timelinePrefixes = [TimelineCopy.prefix, TimelineCopy.followUpPrefix];

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
  (BannerCopy.leftGame, BannerCopy.goHome),
  (BannerCopy.copied, null),
  (BannerCopy.deckDoesNotFit, null),
  (BannerCopy.cannotDeal, null),
];

/// Everything a screen reader says that no screen shows.
final spoken = [
  SpokenCopy.hidden,
  SpokenCopy.working,
  ResultsCopy.nightSpoken,
  // 02's Share glyph.
  TableCopy.share,
  // 03's steppers and the grid card's minus.
  SpokenCopy.lower,
  SpokenCopy.higher,
  SpokenCopy.takeOut,
];
