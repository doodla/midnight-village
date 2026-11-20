// The cold-read pack (first-time play spec, section 5, hook 10): four
// first-game journeys through one recorded game (game 7 of
// contract_samples/, test/helpers/sheet/sheet_data.dart), each the screens
// one phone shows in order, to build/playtest/<journey>/screen-NN.png. Each
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

/// `--dart-define=SCREENS_WIDTH=360` renders at another phone width.
const _width = int.fromEnvironment('SCREENS_WIDTH', defaultValue: 390);

/// The night and the talk, as [viewer]'s phone has them: its card, a look,
/// the board, what it tapped, Choose, the talk and My night.
List<(ComponentPage, Viewer)> _night(Viewer viewer, {bool holdYou = true}) => [
  (ComponentPage.card, viewer),
  (ComponentPage.cardHeld, viewer),
  (ComponentPage.action, viewer),
  if (holdYou) (ComponentPage.actionHeld, viewer),
  (ComponentPage.actionPicked, viewer),
  (ComponentPage.actionChosen, viewer),
  (ComponentPage.talk, viewer),
  (ComponentPage.talkHeld, viewer),
];

/// Each journey's screens, in the order its phone shows them.
final journeys = <String, List<(ComponentPage, Viewer)>>{
  // Ana starts the table and deals; she is the Seer and looks at Cleo's card.
  'host': [
    (ComponentPage.join, Viewer.seer),
    (ComponentPage.table, Viewer.seer),
    (ComponentPage.deck, Viewer.seer),
    (ComponentPage.sheet, Viewer.seer),
    ..._night(Viewer.seer, holdYou: false),
    (ComponentPage.vote, Viewer.seer),
    (ComponentPage.votePicked, Viewer.seer),
    (ComponentPage.voteLocked, Viewer.seer),
    (ComponentPage.count, Viewer.seer),
    (ComponentPage.results, Viewer.seer),
  ],
  // Ben joins with the code; he is the Robber and takes Ana's card.
  'guest': [
    (ComponentPage.join, Viewer.robber),
    (ComponentPage.joinCode, Viewer.robber),
    (ComponentPage.tableGuest, Viewer.robber),
    ..._night(Viewer.robber),
    (ComponentPage.vote, Viewer.robber),
    (ComponentPage.count, Viewer.robber),
    (ComponentPage.resultsGuest, Viewer.robber),
  ],
  // Esme is a Villager: nothing to do at night, and still a turn to take.
  'sleeper': [
    ..._night(Viewer.villager),
    (ComponentPage.vote, Viewer.villager),
    (ComponentPage.count, Viewer.villager),
    (ComponentPage.resultsGuest, Viewer.villager),
  ],
  // Ana's night, read closely: what "You" says, her pick, what she saw.
  'seer': [
    ..._night(Viewer.seer),
    (ComponentPage.vote, Viewer.seer),
    (ComponentPage.votePicked, Viewer.seer),
    (ComponentPage.count, Viewer.seer),
    (ComponentPage.resultsGuest, Viewer.seer),
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
      for (final (i, (page, viewer)) in steps.indexed) {
        final name = 'screen-${(i + 1).toString().padLeft(2, '0')}';
        testWidgets('$name ${page.name}', (tester) async {
          final before = {...learned};
          learned.addAll(page.teaches);
          final capture = await captureScreen(
            tester,
            (tester) => pumpComponentPage(
              tester,
              page,
              page.grounds.single,
              viewer: viewer,
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
