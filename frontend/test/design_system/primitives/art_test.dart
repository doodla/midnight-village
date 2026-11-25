import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/faces/face_content.dart';
import 'package:midnight_village/design_system/faces/held_face.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/art_picture.dart';
import 'package:midnight_village/design_system/primitives/art_precache.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/hold_to_reveal.dart';
import 'package:midnight_village/design_system/primitives/player_token.dart';
import 'package:midnight_village/design_system/skin/art_set.dart';
import 'package:midnight_village/design_system/skin/card_back.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/ground_scope.dart';
import 'package:midnight_village/design_system/skin/skin_id.dart';
import 'package:midnight_village/design_system/skin/skin_theme.dart';

import '../../helpers/pump_skinned.dart';

/// The app's bundle, noting every asset asked for.
class _RecordingBundle extends AssetBundle {
  final asked = <String>[];

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
  Future<String> loadString(String key, {bool cache = true}) {
    asked.add(key);
    return rootBundle.loadString(key, cache: cache);
  }

  @override
  Future<T> loadStructuredData<T>(
    String key,
    Future<T> Function(String value) parser,
  ) => rootBundle.loadStructuredData(key, parser);

  @override
  Future<T> loadStructuredBinaryData<T>(
    String key,
    FutureOr<T> Function(ByteData data) parser,
  ) => rootBundle.loadStructuredBinaryData(key, parser);
}

void main() {
  final skin = SkinId.fallback.skin;

  group('a picture is decoded no larger than it is shown', () {
    final portrait = skin.art.role(RoleId.seer);

    test('in eighths of the full size, at most a step larger than shown', () {
      // 576 x 768 in steps of 72: a 44-wide thumbnail at 3x needs 132 pixels.
      expect(portrait.decodeWidth(const Size(44, 58), 3), 144);
      expect(portrait.decodeWidth(const Size(50, 68), 3), 216);
      // 03's grid portrait, 113 wide on the owner's phone (2.625): not 576.
      expect(portrait.decodeWidth(const Size(113, 151), 2.625), 360);
      for (final ratio in [1.0, 2.0, 2.625, 3.0]) {
        for (var w = 4.0; w < 700; w += 7) {
          final box = Size(w, w * 4 / 3);
          final needed = portrait.neededWidth(box, ratio);
          final got = portrait.decodeWidth(box, ratio);
          expect(got, lessThanOrEqualTo(576));
          if (needed <= 576) {
            expect(got, greaterThanOrEqualTo(needed.floor()));
            expect(got - needed, lessThan(576 / ArtImage.steps + 1));
          }
        }
      }
      // Never smaller than a step, never larger than the picture.
      expect(portrait.decodeWidth(const Size(4, 5), 1), 72);
      expect(portrait.decodeWidth(Size.infinite, 1), 576);
    });

    testWidgets('ArtPicture asks for the decoded size of its box', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await pumpSkinned(
        tester,
        SizedBox(width: 44, height: 58, child: ArtPicture(portrait)),
      );
      final image = tester.widget<Image>(find.byType(Image)).image;
      expect(image, isA<ResizeImage>());
      expect((image as ResizeImage).width, 144);
    });
  });

  testWidgets('revealing a secret loads nothing: its art was decoded at '
      'start, at the size it is shown', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final bundle = _RecordingBundle();
    await tester.runAsync(
      () => precacheArt(secretArt(skin), devicePixelRatio: 1, bundle: bundle),
    );
    expect(
      bundle.asked.where((path) => path.contains('/roles/')).toSet(),
      hasLength(RoleId.values.length),
      reason: 'every role was loaded at start',
    );

    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: bundle,
        child: MaterialApp(
          theme: skinTheme(skin),
          builder: (context, child) =>
              GroundScope(ground: GroundKind.night, child: child!),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: FaceDownSize.hero.mock.width,
                child: HoldToReveal(
                  target: 'Your card',
                  cover: const FaceDownCard(size: FaceDownSize.hero),
                  face: FaceContent.roleText(RoleId.seer),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    bundle.asked.clear();

    await tester.startGesture(tester.getCenter(find.byType(HoldToReveal)));
    await tester.pump(HoldToReveal.holdDelay * 2);
    await tester.pump();

    expect(find.byType(HeldFace), findsOneWidget);
    expect(bundle.asked, isEmpty, reason: 'nothing fetched at reveal time');
    final drawn = tester.widget<RawImage>(
      find.descendant(
        of: find.byType(HeldFace),
        matching: find.byType(RawImage),
      ),
    );
    expect(drawn.image, isNotNull, reason: 'the face is never empty');
  });

  test('every card back ships at a phone size', () async {
    for (final back in CardBack.values) {
      final art = skin.art.cardBack(back);
      final bytes = await rootBundle.load(art.path);
      // Drawn at most 250 wide (S07): 600 pixels is sharp at 2.4x.
      expect(art.pixels.width, lessThanOrEqualTo(600), reason: back.name);
      expect(bytes.lengthInBytes, lessThan(150 * 1024), reason: back.name);
    }
  });

  testWidgets('the game\'s back is the one precached; the others are not', (
    tester,
  ) async {
    final uses = secretArt(skin, back: CardBack.eye);
    final paths = {for (final (image, _) in uses) image.path};
    expect(paths, contains(skin.art.cardBack(CardBack.eye).path));
    for (final other in CardBack.values.where((b) => b != CardBack.eye)) {
      expect(paths, isNot(contains(skin.art.cardBack(other).path)));
    }
    // At start, with no game, it is the fallback's.
    final atStart = {for (final (image, _) in secretArt(skin)) image.path};
    expect(atStart, contains(skin.art.cardBack(CardBack.fallback).path));
  });

  testWidgets('a token this app does not know is a plain disc', (tester) async {
    await pumpSkinned(tester, const PlayerToken(null));
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
