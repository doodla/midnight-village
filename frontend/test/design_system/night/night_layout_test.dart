import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/faces/face_content.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/night/pick_rule.dart';
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

/// Every prompt a phone can have at night, with the card a player of that
/// role would tap first.
final _roles = <String, (RoleId, NightPrompt, PickRule, String)>{
  'a sleeper': (
    RoleId.villager,
    NightPrompt.noChoice,
    const PickRule.anyCard(),
    NightCopy.left,
  ),
  'the Seer': (RoleId.seer, NightPrompt.seer, seerRule, NightCopy.left),
  'the Robber': (
    RoleId.robber,
    NightPrompt.robber,
    PickRule(
      shapes: const {PickShape.self, PickShape.onePlayer},
      players: others,
    ),
    ben.name,
  ),
  'the Troublemaker': (
    RoleId.troublemaker,
    NightPrompt.troublemaker,
    Viewer.troublemaker.rule,
    ben.name,
  ),
  'the Drunk': (
    RoleId.drunk,
    NightPrompt.drunk,
    Viewer.drunk.rule,
    NightCopy.left,
  ),
  'a lone Werewolf': (
    RoleId.werewolf,
    NightPrompt.loneWerewolf,
    const PickRule(
      shapes: {PickShape.self, PickShape.oneCenter},
      centers: {0, 1, 2},
    ),
    NightCopy.left,
  ),
  "the Doppelganger's look": (
    RoleId.doppelganger,
    NightPrompt.doppelgangerLook,
    PickRule(shapes: const {PickShape.onePlayer}, players: others),
    ben.name,
  ),
};

BoardHarness _board(String role, {Future<void> Function()? answer}) {
  final (dealt, prompt, rule, _) = _roles[role]!;
  return BoardHarness(
    face: FaceContent.nightYou(dealt: dealt, prompt: prompt),
    rule: rule,
    answer: answer,
  );
}

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

/// Where everything on the board is.
Map<String, Rect> _layout(WidgetTester tester) => {
  for (final element in find.byType(FaceDownCard).evaluate())
    if ((element.widget as FaceDownCard).semanticLabel case final label?)
      label: _card(tester, label),
  'title': tester.getRect(find.text(CommonCopy.nightTitle)),
  'timer': tester.getRect(find.byType(WorldTimer)),
  'button': tester.getRect(find.byType(PrimaryButton)),
};

void main() {
  testWidgets('every role gets the same board in the same places', (
    tester,
  ) async {
    Map<String, Rect>? first;
    for (final role in _roles.keys) {
      await _board(role).pump(tester);
      final layout = _layout(tester);
      first ??= layout;
      expect(layout, first, reason: role);
    }
  });

  testWidgets('a pick lifts the same way for every role, and nothing else '
      'moves', (tester) async {
    (double, double)? firstLift;
    for (final MapEntry(key: role, value: (_, _, _, tap)) in _roles.entries) {
      await _board(role).pump(tester);
      final before = _layout(tester);
      await tester.tap(card(tap));
      await tester.pump();
      await tester.pump(Motion.quick ~/ 2);
      final halfway = before[tap]!.top - _card(tester, tap).top;
      await tester.pump(Motion.quick);
      final after = _layout(tester);
      double px(double v) => (v * 100).roundToDouble() / 100;
      final lift = (px(halfway), px(before[tap]!.top - after[tap]!.top));
      firstLift ??= lift;
      expect(lift, firstLift, reason: role);
      expect(lift.$2, greaterThan(0), reason: role);
      expect({...after}..remove(tap), {...before}..remove(tap), reason: role);
    }
  });

  group('on Choose, what the table can see changes at once', () {
    Future<String> afterChoose(
      WidgetTester tester,
      Future<void> Function() answer,
    ) async {
      final board = _board('the Seer', answer: answer);
      await board.pump(tester);
      await tapCard(tester, cleo.name);
      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();
      expect(button(tester), (NightCopy.chosen, ButtonPhase.done));
      return visibleTrees(tester);
    }

    testWidgets('the same whether the answer is instant, slow or a failure '
        'still on its way', (tester) async {
      final slow = Completer<void>();
      final failing = Completer<void>();
      final instant = await afterChoose(tester, () async {});
      final delayed = await afterChoose(tester, () => slow.future);
      final failed = await afterChoose(tester, () => failing.future);
      expect(delayed, instant);
      expect(failed, instant);
      slow.complete();
      failing.completeError(StateError('offline'));
    });

    testWidgets('a failure then shows only "Not sent." with "Try again"', (
      tester,
    ) async {
      final board = _board(
        'the Seer',
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
