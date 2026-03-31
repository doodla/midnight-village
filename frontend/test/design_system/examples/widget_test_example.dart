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
import 'package:midnight_village/design_system/components/core/primary_button.dart';
import '../test_helpers/pump_with_tokens.dart';

void main() {
  group('PrimaryButton', () {
    // Default state: renders label
    testWidgets('renders label text', (tester) async {
      await tester.pumpWithTokens(
        PrimaryButton(label: 'Join Game', onPressed: () {}),
      );

      expect(find.text('Join Game'), findsOneWidget);
    });

    // Default variant: backed by FilledButton
    testWidgets('default variant uses FilledButton', (tester) async {
      await tester.pumpWithTokens(
        PrimaryButton(label: 'Test', onPressed: () {}),
      );

      expect(find.byType(FilledButton), findsOneWidget);
    });

    // Outlined variant: backed by OutlinedButton
    testWidgets('outlined variant uses OutlinedButton', (tester) async {
      await tester.pumpWithTokens(
        PrimaryButton.outlined(label: 'Cancel', onPressed: () {}),
      );

      expect(find.byType(OutlinedButton), findsOneWidget);
    });

    // Disabled state: onPressed is null
    testWidgets('is disabled when onPressed is null', (tester) async {
      await tester.pumpWithTokens(
        const PrimaryButton(label: 'Disabled', onPressed: null),
      );

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    // Loading state: shows spinner instead of label
    testWidgets('shows spinner when isLoading is true', (tester) async {
      await tester.pumpWithTokens(
        PrimaryButton(label: 'Loading', onPressed: () {}, isLoading: true),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading'), findsNothing);
    });

    // Interaction: tap triggers callback
    testWidgets('calls onPressed when tapped', (tester) async {
      var tapped = false;

      await tester.pumpWithTokens(
        PrimaryButton(label: 'Tap Me', onPressed: () => tapped = true),
      );

      await tester.tap(find.byType(FilledButton));
      expect(tapped, isTrue);
    });
  });
}
