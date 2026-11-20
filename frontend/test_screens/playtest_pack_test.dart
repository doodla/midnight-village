// The cold-read pack (first-time play spec, section 5, hook 10): four
// first-game journeys through one recorded game (game 7 of
// contract_samples/, test/helpers/sheet/sheet_data.dart), each the screens
// one phone shows in order, to build/playtest/<journey>/screen-NN.png. 01 to
// 03b are the app's real screens through its routes and providers, on the
// recorded lobby bodies (test_screens/table_fixtures.dart); the night and
// after are the component sheet's pages until their screens land. Each
// phone's taps and faces are the ones the server recorded, and what it has
// learned carries from screen to screen. Hand a folder to someone who has
// never played and ask, screen by screen, what they would do next. Run it
// with `just playtest-pack`; it is not part of `just test`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';

import '../test/helpers/component_sheet.dart';
import '../test/helpers/sheet/sheet_data.dart';
import 'screen_gallery.dart';
import 'table_fixtures.dart';

/// One screen of a journey: a component sheet page on a phone of the
/// recorded game, or a real screen reached through the app ([build]).
typedef _Step = ({
  String name,
  ComponentPage? page,
  Viewer? viewer,
  Future<void> Function(WidgetTester tester)? build,
});

_Step _page(ComponentPage page, Viewer viewer) =>
    (name: page.name, page: page, viewer: viewer, build: null);

_Step _real(String name, Future<void> Function(WidgetTester tester) build) =>
    (name: name, page: null, viewer: null, build: build);

/// `--dart-define=SCREENS_WIDTH=360` renders at another phone width.
const _width = int.fromEnvironment('SCREENS_WIDTH', defaultValue: 390);

/// The night and the talk, as [viewer]'s phone has them: its card, a look,
/// the board, what it tapped, Choose, the talk and My night.
List<_Step> _night(Viewer viewer, {bool holdYou = true}) => [
  _page(ComponentPage.card, viewer),
  _page(ComponentPage.cardHeld, viewer),
  _page(ComponentPage.action, viewer),
  if (holdYou) _page(ComponentPage.actionHeld, viewer),
  _page(ComponentPage.actionPicked, viewer),
  _page(ComponentPage.actionChosen, viewer),
  _page(ComponentPage.talk, viewer),
  _page(ComponentPage.talkHeld, viewer),
];

/// Each journey's screens, in the order its phone shows them.
final journeys = <String, List<_Step>>{
  // Ana starts the table and deals; she is the Seer and looks at Cleo's card.
  'host': [
    _real('join', pumpJoinFresh),
    _real('joinNamed', pumpJoinNamed),
    _real('tableAlone', pumpTableHostAlone),
    _real('table', pumpTableHost),
    _real('deck', pumpDeckChips),
    _real('deckGrid', pumpDeckGrid),
    _real('deckRole', pumpDeckRole),
    ..._night(Viewer.seer, holdYou: false),
    _page(ComponentPage.vote, Viewer.seer),
    _page(ComponentPage.votePicked, Viewer.seer),
    _page(ComponentPage.voteLocked, Viewer.seer),
    _page(ComponentPage.count, Viewer.seer),
    _page(ComponentPage.results, Viewer.seer),
  ],
  // Ben scans Ana's QR code; he is the Robber and takes Ana's card.
  'guest': [
    _real('joinLink', pumpJoinLink),
    _real('joinLinkNamed', pumpJoinLinkNamed),
    _real('tableGuest', pumpTableGuest),
    ..._night(Viewer.robber),
    _page(ComponentPage.vote, Viewer.robber),
    _page(ComponentPage.count, Viewer.robber),
    _page(ComponentPage.resultsGuest, Viewer.robber),
  ],
  // Esme is a Villager: nothing to do at night, and still a turn to take.
  'sleeper': [
    ..._night(Viewer.villager),
    _page(ComponentPage.vote, Viewer.villager),
    _page(ComponentPage.count, Viewer.villager),
    _page(ComponentPage.resultsGuest, Viewer.villager),
  ],
  // Ana's night, read closely: what "You" says, her pick, what she saw.
  'seer': [
    ..._night(Viewer.seer),
    _page(ComponentPage.vote, Viewer.seer),
    _page(ComponentPage.votePicked, Viewer.seer),
    _page(ComponentPage.count, Viewer.seer),
    _page(ComponentPage.resultsGuest, Viewer.seer),
  ],
};

void main() {
  for (final MapEntry(key: journey, value: steps) in journeys.entries) {
    group(journey, () {
      final dir = Directory('build/playtest/$journey');
      setUpAll(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
        dir.createSync(recursive: true);
      });

      // A first game: nothing learned at the start, then what each screen
      // taught, carried on.
      final learned = <Cue>{};
      for (final (i, step) in steps.indexed) {
        final name = 'screen-${(i + 1).toString().padLeft(2, '0')}';
        testWidgets('$name ${step.name}', (tester) async {
          final before = {...learned};
          final page = step.page;
          if (page != null) learned.addAll(page.teaches);
          final capture = await captureScreen(
            tester,
            step.build ??
                (tester) => pumpComponentPage(
                  tester,
                  page!,
                  page.grounds.single,
                  viewer: step.viewer!,
                  learned: before,
                ),
            width: _width,
            playerScreen: true,
          );
          if (capture.failure case final failure?) fail(failure);
          File('${dir.path}/$name.png').writeAsBytesSync(capture.png!);
          expect(capture.findings, isEmpty);
        });
      }
    });
  }
}
