import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/tokens/app_decorations.dart';

void main() {
  group('AppDecorations', () {
    group('visionGlow', () {
      test('is a RadialGradient', () {
        expect(AppDecorations.visionGlow, isA<RadialGradient>());
      });

      test('has 2 colors', () {
        expect(AppDecorations.visionGlow.colors.length, 2);
      });

      test('second color is transparent', () {
        expect(AppDecorations.visionGlow.colors.last, Colors.transparent);
      });
    });

    group('bloodVignette', () {
      test('is a RadialGradient', () {
        expect(AppDecorations.bloodVignette, isA<RadialGradient>());
      });

      test('has 2 colors', () {
        expect(AppDecorations.bloodVignette.colors.length, 2);
      });

      test('first color is transparent', () {
        expect(AppDecorations.bloodVignette.colors.first, Colors.transparent);
      });
    });

    group('candleGlow', () {
      test('is a RadialGradient', () {
        expect(AppDecorations.candleGlow, isA<RadialGradient>());
      });

      test('has 2 colors', () {
        expect(AppDecorations.candleGlow.colors.length, 2);
      });

      test('first color is transparent', () {
        expect(AppDecorations.candleGlow.colors.first, Colors.transparent);
      });

      test('second color is voidBlack (#0D0B0F)', () {
        expect(AppDecorations.candleGlow.colors.last, const Color(0xFF0D0B0F));
      });

      test('center is Alignment.center', () {
        expect(AppDecorations.candleGlow.center, Alignment.center);
      });
    });

    group('noiseOverlayAsset', () {
      test('points to noise grain texture', () {
        expect(
          AppDecorations.noiseOverlayAsset,
          'assets/textures/noise_grain.png',
        );
      });
    });
  });
}
