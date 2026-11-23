import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/art_picture.dart';
import 'package:midnight_village/design_system/primitives/art_precache.dart';
import 'package:midnight_village/design_system/primitives/role_card.dart';
import 'package:midnight_village/design_system/skin/card_back.dart';
import 'package:midnight_village/design_system/skin/skin_id.dart';
import 'package:midnight_village/design_system/skin/werewolf_portrait.dart';

import '../../helpers/pump_skinned.dart';
import '../../helpers/shell_setup.dart';

// The Werewolf has three portraits; one is drawn for a whole game, chosen from
// the game's id as the card back is (with another salt), so it is the same on
// every phone and tells nothing about any role.

final _art = SkinId.fallback.skin.art;

Set<String> _wolvesDrawn(WidgetTester tester) => {
  for (final picture in tester.widgetList<ArtPicture>(find.byType(ArtPicture)))
    if (picture.image.path.contains('/roles/werewolf')) picture.image.path,
};

String _uuid(math.Random random) {
  String hex(int n) =>
      List.generate(n, (_) => random.nextInt(16).toRadixString(16)).join();
  return '${hex(8)}-${hex(4)}-4${hex(3)}-a${hex(3)}-${hex(12)}';
}

void main() {
  group('the Werewolf of a game', () {
    test('the same game is the same portrait, every time', () {
      const id = '7d3f2c1a-5b8e-4c2d-9a6f-1e0b3c4d5e6f';
      expect(WerewolfPortrait.forGame(id), WerewolfPortrait.forGame(id));
      expect(
        WerewolfPortrait.forGame(String.fromCharCodes(id.codeUnits)),
        WerewolfPortrait.forGame(id),
      );
    });

    test('no game, or an empty id, is the lunge', () {
      expect(WerewolfPortrait.forGame(null), WerewolfPortrait.lunge);
      expect(WerewolfPortrait.forGame(''), WerewolfPortrait.lunge);
      expect(WerewolfPortrait.fallback, WerewolfPortrait.lunge);
      expect(
        _art.role(RoleId.werewolf).path,
        endsWith('/roles/werewolf_lunge.webp'),
      );
    });

    test('all three come up, about alike often, over many games', () {
      final random = math.Random(20261123);
      final counts = {for (final w in WerewolfPortrait.values) w: 0};
      const games = 3000;
      for (var i = 0; i < games; i++) {
        final w = WerewolfPortrait.forGame(_uuid(random));
        counts[w] = counts[w]! + 1;
      }
      for (final MapEntry(key: w, value: count) in counts.entries) {
        expect(count / games, inInclusiveRange(0.28, 0.39), reason: w.name);
      }
    });

    test('does not move with the card back', () {
      final random = math.Random(7);
      final pairs = <(CardBack, WerewolfPortrait)>{};
      for (var i = 0; i < 2000; i++) {
        final id = _uuid(random);
        pairs.add((CardBack.forGame(id), WerewolfPortrait.forGame(id)));
      }
      // Every back goes with every portrait.
      expect(pairs, hasLength(CardBack.values.length * 3));
    });

    test('only the Werewolf has three; every role has its own file', () {
      for (final role in RoleId.values) {
        for (final w in WerewolfPortrait.values) {
          final path = _art.role(role, wolf: w).path;
          if (role == RoleId.werewolf) {
            expect(path, endsWith('/roles/werewolf_${w.fileName}.webp'));
          } else {
            expect(path, endsWith('/roles/${role.name}.webp'));
          }
        }
      }
    });

    test('the old asset name is referenced nowhere', () {
      expect(
        File('assets/skins/shadow_paper/roles/werewolf.webp').existsSync(),
        isFalse,
      );
      expect(
        File('../docs/design/art/roles/werewolf.jpg').existsSync(),
        isFalse,
      );
      final old = RegExp(r'roles/werewolf\.(webp|jpg)');
      for (final root in ['lib', 'test', 'test_screens', 'tool']) {
        for (final file in Directory(root).listSync(recursive: true)) {
          if (file is! File ||
              file.path.endsWith('werewolf_portrait_test.dart')) {
            continue;
          }
          if (!RegExp(r'\.(dart|py|md|yaml)$').hasMatch(file.path)) continue;
          expect(
            old.hasMatch(file.readAsStringSync()),
            isFalse,
            reason: file.path,
          );
        }
      }
    });
  });

  group('every place that shows the Werewolf shows the game\'s one', () {
    for (final wolf in WerewolfPortrait.values) {
      testWidgets('${wolf.name}: every card size', (tester) async {
        await pumpSkinned(
          tester,
          WerewolfPortraitScope(
            portrait: wolf,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final size in RoleCardSize.values)
                    SizedBox(
                      width: 200,
                      child: RoleCard(role: RoleId.werewolf, size: size),
                    ),
                  const SizedBox(
                    width: 200,
                    child: RoleCard(role: RoleId.werewolf, count: 2),
                  ),
                ],
              ),
            ),
          ),
        );
        expect(_wolvesDrawn(tester), {
          _art.role(RoleId.werewolf, wolf: wolf).path,
        });
      });
    }

    testWidgets('outside a game it is the lunge', (tester) async {
      await pumpSkinned(
        tester,
        const RoleCard(role: RoleId.werewolf, size: RoleCardSize.mini),
      );
      expect(_wolvesDrawn(tester), {_art.role(RoleId.werewolf).path});
    });

    testWidgets('the shell: a game\'s screens draw its portrait only', (
      tester,
    ) async {
      final me = recordedMe('me_results');
      final s = await ShellSetup.pump(
        tester,
        me,
        before: (s) {
          s.answerNightResultsSeen();
        },
      );
      await s.settle(tester);
      final expected = _art
          .role(RoleId.werewolf, wolf: WerewolfPortrait.forGame(s.gameId))
          .path;
      expect(_wolvesDrawn(tester).difference({expected}), isEmpty);
      await s.close(tester);
    });
  });

  testWidgets('the precache warms the portrait the game uses', (tester) async {
    for (final wolf in WerewolfPortrait.values) {
      final uses = secretArt(SkinId.fallback.skin, wolf: wolf);
      final paths = {for (final (image, _) in uses) image.path};
      expect(paths, contains(_art.role(RoleId.werewolf, wolf: wolf).path));
      for (final other in WerewolfPortrait.values.where((o) => o != wolf)) {
        expect(
          paths,
          isNot(contains(_art.role(RoleId.werewolf, wolf: other).path)),
        );
      }
    }
  });
}
