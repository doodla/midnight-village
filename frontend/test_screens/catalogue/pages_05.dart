part of '../screen_catalogue.dart';

/// Screen 05's states (one file per screen, so two screens' work never
/// meets in one file). In the gallery's order within the screen.
final _pages05 = <ScreenEntry>[
  ..._rebuilt('05-night-loading', '05-night-waiting.png', {
    '': const _NoMain(_waits, pumpNightLoading),
  }),
];
