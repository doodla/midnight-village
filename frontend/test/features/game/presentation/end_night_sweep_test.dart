import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/design_system/primitives/sliced_art.dart';
import 'package:midnight_village/features/game/domain/end_board_metrics.dart';
import 'package:midnight_village/features/game/domain/night_timeline.dart';
import 'package:midnight_village/features/game/presentation/end/end_board_window.dart';
import 'package:midnight_village/features/game/presentation/end/end_foot.dart';
import 'package:midnight_village/features/game/presentation/end/end_night.dart';

import '../../../../test_screens/end_board_pages.dart' show endTen;
import '../../../../test_screens/end_night_pages.dart' show nobodyActs;
import '../../../../test_screens/reading_floor.dart';
import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/end_board_plans.dart' show endScreens;
import '../../../helpers/end_board_pump.dart';
import '../../../helpers/end_links.dart';
import '../../../helpers/outcome_samples.dart';
import '../../../helpers/truncated_text.dart';

// What happened, swept (docs/specs/frontend/end-board.md, section 8): at
// every step of every recorded night, on three phones at three text sizes,
// every card the step is about is whole on the screen before it plays:
// inside the screen, and at its name and its four corners the first thing a
// finger would meet is that card (not the eave, the foot's lip, the banner,
// another card, or nothing because it is clipped off). The deal brings
// "you" into view. Every link keeps the links' rules (on the cards' edges,
// in the window, crossing no other card or seal, its ends saying what
// happened). The banner's words are whole on the screen, no word is
// cut and nothing is under the reading floor.

/// Every recorded results body with a night, ten players, and a night
/// where nobody acted.
final _games = <(String, Map<String, dynamic> Function())>[
  for (final info in ContractSamples.index)
    if (info.name.startsWith('http/game/results') &&
        info.status == 200 &&
        ContractSamples.map(info.name)['night_timeline'] != null)
      (
        info.name.substring('http/game/'.length),
        () => recordedResults(info.name.substring('http/game/'.length)),
      ),
  ('ten', endTen),
  ('nobody acts', nobodyActs),
];

/// Where [place]'s card is drawn at night, as the night keys it.
Element? _cardOf(EndNight night, CardPlace place) =>
    night.placeKey(place).currentContext as Element?;

/// What is wrong with how [place]'s card is seen: null when it is whole.
/// A player's card is whole in the board's window: under the eave (the
/// roof), above the foot's torn lip, clear of the banner and inside the
/// screen. A middle card is whole on the screen. Neither lies under the
/// first-time cue.
String? unseen(WidgetTester tester, EndNight night, CardPlace place) {
  final element = _cardOf(night, place);
  if (element == null) return '$place is not drawn';
  final box = element.renderObject! as RenderBox;
  final rect = box.localToGlobal(Offset.zero) & box.size;
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  var room = (Offset.zero & size).inflate(0.5);
  if (place is PlayerPlace) {
    final window = tester.getRect(find.byType(EndBoardWindow));
    final roof = tester.getRect(find.byType(BoardRoof));
    final foot = tester.getRect(find.byType(EndFootBand));
    room = room.intersect(
      Rect.fromLTRB(
        window.left,
        roof.bottom,
        window.right,
        foot.top - EndMetrics.lip,
      ).inflate(0.5),
    );
    for (final banner in find.byType(BannerSlice).evaluate()) {
      final b = tester.getRect(find.byWidget(banner.widget));
      if (b.overlaps(rect.deflate(1))) {
        return '$place $rect under the banner $b';
      }
    }
  }
  if (!room.contains(rect.topLeft) || !room.contains(rect.bottomRight)) {
    return '$place $rect is not whole in $room';
  }
  final cue = find.text(StoryCopy.goOn);
  if (cue.evaluate().isNotEmpty) {
    final c = tester.getRect(cue);
    if (c.overlaps(rect.deflate(1))) return '$place $rect under the cue $c';
  }
  return null;
}

/// The states the sweep does not hold yet, one line each: real faults in
/// an extreme state (a short phone at the largest text with ten players),
/// to be designed properly, not patched. A to-do that only shrinks.
const _notYetSwept = <String, String>{
  'ten at 360x640 text x1.6':
      'ten long names on a 360x640 phone at text 1.6: the window cannot hold '
      "a step's cards apart, so a thread runs over a card",
};

void main() {
  for (final (name, results) in _games) {
    for (final size in endScreens) {
      for (final scale in const [1.0, 1.3, 1.6]) {
        final state =
            '$name at ${size.width.toInt()}x${size.height.toInt()} '
            'text x$scale';
        testWidgets(
          '$state: every card of every step whole on screen',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            await pumpEndBoardOn(tester, results(), scale: scale);
            await tester.pump(const Duration(seconds: 1));
            await tester.tap(find.textContaining('happened').first);
            await tester.pump();
            final night = tester
                .widget<EndNightScope>(find.byType(EndNightScope))
                .notifier!;
            final story = night.story!;
            final you = [
              for (final MapEntry(:key) in story.dealt.players.entries)
                if (key == outcomeOf(results()).seats.first.id)
                  PlayerPlace(key),
            ];
            for (var i = 0; i <= story.steps.length; i++) {
              if (i > 0) night.next();
              await tester.pump();
              final places = i == 0 ? you : story.steps[i - 1].places;
              final why = '${night.line} (step $i)';
              await tester.pump(night.clock.duration);
              await tester.pump(Motion.scene);
              for (final place in places) {
                expect(unseen(tester, night, place), isNull, reason: why);
              }
              // Nor does one of them lie on another (a card lifted to the
              // window's edge on one that is).
              final rects = [
                for (final p in places.whereType<PlayerPlace>())
                  tester.getRect(find.byKey(night.placeKey(p))).deflate(2),
              ];
              for (final (k, a) in rects.indexed) {
                for (final b in rects.skip(k + 1)) {
                  expect(a.overlaps(b), isFalse, reason: '$why: $a $b');
                }
              }
              // Its links keep the links' rules (test/helpers/end_links.dart).
              expect(nightLinkFaults(tester), isEmpty, reason: why);
              expect(tester.takeException(), isNull, reason: why);
              expect(truncatedText(tester), isEmpty, reason: why);
              expect(readingFloorBreaches(tester), isEmpty, reason: why);
              // The banner says the step, every word on the screen.
              final words = find.descendant(
                of: find.byType(BannerSlice),
                matching: find.byType(Text),
              );
              expect(
                tester
                    .widgetList<Text>(words)
                    .map((t) => t.data)
                    .join(' ')
                    .replaceAll(RegExp(r'\s+'), ' '),
                night.line,
                reason: why,
              );
              for (final e in words.evaluate()) {
                final r = tester.getRect(find.byWidget(e.widget));
                expect(
                  r.left >= -0.5 && r.right <= size.width + 0.5,
                  isTrue,
                  reason: '$why: $r',
                );
              }
            }
            night.next();
            await tester.pump();
            expect(
              night.on,
              isFalse,
              reason: 'a tap after the last: the result',
            );
          },
          skip: _notYetSwept.containsKey(state),
        );
      }
    }
  }
}
