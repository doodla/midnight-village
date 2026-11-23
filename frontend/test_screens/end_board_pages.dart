import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/helpers/end_board_pump.dart';
import '../test/helpers/outcome_samples.dart';
import 'screen_catalogue.dart';

// The end board (the end-of-game screen that will replace 10 The count and 11
// Results), static, for every outcome and player count: pages for `just
// screens` (strict at 360 and 390) and the pictures beside the mock. Each is
// the real `EndBoardView` on a recorded results body; the nine-player and
// ten-player tables are the recordings widened (`widened`), and the viewer is
// a seat (0 is the first).

/// The end board on [results], for the player in seat [viewer].
Future<void> pumpEndBoard(
  WidgetTester tester,
  Map<String, dynamic> results, {
  int viewer = 0,
  bool host = true,
  double textScale = 1,
  Size? screen,
  bool scrolled = false,
  bool top = false,
}) async {
  if (screen != null) {
    tester.view.physicalSize = screen * tester.view.devicePixelRatio;
  }
  final controller = ScrollController();
  addTearDown(controller.dispose);
  await pumpEndBoardOn(
    tester,
    results,
    viewer: viewer,
    host: host,
    scale: textScale,
    controller: controller,
  );
  if (controller.hasClients && (scrolled || top)) {
    controller.jumpTo(scrolled ? controller.position.maxScrollExtent : 0);
    await tester.pump();
  }
}

/// The guest's page: Cleo, a Werewolf who lost to the village (the mock's
/// guest is one too).
const endGuestSeat = 2;

/// Ten players with long names, a tie (the mocks' 1d and 1e).
Map<String, dynamic> endTen() => widened(
  recordedResults('results_doppelganger'),
  add: 2,
  rename: longEndNames,
);

const _phone360x640 = Size(360, 640);

/// The pages, in the gallery's order.
final endBoardEntries = <ScreenEntry>[
  for (final (id, build) in <(String, Future<void> Function(WidgetTester))>[
    (
      '12-end-village-one-hanged',
      (t) => pumpEndBoard(t, recordedResults('results_moved_dead_card')),
    ),
    (
      '12-end-werewolves-nobody-hanged',
      (t) => pumpEndBoard(t, recordedResults('results_nobody_dies')),
    ),
    ('12-end-tie', (t) => pumpEndBoard(t, recordedResults('results_tie'))),
    ('12-end-hunter', (t) => pumpEndBoard(t, recordedResults('results'))),
    (
      '12-end-tanner',
      (t) => pumpEndBoard(t, recordedResults('results_tanner_alone')),
    ),
    (
      '12-end-doppelganger',
      (t) =>
          pumpEndBoard(t, recordedResults('results_doppelganger'), viewer: 1),
    ),
    (
      '12-end-three-players',
      (t) =>
          pumpEndBoard(t, recordedResults('results_three_players'), viewer: 1),
    ),
    ('12-end-ten-top', (t) => pumpEndBoard(t, endTen(), top: true)),
    ('12-end-ten-end', (t) => pumpEndBoard(t, endTen(), scrolled: true)),
    (
      '12-end-guest',
      (t) => pumpEndBoard(
        t,
        recordedResults('results_five'),
        viewer: endGuestSeat,
        host: false,
      ),
    ),
    (
      '12-end-text-1.6',
      (t) => pumpEndBoard(t, recordedResults('results'), textScale: 1.6),
    ),
    (
      '12-end-360x640',
      (t) => pumpEndBoard(
        t,
        recordedResults('results_moved_dead_card'),
        screen: _phone360x640,
      ),
    ),
  ])
    ScreenEntry(id, mock: null, build: build, playerScreen: true),
];
