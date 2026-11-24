import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/vote_slip.dart';
import 'package:midnight_village/design_system/primitives/you_tag.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';
import 'package:midnight_village/features/game/domain/game_me.dart';
import 'package:midnight_village/features/game/presentation/shell/vote_screen.dart';

import '../../../helpers/component_sheet.dart' show learnedOverrides;
import '../../../helpers/pump_skinned.dart';
import '../../../helpers/sheet/sheet_data.dart' show recordedMe;

// 09 at a table with practice players (`http/game/me_voting_practice`,
// Quin's phone: Pia, and Scarecrow and Teapot whom the server plays): they
// are tagged "Practice" in the vote, so a person can see who is not a
// person; a person is never tagged; a practice player can be picked like
// anyone.

void main() {
  Future<List<int>> pump(WidgetTester tester, Size phone) async {
    tester.view.physicalSize = phone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final picks = <int>[];
    await pumpSkinned(
      tester,
      SizedBox.fromSize(
        size: phone,
        child: ProviderScope(
          overrides: learnedOverrides(Cue.values.toSet()),
          child: VoteView(
            me: GameMe.fromJson(recordedMe('me_voting_practice')),
            secondsLeft: 72,
            onPick: picks.add,
            onLock: (_) {},
          ),
        ),
      ),
      ground: GroundKind.day,
    );
    await tester.pump();
    return picks;
  }

  for (final phone in const [Size(320, 568), Size(390, 844)]) {
    testWidgets('${phone.width.toInt()} wide: the practice players are '
        'tagged, the person is not', (tester) async {
      await pump(tester, phone);
      final rows = tester.widgetList<VoteSlip>(find.byType(VoteSlip));
      expect(
        {
          for (final r in rows)
            if (!r.you) r.name: r.practice,
        },
        {'Pia': false, 'Scarecrow': true, 'Teapot': true},
      );
      expect(find.byType(PracticeTag), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a practice player is picked like anyone', (tester) async {
    final picks = await pump(tester, const Size(390, 844));
    final me = GameMe.fromJson(recordedMe('me_voting_practice'));
    await tester.tap(find.text('Scarecrow'));
    await tester.pump();
    final scarecrow = me.seats.firstWhere((s) => s.name == 'Scarecrow').id;
    expect(picks, [scarecrow]);
  });
}
