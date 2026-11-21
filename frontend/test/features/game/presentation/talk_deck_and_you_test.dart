import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/player_row.dart';
import 'package:midnight_village/design_system/primitives/role_sheet_body.dart';
import 'package:midnight_village/design_system/primitives/you_tag.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/features/game/domain/game_me.dart';
import 'package:midnight_village/features/game/presentation/shell/talk_screen.dart';

import '../../../helpers/component_sheet.dart' show learnedOverrides;
import '../../../helpers/pump_skinned.dart';
import '../../../helpers/sheet/sheet_data.dart' as sheet;
import '../../../helpers/table_setup.dart';

// Two findings of the cold read on the real screens: the talk's deck was a
// row of tiny unnamed cards nobody read as the deck, and nothing on 02 said
// which player was "me".

void main() {
  group("the talk's deck", () {
    Future<void> pumpTalk(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpSkinned(
        tester,
        ProviderScope(
          overrides: learnedOverrides(const {}),
          child: TalkView(
            me: GameMe.fromJson(sheet.recordedMe('me_discussion_choose_seer')),
            secondsLeft: 252,
            elapsed: null,
            onReady: () {},
          ),
        ),
        ground: GroundKind.day,
      );
      await tester.pump();
    }

    testWidgets('names every role of the game, with how many where there '
        'are several', (tester) async {
      await pumpTalk(tester);
      // Game 7: a Seer, a Robber, a Troublemaker, 2 Werewolves, 3 Villagers.
      for (final label in [
        RoleId.seer.displayName,
        RoleId.robber.displayName,
        RoleId.troublemaker.displayName,
        '2 Werewolves',
        '3 Villagers',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('a tap on a role opens its sheet', (tester) async {
      await pumpTalk(tester);
      await tester.tap(find.text('3 Villagers'));
      // The sheet slides up (the hold cue on My night breathes on: no settle).
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(RoleSheetBody), findsOneWidget);
    });
  });

  testWidgets('02 says "You" on the viewer\'s own row, and only there', (
    tester,
  ) async {
    final setup = await TableSetup.pump(
      tester,
      lobby: v2Lobby('settings_deck_chip'),
      viewer: 'Ben',
    );
    expect(find.byType(YouTag), findsOneWidget);
    expect(
      find.descendant(
        of: find.widgetWithText(PlayerRow, 'Ben'),
        matching: find.byType(YouTag),
      ),
      findsOneWidget,
    );
    await setup.close(tester);
  });
}
