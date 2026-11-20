import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/faces/face_content.dart';
import 'package:midnight_village/design_system/faces/held_face.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/night/night_pick.dart';
import 'package:midnight_village/design_system/night/pick_rule.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/hold_to_reveal.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/teach/cue_wave.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';

import '../../helpers/component_sheet.dart';
import '../../helpers/sheet/sheet_data.dart';
import 'board_harness.dart';

// The night board's behaviour (first-time play spec, sections 3, 7 and 8).
// night_layout_test.dart checks it looks and moves the same for every role.

BoardHarness _board(Viewer viewer, {Set<Cue> learned = const {}}) =>
    BoardHarness(face: viewer.you, rule: viewer.rule, learned: learned);

Future<void> _choose(WidgetTester tester) async {
  await tester.tap(find.byType(PrimaryButton));
  await tester.pump();
}

/// The Doppelganger's look, then her copy's turn: she copied a Seer.
final _look = PickRule(shapes: const {PickShape.onePlayer}, players: others);
final _lookFace = FaceContent.nightYou(
  dealt: RoleId.doppelganger,
  prompt: NightPrompt.doppelgangerLook,
);

void main() {
  testWidgets('it is drawn from the seats in seat order, "You" in yours, '
      'then Left, Middle, Right', (tester) async {
    await _board(Viewer.seer).pump(tester);
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

  group('the picks are always a shape of the prompt, or its start', () {
    testWidgets('a tap picks and a second tap unpicks', (tester) async {
      await _board(Viewer.seer).pump(tester);
      await tapCard(tester, NightCopy.left);
      await tapCard(tester, NightCopy.right);
      expect(lifted(tester), [NightCopy.left, NightCopy.right]);
      await tapCard(tester, NightCopy.left);
      expect(lifted(tester), [NightCopy.right]);
    });

    testWidgets('a card that does not go with the picks starts them again', (
      tester,
    ) async {
      await _board(Viewer.seer).pump(tester);
      await tapCard(tester, NightCopy.left);
      await tapCard(tester, cleo.name);
      expect(lifted(tester), [cleo.name]);
      await tapCard(tester, ben.name);
      expect(lifted(tester), [ben.name]);
    });

    testWidgets('a card the prompt cannot take does not select', (
      tester,
    ) async {
      await _board(Viewer.drunk).pump(tester);
      await tapCard(tester, cleo.name);
      await tapCard(tester, NightCopy.you);
      expect(lifted(tester), isEmpty);
      expect(button(tester), (NightCopy.chooseNone, ButtonPhase.locked));
    });
  });

  testWidgets('the button follows the picks: "Choose a card", "Choose 1 '
      'more", then what it will send', (tester) async {
    await _board(Viewer.seer).pump(tester);
    expect(button(tester), (NightCopy.chooseNone, ButtonPhase.locked));
    await tapCard(tester, NightCopy.left);
    expect(button(tester), (NightCopy.chooseMore, ButtonPhase.locked));
    await tapCard(tester, NightCopy.right);
    expect(button(tester), ('Choose Left, Right', ButtonPhase.ready));
    await tapCard(tester, NightCopy.you);
    expect(button(tester), (NightCopy.keep, ButtonPhase.ready));
    await tapCard(tester, cleo.name);
    expect(button(tester), ('Choose Cleo', ButtonPhase.ready));
  });

  testWidgets('nothing waits on a hold: a sleeper picks any card and '
      'chooses', (tester) async {
    final board = _board(Viewer.villager);
    await board.pump(tester);
    await tapCard(tester, ben.name);
    await tapCard(tester, NightCopy.middle);
    expect(lifted(tester), [NightCopy.middle]);
    await _choose(tester);
    expect(board.sent, [
      [const CenterPick(1)],
    ]);
  });

  testWidgets('a press on "You" past 120 ms is a hold that shows its face, '
      'not a pick, for as long as it is held', (tester) async {
    await _board(Viewer.seer).pump(tester);
    final press = await tester.startGesture(tester.getCenter(you));
    await tester.pump(HoldToReveal.holdDelay);
    expect(find.byType(HeldFace), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
    expect(find.byType(HeldFace), findsOneWidget);
    await press.up();
    await tester.pump(kDoubleTapTimeout);
    expect(lifted(tester), isEmpty);
  });

  testWidgets('the thumbprint points at "You" until it has been held once on '
      'this device, after 04 taught the hold', (tester) async {
    final board = _board(Viewer.seer, learned: {Cue.hold});
    await board.pump(tester);
    bool pointing() => tester.widget<FaceDownCard>(you).hold ?? false;
    expect(pointing(), isTrue);
    await holdAndLetGo(tester, you);
    expect(pointing(), isFalse);
    expect(board.container.read(learnedCuesProvider), contains(Cue.holdYou));
  });

  testWidgets('the face shows above the thumb: the board rests low', (
    tester,
  ) async {
    await _board(Viewer.seer).pump(tester);
    final press = await tester.startGesture(tester.getCenter(you));
    await tester.pump(HoldToReveal.holdDelay);
    expect(
      tester.getRect(find.byType(HeldFace)).bottom,
      lessThan(tester.getCenter(you).dy),
    );
    await press.up();
  });

  testWidgets('a locked Choose, tapped, replays the wave over the cards', (
    tester,
  ) async {
    final board = _board(Viewer.seer, learned: Cue.values.toSet());
    await board.pump(tester);
    bool waving() => tester
        .widgetList<CueWave>(find.byType(CueWave))
        .every((wave) => wave.play);
    expect(waving(), isFalse);
    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();
    expect(waving(), isTrue);
    expect(board.sent, isEmpty);
    await tester.pump(const Duration(seconds: 3));
    expect(waving(), isFalse);
  });

  testWidgets('one Choose sends the stage and the picks in tap order, then '
      '"Chosen" with the picks still lifted, and taps do nothing', (
    tester,
  ) async {
    final board = _board(Viewer.seer);
    await board.pump(tester);
    await tapCard(tester, NightCopy.right);
    await tapCard(tester, NightCopy.left);
    await _choose(tester);

    expect(board.stages, [windowTwo]);
    expect(board.sent, [
      [const CenterPick(2), const CenterPick(0)],
    ]);
    expect(button(tester), (NightCopy.chosen, ButtonPhase.done));
    await tapCard(tester, ben.name);
    expect(lifted(tester), [NightCopy.left, NightCopy.right]);
    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();
    expect(board.sent, hasLength(1));
    expect(
      board.container.read(learnedCuesProvider),
      contains(Cue.nightChoose),
    );
  });

  testWidgets('the Doppelganger: her look, then a new turn re-arms the '
      'board for her copy', (tester) async {
    final board = BoardHarness(face: _lookFace, rule: _look, stage: 'w1');
    await board.pump(tester);
    await tapCard(tester, cleo.name);
    await _choose(tester);
    expect(button(tester), (NightCopy.chosen, ButtonPhase.done));

    board
      ..turn = 1
      ..rule = seerRule
      ..face = FaceContent.copied(name: cleo.name, role: RoleId.seer);
    await tester.pumpWidget(board.build());
    expect(lifted(tester), isEmpty);
    expect(button(tester), (NightCopy.chooseNone, ButtonPhase.locked));
    await tapCard(tester, ben.name);
    await _choose(tester);
    expect(board.stages, ['w1', 'w1']);
    expect(board.sent, [
      [PlayerPick(cleo.id)],
      [PlayerPick(ben.id)],
    ]);
  });

  testWidgets('a new stage starts a fresh board', (tester) async {
    final board = _board(Viewer.seer)..stage = 'w1';
    await board.pump(tester);
    await tapCard(tester, cleo.name);
    await _choose(tester);
    board.stage = windowTwo;
    await tester.pumpWidget(board.build());
    expect(lifted(tester), isEmpty);
    expect(button(tester), (NightCopy.chooseNone, ButtonPhase.locked));
  });

  group('a choose that fails', () {
    testWidgets('says "Not sent." and "Try again" sends the same picks to '
        'the same stage', (tester) async {
      final board = _board(Viewer.seer)
        ..answer = () async => throw StateError('offline');
      await board.pump(tester);
      await tapCard(tester, cleo.name);
      await _choose(tester);
      expect(find.text(BannerCopy.notSent), findsOneWidget);
      expect(button(tester), (NightCopy.chosen, ButtonPhase.done));
      expect(lifted(tester), [cleo.name]);
      expect(
        board.container.read(learnedCuesProvider),
        isNot(contains(Cue.nightChoose)),
      );

      board.answer = () async {};
      await tester.tap(find.text(BannerCopy.tryAgain));
      await tester.pump();
      expect(find.text(BannerCopy.notSent), findsNothing);
      expect(board.stages, [windowTwo, windowTwo]);
      expect(board.sent, [
        [PlayerPick(cleo.id)],
        [PlayerPick(cleo.id)],
      ]);
      expect(
        board.container.read(learnedCuesProvider),
        contains(Cue.nightChoose),
      );
    });

    testWidgets('after its turn has passed is forgotten', (tester) async {
      final late = Completer<void>();
      final board = BoardHarness(
        face: _lookFace,
        rule: _look,
        answer: () => late.future,
      );
      await board.pump(tester);
      await tapCard(tester, cleo.name);
      await _choose(tester);
      board.turn = 1;
      await tester.pumpWidget(board.build());
      late.completeError(StateError('offline'));
      await tester.pump();
      expect(find.text(BannerCopy.notSent), findsNothing);
    });
  });

  testWidgets('with large text it wraps to rows of four', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await BoardHarness(
      face: Viewer.seer.you,
      rule: seerRule,
      seats: tenSeats,
    ).pump(tester);
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
