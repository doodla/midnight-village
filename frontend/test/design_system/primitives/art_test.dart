import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/art_picture.dart';
import 'package:midnight_village/design_system/primitives/art_precache.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/hold_to_reveal.dart';
import 'package:midnight_village/design_system/primitives/player_token.dart';
import 'package:midnight_village/design_system/primitives/role_card.dart';
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

    test('in steps of the full size, a half and a quarter', () {
      // 576 x 768: a 44-wide thumbnail at 3x needs 135 pixels: a quarter.
      expect(portrait.decodeWidth(const Size(44, 58), 3), 144);
      expect(portrait.decodeWidth(const Size(50, 68), 3), 288);
      // Your card at 2x needs more than the picture has: all of it.
      expect(portrait.decodeWidth(RoleCard.largePortrait, 2), 576);
      // Never smaller than a quarter, never larger than the picture.
      expect(portrait.decodeWidth(const Size(4, 5), 1), 144);
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
                  semanticLabel: 'Your card',
                  cover: const FaceDownCard(size: FaceDownSize.hero),
                  secret: (_) => const RoleCard(
                    role: RoleId.seer,
                    size: RoleCardSize.large,
                    team: 'Village team',
                  ),
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

    expect(find.byType(RoleCard), findsOneWidget);
    expect(bundle.asked, isEmpty, reason: 'nothing fetched at reveal time');
    final drawn = tester.widget<RawImage>(
      find.descendant(
        of: find.byType(RoleCard),
        matching: find.byType(RawImage),
      ),
    );
    expect(drawn.image, isNotNull, reason: 'the card is never empty');
  });

  test('the card back ships at a phone size', () async {
    final back = skin.art.cardBack;
    final bytes = await rootBundle.load(back.path);
    // Drawn at most 250 wide (S07): 600 pixels is sharp at 2.4x.
    expect(back.pixels.width, lessThanOrEqualTo(600));
    expect(bytes.lengthInBytes, lessThan(150 * 1024));
  });

  testWidgets('a token this app does not know is a plain disc', (tester) async {
    await pumpSkinned(tester, const PlayerToken(null));
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test(
    'a phone in the default skin loads no other skin\'s faces at start',
    () async {
      final manifest =
          jsonDecode(await rootBundle.loadString('FontManifest.json'))
              as List<dynamic>;
      final families = {
        for (final entry in manifest.cast<Map<String, dynamic>>())
          entry['family'] as String,
      };
      for (final id in SkinId.values.skip(1)) {
        expect(
          families.intersection(id.skin.fonts.onDemand.keys.toSet()),
          isEmpty,
          reason: id.label,
        );
      }
    },
  );
}
