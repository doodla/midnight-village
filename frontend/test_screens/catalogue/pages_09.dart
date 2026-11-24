part of '../screen_catalogue.dart';

/// Screen 09's states (one file per screen, so two screens' work never
/// meets in one file). In the gallery's order within the screen.
final _pages09 = <ScreenEntry>[
  ..._rebuilt('09-vote', null, {
    '-waiting': const _NoMain(_waits, pumpVoteWaiting),
    '-not-sent': pumpVoteNotSent,
    '-offline': const _NoMain(_waits, pumpVoteOffline),
  }),
  ..._rebuilt('09-vote', '09-vote.png', {
    // "Pick a name" is the locked plaque: pressed, it nudges the slips.
    '': (tester) => pumpVoteOpen(tester),
    '-picked': pumpVotePicked,
    '-locked': const _NoMain(_done, pumpVoteLocked),
    '-restart-picked': pumpVoteRestartPicked,
    '-restart-locked': const _NoMain(_done, pumpVoteRestartLocked),
    '-3': pumpVoteThree,
    '-10-long': (tester) => pumpVoteTenLong(tester),
    '-10-long-x1.6': const _AtText(1.6, pumpVoteTenLong),
    '-practice': pumpVotePractice,
    '-x1.3': const _AtText(1.3, pumpVoteOpen),
  }),
];
