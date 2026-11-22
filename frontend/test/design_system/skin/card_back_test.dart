import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/art_picture.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/panels.dart';
import 'package:midnight_village/design_system/skin/card_back.dart';
import 'package:midnight_village/design_system/skin/card_back_scope.dart';
import 'package:midnight_village/core/storage/device_preferences.dart';
import 'package:midnight_village/design_system/skin/skin_id.dart';
import 'package:midnight_village/design_system/skin_loader.dart';
import 'package:midnight_village/features/lobby/presentation/last_seat.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:midnight_village/features/game/domain/screen_table.dart';
import 'package:midnight_village/features/game/presentation/shell/count_screen.dart';
import 'package:midnight_village/features/game/presentation/shell/night_screen.dart';
import 'package:midnight_village/features/game/presentation/shell/your_card_screen.dart';

import '../../helpers/contract/sample_sets.dart';
import '../../helpers/pump_skinned.dart';
import '../../helpers/shell_setup.dart';

// The five card backs, and the one rule that matters: within one game every
// face-down card has the same back, on every phone at the table. Cards are
// swapped and looked at during the night; a back that told one card from
// another would let a player follow a card.

final _art = SkinId.fallback.skin.art;

/// The app's bundle, noting every asset asked for.
class _AskedBundle extends AssetBundle {
  _AskedBundle(this.asked);

  final List<String> asked;

  @override
  Future<ByteData> load(String key) {
    asked.add(key);
    return rootBundle.load(key);
  }

  @override
  Future<ui.ImmutableBuffer> loadBuffer(String key) {
    asked.add(key);
    return rootBundle.loadBuffer(key);
  }

  @override
  Future<T> loadStructuredData<T>(
    String key,
    Future<T> Function(String value) parser,
  ) => rootBundle.loadStructuredData(key, parser);
}

/// The back of every card back picture drawn on screen, by file.
Set<String> _backsDrawn(WidgetTester tester) => {
  for (final picture in tester.widgetList<ArtPicture>(find.byType(ArtPicture)))
    if (picture.image.path.contains('/card_back_')) picture.image.path,
};

void main() {
  group('the back of a game', () {
    test('the same game is the same back, every time', () {
      const id = '7d3f2c1a-5b8e-4c2d-9a6f-1e0b3c4d5e6f';
      expect(CardBack.forGame(id), CardBack.forGame(id));
      expect(
        CardBack.forGame(String.fromCharCodes(id.codeUnits)),
        CardBack.forGame(id),
      );
    });

    // Fixed answers: the choice must not move between platforms or releases
    // (a phone and a table-mate's browser must agree), so a change to the
    // hash fails here.
    test('is the same on every platform: fixed ids, fixed backs', () {
      expect(
        {
          for (final id in [
            '7d3f2c1a-5b8e-4c2d-9a6f-1e0b3c4d5e6f',
            '9a1e5c7b-3d2f-4b6a-8c0e-2f4a6b8c0d1e',
            '00000000-0000-4000-a000-000000000004',
            'abc',
          ])
            id: CardBack.forGame(id),
        },
        {
          '7d3f2c1a-5b8e-4c2d-9a6f-1e0b3c4d5e6f': CardBack.window,
          '9a1e5c7b-3d2f-4b6a-8c0e-2f4a6b8c0d1e': CardBack.teeth,
          '00000000-0000-4000-a000-000000000004': CardBack.window,
          'abc': CardBack.eye,
        },
      );
    });

    test('no game is the calm fallback, the moon', () {
      expect(CardBack.forGame(null), CardBack.moon);
      expect(CardBack.forGame(''), CardBack.moon);
      expect(CardBack.fallback, CardBack.moon);
    });

    test('all five come up, about alike often, over many games', () {
      final random = math.Random(20261122);
      String uuid() {
        String hex(int n) => List.generate(
          n,
          (_) => random.nextInt(16).toRadixString(16),
        ).join();
        return '${hex(8)}-${hex(4)}-4${hex(3)}-a${hex(3)}-${hex(12)}';
      }

      final counts = {for (final back in CardBack.values) back: 0};
      const games = 2000;
      final ids = [for (var i = 0; i < games; i++) uuid()];
      for (final id in ids) {
        counts[CardBack.forGame(id)] = counts[CardBack.forGame(id)]! + 1;
      }
      for (final MapEntry(key: back, value: count) in counts.entries) {
        expect(count / games, inInclusiveRange(0.15, 0.25), reason: back.name);
      }
    });

    test('a table playing again usually sees another back', () {
      final random = math.Random(5);
      String uuid() =>
          List.generate(32, (_) => random.nextInt(16).toRadixString(16)).join();
      var changed = 0;
      const rounds = 1000;
      for (var i = 0; i < rounds; i++) {
        if (CardBack.forGame(uuid()) != CardBack.forGame(uuid())) changed++;
      }
      // One in five is the same by chance; four in five differ.
      expect(changed / rounds, inInclusiveRange(0.72, 0.88));
    });
  });

  group('every face-down card of a game has the one back', () {
    for (final back in CardBack.values) {
      testWidgets('${back.name}: every size, the peek box and the count\'s '
          'card', (tester) async {
        await pumpSkinned(
          tester,
          CardBackScope(
            back: back,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final size in FaceDownSize.values)
                    SizedBox(
                      width: 400,
                      child: FaceDownCard(
                        size: size,
                        ownerName: 'Ana',
                        selected: size == FaceDownSize.board,
                        dimmed: size == FaceDownSize.player,
                        hold: true,
                      ),
                    ),
                  const PeekBox(title: 'My night', teaching: true),
                ],
              ),
            ),
          ),
        );
        expect(_backsDrawn(tester), {_art.cardBack(back).path});
        expect(
          find.byType(ArtPicture),
          findsNWidgets(FaceDownSize.values.length + 1),
        );
      });
    }

    testWidgets('outside a game it is the fallback', (tester) async {
      await pumpSkinned(tester, const FaceDownCard());
      expect(_backsDrawn(tester), {_art.cardBack(CardBack.fallback).path});
    });

    testWidgets('a card cannot bring a back of its own: the scope above is '
        'the only way a back is chosen', (tester) async {
      // Two cards side by side under one scope, whatever their owner, name,
      // size or state: the same file.
      await pumpSkinned(
        tester,
        const CardBackScope(
          back: CardBack.teeth,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FaceDownCard(caption: 'Left'),
              FaceDownCard(caption: 'Middle', selected: true),
              FaceDownCard(caption: 'Right', dimmed: true),
            ],
          ),
        ),
      );
      expect(_backsDrawn(tester), hasLength(1));
    });

    test('no screen reads a back from the skin: only the game\'s, from '
        'its scope', () {
      // `art.cardBack(` is what picks a picture; it may be asked in the
      // places that already hold the game's one back and nowhere else.
      const allowed = {
        'lib/design_system/skin/art_set.dart',
        'lib/design_system/skin/card_back_scope.dart',
        'lib/design_system/primitives/art_precache.dart',
      };
      final readers = [
        for (final file in Directory('lib').listSync(recursive: true))
          if (file is File &&
              file.path.endsWith('.dart') &&
              file.readAsStringSync().contains(RegExp(r'art\.cardBack\(')))
            file.path,
      ];
      expect(readers.toSet().difference(allowed), isEmpty);
      // And no randomness near the choice.
      for (final path in [
        'lib/design_system/skin/card_back.dart',
        'lib/design_system/skin/card_back_scope.dart',
        'lib/features/game/presentation/card_back_provider.dart',
      ]) {
        expect(File(path).readAsStringSync(), isNot(contains('Random')));
      }
    });
  });

  group('the shell gives a game one back on every screen and phone', () {
    // Every recorded /me/ of a night, a talk and the count, as a different
    // phone of the table would hold it: the back is that of the game's id,
    // and the same for the same id.
    const samples = [
      'me_look_stage',
      'me_choose_prompt_seer',
      'me_choose_prompt_robber',
      'me_choose_prompt_troublemaker',
      'me_results',
    ];
    final backsByGame = <String, Set<String>>{};
    for (final sample in samples) {
      testWidgets('$sample: the back of its game', (tester) async {
        final me = recordedMe(sample);
        final s = await ShellSetup.pump(
          tester,
          me,
          before: (s) {
            s.answerNightResultsSeen();
          },
        );
        await s.settle(tester);
        final expected = _art.cardBack(CardBack.forGame(s.gameId)).path;
        expect(
          find.byType(switch (meScreens[sample]!) {
            AppScreen.yourCard => YourCardScreen,
            AppScreen.count => CountScreen,
            _ => NightScreen,
          }),
          findsOneWidget,
        );
        final drawn = _backsDrawn(tester);
        expect(drawn, isNotEmpty);
        expect(drawn, {expected});
        backsByGame.putIfAbsent(s.gameId, () => {}).addAll(drawn);
        await s.close(tester);
      });
    }

    tearDownAll(() {
      // Every phone of a game drew one back.
      for (final backs in backsByGame.values) {
        expect(backs, hasLength(1));
      }
    });
  });

  group('the game\'s back is decoded before 04\'s card first shows', () {
    // The deal names the game, and 04 shows its frame (no card) while its
    // `/me/` is fetched. The back is decoded from that moment, in the
    // background: the card never waits for it and never shows without it.
    testWidgets('named at the deal, in the cache before /me/ answers, and '
        'the card paints it on its first frame', (tester) async {
      final me = recordedMe('me_look_stage');
      final gameId = me['game_id'] as String;
      final back = CardBack.forGame(gameId);
      expect(back, isNot(CardBack.fallback), reason: 'the fallback is warm');

      PaintingBinding.instance.imageCache.clear();
      final s = await ShellSetup.pump(tester, me, holdMe: true);
      await s.settle(tester);
      // The decode runs on real time; the shell does not wait for it.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();
      expect(find.byType(YourCardScreen), findsNothing);
      expect(find.byType(FaceDownCard), findsNothing);

      final context = tester.element(find.byType(Scaffold).first);
      final ratio = MediaQuery.devicePixelRatioOf(context);
      final config = ImageConfiguration(devicePixelRatio: ratio);
      final cache = PaintingBinding.instance.imageCache;
      for (final size in FaceDownSize.values) {
        final provider = _art.cardBack(back).decodedFor(size.mock, ratio);
        final key = await tester.runAsync(() => provider.obtainKey(config));
        expect(
          cache.containsKey(key!),
          isTrue,
          reason: '${size.name} is decoded before 04 asks for it',
        );
      }

      // /me/ answers: the card appears already painted.
      s.meReplies!.releaseAll();
      for (
        var i = 0;
        i < 60 && find.byType(YourCardScreen).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.byType(YourCardScreen), findsOneWidget);
      final drawn = tester.widgetList<RawImage>(
        find.descendant(
          of: find.byType(FaceDownCard),
          matching: find.byType(RawImage),
        ),
      );
      expect(drawn, isNotEmpty);
      expect(drawn.every((picture) => picture.image != null), isTrue);
      await s.close(tester);
    });
  });

  group('a restart in a game decodes that game\'s back with the start', () {
    Future<void> restoreSeat(String? seat) async {
      SharedPreferences.setMockInitialValues({
        if (seat != null) '${LastSeat.prefix}$seat': '1',
      });
      await LastSeat.restore(DevicePreferences());
    }

    tearDown(LastSeat.forget);

    test('the game of the seat kept on the device; none for a waiting '
        'table or no table', () async {
      await restoreSeat('7:ABCD|9a1e5c7b-3d2f-4b6a-8c0e-2f4a6b8c0d1e');
      expect(LastSeat.openingGame, '9a1e5c7b-3d2f-4b6a-8c0e-2f4a6b8c0d1e');
      await restoreSeat('7:ABCD');
      expect(LastSeat.openingGame, isNull);
      await restoreSeat(null);
      expect(LastSeat.openingGame, isNull);
      expect(CardBack.forGame(LastSeat.openingGame), CardBack.fallback);
    });

    testWidgets('prepare takes the back asked for, and no other of the '
        'five', (tester) async {
      final skin = SkinId.fallback.skin;
      final asked = <String>[];
      await tester.runAsync(
        () => SkinLoader(
          bundle: _AskedBundle(asked),
          devicePixelRatio: () => 3,
        ).prepare(skin, back: CardBack.quilt),
      );
      expect(asked.where((key) => key.contains('/card_back_')).toSet(), {
        _art.cardBack(CardBack.quilt).path,
      });
    });
  });
}
