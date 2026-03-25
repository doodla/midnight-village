// Example: Widget testing a design system component
//
// Pattern: Use pumpWithTokens from test_helpers — it sets up ProviderScope
// with the design token provider and wraps in MaterialApp.
//
// To adapt for your component:
//   1. Replace the import with your component
//   2. Replace widget construction with your component's constructor
//   3. Find by type, text, or semantic label as appropriate
//   4. Test each meaningful state (default, disabled, loading, etc.)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/components/core/mv_button.dart';
import '../test_helpers/pump_with_tokens.dart';

void main() {
  group('MvButton', () {
    // Default state: renders label
    testWidgets('renders label text', (tester) async {
      await tester.pumpWithTokens(
        MvButton(label: 'Join Game', onPressed: () {}),
      );

      expect(find.text('Join Game'), findsOneWidget);
    });

    // Primary variant: backed by ElevatedButton
    testWidgets('primary variant uses ElevatedButton', (tester) async {
      await tester.pumpWithTokens(
        MvButton(label: 'Test', onPressed: () {}),
      );

      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    // Secondary variant: backed by OutlinedButton
    testWidgets('secondary variant uses OutlinedButton', (tester) async {
      await tester.pumpWithTokens(
        MvButton(
          label: 'Cancel',
          onPressed: () {},
          variant: MvButtonVariant.secondary,
        ),
      );

      expect(find.byType(OutlinedButton), findsOneWidget);
    });

    // Disabled state: onPressed is null
    testWidgets('is disabled when onPressed is null', (tester) async {
      await tester.pumpWithTokens(
        const MvButton(label: 'Disabled', onPressed: null),
      );

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });

    // Loading state: shows spinner instead of label
    testWidgets('shows spinner when isLoading is true', (tester) async {
      await tester.pumpWithTokens(
        MvButton(label: 'Loading', onPressed: () {}, isLoading: true),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading'), findsNothing);
    });

    // Interaction: tap triggers callback
    testWidgets('calls onPressed when tapped', (tester) async {
      var tapped = false;

      await tester.pumpWithTokens(
        MvButton(label: 'Tap Me', onPressed: () => tapped = true),
      );

      await tester.tap(find.byType(ElevatedButton));
      expect(tapped, isTrue);
    });
  });
}
