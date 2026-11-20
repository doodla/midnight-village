// The golden comparator works end-to-end: a fixed-colour box in the app's
// theme at a phone's size matches its baseline.
//
// Run with: just flutter-test-golden
// Generate baselines: just flutter-golden-update
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/skin/skin_theme.dart';
import 'package:midnight_village/design_system/skin/skins/shadow_paper.dart';

void main() {
  testWidgets('a fixed-colour box renders deterministically', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: skinTheme(shadowPaper),
        home: const ColoredBox(
          color: Color(0xFF1A2B3C),
          child: SizedBox(width: 100, height: 100),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/smoke_colored_container.png'),
    );
  });
}
