import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/components/core/primary_button.dart';

import '../../test_helpers/pump_with_tokens.dart';
import '../../test_helpers/test_theme.dart';

void main() {
  group('PrimaryButton', () {
    testWidgets('default renders FilledButton with label', (tester) async {
      await tester.pumpWithTokens(
        PrimaryButton(label: 'Enter the Village', onPressed: () {}),
      );

      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.text('Enter the Village'), findsOneWidget);
    });

    testWidgets('disabled when onPressed is null', (tester) async {
      await tester.pumpWithTokens(
        const PrimaryButton(label: 'Start', onPressed: null),
      );

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('loading shows CircularProgressIndicator and hides label', (
      tester,
    ) async {
      await tester.pumpWithTokens(
        PrimaryButton(label: 'Joining...', onPressed: () {}, isLoading: true),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Joining...'), findsNothing);
    });

    testWidgets('loading disables button interaction', (tester) async {
      await tester.pumpWithTokens(
        PrimaryButton(label: 'Wait', onPressed: () {}, isLoading: true),
      );

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('outlined renders OutlinedButton with label', (tester) async {
      await tester.pumpWithTokens(
        PrimaryButton.outlined(label: 'Leave', onPressed: () {}),
      );

      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.text('Leave'), findsOneWidget);
    });

    testWidgets('destructive renders FilledButton with label', (tester) async {
      await tester.pumpWithTokens(
        PrimaryButton(label: 'Delete', onPressed: () {}, isDestructive: true),
      );

      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('onPressed callback fires on tap', (tester) async {
      var tapped = false;

      await tester.pumpWithTokens(
        PrimaryButton(label: 'Tap Me', onPressed: () => tapped = true),
      );

      await tester.tap(find.byType(FilledButton));
      expect(tapped, isTrue);
    });

    testWidgets('consumes tokens from activeThemeProvider', (tester) async {
      const testTokens = TestThemeTokens();
      await tester.pumpWithTokens(
        PrimaryButton(label: 'Token Test', onPressed: () {}),
        theme: testTokens,
      );

      expect(find.byType(FilledButton), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      final bgColor = button.style?.backgroundColor?.resolve({});
      expect(bgColor, equals(testTokens.colors.primary));
    });

    testWidgets('destructive uses error color from tokens', (tester) async {
      const testTokens = TestThemeTokens();
      await tester.pumpWithTokens(
        PrimaryButton(label: 'Destroy', onPressed: () {}, isDestructive: true),
        theme: testTokens,
      );

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      final bgColor = button.style?.backgroundColor?.resolve({});
      expect(bgColor, equals(testTokens.colors.error));
    });
  });
}
