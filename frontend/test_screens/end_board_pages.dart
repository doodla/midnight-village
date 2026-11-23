import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/primitives/board_pieces.dart';
import 'package:midnight_village/design_system/primitives/death_mark.dart';
import 'package:midnight_village/design_system/primitives/paper_scrap.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/sliced_art.dart';
import 'package:midnight_village/design_system/primitives/vote_tag.dart';
import 'package:midnight_village/design_system/primitives/you_seal.dart';
import 'package:midnight_village/features/game/domain/end_board_metrics.dart';
import 'package:midnight_village/features/game/presentation/end/end_board_view.dart';
import 'package:midnight_village/features/game/presentation/end/end_foot.dart';

import '../test/helpers/end_board_pump.dart';
import '../test/helpers/outcome_samples.dart';
import '../test/helpers/screen_sweep.dart';
import 'screen_catalogue.dart';

// The end board (the end-of-game screen that will replace 10 The count and 11
// Results), static, for every outcome and player count: pages for `just
// screens` (strict at 360 and 390) and the pictures beside the mock. Each is
// the real `EndBoardView` on a recorded results body; the nine-player and
// ten-player tables are the recordings widened (`widened`), and the viewer is
// a seat (0 is the first). Each page is also a screen case: the sweep
// (test/screen_cases/) holds it to [endBoardSweep] at three phones and three
// text sizes, and presses its Play again like a finger.

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
      '12-end-werewolves-win',
      (t) => pumpEndBoard(t, recordedResults('results_werewolves_win')),
    ),
    (
      '12-end-hunter-chain',
      (t) => pumpEndBoard(t, recordedResults('results_hunter_chain')),
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
    ScreenEntry(
      id,
      mock: null,
      build: build,
      playerScreen: true,
      sweep: switch (id) {
        '12-end-guest' => endBoardGuestSweep,
        // Scrolled after it opens: the hanged need not be in view.
        '12-end-ten-end' || '12-end-ten-top' => endBoardScrolledSweep,
        _ => endBoardSweep,
      },
    ),
  // The phone's text at 1.6 (the gallery sets it on the phone).
  ScreenEntry(
    '12-end-text-1.6',
    mock: null,
    build: (t) => pumpEndBoard(t, recordedResults('results')),
    playerScreen: true,
    textScale: 1.6,
    sweep: endBoardSweep,
  ),
];

final _onBoard = find.descendant(
  of: find.byType(EndBoardWindow),
  matching: find.byType(BoardCard),
);
final _foot = find.byType(EndFootBand);

/// What the end board is held to, beyond every screen's rules: no card lies
/// on another; no tag on a card or another tag; the Hunter's slip covers no
/// tag, seal or ribbon; the board's pieces are on the screen; the foot's
/// pieces lie apart, on the screen, each 48 to touch; the banner's words lie
/// inside the banner; the hanged are in the board's window when it opens (on
/// the mocks' phone; `end_board_test.dart` opens the plan on every phone
/// and text size).
/// The host's foot has Play again.
final endBoardSweep = SweepPlan(
  mustSee: [find.byType(EndBoardWindow), _foot],
  apart: [
    Apart.each('cards', _onBoard),
    Apart.each('tags', find.byType(VoteTag)),
    Apart.from('a tag on a card', find.byType(VoteTag), _onBoard),
    Apart.from(
      'the slip',
      find.descendant(
        of: find.byType(EndBoardWindow),
        matching: find.byType(PaperSlip),
      ),
      find.byWidgetPredicate(
        (w) => w is VoteTag || w is YouSeal || w is DeathRibbon,
      ),
    ),
    Apart.each('the foot', _footPieces),
  ],
  rules: [_boardOnScreen, _footToTouch, _bannerHoldsItsWords],
  whenOpened: [_hangedInView],
);

/// The board scrolled after it opens: every rule but the hanged in view.
final endBoardScrolledSweep = SweepPlan(
  main: endBoardSweep.main,
  mustSee: endBoardSweep.mustSee,
  apart: endBoardSweep.apart,
  rules: [_boardOnScreen, _footToTouch, _bannerHoldsItsWords],
);

/// A guest's end board: the host deals next, no Play again.
final endBoardGuestSweep = SweepPlan(
  main: const MainAction.none('a guest waits for the host to deal again'),
  mustSee: endBoardSweep.mustSee,
  apart: endBoardSweep.apart,
  rules: endBoardSweep.rules,
  whenOpened: endBoardSweep.whenOpened,
);

/// The foot's pieces: its cards, its scraps, Play again, and a guest's line
/// that the host deals next.
final _footPieces = find.descendant(
  of: _foot,
  matching: find.byWidgetPredicate(
    (w) =>
        w is BoardCard ||
        w is PaperScrap ||
        w is PrimaryButton ||
        (w is Text &&
            (w.data ?? '').contains(
              EndCopy.hostDealsNext.fill({'host': ''}).trim(),
            )),
  ),
);

List<String> _boardOnScreen(WidgetTester tester, Size screen) => [
  for (final r in paintedRects(
    find.byWidgetPredicate(
      (w) => w is VoteTag || w is YouSeal || w is DeathRibbon,
    ),
  ))
    if (r.left < -0.5 || r.right > screen.width + 0.5) 'off the screen: $r',
  for (final r in paintedRects(_onBoard))
    if (r.left < -0.5 || r.right > screen.width + 0.5) 'a card off: $r',
  for (final r in paintedRects(_footPieces))
    if (!onScreen(r, screen)) 'a piece of the foot off the screen: $r',
];

List<String> _footToTouch(WidgetTester tester, Size screen) => [
  for (final e in [
    ...find.byType(PaperScrap).evaluate(),
    ...find.byType(PrimaryButton).evaluate(),
  ])
    if ((e.renderObject! as RenderBox).size.height < 48)
      '${e.widget.runtimeType} under 48 to touch',
];

List<String> _bannerHoldsItsWords(WidgetTester tester, Size screen) {
  final banner = tester.getRect(find.byType(BannerSlice));
  return [
    for (final r in paintedRects(
      find.descendant(
        of: find.byType(BannerSlice),
        matching: find.byType(Text),
      ),
    ))
      if (r.left < -1 ||
          r.right > screen.width + 1 ||
          r.top < banner.top - 1 ||
          r.bottom > banner.bottom + 1)
        'the banner\'s words leave it: $r in $banner',
  ];
}

List<String> _hangedInView(WidgetTester tester, Size screen) {
  final window = tester.getRect(find.byType(EndBoardWindow));
  final seen = Rect.fromLTRB(
    window.left,
    window.top + EndMetrics.roof,
    window.right,
    window.bottom - EndMetrics.lip,
  ).inflate(1);
  return [
    for (final e in _onBoard.evaluate())
      if ((e.widget as BoardCard).semantics?.contains(EndCopy.hangedWord) ??
          false)
        if (paintedRect(e) case final r
            when !seen.contains(r.topLeft) || !seen.contains(r.bottomRight))
          '${(e.widget as BoardCard).name} (hanged) is not in view: $r',
  ];
}
