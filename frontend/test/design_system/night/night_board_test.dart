import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/faces/held_face.dart';
import 'package:midnight_village/design_system/night/night_board.dart';
import 'package:midnight_village/design_system/night/night_pick.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/hold_to_reveal.dart';
import 'package:midnight_village/design_system/primitives/paper_card.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/world_timer.dart';
import 'package:midnight_village/design_system/skin/skin_tilt.dart';
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
  testWidgets('a window with no deadline shows the candle alone, no number', (
    tester,
  ) async {
    await BoardHarness(Viewer.seer.nightMe, secondsLeft: null).pump(tester);
    expect(
      tester.widget<WorldTimer>(find.byType(WorldTimer)).secondsLeft,
      isNull,
    );
    expect(find.text('0'), findsNothing);
  });

  testWidgets('the title is the prompt\'s: what the role does tonight on a '
      'phone with a choice, "The village sleeps" on a sleeper\'s', (
    tester,
  ) async {
    for (final (viewer, title) in [
      (Viewer.seer, NightCopy.seerTitle),
      (Viewer.robber, NightCopy.robberTitle),
      (Viewer.troublemaker, NightCopy.troublemakerTitle),
      (Viewer.drunk, NightCopy.drunkTitle),
      (Viewer.loneWerewolf, NightCopy.loneWerewolfTitle),
      (Viewer.doppelganger, NightCopy.doppelgangerTitle),
      (Viewer.villager, CommonCopy.nightTitle),
      (Viewer.windowOneSleeper, CommonCopy.nightTitle),
    ]) {
      await BoardHarness.of(viewer).pump(tester);
      expect(find.text(title), findsOneWidget, reason: viewer.name);
      expect(
        tester.getSemantics(find.text(title)),
        matchesSemantics(label: title, isHeader: true),
        reason: viewer.name,
      );
    }
  });

  testWidgets('it is drawn from the other seats in seat order, then "You" '
      'in front, then Left, Middle, Right', (tester) async {
    await BoardHarness.of(Viewer.seer).pump(tester);
    final captions = [
      for (final element in find.byType(FaceDownCard).evaluate())
        (element.widget as FaceDownCard).semanticLabel,
    ];
    expect(captions, [
      ben.name,
      cleo.name,
      dev.name,
      esme.name,
      NightCopy.you,
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
      expect(button(tester), (NightCopy.chooseForMe, ButtonPhase.ready));

      await BoardHarness.of(Viewer.doppelganger).pump(tester);
      await tapCard(tester, NightCopy.you);
      expect(button(tester), (NightCopy.skip, ButtonPhase.ready));
    });
  });

  testWidgets('the button follows the picks: "Choose a card", "Choose 1 '
      'more", then what it will send', (tester) async {
    await BoardHarness.of(Viewer.seer).pump(tester);
    expect(button(tester), (NightCopy.chooseNone, ButtonPhase.locked));
    await tapCard(tester, NightCopy.left);
    expect(button(tester), (NightCopy.chooseMore, ButtonPhase.locked));
    await tapCard(tester, NightCopy.right);
    expect(button(tester), ('See Left, Right', ButtonPhase.ready));
    await tapCard(tester, NightCopy.you);
    expect(button(tester), (NightCopy.skip, ButtonPhase.ready));
    await tapCard(tester, cleo.name);
    expect(button(tester), ('See Cleo', ButtonPhase.ready));
  });

  group('the button says what will happen, by the prompt', () {
    // The viewer, the cards tapped, the button, then "You" alone and its
    // button: the verb follows the prompt's kind, the cards are the picks.
    for (final (viewer, taps, go, pass) in [
      (Viewer.seer, [cleo.name], 'See Cleo', NightCopy.skip),
      (Viewer.seer, ['Left', 'Right'], 'See Left, Right', NightCopy.skip),
      (Viewer.robber, [cleo.name], 'Swap with Cleo', NightCopy.keep),
      (Viewer.troublemaker, [ana.name, ben.name], 'Swap Ana, Ben', 'Skip'),
      (Viewer.loneWerewolf, ['Middle'], 'See Middle', NightCopy.skip),
      (Viewer.doppelganger, [ben.name], 'Copy Ben', NightCopy.skip),
    ]) {
      testWidgets('${viewer.name}: "$go", passing "$pass"', (tester) async {
        final board = BoardHarness.of(viewer);
        await board.pump(tester);
        for (final tap in taps) {
          await tapCard(tester, tap);
        }
        expect(button(tester), (go, ButtonPhase.ready));
        await tapCard(tester, NightCopy.you);
        expect(button(tester), (pass, ButtonPhase.ready));
      });
    }

    testWidgets('the Drunk who passes is told the server chooses: he is '
        'swapped all the same', (tester) async {
      final board = BoardHarness.of(Viewer.drunk);
      await board.pump(tester);
      await tapCard(tester, NightCopy.middle);
      expect(button(tester), ('Swap with Middle', ButtonPhase.ready));
      await tapCard(tester, NightCopy.you);
      expect(button(tester), (NightCopy.chooseForMe, ButtonPhase.ready));
    });

    testWidgets('only the Robber "keeps my card"', (tester) async {
      for (final viewer in Viewer.values) {
        final board = BoardHarness.of(viewer);
        if (board.prompt.sleeps) continue;
        await board.pump(tester);
        await tapCard(tester, NightCopy.you);
        expect(
          button(tester).$1 == NightCopy.keep,
          viewer == Viewer.robber,
          reason: viewer.name,
        );
      }
    });
  });

  group('a card that cannot join the pick is dimmed, from the shapes', () {
    /// The cards drawn dimmed, by caption.
    List<String> dimmed(WidgetTester tester) => [
      for (final element in find.byType(FaceDownCard).evaluate())
        if ((element.widget as FaceDownCard).dimmed)
          (element.widget as FaceDownCard).semanticLabel!,
    ];

    Future<BoardHarness> open(WidgetTester tester, Viewer viewer) async {
      final board = BoardHarness.of(viewer);
      await board.pump(tester);
      return board;
    }

    List<String> others(BoardHarness board) => [
      for (final s in board.seats)
        if (s.id != board.selfId) s.name,
    ];

    testWidgets('until the first tap the board is identical for every role: '
        'nothing is dimmed (no role is readable across the table)', (
      tester,
    ) async {
      for (final viewer in Viewer.values) {
        await open(tester, viewer);
        expect(dimmed(tester), isEmpty, reason: viewer.name);
      }
    });

    testWidgets('after the first pick: a Drunk\'s or a lone Werewolf\'s center '
        'card dims the players and the other two center cards', (tester) async {
      for (final viewer in [Viewer.drunk, Viewer.loneWerewolf]) {
        final board = await open(tester, viewer);
        await tapCard(tester, NightCopy.middle);
        expect(dimmed(tester), [
          ...others(board),
          NightCopy.left,
          NightCopy.right,
        ], reason: viewer.name);
        await tapCard(tester, NightCopy.middle);
        expect(dimmed(tester), isEmpty, reason: viewer.name);
      }
    });

    testWidgets('the Seer: one player dims everything else; one centre card '
        'dims the players and leaves the other two lit', (tester) async {
      final board = await open(tester, Viewer.seer);
      await tapCard(tester, cleo.name);
      expect(dimmed(tester), [
        ben.name,
        dev.name,
        esme.name,
        ...NightCopy.center,
      ]);
      await tapCard(tester, cleo.name);
      expect(dimmed(tester), isEmpty);

      await tapCard(tester, NightCopy.left);
      expect(dimmed(tester), others(board));
      await tapCard(tester, NightCopy.right);
      expect(lifted(tester), [NightCopy.left, NightCopy.right]);
      expect(dimmed(tester), [...others(board), NightCopy.middle]);
    });

    testWidgets('a dimmed card still switches the pick', (tester) async {
      await open(tester, Viewer.seer);
      await tapCard(tester, NightCopy.left);
      expect(dimmed(tester), contains(cleo.name));
      await tapCard(tester, cleo.name);
      expect(lifted(tester), [cleo.name]);
      expect(dimmed(tester), contains(NightCopy.left));
    });

    testWidgets('the Robber and the Doppelganger, once a player is picked: '
        'the other players and the center dim; "You" is never dimmed and '
        'picking it leaves the pick empty', (tester) async {
      for (final viewer in [Viewer.robber, Viewer.doppelganger]) {
        final board = await open(tester, viewer);
        final [first, ...rest] = others(board);
        await tapCard(tester, first);
        expect(dimmed(tester), [...rest, ...NightCopy.center]);
        await tapCard(tester, NightCopy.you);
        expect(dimmed(tester), isEmpty);
      }
    });

    testWidgets('the Troublemaker: after one player only the center dims; '
        'after two the other players dim too', (tester) async {
      final board = await open(tester, Viewer.troublemaker);
      final [first, second, ...rest] = others(board);
      await tapCard(tester, first);
      expect(dimmed(tester), NightCopy.center);
      await tapCard(tester, second);
      expect(dimmed(tester), [...rest, ...NightCopy.center]);
    });

    testWidgets('a dimmed card tells a screen reader that a tap still '
        'switches the pick; a lit one says nothing', (tester) async {
      final handle = tester.ensureSemantics();
      final board = await open(tester, Viewer.robber);
      await tapCard(tester, others(board).first);
      for (final caption in NightCopy.center) {
        final node = tester.getSemantics(card(caption));
        expect(node.label, caption);
        expect(node.hint, NightCopy.switchesPick);
      }
      expect(tester.getSemantics(card(others(board).first)).hint, isEmpty);
      handle.dispose();
    });

    testWidgets('names and captions stay in full ink: only the card back '
        'and its token dim', (tester) async {
      final board = await open(tester, Viewer.robber);
      await tapCard(tester, others(board).first);
      final caption = tester.widget<Text>(find.text(NightCopy.left));
      expect(caption.style!.color!.a, 1);
      final back = find.descendant(
        of: card(NightCopy.left),
        matching: find.byType(AnimatedOpacity),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.widget<AnimatedOpacity>(back).opacity, lessThan(1));
    });

    testWidgets('a sleeper dims nothing, whatever it taps', (tester) async {
      await open(tester, Viewer.villager);
      await tapCard(tester, ben.name);
      await tapCard(tester, NightCopy.middle);
      expect(dimmed(tester), isEmpty);
    });
  });

  testWidgets('the table\'s three cards carry the word "Center", on every '
      'phone, and the four cards of the band sit level', (tester) async {
    for (final viewer in [Viewer.seer, Viewer.villager, Viewer.drunk]) {
      await BoardHarness.of(viewer).pump(tester);
      expect(find.text(NightCopy.centerLabel), findsOneWidget);
      final label = tester.getRect(find.text(NightCopy.centerLabel));
      final left = tester.getRect(card(NightCopy.left));
      final right = tester.getRect(card(NightCopy.right));
      expect(label.bottom, lessThanOrEqualTo(left.top + 1));
      expect(label.center.dx, closeTo((left.left + right.right) / 2, 8));
      expect(tester.getRect(you).top, closeTo(left.top, 6));
    }
  });

  testWidgets('a sleeper is asked nothing: no button, "Nothing to do" in its '
      'place, and a tap bobs a card and picks or sends nothing', (
    tester,
  ) async {
    final board = BoardHarness.of(Viewer.villager);
    expect(board.prompt.sleeps, isTrue);
    await board.pump(tester);
    expect(button(tester), (NightCopy.nothingToDo, ButtonPhase.done));

    await tapCard(tester, ben.name);
    // The card lifts and settles: a fidget, never a pick.
    final bob = find.ancestor(
      of: find.text(ben.name),
      matching: find.byType(CueWave),
    );
    expect(bob, findsWidgets);
    await tapCard(tester, NightCopy.middle);
    await tapCard(tester, NightCopy.you);
    await tester.pump(const Duration(seconds: 1));
    expect(lifted(tester), isEmpty);
    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();
    expect(board.sent, isEmpty);
    expect(button(tester), (NightCopy.nothingToDo, ButtonPhase.done));

    // Holding "You" still shows the card and that there is nothing to do.
    final press = await tester.startGesture(tester.getCenter(you));
    await tester.pump(HoldToReveal.holdDelay);
    expect(find.text(NightCopy.noChoice), findsOneWidget);
    await press.up();
  });

  testWidgets('a sleeper in a first game is not waved at to pick', (
    tester,
  ) async {
    await BoardHarness.of(Viewer.villager, learned: {Cue.hold}).pump(tester);
    expect(
      tester.widgetList<CueWave>(find.byType(CueWave)).map((w) => w.play),
      everyElement(isFalse),
    );
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

  testWidgets('the hold is taught once: no ring on "You" after 04 taught it; '
      'on a device that never held a face, the ring until the first reveal', (
    tester,
  ) async {
    bool pointing() => tester.widget<FaceDownCard>(you).hold ?? false;
    await BoardHarness.of(Viewer.seer, learned: {Cue.hold}).pump(tester);
    expect(pointing(), isFalse);

    final fresh = BoardHarness.of(Viewer.seer, learned: const {});
    await fresh.pump(tester);
    expect(pointing(), isTrue);
    await holdAndLetGo(tester, you);
    expect(pointing(), isFalse);
    expect(fresh.container.read(learnedCuesProvider), {Cue.hold});
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

  testWidgets('any other phone sends nothing in window 1, whatever the '
      "prompt's counts say", (tester) async {
    final board = BoardHarness.of(Viewer.windowOneSleeper);
    expect(board.me['action_prompt']['max_chooses'], 2);
    expect(board.prompt.choosesLeft, 0);
    await board.pump(tester);
    await tapCard(tester, NightCopy.left);
    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();
    expect(board.sent, isEmpty);
    expect(button(tester), (NightCopy.nothingToDo, ButtonPhase.done));
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
      (me['action_prompt'] as Map)
        ..['chosen'] = 2
        ..['chooses_left'] = 0;
      await BoardHarness(me).pump(tester);
      expect(button(tester), (NightCopy.chosen, ButtonPhase.done));
    });
  });

  testWidgets('a new stage starts a fresh board', (tester) async {
    final board = BoardHarness.of(Viewer.windowOneSleeper);
    await board.pump(tester);
    expect(button(tester), (NightCopy.nothingToDo, ButtonPhase.done));
    board.show(recordedMe('me_choose_prompt_drunk'));
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
      expect(button(tester), ('See Cleo', ButtonPhase.ready));
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

  group('the look', () {
    /// The seats' cards and the table's, by the top of where they lie.
    Map<double, List<FaceDownCard>> rows(WidgetTester tester) {
      final rows = <double, List<FaceDownCard>>{};
      for (final element in find.byType(FaceDownCard).evaluate()) {
        final card = element.widget as FaceDownCard;
        final top = tester.getTopLeft(find.byWidget(card)).dy;
        (rows[top] ??= []).add(card);
      }
      return rows;
    }

    testWidgets('five at the table: the four others sit two and two; '
        '"You" is not among them but in front, on its paper place, beside '
        'the table\'s three, tilted on their strip', (tester) async {
      await BoardHarness.of(Viewer.seer).pump(tester);
      final byTop = rows(tester);
      final seats = [
        for (final top in byTop.keys.toList()..sort())
          [
            for (final card in byTop[top]!)
              if (card.owner != null && card.ownerName != NightCopy.you) card,
          ],
      ].where((row) => row.isNotEmpty).toList();
      expect([for (final row in seats) row.length], [2, 2]);
      expect(
        find.ancestor(of: you, matching: find.byType(PaperCard)),
        findsOneWidget,
      );
      final center = [
        for (final element in find.byType(FaceDownCard).evaluate())
          if ((element.widget as FaceDownCard).caption != null)
            element.widget as FaceDownCard,
      ];
      expect(center.map((c) => c.caption), [
        NightCopy.left,
        NightCopy.middle,
        NightCopy.right,
      ]);
      expect(center.map((c) => c.tilt), [
        for (var i = 0; i < 3; i++) Tilt.scatter(i),
      ]);
      // The band in front of the player is under every seat.
      final lowestSeat = seats.last
          .map((c) => tester.getRect(find.byWidget(c)).bottom)
          .reduce((a, b) => a > b ? a : b);
      expect(tester.getTopLeft(you).dy, greaterThan(lowestSeat));
      expect(tester.takeException(), isNull);
    });

    testWidgets('every name is set at one size, "You" too', (tester) async {
      await BoardHarness.of(Viewer.drunk).pump(tester);
      final named = [
        for (final element in find.byType(FaceDownCard).evaluate())
          if ((element.widget as FaceDownCard).ownerName != null)
            element.widget as FaceDownCard,
      ];
      expect(named, hasLength(9));
      expect(named.map((c) => c.nameSize).toSet(), hasLength(1));
    });

    testWidgets('a tap anywhere in a seat\'s column picks it, and anywhere '
        'on the paper place picks "You"', (tester) async {
      await BoardHarness.of(Viewer.seer).pump(tester);
      final column = tester.getRect(card(ben.name));
      final back = tester.getRect(
        find
            .descendant(of: card(ben.name), matching: find.byType(ClipRRect))
            .first,
      );
      expect(column.width, greaterThan(back.width));
      await tester.tapAt(column.centerLeft + const Offset(2, 0));
      await tester.pump();
      expect(lifted(tester), [ben.name]);

      final place = tester.getRect(
        find.ancestor(of: you, matching: find.byType(PaperCard)),
      );
      await tester.tapAt(place.topLeft + const Offset(3, 3));
      await tester.pump();
      expect(lifted(tester), [NightCopy.you]);
    });

    testWidgets('"You" alone picked is doing nothing: the button says what '
        'passing is for this role', (tester) async {
      await BoardHarness.of(Viewer.seer).pump(tester);
      await tapCard(tester, NightCopy.you);
      expect(lifted(tester), [NightCopy.you]);
      expect(button(tester), (NightCopy.skip, ButtonPhase.ready));
    });

    testWidgets('with large text the words grow only so far, and the cards '
        'stay the board\'s', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await BoardHarness.of(Viewer.drunk).pump(tester);
      double scaleOf(String text) => tester
          .renderObject<RenderParagraph>(find.text(text).first)
          .textScaler
          .scale(1);
      expect(scaleOf(NightCopy.you), NightBoard.labelScale);
      expect(scaleOf(NightCopy.drunkTitle), NightBoard.labelScale);
      expect(scaleOf(NightCopy.chooseNone), NightBoard.buttonScale);
      expect(tester.takeException(), isNull);
    });
  });

  test('picks go to the server as the contract has them', () {
    expect(PlayerPick(cleo.id).toJson(), {'player_id': cleo.id});
    expect(const CenterPick(1).toJson(), {'center_index': 1});
    expect(const SelfPick().toJson(), {'self': true});
  });
}
