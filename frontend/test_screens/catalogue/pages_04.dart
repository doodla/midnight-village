part of '../screen_catalogue.dart';

/// Screen 04's states (one file per screen, so two screens' work never
/// meets in one file). In the gallery's order within the screen.
final _pages04 = <ScreenEntry>[
  // 04 to the end board, through the real shell (shell_fixtures.dart,
  // end_fixtures.dart).
  ..._rebuilt('04-your-card', '04-your-card.png', {
    '': pumpYourCard,
    '-held': pumpYourCardHeld,
    '-held-minion': pumpYourCardHeldMinion,
    '-held-doppelganger': (tester) =>
        pumpYourCardHeldAs(tester, 'Doppelganger'),
    // The Werewolf's three portraits, each held on the card.
    for (final wolf in WerewolfPortrait.values)
      '-held-werewolf-${wolf.name}': (tester) =>
          _withWerewolf(wolf, () => pumpYourCardHeldAs(tester, 'Werewolf')),
    '-ready': const _NoMain(_done, pumpYourCardReady),
    '-x1.3': const _AtText(1.3, pumpYourCard),
    '-held-minion-x1.6': const _AtText(1.6, pumpYourCardHeldMinion),
  }),
  ..._rebuilt('04-your-card', null, {
    '-waiting': const _NoMain(_waits, pumpYourCardWaiting),
    '-wait-failing': const _NoMain(_waits, pumpYourCardWaitFailing),
    '-not-sent': const _NoMain(_done, pumpYourCardNotSent),
  }),
];
