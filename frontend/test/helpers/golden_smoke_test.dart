// Smoke test validating that pumpWithGolden and the golden comparator
// (T002, T003) work end-to-end.
//
// Run with: just flutter-test-golden
// Generate baselines: just flutter-golden-update
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_test_helper.dart';

void main() {
  group('Golden infrastructure smoke tests', () {
    testWidgets(
      'pumpWithGolden renders a fixed-color container deterministically',
      (tester) async {
        await tester.pumpWithGolden(
          ColoredBox(
            color: const Color(0xFF1A2B3C),
            child: const SizedBox(width: 100, height: 100),
          ),
          'goldens/smoke_colored_container.png',
        );
      },
    );
  });
}
