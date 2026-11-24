part of '../screen_catalogue.dart';

/// Screen 01b's states (one file per screen, so two screens' work never
/// meets in one file). In the gallery's order within the screen.
final _pages01b = <ScreenEntry>[
  // The scanner 01 opens (no mock: its pictures are the build's own).
  ..._rebuilt('01b-scan', null, {
    '': const _NoMain(
      'the scanner looks for a code: nothing to press',
      pumpScanLooking,
    ),
    '-found': const _NoMain('a code is found: the table opens', pumpScanFound),
    '-refused': pumpScanRefused,
    '-x1.3': const _AtText(1.3, pumpScanLooking),
  }),
];
