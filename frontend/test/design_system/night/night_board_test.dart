import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/faces/held_face.dart';
import 'package:midnight_village/design_system/night/night_pick.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/hold_to_reveal.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';

import '../../helpers/component_sheet.dart';
import '../../helpers/sheet/sheet_data.dart';
import 'board_harness.dart';

// The night board's behaviour (first-time play spec, "The night, second by
// second"). night_uniformity_test.dart checks it is the same for every role.

BoardHarness _seer({NightWindow window = NightWindow.two}) =>
    BoardHarness(face: Viewer.seer.you, window: window);

Future<void> _holdYou(WidgetTester tester) => holdAndLetGo(tester, you);

void main() {
  testWidgets('it is drawn from the seats in seat order, "You" in yours, '
      'then Left, Middle, Right', (tester) async {
    await _seer().pump(tester);
    final captions = [
      for (final element in find.byType(FaceDownCard).evaluate())
        (element.widget as FaceDownCard).semanticLabel,
    ];
    expect(captions, [
      NightCopy.you,
      ben.name,
      cleo.name,
      dev.name,
      esme.name,
      ...NightCopy.center,
    ]);
    expect(find.text(ana.name), findsNothing);
  });

  testWidgets('a tap picks; up to two; a third replaces the oldest; tapping '
      'a pick again unpicks it', (tester) async {
    await _seer().pump(tester);
    await tapCard(tester, cleo.name);
    expect(lifted(tester), [cleo.name]);
    await tapCard(tester, NightCopy.left);
    await tapCard(tester, NightCopy.right);
    expect(lifted(tester), [NightCopy.left, NightCopy.right]);
    await tapCard(tester, NightCopy.left);
    expect(lifted(tester), [NightCopy.right]);
  });

  testWidgets('the button names what it will send, and stays locked until '
      '"You" has been held 0.8 s', (tester) async {
    await _seer().pump(tester);
    expect(button(tester), (NightCopy.chooseNone, ButtonPhase.waiting));

    await tapCard(tester, NightCopy.left);
    await tapCard(tester, NightCopy.right);
    expect(button(tester), ('Choose Left, Right', ButtonPhase.locked));

    await _holdYou(tester);
    expect(button(tester), ('Choose Left, Right', ButtonPhase.ready));

    await tapCard(tester, NightCopy.left);
    await tapCard(tester, NightCopy.right);
    await tapCard(tester, NightCopy.you);
    expect(button(tester), (NightCopy.keep, ButtonPhase.ready));
  });

  testWidgets('a press on "You" past 120 ms is a hold that shows its face, '
      'not a pick', (tester) async {
    await _seer().pump(tester);
    final press = await tester.startGesture(tester.getCenter(you));
    await tester.pump(HoldToReveal.holdDelay);
    expect(find.byType(HeldFace), findsOneWidget);
    await press.up();
    await tester.pump(kDoubleTapTimeout);
    expect(lifted(tester), isEmpty);
  });

  testWidgets('the face shows above the thumb: the board rests low', (
    tester,
  ) async {
    await _seer().pump(tester);
    final press = await tester.startGesture(tester.getCenter(you));
    await tester.pump(HoldToReveal.holdDelay);
    expect(
      tester.getRect(find.byType(HeldFace)).bottom,
      lessThan(tester.getCenter(you).dy),
    );
    await press.up();
  });

  testWidgets('a locked Choose, tapped, replays the hold cue on "You"', (
    tester,
  ) async {
    final board = BoardHarness(
      face: Viewer.seer.you,
      learned: Cue.values.toSet(),
    );
    await board.pump(tester);
    await tapCard(tester, cleo.name);
    expect(find.text(CommonCopy.hold), findsNothing);
    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();
    expect(find.text(CommonCopy.hold), findsOneWidget);
    expect(board.sent, isEmpty);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('window 2: one Choose sends the picks in tap order, then '
      '"Chosen" with the picks still lifted, and taps do nothing', (
    tester,
  ) async {
    final board = _seer();
    await board.pump(tester);
    await tapCard(tester, NightCopy.right);
    await tapCard(tester, cleo.name);
    await _holdYou(tester);
    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();

    expect(board.sent, [
      [const CenterPick(2), PlayerPick(cleo.id)],
    ]);
    expect(button(tester), (NightCopy.chosen, ButtonPhase.done));
    await tapCard(tester, ben.name);
    expect(lifted(tester), [cleo.name, NightCopy.right]);
    expect(
      board.container.read(learnedCuesProvider),
      contains(Cue.nightChoose),
    );
  });

  testWidgets('window 1: every phone chooses twice; the first clears the '
      'picks and locks again until "You" is held again', (tester) async {
    final board = _seer(window: NightWindow.one);
    await board.pump(tester);
    await tapCard(tester, cleo.name);
    await _holdYou(tester);
    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();
    expect(lifted(tester), isEmpty);
    expect(button(tester), (NightCopy.chooseNone, ButtonPhase.waiting));

    await tapCard(tester, NightCopy.you);
    expect(button(tester), (NightCopy.keep, ButtonPhase.locked));
    await _holdYou(tester);
    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();
    expect(button(tester), (NightCopy.chosen, ButtonPhase.done));
    expect(board.sent, [
      [PlayerPick(cleo.id)],
      [const SelfPick()],
    ]);
  });

  testWidgets('a choose the server does not take rolls back', (tester) async {
    final board = _seer()..taken = false;
    await board.pump(tester);
    await tapCard(tester, cleo.name);
    await _holdYou(tester);
    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();
    expect(lifted(tester), [cleo.name]);
    expect(button(tester), ('Choose Cleo', ButtonPhase.ready));
    expect(
      board.container.read(learnedCuesProvider),
      isNot(contains(Cue.nightChoose)),
    );
  });

  testWidgets('a new window starts a fresh board', (tester) async {
    final board = _seer(window: NightWindow.one);
    await board.pump(tester);
    await tapCard(tester, cleo.name);
    await _holdYou(tester);
    await tester.pumpWidget(BoardHarness(face: Viewer.seer.you).build());
    await tester.pump();
    expect(lifted(tester), isEmpty);
    expect(button(tester), (NightCopy.chooseNone, ButtonPhase.waiting));
  });

  testWidgets('with large text it wraps to rows of four', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await BoardHarness(face: Viewer.seer.you, seats: tenSeats).pump(tester);
    final rows = <double, int>{};
    for (final element in find.byType(FaceDownCard).evaluate()) {
      final top = tester.getTopLeft(find.byWidget(element.widget)).dy;
      rows[top] = (rows[top] ?? 0) + 1;
    }
    expect(rows.values, everyElement(lessThanOrEqualTo(4)));
    expect(tester.takeException(), isNull);
  });

  test('picks go to the server as the contract has them', () {
    expect(PlayerPick(cleo.id).toJson(), {'player_id': cleo.id});
    expect(const CenterPick(1).toJson(), {'center_index': 1});
    expect(const SelfPick().toJson(), {'self': true});
  });
}
