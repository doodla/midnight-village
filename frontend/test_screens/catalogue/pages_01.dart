part of '../screen_catalogue.dart';

/// Screen 01's states (one file per screen, so two screens' work never
/// meets in one file). In the gallery's order within the screen.
final _pages01 = <ScreenEntry>[
  // 01 to 03b through the app's routes (table_fixtures.dart).
  // Home before 01: the saved account read back (then a try unanswered).
  ..._rebuilt('01-home-reading-account', null, {
    '': const _NoMain(_opening, pumpHomeReading),
    '-unanswered': const _NoMain(_opening, pumpHomeUnanswered),
    '-slow': const _NoMain(_opening, pumpHomeSlow),
    '-seat-unknown': const _NoMain(_opening, pumpHomeSeatUnknown),
  }),
  // The opening in its first frame (no sign yet: an answer that comes now
  // shows none).
  ScreenEntry(
    '01-home-reading-account-first-frame',
    mock: null,
    build: pumpHomeFirstFrame,
    playerScreen: true,
    frames: 1,
    sweep: SweepPlan.noMainAction(_opening),
  ),
  // What 01's taps look like while they are on their way and when they fail.
  ..._rebuilt('01-join', null, {
    '-starting': const _NoMain(_onItsWay, pumpJoinStarting),
    '-joining': const _NoMain(_onItsWay, pumpJoinJoining),
    '-join-not-sent': pumpJoinNotSent,
    '-start-not-sent': pumpStartNotSent,
    '-no-table': pumpJoinRefused,
    '-full': (tester) =>
        pumpJoinRefused(tester, sample: 'join_full', status: 400),
    '-playing': (tester) =>
        pumpJoinRefused(tester, sample: 'join_closed', status: 400),
  }),
  ..._rebuilt('01-join', '01-join.png', {
    '': pumpJoinFresh,
    '-returning': pumpJoinReturning,
    // The one plaque: Start a table until the code is whole, then Join.
    '-code-open': pumpJoinCodeOpen,
    '-code': pumpJoinCode,
    '-link': pumpJoinLink,
    '-link-named': pumpJoinLinkNamed,
    '-link-elsewhere': const _NoMain(_elsewhere, pumpJoinLinkElsewhere),
    '-closed': pumpJoinClosed,
    '-keyboard': pumpJoinKeyboard,
    '-android-web': pumpJoinAndroidWeb,
    '-android-web-fresh': pumpJoinAndroidWebFresh,
    '-android-web-keyboard': pumpJoinAndroidWebKeyboard,
    '-android-web-x2': const _AtText(2.0, pumpJoinAndroidWeb),
    '-x1.3': const _AtText(1.3, pumpJoinFresh),
    '-x1.6': const _AtText(1.6, pumpJoinFresh),
    '-code-x1.6': const _AtText(1.6, pumpJoinCode),
    '-x2': const _AtText(2.0, pumpJoinFresh),
  }),
];
