import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/faces/held_face.dart';
import 'package:midnight_village/design_system/night/night_board.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';

import '../../../helpers/component_sheet.dart' show holdDown;
import '../../../helpers/finger.dart';
import '../../../helpers/shell_setup.dart';

/// A result settled at the choose opens on the night board by itself, once
/// (owner, 25 November 2026: "It should show when the person selects").

Finder get _held => find.byType(HeldFace);

Finder get _you => find.ancestor(
  of: find.text(NightCopy.you),
  matching: find.byType(FaceDownCard),
);

Finder _says(String text) =>
    find.descendant(of: _held, matching: find.textContaining(text));

Future<ShellSetup> _chosen(
  WidgetTester tester,
  String me,
  String answer,
  String target,
) async {
  final s = await ShellSetup.pump(
    tester,
    recordedMe(me),
    learned: Cue.values.toSet(),
  );
  await s.settle(tester);
  s.answerPost('/action/', answer);
  await pressLikeAFinger(tester, find.text(target).last);
  await tester.pump();
  await pressLikeAFinger(tester, find.byType(PrimaryButton).last);
  await s.settle(tester);
  return s;
}

void main() {
  group('the night board opens a result that came with the choose', () {
    testWidgets('the Seer: her look is showing without a hold; a touch puts '
        'it away, and it stays away', (tester) async {
      final s = await _chosen(
        tester,
        'me_choose_prompt_seer',
        'game/choose_submitted_seer',
        'Cleo',
      );
      expect(_held, findsOneWidget);
      expect(_says('Cleo'), findsOneWidget);
      expect(s.meFetches, 1, reason: 'one request per choose');

      await pressAtLikeAFinger(tester, const Offset(10, 300));
      await s.settle(tester);
      expect(_held, findsNothing);
      // The touch was only that: nothing else was picked or sent.
      expect(s.posts('/action/'), 1);

      // The second ticks of the clock and a rebuild do not open it again.
      await tester.pump(const Duration(seconds: 3));
      await s.settle(tester);
      expect(_held, findsNothing);
      await s.close(tester);
    });

    testWidgets('held again, "You" shows the result; let go, it is gone', (
      tester,
    ) async {
      final s = await _chosen(
        tester,
        'me_choose_prompt_seer',
        'game/choose_submitted_seer',
        'Cleo',
      );
      await pressAtLikeAFinger(tester, const Offset(10, 300));
      await s.settle(tester);
      final gesture = await holdDown(tester, _you);
      expect(_says('Cleo'), findsOneWidget);
      await gesture.up();
      await tester.pump();
      expect(_held, findsNothing);
      await s.close(tester);
    });

    testWidgets('the Robber: her new card opens by itself', (tester) async {
      final s = await _chosen(
        tester,
        'me_choose_prompt_robber',
        'game/choose_submitted_robber',
        'Ana',
      );
      expect(_held, findsOneWidget);
      await s.close(tester);
    });

    testWidgets('the Troublemaker: her swap is a line on My night, so it '
        'opens too', (tester) async {
      final s = await ShellSetup.pump(
        tester,
        recordedMe('me_choose_prompt_troublemaker'),
        learned: Cue.values.toSet(),
      );
      await s.settle(tester);
      s.answerPost('/action/', 'game/choose_submitted_troublemaker');
      final board = tester.widget<NightBoard>(find.byType(NightBoard));
      final others = board.seats.where((p) => p.id != board.selfId).toList();
      await pressLikeAFinger(tester, find.text(others[0].name).last);
      await tester.pump();
      await pressLikeAFinger(tester, find.text(others[1].name).last);
      await tester.pump();
      await pressLikeAFinger(tester, find.byType(PrimaryButton).last);
      await s.settle(tester);
      expect(_held, findsOneWidget);
      await s.close(tester);
    });

    testWidgets('a board built with the result already there (a reload, a '
        'poll) does not open it; holding "You" shows it', (tester) async {
      final s = await ShellSetup.pump(
        tester,
        recordedMe('me_choose_chosen'),
        learned: Cue.values.toSet(),
      );
      await s.settle(tester);
      expect(_held, findsNothing);
      await tester.pump(const Duration(seconds: 3));
      expect(_held, findsNothing, reason: 'nor on a poll');
      final gesture = await holdDown(tester, _you);
      expect(_held, findsOneWidget);
      await gesture.up();
      await s.close(tester);
    });

    testWidgets('the Insomniac chooses nothing: nothing opens', (tester) async {
      final s = await ShellSetup.pump(
        tester,
        recordedMe('me_choose_prompt_insomniac'),
        learned: Cue.values.toSet(),
      );
      await s.settle(tester);
      await tester.pump(const Duration(seconds: 3));
      expect(_held, findsNothing);
      await s.close(tester);
    });

    testWidgets('a Villager has no result to open: Keep my card opens '
        'nothing', (tester) async {
      final s = await ShellSetup.pump(
        tester,
        recordedMe('me_choose_prompt_villager'),
        learned: Cue.values.toSet(),
      );
      await s.settle(tester);
      s.answerPost('/action/', 'game/choose_submitted_villager');
      await tester.pump(const Duration(seconds: 3));
      expect(_held, findsNothing);
      await s.close(tester);
    });
  });
}
