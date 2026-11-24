part of '../screen_catalogue.dart';

/// Screen 02's states (one file per screen, so two screens' work never
/// meets in one file). In the gallery's order within the screen.
final _pages02 = <ScreenEntry>[
  ..._rebuilt('02-table', '02-table.png', {
    '': pumpTableHost,
    '-4': pumpTableHostFour,
    '-7-chaos': pumpTableHostChaos,
    '-alone': pumpTableHostAlone,
    '-9-long': pumpTableHostNine,
    '-9-long-x1.6': const _AtText(1.6, pumpTableHostNine),
    '-custom': pumpTableHostCustom,
    '-custom-short': pumpTableHostMismatch,
    '-dropped': pumpTableDropped,
    '-guest': const _NoMain(_guest, pumpTableGuest),
    '-handover': pumpTableHandover,
    '-seats-alone': pumpTableSeatsAlone,
    '-seats-3': pumpTableSeatsThree,
    '-seats-3-guest': _NoMain(
      _guest,
      (tester) => pumpTableSeatsThree(tester, viewer: 'Ugo'),
    ),
    '-seats-4': pumpTableSeatsFour,
    '-seats-4-guest': const _NoMain(_guest, pumpTableSeatsGuest),
    '-seats-7': pumpTableSeatsSeven,
    '-seats-lowered': pumpTableSeatsLowered,
    '-blocked': pumpTableLowered,
    '-blocked-guest': const _NoMain(_guest, pumpTableLoweredGuest),
    '-seats-full': pumpTableSeatsFull,
    '-practice': pumpTablePractice,
    '-practice-guest': _NoMain(
      _guest,
      (tester) => pumpTablePractice(tester, viewer: 'Quin'),
    ),
    '-practice-short': pumpTablePracticeShort,
    '-seats-x1.3': const _AtText(1.3, pumpTableSeatsAlone),
    '-x1.3': const _AtText(1.3, pumpTableHost),
    '-guest-x2': const _AtText(2.0, pumpTableGuest),
  }),
  // 02 while its table is read, and while it is not reachable; its taps
  // while they are on their way and when they fail.
  ..._rebuilt('02-table', null, {
    '-waiting': const _NoMain(_waits, pumpTableWaiting),
    '-offline': const _NoMain(_waits, pumpTableOffline),
    '-dealing': const _NoMain(_onItsWay, pumpTableDealing),
    '-deal-not-sent': pumpTableDealNotSent,
    '-leaving': const _NoMain(_onItsWay, pumpTableLeaving),
    '-leave-not-sent': const _NoMain(_guest, pumpTableLeaveNotSent),
  }),
];
