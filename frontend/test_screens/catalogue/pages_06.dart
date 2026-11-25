part of '../screen_catalogue.dart';

/// Screen 06's states (one file per screen, so two screens' work never
/// meets in one file). In the gallery's order within the screen.
final _pages06 = <ScreenEntry>[
  // The Werewolf in a game, each of its three portraits (the gallery pins one
  // for every other picture, so a missing or wrong one would hide behind it).
  for (final wolf in WerewolfPortrait.values)
    ..._rebuilt('06-night-board', '06-night-action.png', {
      '-lone-werewolf-${wolf.name}': (tester) => _withWerewolf(
        wolf,
        () => pumpNightAs(tester, 'me_choose_prompt_werewolf_lone'),
      ),
    }),
  ..._rebuilt('06-night-board', null, {'-offline': pumpNightOffline}),
  ..._rebuilt('06-night-board', '06-night-action.png', {
    '': pumpNightBoard,
    '-sleeper': const _NoMain(
      'nothing to do tonight: the board waits for the day',
      pumpNightSleeper,
    ),
    '-picked': pumpNightPicked,
    '-seer-center': pumpNightSeerCenter,
    '-robber': (tester) => pumpNightAs(tester, 'me_choose_prompt_robber'),
    '-troublemaker': (tester) =>
        pumpNightAs(tester, 'me_choose_prompt_troublemaker'),
    '-troublemaker-long': pumpNightTroublemakerLong,
    '-lone-werewolf': (tester) =>
        pumpNightAs(tester, 'me_choose_prompt_werewolf_lone'),
    '-doppelganger': (tester) =>
        pumpNightAs(tester, 'me_choose_prompt_doppelganger_look'),
    '-chosen': const _NoMain(_done, pumpNightChosen),
    '-robber-chosen': const _NoMain(_done, pumpNightRobberChosen),
    '-follow-up': pumpNightFollowUp,
    '-chosen-seen': const _NoMain(_done, pumpNightChosenSeen),
    '-robber-chosen-seen': const _NoMain(_done, pumpNightRobberChosenSeen),
    '-3': pumpNightThree,
    '-4': pumpNightFour,
    '-9': pumpNightNine,
    '-10-long': pumpNightTenLong,
    '-10-long-x1.6': const _AtText(1.6, pumpNightTenLong),
    '-x1.3': const _AtText(1.3, pumpNightBoard),
  }),
];
