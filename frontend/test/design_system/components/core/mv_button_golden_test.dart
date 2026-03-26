// Golden Test Cycle Validation:
// 1. Generate: just flutter-golden-update
// 2. Verify: just flutter-test-golden (should pass)
// 3. Break: modify widget appearance (e.g., change a color in MvButton)
// 4. Detect: just flutter-test-golden (should fail)
// 5. Update: just flutter-golden-update (new baselines)
// 6. Recover: just flutter-test-golden (should pass)
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/components/core/mv_button.dart';

import '../../../helpers/golden_test_helper.dart';

void main() {
  group('MvButton golden tests', () {
    testWidgets('primary variant renders correctly', (tester) async {
      await tester.pumpWithGolden(
        Scaffold(
          body: Center(
            child: MvButton(
              label: 'Primary',
              onPressed: () {},
              variant: MvButtonVariant.primary,
            ),
          ),
        ),
        'goldens/mv_button_primary.png',
      );
    });

    testWidgets('secondary variant renders correctly', (tester) async {
      await tester.pumpWithGolden(
        Scaffold(
          body: Center(
            child: MvButton(
              label: 'Secondary',
              onPressed: () {},
              variant: MvButtonVariant.secondary,
            ),
          ),
        ),
        'goldens/mv_button_secondary.png',
      );
    });

    testWidgets('disabled variant renders correctly', (tester) async {
      await tester.pumpWithGolden(
        const Scaffold(
          body: Center(
            child: MvButton(
              label: 'Disabled',
              onPressed: null,
              variant: MvButtonVariant.primary,
            ),
          ),
        ),
        'goldens/mv_button_disabled.png',
      );
    });
  });
}
