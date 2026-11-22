import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:midnight_village/design_system/primitives/layered_art.dart';
import 'package:midnight_village/design_system/primitives/scene_arrival.dart';
import 'package:midnight_village/design_system/skin/art_set.dart';
import 'package:midnight_village/design_system/skin/skin_id.dart';

import '../../helpers/frame_pixels.dart';
import '../../helpers/pump_skinned.dart';

// The layered scenes (`LayeredScene`): their description is consistent, a
// layer never shows its own edge at the start of a scene, and drawn at rest
// the layers make the flat picture they were cut from.

final _art = SkinId.fallback.skin.art;

/// The flat picture each scene was cut from, kept beside its layers.
const _flats = {
  LayeredSceneId.nightVillage:
      '../docs/design/art/layers/night-village/flat.jpg',
  LayeredSceneId.dawnGallows: '../docs/design/art/layers/dawn-gallows/flat.jpg',
};

/// How far a layer of 04 may start from where it rests, in canvas pixels:
/// what the art was cut for (the clouds' shadows end and the moon's rim are
/// only drawn that far; `docs/design/art/layers/night-village/PROVENANCE.md`).
const _nightTravel = {
  // Nothing of the plate is under the moon and its shadows are cast by the
  // clouds, so it may come from anywhere: from above the top edge.
  'moon': Offset(0, 240),
  'moon_shadow_dark': Offset(16, 0),
  'moon_shadow_cream': Offset(16, 0),
  'clouds_dark': Offset(16, 0),
  'clouds_dark_shadow': Offset(16, 0),
  'clouds_cream': Offset(16, 0),
  'clouds_cream_shadow': Offset(16, 0),
};

void main() {
  group('the description', () {
    for (final id in LayeredSceneId.values) {
      final scene = _art.layeredScene(id);
      group(id.name, () {
        test('every layer is named once and a shadow follows the layer it is '
            'cast on', () {
          final names = [for (final layer in scene.files) layer.file];
          expect(names.toSet().length, names.length);
          final all = scene.layers;
          for (var i = 0; i < all.length; i++) {
            final entry = all[i];
            if (entry is! SceneLayer || entry.clipTo == null) continue;
            var at = i - 1;
            // Directly after its target, or after another cast on it.
            while (at >= 0 &&
                all[at] is SceneLayer &&
                (all[at] as SceneLayer).clipTo == entry.clipTo) {
              at--;
            }
            expect(
              at >= 0 &&
                  all[at] is SceneLayer &&
                  (all[at] as SceneLayer).file == entry.clipTo,
              isTrue,
              reason: '${entry.file} is not directly after ${entry.clipTo}',
            );
          }
        });

        test('a layer that reaches the canvas edge at rest still does where '
            'it starts', () {
          final canvas = scene.canvas;
          for (final layer in scene.layers.whereType<SceneLayer>()) {
            // A shadow cast on another layer is only ever seen on it.
            if (layer.clipTo != null) continue;
            final rest = layer.anchor & layer.size;
            final start = rest.shift(layer.from);
            reason(String edge) => '${layer.file} shows its $edge edge';
            if (rest.left <= 0) {
              expect(start.left, lessThanOrEqualTo(0), reason: reason('left'));
            }
            if (rest.top <= 0) {
              expect(start.top, lessThanOrEqualTo(0), reason: reason('top'));
            }
            if (rest.right >= canvas.width) {
              expect(
                start.right,
                greaterThanOrEqualTo(canvas.width),
                reason: reason('right'),
              );
            }
            if (rest.bottom >= canvas.height) {
              expect(
                start.bottom,
                greaterThanOrEqualTo(canvas.height),
                reason: reason('bottom'),
              );
            }
          }
        });
      });
    }

    test('04 travels no further than its art was cut for', () {
      for (final layer
          in _art
              .layeredScene(LayeredSceneId.nightVillage)
              .layers
              .whereType<SceneLayer>()) {
        final limit = _nightTravel[layer.file] ?? Offset.zero;
        expect(
          layer.from.dx.abs(),
          lessThanOrEqualTo(limit.dx),
          reason: layer.file,
        );
        expect(
          layer.from.dy.abs(),
          lessThanOrEqualTo(limit.dy),
          reason: layer.file,
        );
      }
    });

    test('the dawn\'s hills, roofs and gallows rise as one bank: no edge of '
        'one is shown free of what hides it', () {
      final layers = {
        for (final l
            in _art
                .layeredScene(LayeredSceneId.dawnGallows)
                .layers
                .whereType<SceneLayer>())
          l.file: l,
      };
      final bank = layers['hills_far']!.from;
      expect(layers['roofs_mid']!.from, bank);
      expect(layers['gallows']!.from, bank);
      // The paper under the seams is drawn 12 px deep: the near roofs may
      // lead or lag the rest by that much, for the parallax, and no more.
      expect(
        (layers['roofs_near']!.from - bank).distance,
        inInclusiveRange(1, 12),
      );
      expect(bank.dy, greaterThan(0), reason: 'they rise from below');
    });

    test('the sun is more than half in view from the first second to the '
        'last of the talk', () {
      final scene = _art.layeredScene(LayeredSceneId.dawnGallows);
      final arc = scene.layers.whereType<SceneSlot>().single.arc!;
      img.Image master(String name) => img.decodePng(
        File(
          '../docs/design/art/layers/dawn-gallows/$name.png',
        ).readAsBytesSync(),
      )!;
      final hills = master('hills_far');
      final gallows = master('gallows');
      // The roofs' masters carry 12 px of paper beyond the canvas.
      final mid = master('roofs_mid_bleed12');
      final near = master('roofs_near_bleed12');
      double covered(int x, int y) {
        double alpha(img.Image im, int dx, int dy) {
          final px = x + dx;
          final py = y + dy;
          if (px < 0 || py < 0 || px >= im.width || py >= im.height) return 0;
          return im.getPixel(px, py).a / 255;
        }

        return 1 -
            (1 - alpha(hills, 0, 0)) *
                (1 - alpha(gallows, 0, 0)) *
                (1 - alpha(mid, 12, 12)) *
                (1 - alpha(near, 12, 12));
      }

      final path = Path()
        ..moveTo(arc.start.dx, arc.start.dy)
        ..quadraticBezierTo(
          arc.control.dx,
          arc.control.dy,
          arc.end.dx,
          arc.end.dy,
        );
      final metric = path.computeMetrics().first;
      double inView(double elapsed) {
        final at = metric
            .getTangentForOffset(
              metric.length * (arc.rise + (arc.set - arc.rise) * elapsed),
            )!
            .position;
        var seen = 0.0;
        var total = 0;
        for (var dy = -50; dy <= 50; dy += 2) {
          for (var dx = -50; dx <= 50; dx += 2) {
            if (dx * dx + dy * dy > 2500) continue;
            total++;
            seen += 1 - covered((at.dx + dx).round(), (at.dy + dy).round());
          }
        }
        return seen / total;
      }

      expect(inView(0), greaterThan(0.95), reason: 'just clear of the ridge');
      for (final e in [0.25, 0.5, 0.75, 0.9, 0.99, 1.0]) {
        expect(inView(e), greaterThan(0.5), reason: 'at $e of the talk');
      }
    });

    test('the dawn has one sun slot with its path and sprite', () {
      final slots = _art
          .layeredScene(LayeredSceneId.dawnGallows)
          .layers
          .whereType<SceneSlot>()
          .toList();
      expect(slots.map((s) => s.name), ['sun']);
      final arc = slots.single.arc!;
      expect(slots.single.sprite, isNotNull);
      expect(arc.rise, inInclusiveRange(0, 1));
      expect(arc.set, inInclusiveRange(arc.rise, 1));
    });
  });

  group('at rest the layers make the flat picture they were cut from', () {
    Future<(FramePixels, img.Image)> drawn(
      WidgetTester tester,
      LayeredSceneId id,
    ) async {
      final canvas = _art.layeredScene(id).canvas;
      tester.view.physicalSize = canvas;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      WidgetsApp.debugAllowBannerOverride = false;
      addTearDown(() => WidgetsApp.debugAllowBannerOverride = true);
      await pumpSkinned(
        tester,
        SizedBox.fromSize(size: canvas, child: LayeredArt(id)),
      );
      await tester.runAsync(
        () => Future.wait([
          for (final element in find.byType(Image).evaluate())
            precacheImage((element.widget as Image).image, element),
        ]),
      );
      await tester.pump();
      final frame = await FramePixels.of(tester);
      final flat = img.decodeJpg(File(_flats[id]!).readAsBytesSync())!;
      return (frame, flat);
    }

    /// The two pictures in blocks of 4 x 4 pixels (the paper's grain, which
    /// two encodings of one picture do not share, averages out; a layer laid
    /// a pixel or two off does not): the mean difference of the blocks'
    /// colours, and the share of blocks more than 12 off in some colour.
    (double, double) compare(
      FramePixels frame,
      img.Image flat, {
      bool Function(int x, int y)? skip,
    }) {
      const block = 4;
      var sum = 0.0;
      var counted = 0;
      var far = 0;
      for (var by = 0; by + block <= flat.height; by += block) {
        for (var bx = 0; bx + block <= flat.width; bx += block) {
          if (skip != null && skip(bx + block ~/ 2, by + block ~/ 2)) continue;
          final drawn = [0.0, 0.0, 0.0];
          final cut = [0.0, 0.0, 0.0];
          for (var y = by; y < by + block; y++) {
            for (var x = bx; x < bx + block; x++) {
              final p = frame.at(x.toDouble(), y.toDouble());
              final q = flat.getPixel(x, y);
              drawn[0] += FramePixels.red(p);
              drawn[1] += FramePixels.green(p);
              drawn[2] += FramePixels.blue(p);
              cut[0] += q.r;
              cut[1] += q.g;
              cut[2] += q.b;
            }
          }
          final d = [
            for (var c = 0; c < 3; c++)
              (drawn[c] - cut[c]).abs() / (block * block),
          ];
          sum += d[0] + d[1] + d[2];
          counted++;
          if (d.any((v) => v > 12)) far++;
        }
      }
      return (sum / (counted * 3), far / counted);
    }

    testWidgets('04 the village at night', (tester) async {
      final (frame, flat) = await drawn(tester, LayeredSceneId.nightVillage);
      expect(frame.unpainted, 0);
      final (mean, far) = compare(frame, flat);
      expect(mean, lessThan(1.6));
      expect(far, lessThan(0.008));
    });

    testWidgets('08 the dawn, but for the sun baked into the picture', (
      tester,
    ) async {
      final (frame, flat) = await drawn(tester, LayeredSceneId.dawnGallows);
      expect(frame.unpainted, 0);
      // The flat picture has its sun in it (at 762, 354, 64 px across the
      // rim, plus its shadow); the layers carry none, the screen draws its own.
      final (mean, far) = compare(
        frame,
        flat,
        skip: (x, y) => (x - 762) * (x - 762) + (y - 354) * (y - 354) < 72 * 72,
      );
      expect(mean, lessThan(2.2));
      expect(far, lessThan(0.014));
    });
  });

  testWidgets('a scene brings the layers in from where they start, and they '
      'rest where the flat picture had them', (tester) async {
    const id = LayeredSceneId.nightVillage;
    final scene = _art.layeredScene(id);
    final arrival = AnimationController(vsync: tester);
    addTearDown(arrival.dispose);
    await pumpSkinned(
      tester,
      SizedBox(
        width: 384,
        height: 512,
        child: SceneArrival(progress: arrival, child: const LayeredArt(id)),
      ),
    );
    final moonFile = scene.files.firstWhere((l) => l.file == 'moon');
    Offset moon() {
      final image = find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is ResizeImage &&
            ((w.image as ResizeImage).imageProvider as AssetImage).assetName
                .endsWith('/${moonFile.file}.webp'),
      );
      return tester.getTopLeft(image);
    }

    final start = moon();
    arrival.value = 1;
    await tester.pump();
    final rest = moon();
    // 384 wide for a canvas 768 wide: half the scale; it starts as far from
    // its place as the scene says.
    expect(rest.dy - start.dy, closeTo(-moonFile.from.dy * 0.5, 0.01));
    expect(rest.dx, start.dx);
  });
}
