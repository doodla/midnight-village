import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/tokens/app_radius.dart';

void main() {
  group('AppRadius', () {
    test('small is circular 4', () {
      expect(AppRadius.small, const BorderRadius.all(Radius.circular(4)));
    });

    test('medium is circular 8', () {
      expect(AppRadius.medium, const BorderRadius.all(Radius.circular(8)));
    });

    test('large is circular 12', () {
      expect(AppRadius.large, const BorderRadius.all(Radius.circular(12)));
    });

    test('xl is circular 16', () {
      expect(AppRadius.xl, const BorderRadius.all(Radius.circular(16)));
    });

    test('full is circular 999', () {
      expect(AppRadius.full, const BorderRadius.all(Radius.circular(999)));
    });
  });
}
