// Smoke test validating that Google Fonts render without errors in tests.
// Google Fonts HTTP fetching is disabled in flutter_test_config.dart and these
// families are not bundled, so they are drawn in Figtree stand-ins
// (test_fonts.dart) — this test verifies no exceptions are thrown.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  group('Font rendering smoke tests', () {
    testWidgets('renders Epilogue text without font-loading errors', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Text(
              'Midnight Village',
              style: GoogleFonts.epilogue(fontSize: 24),
            ),
          ),
        ),
      );

      expect(find.text('Midnight Village'), findsOneWidget);
    });

    testWidgets('renders DM Sans text without font-loading errors', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Text(
              'Body text in DM Sans',
              style: GoogleFonts.dmSans(fontSize: 16),
            ),
          ),
        ),
      );

      expect(find.text('Body text in DM Sans'), findsOneWidget);
    });

    testWidgets('renders Space Grotesk text without font-loading errors', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Text(
              'Timer: 00:30',
              style: GoogleFonts.spaceGrotesk(fontSize: 48),
            ),
          ),
        ),
      );

      expect(find.text('Timer: 00:30'), findsOneWidget);
    });
  });
}
