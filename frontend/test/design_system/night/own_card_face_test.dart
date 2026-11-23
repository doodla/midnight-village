import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/faces/face_content.dart';
import 'package:midnight_village/design_system/faces/night_report.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/skin/dress.dart';

import '../../helpers/sheet/sheet_data.dart';
import 'board_harness.dart';

// The night board's own card, "You", shows the role this phone was DEALT, face
// up (owner, 23 November 2026: "keeping that face down makes no sense here").
// The spec's hidden-information rule (docs/specs/onuw/index.md): a player may
// know the card they were dealt, which they looked at on 04; never a role that
// changed in the night (what the night changed is told only on a held face,
// and only by the player's own results).

FaceDownCard _you(WidgetTester tester) => tester.widget<FaceDownCard>(you);

RoleId _dealtIn(Map<String, dynamic> me) =>
    serverRole((me['your_role'] as Map)['original_role']);

void main() {
  for (final viewer in Viewer.values) {
    testWidgets(
      '${viewer.name}: "You" shows the dealt role, face up, with its name; '
      'no other card on the board is face up',
      (tester) async {
        await BoardHarness.of(viewer, dress: Dress.paper).pump(tester);
        final dealt = _dealtIn(viewer.nightMe);
        expect(_you(tester).face, dealt);
        expect(
          find.descendant(of: you, matching: find.text(dealt.displayName)),
          findsOneWidget,
          reason: 'the role\'s name is on the card',
        );
        final faceUp = [
          for (final e in find.byType(FaceDownCard).evaluate())
            if ((e.widget as FaceDownCard).face != null)
              (e.widget as FaceDownCard).face,
        ];
        expect(faceUp, [dealt]);
      },
    );
  }

  testWidgets('a role the night changed is never shown: the Doppelganger who '
      'copied someone still shows the Doppelganger she was dealt', (
    tester,
  ) async {
    final harness = BoardHarness.of(
      Viewer.doppelgangerFollowUp,
      dress: Dress.paper,
    );
    await harness.pump(tester);
    final report = NightReport.fromMe(Viewer.doppelgangerFollowUp.nightMe);
    final copied = report.windowOne;
    expect(copied, isA<CopiedResult>(), reason: 'the sample is her follow-up');
    final copiedRole = (copied! as CopiedResult).role;
    expect(copiedRole, isNot(RoleId.doppelganger));
    expect(_you(tester).face, RoleId.doppelganger);
    expect(
      find.descendant(of: you, matching: find.text(copiedRole.displayName)),
      findsNothing,
    );
  });

  testWidgets('it is the dealt role in every window: the one `dealt` reads '
      'from `your_role.original_role`, nothing the board is given later', (
    tester,
  ) async {
    for (final viewer in Viewer.values) {
      final me = viewer.nightMe;
      expect(NightReport.fromMe(me).dealt, _dealtIn(me), reason: viewer.name);
    }
  });

  group('it stays a choice where the rules allow one', () {
    for (final viewer in [
      Viewer.seer,
      Viewer.robber,
      Viewer.troublemaker,
      Viewer.drunk,
      Viewer.loneWerewolf,
    ]) {
      testWidgets(
        '${viewer.name}: a tap on the face-up card picks it (lifted and '
        'ringed), the button says what passing is, a second tap unpicks',
        (tester) async {
          final harness = BoardHarness.of(viewer, dress: Dress.paper);
          await harness.pump(tester);
          final pass = harness.prompt.kind.pass;
          await tapCard(tester, NightCopy.you);
          expect(lifted(tester), [NightCopy.you]);
          expect(_you(tester).selected, isTrue);
          expect(_you(tester).face, isNotNull);
          final (label, phase) = button(tester);
          expect(label, pass);
          expect(phase, isNot(ButtonPhase.locked));
          await tapCard(tester, NightCopy.you);
          expect(lifted(tester), isEmpty);
        },
      );
    }

    testWidgets('a tap on the role name or the portrait is a tap on the '
        'card, and the card is still a 44 or larger target', (tester) async {
      final harness = BoardHarness.of(Viewer.seer, dress: Dress.paper);
      await harness.pump(tester);
      final name = find.descendant(of: you, matching: find.text('Seer'));
      await tester.tap(name);
      await tester.pump();
      expect(lifted(tester), [NightCopy.you]);
      final cell = tester.getRect(you);
      expect(cell.width, greaterThanOrEqualTo(44));
      expect(cell.height, greaterThanOrEqualTo(44));
    });
  });

  testWidgets('a screen reader hears "You" and then which card it is', (
    tester,
  ) async {
    await BoardHarness.of(Viewer.seer, dress: Dress.paper).pump(tester);
    final card = _you(tester);
    expect(card.semanticLabel, NightCopy.you);
    expect(card.semanticHint, RoleId.seer.displayName);
  });
}
