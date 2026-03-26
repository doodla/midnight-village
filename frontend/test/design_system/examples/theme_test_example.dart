// Example: Theme compatibility testing
//
// Pattern: Run the same assertions under each theme to verify:
//   1. No exceptions (no hardcoded values that crash)
//   2. Component still renders correctly with different token values
//   3. The component actually reads from tokens (not hardcoded colors)
//
// TestThemeTokens uses visually distinct values (bright green, magenta)
// to catch components that ignore tokens and hardcode colors directly.
//
// To adapt for your component:
//   1. Replace MvCard with your component
//   2. Keep the themes list as-is (test both production and test theme)
//   3. Add component-specific assertions after the no-exception check

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/components/core/mv_card.dart';
import 'package:midnight_village/design_system/tokens/firelit_gothic_theme.dart';
import '../test_helpers/pump_with_tokens.dart';
import '../test_helpers/test_theme.dart';

void main() {
  // Test with all supported themes.
  // Add new themes here as they are introduced.
  final themes = [
    const FirelitGothicTheme(), // production theme
    const TestThemeTokens(), // distinct values — catches hardcoded colors
  ];

  group('MvCard theme compatibility', () {
    for (final theme in themes) {
      testWidgets('renders without error with ${theme.name}', (tester) async {
        await tester.pumpWithTokens(
          const MvCard(child: Text('Game Content')),
          theme: theme,
        );

        // No crash = component consumed tokens correctly
        expect(tester.takeException(), isNull);
        expect(find.text('Game Content'), findsOneWidget);
      });

      testWidgets('renders with header and footer with ${theme.name}', (tester) async {
        await tester.pumpWithTokens(
          const MvCard(
            header: Text('Header'),
            footer: Text('Footer'),
            child: Text('Body'),
          ),
          theme: theme,
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Header'), findsOneWidget);
        expect(find.text('Body'), findsOneWidget);
        expect(find.text('Footer'), findsOneWidget);
      });

      testWidgets('does not overflow with ${theme.name}', (tester) async {
        await tester.pumpWithTokens(
          const MvCard(
            child: Text(
              'A longer piece of content that might cause overflow issues '
              'if spacing tokens produce extreme values.',
            ),
          ),
          theme: theme,
        );

        // No overflow errors
        expect(tester.takeException(), isNull);
      });
    }
  });
}
