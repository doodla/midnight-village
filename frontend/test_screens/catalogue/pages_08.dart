part of '../screen_catalogue.dart';

/// Screen 08's states (one file per screen, so two screens' work never
/// meets in one file). In the gallery's order within the screen.
final _pages08 = <ScreenEntry>[
  ..._rebuilt('08-talk', null, {
    '-waiting': const _NoMain(_waits, pumpTalkWaiting),
    '-wait-failing': const _NoMain(_waits, pumpTalkWaitFailing),
    '-offline': pumpTalkOffline,
  }),
  ..._rebuilt('08-talk', '08-talk.png', {
    '': pumpTalkOpen,
    '-open-drunk': pumpTalkOpenDrunk,
    '-open-x1.3': const _AtText(1.3, pumpTalkOpen),
    '-put-away': pumpTalkPutAway,
    '-slept': pumpTalkSlept,
    '-held': pumpTalkHeld,
    '-held-doppelganger': pumpTalkDoppelgangerHeld,
    '-ready': pumpTalkReady,
    '-not-sent': pumpTalkNotSent,
    '-3': pumpTalkThree,
    '-8-roles': pumpTalkEightRoles,
    '-9': pumpTalkNine,
    '-10-long': pumpTalkTenLong,
    '-x1.3': const _AtText(1.3, pumpTalkPutAway),
  }),
  // My night held, every night's picture story (each a recorded talk:
  // story_samples.dart).
  ..._rebuilt('08-talk', '08-talk.png', {
    for (final night in allNights.keys)
      '-held-$night': (tester) => pumpTalkStory(tester, night),
  }),
];
