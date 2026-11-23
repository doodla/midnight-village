import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/sheet_scaffold.dart';
import 'package:midnight_village/design_system/skin/card_back.dart';
import 'package:midnight_village/design_system/skin/card_back_scope.dart';
import 'package:midnight_village/design_system/skin/dress.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/ground_scope.dart';
import 'package:midnight_village/design_system/skin/skin_id.dart';
import 'package:midnight_village/design_system/skin/werewolf_portrait.dart';

import '../../helpers/pump_skinned.dart';

// A sheet or dialog is a route on the root navigator, above the table shell:
// it must still see every game-wide scope (`GameScopes`), so a card detail
// shows the game's Werewolf and the game's back, not the fallbacks.

void main() {
  const wolf = WerewolfPortrait.stare;
  const back = CardBack.eye;

  Future<void> open(
    WidgetTester tester,
    Future<void> Function(BuildContext, WidgetBuilder) show,
    void Function(BuildContext) seen,
  ) async {
    await pumpSkinned(
      tester,
      DressScope(
        dress: Dress.paper,
        child: CardBackScope(
          back: back,
          child: WerewolfPortraitScope(
            portrait: wolf,
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => show(context, (inner) {
                  seen(inner);
                  return const SizedBox();
                }),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
      ground: GroundKind.day,
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  for (final (name, show)
      in <(String, Future<void> Function(BuildContext, WidgetBuilder))>[
        ('a sheet', (c, b) => showSkinSheet<void>(c, builder: b)),
        ('a dialog', (c, b) => showSkinDialog<void>(c, builder: b)),
      ]) {
    testWidgets('$name carries every game-wide scope', (tester) async {
      final art = SkinId.fallback.skin.art;
      late BuildContext inside;
      await open(tester, show, (context) => inside = context);
      expect(WerewolfPortraitScope.of(inside), wolf);
      expect(
        inside.roleArt(RoleId.werewolf),
        art.role(RoleId.werewolf, wolf: wolf),
      );
      expect(CardBackScope.of(inside), back);
      expect(inside.cardBack, art.cardBack(back));
      expect(inside.dress, Dress.paper);
      expect(GroundScope.of(inside), GroundKind.day);
    });
  }

  test('no code outside the design system opens a route by hand, or reads '
      'a role picture past the game\'s portrait', () {
    final direct = RegExp(
      r'\b(showModalBottomSheet|showDialog|showGeneralDialog|showCupertinoDialog|showCupertinoModalPopup|showMenu)\s*[<(]',
    );
    final artRole = RegExp(r'\bart\.role\(');
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (file.path.endsWith('.g.dart')) continue;
      final text = file.readAsStringSync();
      // Only the art set itself and the precache name a role's picture
      // without a game (`context.roleArt` is the way a screen draws one).
      if (!file.path.endsWith('skin/werewolf_portrait.dart') &&
          !file.path.endsWith('primitives/art_precache.dart')) {
        expect(artRole.hasMatch(text), isFalse, reason: file.path);
      }
      if (!file.path.startsWith('lib/design_system/')) {
        expect(direct.hasMatch(text), isFalse, reason: file.path);
      } else if (!file.path.endsWith('primitives/sheet_scaffold.dart')) {
        expect(direct.hasMatch(text), isFalse, reason: file.path);
      }
    }
  });
}
