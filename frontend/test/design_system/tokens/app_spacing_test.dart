import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/tokens/app_spacing.dart';

void main() {
  group('AppSpacing', () {
    test('xs is 4.0', () {
      expect(AppSpacing.xs, 4.0);
    });

    test('sm is 8.0', () {
      expect(AppSpacing.sm, 8.0);
    });

    test('md is 12.0', () {
      expect(AppSpacing.md, 12.0);
    });

    test('lg is 16.0', () {
      expect(AppSpacing.lg, 16.0);
    });

    test('xl is 24.0', () {
      expect(AppSpacing.xl, 24.0);
    });

    test('xxl is 32.0', () {
      expect(AppSpacing.xxl, 32.0);
    });

    test('xxxl is 48.0', () {
      expect(AppSpacing.xxxl, 48.0);
    });
  });
}
