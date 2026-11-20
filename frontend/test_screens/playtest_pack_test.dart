// The cold-read pack (first-time play spec, section 5, hook 10): four
// first-game journeys, each the screens one phone shows in order, rendered
// from the component sheet's pages to build/playtest/<journey>/screen-NN.png.
// Hand a folder to someone who has never played and ask, screen by screen,
// what they would do next. Run it with `just playtest-pack`; it is not part of
// `just test`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../test/helpers/component_sheet.dart';
import 'screen_gallery.dart';

/// `--dart-define=SCREENS_WIDTH=360` renders at another phone width.
const _width = int.fromEnvironment('SCREENS_WIDTH', defaultValue: 390);

/// Each journey's screens, in the order its phone shows them.
const journeys = {
  // Starts the table, deals, is a Villager, votes.
  'host': [
    ComponentPage.join,
    ComponentPage.table,
    ComponentPage.deck,
    ComponentPage.sheet,
    ComponentPage.card,
    ComponentPage.cardHeldVillager,
    ComponentPage.action,
    ComponentPage.actionPicked,
    ComponentPage.talk,
    ComponentPage.vote,
    ComponentPage.votePicked,
    ComponentPage.voteLocked,
    ComponentPage.count,
    ComponentPage.results,
  ],
  // Joins with a code and waits for the host.
  'guest': [
    ComponentPage.join,
    ComponentPage.joinCode,
    ComponentPage.tableGuest,
    ComponentPage.card,
    ComponentPage.cardHeldVillager,
    ComponentPage.action,
    ComponentPage.actionPicked,
    ComponentPage.talk,
    ComponentPage.vote,
    ComponentPage.count,
    ComponentPage.resultsGuest,
  ],
  // Has nothing to do at night, and must still take a turn.
  'sleeper': [
    ComponentPage.card,
    ComponentPage.cardHeldVillager,
    ComponentPage.action,
    ComponentPage.actionHeldVillager,
    ComponentPage.actionPicked,
    ComponentPage.wait,
    ComponentPage.talk,
    ComponentPage.talkHeld,
    ComponentPage.vote,
    ComponentPage.count,
    ComponentPage.resultsGuest,
  ],
  // Looks at two center cards, then reads what she saw at the talk.
  'seer': [
    ComponentPage.card,
    ComponentPage.cardHeld,
    ComponentPage.actionHeld,
    ComponentPage.actionOneMore,
    ComponentPage.actionTwoPicks,
    ComponentPage.actionChosen,
    ComponentPage.talk,
    ComponentPage.talkHeld,
    ComponentPage.talkSeer,
    ComponentPage.vote,
    ComponentPage.votePicked,
    ComponentPage.count,
    ComponentPage.resultsGuest,
  ],
};

void main() {
  for (final MapEntry(key: journey, value: pages) in journeys.entries) {
    group(journey, () {
      final dir = Directory('build/playtest/$journey');
      setUpAll(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
        dir.createSync(recursive: true);
      });

      for (final (i, page) in pages.indexed) {
        final name = 'screen-${(i + 1).toString().padLeft(2, '0')}';
        testWidgets('$name ${page.name}', (tester) async {
          final capture = await captureScreen(
            tester,
            (tester) => pumpComponentPage(tester, page, page.grounds.single),
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
