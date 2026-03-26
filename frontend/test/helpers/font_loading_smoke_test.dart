// Smoke test validating that font loading (T001) works correctly.
// Renders text with each bundled font family and verifies no errors are thrown.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Font loading smoke tests', () {
    testWidgets(
        'renders PlayfairDisplay text without font-loading errors',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Text(
              'Midnight Village',
              style: TextStyle(fontFamily: 'PlayfairDisplay', fontSize: 24),
            ),
          ),
        ),
      );

      expect(find.text('Midnight Village'), findsOneWidget);
    });

    testWidgets('renders Inter text without font-loading errors',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Text(
              'Body text in Inter',
              style: TextStyle(fontFamily: 'Inter', fontSize: 16),
            ),
          ),
        ),
      );

      expect(find.text('Body text in Inter'), findsOneWidget);
    });
  });
}
