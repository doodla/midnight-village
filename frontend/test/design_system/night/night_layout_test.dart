import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/design_system/night/night_pick.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/world_timer.dart';

import '../../helpers/sheet/sheet_data.dart';
import 'board_harness.dart';

// The night board looks and moves the same for every role (first-time play
// spec, section 8): the same cards in the same places, the same lift, the
// button in the same place. Only the button's words and whether it is
// enabled follow the player's own picks. And what the table can see changes
// at once on Choose, whatever the server answers and whenever (section 7).

/// The recorded prompts of each game, one per phone: each phone's board has
/// its own seat as "You", the rest the same table.
const _games = {
  'game 7': [
    'me_choose_prompt_seer',
    'me_choose_prompt_robber',
    'me_choose_prompt_troublemaker',
    'me_choose_prompt_villager',
    'me_choose_prompt_werewolf_lone',
  ],
  'game 8': [
    'me_choose_prompt_doppelganger_look',
    'me_choose_prompt_window1_sleeper',
    'me_choose_prompt_drunk',
    'me_choose_prompt_insomniac',
    'me_choose_prompt_mason',
    'me_choose_prompt_minion',
    'me_choose_prompt_werewolf_pack',
  ],
};

BoardHarness _board(String sample, {Future<ChooseAnswer> Function()? answer}) =>
    BoardHarness(recordedMe(sample), answer: answer);

/// A card's back as drawn, lift included.
Rect _card(WidgetTester tester, String label) => tester.getRect(
  find
      .descendant(
        of: find.byWidgetPredicate(
          (w) => w is FaceDownCard && w.semanticLabel == label,
        ),
        matching: find.byType(LayoutBuilder),
      )
      .first,
);

/// Where everything on the board is: the cards in seat order (each phone
/// has its own seat as "You"), then the title, the timer and the button.
List<Rect> _layout(WidgetTester tester) => [
  for (final element in find.byType(FaceDownCard).evaluate())
    _card(tester, (element.widget as FaceDownCard).semanticLabel!),
  tester.getRect(find.text(CommonCopy.nightTitle)),
  tester.getRect(find.byType(WorldTimer)),
  tester.getRect(find.byType(PrimaryButton)),
];

void main() {
  for (final MapEntry(key: game, value: phones) in _games.entries) {
    testWidgets('in $game every phone gets the same board in the same places', (
      tester,
    ) async {
      List<Rect>? first;
      for (final phone in phones) {
        await _board(phone).pump(tester);
        final layout = _layout(tester);
        first ??= layout;
        expect(layout, first, reason: phone);
      }
    });

    testWidgets('in $game a pick lifts the same way on every phone, and '
        'nothing else moves', (tester) async {
      (double, double)? firstLift;
      for (final phone in phones) {
        await _board(phone).pump(tester);
        final before = _layout(tester);
        final at = [
          for (final element in find.byType(FaceDownCard).evaluate())
            (element.widget as FaceDownCard).semanticLabel,
        ].indexOf(NightCopy.you);
        await tester.tap(you);
        await tester.pump();
        await tester.pump(Motion.quick ~/ 2);
        final halfway = before[at].top - _card(tester, NightCopy.you).top;
        await tester.pump(Motion.quick);
        final after = _layout(tester);
        double px(double v) => (v * 100).roundToDouble() / 100;
        final lift = (px(halfway), px(before[at].top - after[at].top));
        firstLift ??= lift;
        expect(lift, firstLift, reason: phone);
        expect(lift.$2, greaterThan(0), reason: phone);
        expect(
          [...after]..removeAt(at),
          [...before]..removeAt(at),
          reason: phone,
        );
      }
    });
  }

  group('on Choose, what the table can see changes at once', () {
    Future<String> afterChoose(
      WidgetTester tester,
      Future<ChooseAnswer> Function() answer,
    ) async {
      final board = _board('me_choose_prompt_seer', answer: answer);
      await board.pump(tester);
      await tapCard(tester, cleo.name);
      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();
      expect(button(tester), (NightCopy.chosen, ButtonPhase.done));
      return visibleTrees(tester);
    }

    testWidgets('the same whether the answer is instant, slow or a failure '
        'still on its way', (tester) async {
      final slow = Completer<ChooseAnswer>();
      final failing = Completer<ChooseAnswer>();
      final instant = await afterChoose(tester, () async => ChooseAnswer.taken);
      final delayed = await afterChoose(tester, () => slow.future);
      final failed = await afterChoose(tester, () => failing.future);
      expect(delayed, instant);
      expect(failed, instant);
      slow.complete(ChooseAnswer.taken);
      failing.completeError(StateError('offline'));
    });

    testWidgets('a failure then shows only "Not sent." with "Try again"', (
      tester,
    ) async {
      final board = _board(
        'me_choose_prompt_seer',
        answer: () => Future.error(StateError('offline')),
      );
      await board.pump(tester);
      await tapCard(tester, cleo.name);
      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();
      await tester.pump();
      expect(find.text(BannerCopy.notSent), findsOneWidget);
      expect(find.text(BannerCopy.tryAgain), findsOneWidget);
      expect(button(tester), (NightCopy.chosen, ButtonPhase.done));
      expect(lifted(tester), [cleo.name]);
    });
  });
}
