part of '../screen_catalogue.dart';

/// Screen 03's states (one file per screen, so two screens' work never
/// meets in one file). In the gallery's order within the screen.
final _pages03 = <ScreenEntry>[
  ..._rebuilt('03-deck', null, {
    '-waiting': const _NoMain(_waits, pumpDeckWaiting),
    '-offline': const _NoMain(_waits, pumpDeckOffline),
  }),
  ..._rebuilt('03-deck', '03-deck.png', {
    '': pumpDeckChips,
    '-chaos': pumpDeckChaos,
    '-edit': pumpDeckEdit,
    '-grid': pumpDeckGrid,
    '-grid-short': pumpDeckGridShort,
    '-grid-over': pumpDeckGridOver,
    '-seats-8': pumpDeckSeats,
    '-alone': pumpDeckAlone,
    '-lengths': pumpDeckLengths,
    '-lengths-doppelganger': pumpDeckLengthsDoppelganger,
    '-practice': pumpDeckPractice,
    '-practice-switched': pumpDeckPracticeSwitched,
    '-x1.3': const _AtText(1.3, pumpDeckAlone),
  }),
];
