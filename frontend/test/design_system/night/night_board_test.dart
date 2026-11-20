import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/faces/held_face.dart';
import 'package:midnight_village/design_system/night/night_pick.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/hold_to_reveal.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/teach/cue_wave.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';

import '../../helpers/component_sheet.dart';
import '../../helpers/contract/contract_samples.dart';
import '../../helpers/sheet/sheet_data.dart';
import 'board_harness.dart';

// The night board's behaviour (first-time play spec, sections 3, 7 and 8),
// on phones of the recorded games. night_layout_test.dart checks it looks
// and moves the same for every role.

Future<void> _choose(WidgetTester tester) async {
  await tester.tap(find.byType(PrimaryButton));
  await tester.pump();
}

/// What a choose that got [sample]'s answer came to.
ChooseAnswer _answered(String sample) => ChooseAnswer.fromStatus(
  ContractSamples.index
      .firstWhere((s) => s.name == 'http/game/$sample')
      .status!,
);

void main() {
  testWidgets('it is drawn from the seats in seat order, "You" in yours, '
      'then Left, Middle, Right', (tester) async {
    await BoardHarness.of(Viewer.seer).pump(tester);
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

  group('the picks are always "You", a shape of the prompt, or its start', () {
    testWidgets('a tap picks at once and a second tap unpicks', (tester) async {
      await BoardHarness.of(Viewer.seer).pump(tester);
      await tester.tap(you);
      await tester.pump();
      expect(lifted(tester), [NightCopy.you]);
      await tapCard(tester, NightCopy.left);
      await tapCard(tester, NightCopy.right);
      expect(lifted(tester), [NightCopy.left, NightCopy.right]);
      await tapCard(tester, NightCopy.left);
      expect(lifted(tester), [NightCopy.right]);
    });

    testWidgets('a card that does not go with the picks starts them again', (
      tester,
    ) async {
      await BoardHarness.of(Viewer.seer).pump(tester);
      await tapCard(tester, NightCopy.left);
      await tapCard(tester, cleo.name);
      expect(lifted(tester), [cleo.name]);
      await tapCard(tester, ben.name);
      expect(lifted(tester), [ben.name]);
    });

    testWidgets('a card the prompt cannot take does not select; "You" '
        'always does, for every role', (tester) async {
      final drunk = BoardHarness.of(Viewer.drunk);
      await drunk.pump(tester);
      final other = drunk.seats.firstWhere((s) => s.id != drunk.selfId);
      await tapCard(tester, other.name);
      expect(lifted(tester), isEmpty);
      expect(button(tester), (NightCopy.chooseNone, ButtonPhase.locked));
      await tapCard(tester, NightCopy.you);
      expect(button(tester), (NightCopy.keep, ButtonPhase.ready));

      await BoardHarness.of(Viewer.doppelganger).pump(tester);
      await tapCard(tester, NightCopy.you);
      expect(button(tester), (NightCopy.keep, ButtonPhase.ready));
    });
  });

  testWidgets('the button follows the picks: "Choose a card", "Choose 1 '
      'more", then what it will send', (tester) async {
    await BoardHarness.of(Viewer.seer).pump(tester);
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
    final board = BoardHarness.of(Viewer.villager);
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
    await BoardHarness.of(Viewer.seer).pump(tester);
    final press = await tester.startGesture(tester.getCenter(you));
    await tester.pump(HoldToReveal.holdDelay);
    expect(find.byType(HeldFace), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
    expect(find.byType(HeldFace), findsOneWidget);
    await press.up();
    await tester.pump();
    expect(lifted(tester), isEmpty);
  });

  testWidgets('the thumbprint points at "You" until it has been held once on '
      'this device, after 04 taught the hold', (tester) async {
    final board = BoardHarness.of(Viewer.seer, learned: {Cue.hold});
    await board.pump(tester);
    bool pointing() => tester.widget<FaceDownCard>(you).hold ?? false;
    expect(pointing(), isTrue);
    await holdAndLetGo(tester, you);
    expect(pointing(), isFalse);
    expect(board.container.read(learnedCuesProvider), contains(Cue.holdYou));
  });

  testWidgets('the face is never under the thumb', (tester) async {
    await BoardHarness.of(Viewer.seer).pump(tester);
    final touch = tester.getCenter(you);
    final press = await tester.startGesture(touch);
    await tester.pump(HoldToReveal.holdDelay);
    expect(tester.getRect(find.byType(HeldFace)).contains(touch), isFalse);
    await press.up();
  });

  testWidgets('a locked Choose, tapped, replays the wave over the cards', (
    tester,
  ) async {
    final board = BoardHarness.of(Viewer.seer, learned: Cue.values.toSet());
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
    final board = BoardHarness.of(Viewer.seer);
    await board.pump(tester);
    await tapCard(tester, NightCopy.right);
    await tapCard(tester, NightCopy.left);
    await _choose(tester);

    expect(board.stages, [board.prompt.stage]);
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

  testWidgets("the Doppelganger: her look, then the server's follow-up "
      'prompt re-arms the board for her copy', (tester) async {
    final board = BoardHarness.of(Viewer.doppelganger);
    await board.pump(tester);
    final look = board.seat('Ben');
    await tapCard(tester, look.name);
    await _choose(tester);
    expect(button(tester), (NightCopy.chosen, ButtonPhase.done));

    board.show(Viewer.doppelgangerFollowUp.nightMe);
    await tester.pumpWidget(board.build());
    expect(lifted(tester), isEmpty);
    expect(button(tester), (NightCopy.chooseNone, ButtonPhase.locked));
    await tapCard(tester, NightCopy.left);
    await tapCard(tester, NightCopy.middle);
    await _choose(tester);
    expect(board.stages.toSet(), {board.prompt.stage});
    expect(board.sent, [
      [PlayerPick(look.id)],
      [const CenterPick(0), const CenterPick(1)],
    ]);
  });

  testWidgets('any other phone chooses once in window 1, whatever the '
      "prompt's counts say", (tester) async {
    final board = BoardHarness.of(Viewer.windowOneSleeper);
    expect(board.me['action_prompt']['max_chooses'], 2);
    await board.pump(tester);
    await tapCard(tester, NightCopy.left);
    await _choose(tester);
    // The server counts the choose; its next /me/ says so.
    final after = Viewer.windowOneSleeper.nightMe;
    (after['action_prompt'] as Map)['chosen'] = 1;
    board.show(after);
    await tester.pumpWidget(board.build());
    expect(button(tester), (NightCopy.chosen, ButtonPhase.done));
    await tapCard(tester, NightCopy.right);
    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();
    expect(board.sent, hasLength(1));
  });

  group('a phone whose turn the server already has starts at "Chosen"', () {
    testWidgets('window 2, chosen once', (tester) async {
      final board = BoardHarness(recordedMe('me_choose_chosen'));
      expect(board.prompt.used, isTrue);
      await board.pump(tester);
      expect(button(tester), (NightCopy.chosen, ButtonPhase.done));
      await tapCard(tester, cleo.name);
      expect(lifted(tester), isEmpty);
    });

    testWidgets("the Doppelganger's follow-up: armed at chosen 1, done at "
        'chosen 2', (tester) async {
      final armed = BoardHarness.of(Viewer.doppelgangerFollowUp);
      await armed.pump(tester);
      expect(button(tester), (NightCopy.chooseNone, ButtonPhase.locked));

      final me = Viewer.doppelgangerFollowUp.nightMe;
      (me['action_prompt'] as Map)['chosen'] = 2;
      await BoardHarness(me).pump(tester);
      expect(button(tester), (NightCopy.chosen, ButtonPhase.done));
    });
  });

  testWidgets('a new stage starts a fresh board', (tester) async {
    final board = BoardHarness.of(Viewer.windowOneSleeper);
    await board.pump(tester);
    await tapCard(tester, NightCopy.left);
    await _choose(tester);
    board.show(recordedMe('me_choose_prompt_werewolf_pack'));
    await tester.pumpWidget(board.build());
    expect(lifted(tester), isEmpty);
    expect(button(tester), (NightCopy.chooseNone, ButtonPhase.locked));
  });

  group('what became of a choose', () {
    testWidgets('no answer: "Not sent." and "Try again" sends the same picks '
        'to the same stage', (tester) async {
      final board = BoardHarness.of(
        Viewer.seer,
        answer: () async => throw StateError('offline'),
      );
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

      board.answer = () async => _answered('choose_submitted_seer');
      await tester.tap(find.text(BannerCopy.tryAgain));
      await tester.pump();
      expect(find.text(BannerCopy.notSent), findsNothing);
      expect(board.stages, [board.prompt.stage, board.prompt.stage]);
      expect(board.sent, [
        [PlayerPick(cleo.id)],
        [PlayerPick(cleo.id)],
      ]);
      expect(
        board.container.read(learnedCuesProvider),
        contains(Cue.nightChoose),
      );
    });

    for (final refusal in ['choose_wrong_stage', 'choose_already_chosen']) {
      testWidgets('$refusal: done, never "Try again"', (tester) async {
        final board = BoardHarness.of(
          Viewer.seer,
          answer: () async => _answered(refusal),
        );
        await board.pump(tester);
        await tapCard(tester, cleo.name);
        await _choose(tester);
        expect(find.text(BannerCopy.notSent), findsNothing);
        expect(button(tester), (NightCopy.chosen, ButtonPhase.done));
      });
    }

    testWidgets('any other refusal (choose_bad_request) arms the board '
        'again, the picks still lifted, with no banner', (tester) async {
      final board = BoardHarness.of(
        Viewer.seer,
        answer: () async => _answered('choose_bad_request'),
      );
      await board.pump(tester);
      await tapCard(tester, cleo.name);
      await _choose(tester);
      expect(find.text(BannerCopy.notSent), findsNothing);
      expect(button(tester), ('Choose Cleo', ButtonPhase.ready));
      expect(lifted(tester), [cleo.name]);
    });

    testWidgets('an answer after its turn has passed is forgotten', (
      tester,
    ) async {
      final late = Completer<ChooseAnswer>();
      final board = BoardHarness.of(
        Viewer.doppelganger,
        answer: () => late.future,
      );
      await board.pump(tester);
      await tapCard(tester, board.seat('Ben').name);
      await _choose(tester);
      board.show(Viewer.doppelgangerFollowUp.nightMe);
      await tester.pumpWidget(board.build());
      late.complete(ChooseAnswer.notSent);
      await tester.pump();
      expect(find.text(BannerCopy.notSent), findsNothing);
    });
  });

  testWidgets('with large text it wraps to rows of four', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await BoardHarness.of(Viewer.drunk).pump(tester);
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
