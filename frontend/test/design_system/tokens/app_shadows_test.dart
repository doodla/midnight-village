import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/tokens/app_shadows.dart';

void main() {
  group('AppShadows', () {
    group('fireGlow', () {
      test('has one BoxShadow', () {
        expect(AppShadows.fireGlow.length, 1);
      });

      test('color is emberRed at ~15% opacity (0x26B8432F)', () {
        expect(AppShadows.fireGlow.first.color, const Color(0x26B8432F));
      });

      test('blurRadius is 20', () {
        expect(AppShadows.fireGlow.first.blurRadius, 20);
      });

      test('spreadRadius is 2', () {
        expect(AppShadows.fireGlow.first.spreadRadius, 2);
      });
    });

    group('selectionGlow', () {
      test('has one BoxShadow', () {
        expect(AppShadows.selectionGlow.length, 1);
      });

      test('color is tallowGold at ~25% opacity (0x40C8A24D)', () {
        expect(AppShadows.selectionGlow.first.color, const Color(0x40C8A24D));
      });

      test('blurRadius is 12', () {
        expect(AppShadows.selectionGlow.first.blurRadius, 12);
      });

      test('spreadRadius is 1', () {
        expect(AppShadows.selectionGlow.first.spreadRadius, 1);
      });
    });

    group('dangerGlow', () {
      test('has one BoxShadow', () {
        expect(AppShadows.dangerGlow.length, 1);
      });

      test('color is teamWerewolf at ~25% opacity (0x40C94038)', () {
        expect(AppShadows.dangerGlow.first.color, const Color(0x40C94038));
      });

      test('blurRadius is 12', () {
        expect(AppShadows.dangerGlow.first.blurRadius, 12);
      });

      test('spreadRadius is 1', () {
        expect(AppShadows.dangerGlow.first.spreadRadius, 1);
      });
    });
  });
}
