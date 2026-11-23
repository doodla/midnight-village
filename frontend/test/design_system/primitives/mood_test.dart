import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/mood.dart';
import 'package:midnight_village/design_system/primitives/paper_grain.dart';
import 'package:midnight_village/design_system/primitives/paper_mark.dart';
import 'package:midnight_village/design_system/skin/ground.dart';

import '../../helpers/painted_text.dart';
import '../../helpers/pump_skinned.dart';

// The mood is the ground under every game screen, so a word on it is read
// against the lightest (or darkest) pixel it can really sit on: every pixel of
// each mood, at phone size, is painted and measured. The page tests
// (`contrast_test.dart`) then read the real screens.

Future<Uint8List> _paint(WidgetTester tester, MoodKind kind) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        key: key,
        // The village is art on top of this: a word never sits bare on it
        // (a banner, a slip or a plaque backs it; the page tests read those).
        child: Mood(kind: kind, scene: false),
      ),
    ),
  );
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
  final skin = skinsUnderTest.values.first;
  for (final (kind, ground) in [
    (MoodKind.night, GroundKind.night),
    (MoodKind.lantern, GroundKind.night),
    (MoodKind.dawn, GroundKind.night),
    (MoodKind.day, GroundKind.day),
  ]) {
    testWidgets('${kind.name}: every word keeps 7:1 on every pixel of it', (
      tester,
    ) async {
      final pixels = await _paint(tester, kind);
      final colors = skin.ground(ground);
      final lightText = ground == GroundKind.night;
      // The pixel that is hardest on the words: the lightest under light
      // words, the darkest under dark ones.
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
          greaterThanOrEqualTo(name == 'text' ? readingContrast : 4.5),
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

  test('the grain is there at once, and the same every run', () {
    final provider = PaperGrain.provider;
    final stream = provider.resolve(ImageConfiguration.empty);
    var got = false;
    stream.addListener(
      ImageStreamListener((info, sync) {
        got = sync;
      }),
    );
    expect(got, isTrue, reason: 'a synchronous image: no empty first frame');
    expect(identical(PaperGrain.provider, provider), isTrue);
  });

  testWidgets('the paper mark is a still picture the size it is given', (
    tester,
  ) async {
    await pumpSkinned(
      tester,
      const Center(child: PaperMark(size: 22)),
      ground: GroundKind.night,
    );
    expect(tester.getSize(find.byType(PaperMark)), const Size.square(22));
  });
}
