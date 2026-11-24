import '../../../helpers/finger.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/game/presentation/shell/talk_square.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/art_picture.dart';
import 'package:midnight_village/design_system/primitives/role_sheet_body.dart';
import 'package:midnight_village/design_system/skin/skin_id.dart';
import 'package:midnight_village/design_system/skin/werewolf_portrait.dart';

import '../../../helpers/shell_setup.dart';

// A sheet is a route above the table shell. In a game whose Werewolf is not
// the lunge, the deck chip and the sheet it opens must draw the same wolf.

String _gameWith(WerewolfPortrait wolf) {
  final random = math.Random(7);
  while (true) {
    final id = List.generate(
      8,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
    if (WerewolfPortrait.forGame(id) == wolf) return id;
  }
}

Set<String> _wolvesIn(WidgetTester tester, Finder within) => {
  for (final picture in tester.widgetList<ArtPicture>(
    find.descendant(of: within, matching: find.byType(ArtPicture)),
  ))
    if (picture.image.path.contains('/roles/werewolf')) picture.image.path,
};

void main() {
  for (final wolf in [WerewolfPortrait.stare, WerewolfPortrait.snarl]) {
    testWidgets('${wolf.name} game: the role sheet and My night draw its '
        'wolf', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final me = recordedMe('me_discussion_choose_werewolf_pack')
        ..['game_id'] = _gameWith(wolf);
      final s = await ShellSetup.pump(
        tester,
        me,
        before: (s) =>
            s.answerPost('/night-results/seen/', 'game/night_results_seen'),
      );
      await s.settle(tester);
      final expected = SkinId.fallback.skin.art
          .role(RoleId.werewolf, wolf: wolf)
          .path;
      expect(WerewolfPortrait.forGame(s.gameId), wolf);

      // My night comes up by itself: it holds the Werewolf's face.
      final night = find.byType(MyNightPanel);
      expect(night, findsOneWidget);
      expect(_wolvesIn(tester, night), {expected});
      await pressAtLikeAFinger(tester, const Offset(4, 400));
      await tester.pumpAndSettle();

      // The deck's Werewolf chip opens the card details.
      await pressLikeAFinger(tester, find.text('2 Werewolves'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      final sheet = find.byType(RoleSheetBody);
      expect(sheet, findsOneWidget);
      expect(_wolvesIn(tester, sheet), {expected});
      await s.close(tester);
    });
  }
}
