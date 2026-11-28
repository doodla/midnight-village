import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/faces/face_content.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/hold_to_reveal.dart';
import 'package:midnight_village/design_system/primitives/paper_flip.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/role_card.dart';
import 'package:midnight_village/design_system/primitives/role_sheet_body.dart';
import 'package:midnight_village/design_system/primitives/sealed_note.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/ground_scope.dart';
import 'package:midnight_village/design_system/skin/skin_id.dart';
import 'package:midnight_village/design_system/skin/skin_theme.dart';
import 'package:midnight_village/features/game/presentation/shell/talk_square.dart';

import '../../helpers/finger.dart';
import '../../helpers/shell_setup.dart';
import '../../helpers/table_setup.dart';

// What a hold starts shows in the frame it showed in before the hold was
// timed from the finger (`FingerTimedLongPress`): the frame after the one in
// which the hold's time is reached for a sheet that slides up (its first
// frame is drawn where it starts), that very frame for a face shown at once.
// Counted on the real parts, a frame every 16 ms.

const _frame = Duration(milliseconds: 16);

/// The frames from the one in which [hold] is reached (0) to the first that
/// draws [shown], a finger down on [at] all along.
Future<int> _framesToShow(
  WidgetTester tester,
  Offset at,
  Duration hold,
  bool Function() shown,
) async {
  expect(shown(), isFalse, reason: 'nothing shown before the finger');
  final finger = await tester.startGesture(at);
  var elapsed = Duration.zero;
  int? reached;
  for (var frame = 0; frame < 90; frame++) {
    await tester.pump(_frame);
    elapsed += _frame;
    if (reached == null && elapsed >= hold) reached = frame;
    if (shown()) {
      await finger.up();
      await tester.pumpAndSettle();
      expect(reached, isNotNull, reason: 'shown before the hold: a tap?');
      return frame - reached!;
    }
  }
  fail('never shown');
}

void main() {
  testWidgets("03: a held role card's sheet moves the frame after the hold "
      'is reached', (tester) async {
    final setup = await TableSetup.pump(
      tester,
      lobby: v2Lobby('detail_custom_deck'),
      viewer: 'Ana',
    );
    final edit = find.text(TableCopy.editDeck);
    await pressLikeAFinger(
      tester,
      edit.evaluate().isNotEmpty ? edit : find.byType(PrimaryButton),
    );
    await setup.settle(tester);
    final card = find.byWidgetPredicate(
      (w) => w is RoleCard && w.role == RoleId.troublemaker,
    );
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();

    bool moved() {
      final sheet = find.byType(RoleSheetBody);
      if (sheet.evaluate().isEmpty) return false;
      final route = ModalRoute.of(tester.element(sheet))!;
      return route.animation!.value > 0;
    }

    final frames = await _framesToShow(
      tester,
      tester.getCenter(card),
      RoleCard.holdDelay,
      moved,
    );
    expect(frames, 1);
    await setup.close(tester);
  });

  testWidgets("04: a held card's turn moves the frame after the hold is "
      'reached', (tester) async {
    tester.view.physicalSize = const Size(400, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: skinTheme(SkinId.fallback.skin),
        builder: (context, app) =>
            GroundScope(ground: GroundKind.night, child: app!),
        home: Scaffold(
          body: GroundScope(
            ground: GroundKind.night,
            fill: true,
            child: Center(
              child: HoldToReveal(
                inPlace: true,
                target: 'Your card',
                face: FaceContent.roleText(RoleId.seer),
                cover: const FaceDownCard(
                  size: FaceDownSize.hero,
                  cardWidth: 200,
                  cardHeight: 266,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // The card on its side: any turn about its upright axis.
    bool turning() => tester
        .widgetList<Transform>(
          find.descendant(
            of: find.byType(PaperFlip),
            matching: find.byType(Transform),
          ),
        )
        .any((t) => t.transform.entry(0, 0) < 1 - 1e-6);

    final frames = await _framesToShow(
      tester,
      tester.getCenter(find.byType(HoldToReveal)),
      HoldToReveal.holdDelay,
      turning,
    );
    expect(frames, 1);
  });

  testWidgets('08: My night held shows in the frame the hold is reached', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final s = await ShellSetup.pump(
      tester,
      recordedMe('me_discussion_choose_werewolf_pack'),
      before: (s) =>
          s.answerPost('/night-results/seen/', 'game/night_results_seen'),
    );
    await s.settle(tester);
    // It comes up by itself the first time: a touch puts it away.
    await pressAtLikeAFinger(tester, const Offset(4, 400));
    await tester.pumpAndSettle();

    final frames = await _framesToShow(
      tester,
      tester.getCenter(find.byType(SealedNote)),
      HoldToReveal.holdDelay,
      () => find.byType(MyNightPanel).evaluate().isNotEmpty,
    );
    expect(frames, 0);
    await s.close(tester);
  });
}
