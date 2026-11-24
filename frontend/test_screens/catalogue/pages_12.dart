part of '../screen_catalogue.dart';

/// Screen 12's states (one file per screen, so two screens' work never
/// meets in one file). In the gallery's order within the screen.
final _pages12 = <ScreenEntry>[
  // The end board's live states, through the shell (end_fixtures.dart).
  ..._rebuilt('12-end-shell', null, {
    '-loading': const _NoMain(_waits, pumpResultsLoading),
    '-playing-again': const _NoMain(_onItsWay, pumpResultsPlayingAgain),
    '-leaving': const _NoMain(_onItsWay, pumpResultsLeaving),
    '-not-sent': pumpResultsNotSent,
    '-refused': pumpResultsRefused,
  }),
];
