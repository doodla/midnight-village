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
  'Robber or Insomniac': [SawCopy.newCard],
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

/// "You" on the board: each prompt's instruction, the Doppelganger's page
/// once her copy is back, and window 2's second page.
final _you = <String, List<Object>>{
  for (final prompt in NightPrompt.values) prompt.name: [prompt.instruction],
  for (final followUp in NightPrompt.values)
    'copied, then ${followUp.name}': [NightCopy.copied, followUp.instruction],
  for (final MapEntry(:key, :value) in _windowOne.entries)
    'window 2 page 2, $key': value,
};

/// My night's pages (08).
final _myNight = <String, List<Object>>{
  'dealt': [TalkCopy.dealt],
  for (final MapEntry(:key, :value) in _windowOne.entries)
    'window 1, $key': value,
  for (final MapEntry(:key, :value) in _saw.entries) 'saw, $key': value,
};

List<Line> _face(List<Object> lines) => [for (final l in lines) face(l)];

const _tiles = [DeckCopy.talk, DeckCopy.vote, DeckCopy.night, DeckCopy.copy];

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
    // The spec's 7, and the host's quiet labelled "Leave" (review, 21
    // November 2026: a glyph in the corner handed the table away on one
    // stray tap); Share is a glyph, spoken only.
    budget: 8,
    states: {
      for (final chip in DeckCopy.chips)
        for (final deal in <Object>[
          TableCopy.deal,
          TableCopy.needPlayers,
          CommonCopy.addCards,
          CommonCopy.removeCards,
          CommonCopy.addCard,
          CommonCopy.removeCard,
        ])
          'host, $chip: $deal': [
            headline(TableCopy.scan),
            button(chip),
            button(TableCopy.editDeck),
            button(deal),
            button(CommonCopy.leave),
          ],
      // The host's "Leave" asks first, in a sheet over the table.
      'host: leave asked': [button(TableCopy.stay), button(CommonCopy.leave)],
      'guest': [
        headline(TableCopy.hostDeals),
        text(TableCopy.scan),
        button(CommonCopy.leave),
      ],
    },
  ),
  '03 Deck': (
    budget: 15,
    states: {
      // A chip's deck: its cards face up when the server sends them (role
      // names are exempt), "Edit" opens the grid; the lengths show once set,
      // "Copy" not (the chip's cards are the server's).
      'chips': [
        headline(DeckCopy.headline),
        for (final chip in DeckCopy.chips) button(chip),
        button(TableCopy.editDeck),
        for (final pace in DeckCopy.paces) button(pace),
        for (final tile in _tiles.take(3)) text(tile),
        button(DeckCopy.useDeck),
      ],
      // The grid open: the role names are exempt; "Copy" with the
      // Doppelganger in the deck.
      for (final use in <Object>[
        DeckCopy.useDeck,
        CommonCopy.addCards,
        CommonCopy.removeCards,
        CommonCopy.addCard,
        CommonCopy.removeCard,
      ])
        'grid: $use': [
          headline(DeckCopy.headline),
          for (final chip in DeckCopy.chips) button(chip),
          for (final pace in DeckCopy.paces) button(pace),
          for (final tile in _tiles) text(tile),
          button(use),
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
      ])
        for (final MapEntry(:key, :value) in _you.entries)
          '$label, $key': [
            headline(CommonCopy.nightTitle),
            text(NightCopy.you),
            for (final side in NightCopy.center) text(side),
            cue(CommonCopy.hold),
            button(label),
            ..._face(value),
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
        text(TalkCopy.progress),
        button(TalkCopy.readyToVote),
      ],
      for (final ready in [TalkCopy.readyToVote, CommonCopy.readyDone])
        for (final MapEntry(:key, :value) in _myNight.entries)
          '$ready, $key': [
            headline(TalkCopy.headline),
            text(TalkCopy.myNight),
            text(TalkCopy.progress),
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
      for (final dies in [CountCopy.dies, CountCopy.die])
        for (final hunter in [false, true])
          for (final team in TeamId.values)
            '$dies${hunter ? ' + Hunter' : ''}, ${team.name}': [
              headline(dies),
              if (hunter) text(CountCopy.diesToo),
              text(CountCopy.noVote),
              ..._deadCard(team),
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

/// A dead player's card on 10: "Now", "Dealt" (the card moved) and the team
/// tag. With several dead, the cards are shown one at a time: three cards'
/// captions at once would break the budget of 16 (a tie of two and the
/// Hunter's pick is 17).
List<Line> _deadCard(TeamId team) => [
  text(CountCopy.now),
  text(CountCopy.dealt),
  text(RoleText.teamTag(team)),
];

/// 11 above its buttons. The timeline's last row counts once ("Won" or
/// "Died" under every player); its other rows are capped on their own
/// ([timelineRows]).
List<Line> _results(String winner, String you) => [
  headline(winner),
  text(you),
  text(ResultsCopy.won),
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
  (BannerCopy.offline, null),
  (BannerCopy.leftGame, BannerCopy.goHome),
  (BannerCopy.copied, null),
  (BannerCopy.stillJoining, null),
  (BannerCopy.deckDoesNotFit, null),
  (BannerCopy.cannotDeal, null),
];

/// Everything a screen reader says that no screen shows.
final spoken = [
  SpokenCopy.hidden,
  SpokenCopy.working,
  // 02's Share glyph.
  TableCopy.share,
];
