import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/mood.dart';
import 'package:midnight_village/design_system/skin/dress.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/ground_scope.dart';
import 'package:midnight_village/design_system/skin/skin_theme.dart';

import '../../helpers/painted_text.dart';
import '../../helpers/pump_skinned.dart';

// The mood is the ground under every dressed screen, so a word on it is read
// against the lightest (or darkest) pixel it can really sit on: every pixel of
// each mood, at phone size, is painted and measured; the village, which no
// bare word sits on, is measured by the page tests on the real screens
// (`dressed_contrast_test.dart`). What it costs is held here too: it is
// composed once into one picture, and a frame draws that picture.

Widget _app(Widget child, {Key? key}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: skinTheme(skinsUnderTest.values.first),
  builder: (context, app) => GroundScope(ground: GroundKind.night, child: app!),
  home: DressScope(
    dress: Dress.paper,
    child: RepaintBoundary(key: key, child: child),
  ),
);

Future<Uint8List> _paint(
  WidgetTester tester,
  MoodKind kind, {
  bool scene = false,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  await tester.pumpWidget(
    _app(
      Mood(kind: kind, scene: scene),
      key: key,
    ),
  );
  if (scene) {
    // The village's layers decode on real I/O; the picture takes them in.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 800)),
    );
    await tester.pump();
  }
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return data!.buffer.asUint8List();
  });
  return bytes!;
}

void main() {
  setUp(() {
    Mood.forget();
    Mood.composed = 0;
    Mood.painted = 0;
  });

  final skin = skinsUnderTest.values.first.dressedUp!;
  for (final (kind, ground) in [
    (MoodKind.night, GroundKind.night),
    (MoodKind.lantern, GroundKind.night),
    (MoodKind.dawn, GroundKind.night),
    (MoodKind.day, GroundKind.day),
  ]) {
    testWidgets('${kind.name}: every word keeps 7:1 on every pixel of the '
        'ground and its lights', (tester) async {
      final pixels = await _paint(tester, kind);
      final colors = skin.ground(ground);
      final lightText = ground == GroundKind.night;
      Color? worst;
      var worstL = lightText ? -1.0 : 2.0;
      for (var i = 0; i < pixels.length; i += 4 * 3) {
        final c = Color.fromARGB(255, pixels[i], pixels[i + 1], pixels[i + 2]);
        final l = luminance(c);
        if (lightText ? l > worstL : l < worstL) {
          worstL = l;
          worst = c;
        }
      }
      for (final (name, text) in [
        ('text', colors.text),
        ('quiet', colors.quietText),
      ]) {
        expect(
          contrast(text, worst!),
          greaterThanOrEqualTo(readingContrast),
          reason: '$name on ${kind.name}: the hardest pixel is $worst',
        );
      }
      expect(
        contrast(colors.faintText, worst!),
        greaterThanOrEqualTo(4.5),
        reason: 'faint on ${kind.name}',
      );
    });

    testWidgets('${kind.name}: it is not a flat field', (tester) async {
      final pixels = await _paint(tester, kind);
      final seen = <int>{};
      for (var i = 0; i < pixels.length; i += 4 * 97) {
        seen.add((pixels[i] << 16) | (pixels[i + 1] << 8) | pixels[i + 2]);
      }
      expect(seen.length, greaterThan(40));
    });
  }

  for (final size in const [Size(360, 780), Size(390, 844)]) {
    testWidgets('the village stands in the night and the day at ${size.width}'
        ' x ${size.height}: the picture with it differs from the ground '
        'alone', (tester) async {
      for (final kind in [MoodKind.night, MoodKind.day]) {
        final bare = await _paint(tester, kind, size: size);
        await tester.pumpWidget(const SizedBox());
        Mood.forget();
        final withVillage = await _paint(tester, kind, scene: true, size: size);
        var differing = 0;
        for (var i = 0; i < bare.length; i += 4) {
          if ((bare[i] - withVillage[i]).abs() > 12) differing++;
        }
        expect(
          differing,
          greaterThan(bare.length ~/ 4 ~/ 20),
          reason: '${kind.name}: the village shows',
        );
      }
    });
  }

  group('what it costs: one picture, not a layer to draw per frame', () {
    testWidgets('an animation ticking above it does not paint or compose it '
        'again', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final tick = ValueNotifier<double>(0);
      await tester.pumpWidget(
        _app(
          ValueListenableBuilder<double>(
            valueListenable: tick,
            // A new Mood instance every tick, as a parent that rebuilds on
            // an animation gives it.
            builder: (context, t, _) => Opacity(
              opacity: 0.5 + t / 2,
              child: const Mood(kind: MoodKind.night, scene: false),
            ),
          ),
        ),
      );
      final composed = Mood.composed;
      final painted = Mood.painted;
      expect(composed, 1);
      for (var i = 1; i <= 12; i++) {
        tick.value = i / 12;
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(Mood.composed, composed);
      expect(Mood.painted, painted);
    });

    testWidgets('the same screen size, phase and light reuses the picture; '
        'another size makes one more; the keyboard rising makes none', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(const Mood(kind: MoodKind.lantern, scene: false)),
      );
      expect(Mood.composed, 1);
      // Another screen of the same size and phase: the picture is kept.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        _app(const Mood(kind: MoodKind.lantern, scene: false)),
      );
      expect(Mood.composed, 1);
      // The body shrinking for the keyboard: still the screen's picture.
      await tester.pumpWidget(
        _app(
          const Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: 500,
              child: Mood(kind: MoodKind.lantern, scene: false),
            ),
          ),
        ),
      );
      expect(Mood.composed, 1);
      // A different light is another picture.
      await tester.pumpWidget(
        _app(const Mood(kind: MoodKind.day, scene: false)),
      );
      expect(Mood.composed, 2);
    });

    testWidgets('what a frame draws is one image, with no blend over the '
        'screen and no layer saved', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(const Mood(kind: MoodKind.night, scene: false)),
      );
      expect(find.byType(RawImage), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Mood),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
    });
  });
}
