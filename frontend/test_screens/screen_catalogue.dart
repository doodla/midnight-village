import 'package:flutter_test/flutter_test.dart';

import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/werewolf_portrait.dart';

import '../test/helpers/component_sheet.dart';
import '../test/helpers/screen_sweep.dart';
import '../test/helpers/sheet/story_samples.dart';
import '../test/helpers/shell_setup.dart';
import 'end_board_pages.dart';
import 'end_night_pages.dart';
import 'end_reveal_pages.dart';
import 'end_fixtures.dart';
import 'shell_fixtures.dart';
import 'story_fixtures.dart';
import 'table_fixtures.dart';

part 'catalogue/pages_01.dart';
part 'catalogue/pages_01b.dart';
part 'catalogue/pages_02.dart';
part 'catalogue/pages_03.dart';
part 'catalogue/pages_03b.dart';
part 'catalogue/pages_04.dart';
part 'catalogue/pages_05.dart';
part 'catalogue/pages_06.dart';
part 'catalogue/pages_08.dart';
part 'catalogue/pages_09.dart';
part 'catalogue/pages_12.dart';

/// One screen, or one state of a screen, in the gallery.
class ScreenEntry {
  /// A screen the app has: [build] puts the app into that state.
  const ScreenEntry(
    this.id, {
    required this.mock,
    required this.build,
    this.playerScreen = false,
    this.frames,
    this.sweep = const SweepPlan(),
    this.textScale = 1,
  }) : notBuilt = null;

  /// A screen the mocks have and the app does not yet: listed so the summary
  /// shows the gap.
  const ScreenEntry.notBuilt(this.id, {required this.mock, required String why})
    : notBuilt = why,
      build = null,
      playerScreen = false,
      frames = null,
      sweep = const SweepPlan(),
      textScale = 1;

  /// File name stem of the PNG, e.g. `02-table`; states add a suffix.
  final String id;

  /// The mock in docs/design/mocks/ this is compared with, or null.
  final String? mock;

  final Future<void> Function(WidgetTester tester)? build;

  /// For a screen the app lacks: what is missing.
  final String? notBuilt;

  /// A screen built to the first-time play spec, which the gallery holds to
  /// the reading floor (reading_floor.dart): every app screen, and the
  /// component sheet's screen pages.
  final bool playerScreen;

  /// Frames drawn (100 ms each) after the build before the picture; null for
  /// the gallery's own settling. A first frame is 1.
  final int? frames;

  /// What the screen sweep (test/screen_cases/) holds this state to beyond
  /// the rules every state keeps (nothing cut, overflowing or off the screen;
  /// every name whole and uncovered; the main action there, on the screen,
  /// reachable, labelled, 48 to touch and pressed by a finger): what must be
  /// seen, what lies apart, the state's own rules. A state with no main
  /// action says why here (`SweepPlan.noMainAction`).
  /// Declared here, once, beside the state: the page, the sweep and the
  /// finger's press all come from this entry.
  final SweepPlan sweep;

  /// The phone's text size this page is drawn at (the gallery sets it on the
  /// phone). A page at another size than the phone's own is the twin of the
  /// state at 1, which the sweep turns through every text size already: it
  /// is drawn, not swept again.
  final double textScale;
}

/// Every screen and state, by screen (each screen's states are its own file,
/// `catalogue/pages_<screen>.dart`), then the end board's pages and the component
/// sheet. Adding a state is one entry in its screen's file; a new screen is a new
/// file and one line here.
final screenCatalogue = <ScreenEntry>[
  ..._pages01,
  ..._pages01b,
  ..._pages02,
  ..._pages03,
  ..._pages03b,
  ..._pages04,
  ..._pages05,
  ..._pages06,
  ..._pages08,
  ..._pages09,
  ..._pages12,
  ...endBoardEntries,
  ...endRevealEntries,
  ...endNightEntries,
  ...componentSheet,
];

/// Runs [build] with every game drawn with the Werewolf portrait [wolf], then
/// puts the gallery's pin back.
Future<void> _withWerewolf(
  WerewolfPortrait wolf,
  Future<void> Function() build,
) async {
  final pinned = ShellSetup.pinnedWerewolf;
  ShellSetup.pinnedWerewolf = wolf;
  try {
    await build();
  } finally {
    ShellSetup.pinnedWerewolf = pinned;
  }
}

typedef _Pump = Future<void> Function(WidgetTester tester);

// Why a state has no main action (`SweepPlan.noMainAction`).
const _opening = 'the opening reads the saved account: it waits';
const _onItsWay = 'the tap is on its way: its button is busy';
const _waits = 'the screen waits for what it shows (a Waiting sign)';
const _elsewhere =
    'seated at another table: Join is not offered (never a second seat); the '
    "one way on is the text link \"Go there\" on the line \"You're at "
    "another table.\", which is also Back's";
const _guest = 'a guest waits for the host to deal';
const _sheet = 'a sheet the player opened: Close, the scrim or Back close it';
const _done =
    'done (ready, chosen or locked): it waits for the others; a send that '
    'failed is a quiet line with its own Try again';

/// A state with no main action, saying [why] (a wait for the others, a
/// lock): `SweepPlan.noMainAction`, the sweep's one opt-out.
class _NoMain {
  const _NoMain(this.why, this.build);

  final String why;
  final _Pump build;
}

/// The state [build] draws, at the phone's text size [scale]: a page of its
/// own in `just screens`. The sweep turns every state through the text sizes
/// already, so it sweeps the state once, as [build] draws it.
class _AtText {
  const _AtText(this.scale, this.build);

  final double scale;
  final _Pump build;
}

/// A rebuilt screen's states ([states]: suffix to a builder, a [_NoMain] or
/// an [_AtText]), each a player screen next to [mock].
List<ScreenEntry> _rebuilt(
  String id,
  String? mock,
  Map<String, Object> states,
) => [
  for (final MapEntry(key: suffix, value: state) in states.entries)
    switch (state) {
      final _Pump build => ScreenEntry(
        '$id$suffix',
        mock: mock,
        build: build,
        playerScreen: true,
      ),
      _NoMain(:final why, :final build) => ScreenEntry(
        '$id$suffix',
        mock: mock,
        build: build,
        playerScreen: true,
        sweep: SweepPlan.noMainAction(why),
      ),
      _AtText(:final scale, :final build) => ScreenEntry(
        '$id$suffix',
        mock: mock,
        build: build,
        playerScreen: true,
        textScale: scale,
      ),
      _ => throw ArgumentError('$id$suffix: not a state: $state'),
    },
];

/// The component sheet (test/helpers/component_sheet.dart): each screen
/// rebuilt from the primitives to the spec, next to its mock, and each state
/// page on every ground: `c-<page>-<ground>`. Its screen pages are player
/// screens.
final componentSheet = [
  for (final page in ComponentPage.values)
    for (final ground in page.grounds)
      ScreenEntry(
        sheetId(page, ground),
        mock: page.mock,
        build: (tester) => pumpComponentPage(tester, page, ground),
        playerScreen: page.playerScreen,
      ),
];

/// A component sheet page's catalogue id.
String sheetId(ComponentPage page, GroundKind ground) =>
    'c-${page.name}-${ground.name}';
