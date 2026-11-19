// OLD LOOK: delete when 02 Table and the game screens (04 to 11) are rebuilt
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/components/foundation/player_avatar.dart';
import 'package:midnight_village/design_system/models/avatar_size.dart';

import '../../test_helpers/pump_with_tokens.dart';
import '../../test_helpers/test_theme.dart';

void main() {
  const testTheme = TestThemeTokens();

  group('PlayerAvatar', () {
    testWidgets('extracts single initial from single name', (tester) async {
      await tester.pumpWithTokens(
        const PlayerAvatar(displayName: 'Alice', size: AvatarSize.medium),
        theme: testTheme,
      );
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('extracts two initials from multi-word name', (tester) async {
      await tester.pumpWithTokens(
        const PlayerAvatar(displayName: 'Bob Smith', size: AvatarSize.medium),
        theme: testTheme,
      );
      expect(find.text('BS'), findsOneWidget);
    });

    testWidgets('shows ? for empty name', (tester) async {
      await tester.pumpWithTokens(
        const PlayerAvatar(displayName: '', size: AvatarSize.medium),
        theme: testTheme,
      );
      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('shows ? for whitespace-only name', (tester) async {
      await tester.pumpWithTokens(
        const PlayerAvatar(displayName: '   ', size: AvatarSize.medium),
        theme: testTheme,
      );
      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('deterministic hue - same name same color', (tester) async {
      await tester.pumpWithTokens(
        const PlayerAvatar(displayName: 'Alice', size: AvatarSize.medium),
        theme: testTheme,
      );

      final containers1 = tester
          .widgetList<Container>(find.byType(Container))
          .toList();
      final circle1 = containers1.firstWhere(
        (c) =>
            c.decoration is BoxDecoration &&
            (c.decoration! as BoxDecoration).shape == BoxShape.circle,
      );
      final color1 = (circle1.decoration! as BoxDecoration).color;

      await tester.pumpWithTokens(
        const PlayerAvatar(displayName: 'Alice', size: AvatarSize.medium),
        theme: testTheme,
      );

      final containers2 = tester
          .widgetList<Container>(find.byType(Container))
          .toList();
      final circle2 = containers2.firstWhere(
        (c) =>
            c.decoration is BoxDecoration &&
            (c.decoration! as BoxDecoration).shape == BoxShape.circle,
      );
      final color2 = (circle2.decoration! as BoxDecoration).color;

      expect(color1, isNotNull);
      expect(color1, equals(color2));
    });

    testWidgets('renders small size at 32dp', (tester) async {
      await tester.pumpWithTokens(
        const PlayerAvatar(displayName: 'Alice', size: AvatarSize.small),
        theme: testTheme,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == 32.0 && w.height == 32.0,
        ),
        findsWidgets,
      );
    });

    testWidgets('renders medium size at 48dp', (tester) async {
      await tester.pumpWithTokens(
        const PlayerAvatar(displayName: 'Alice', size: AvatarSize.medium),
        theme: testTheme,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == 48.0 && w.height == 48.0,
        ),
        findsWidgets,
      );
    });

    testWidgets('renders large size at 64dp', (tester) async {
      await tester.pumpWithTokens(
        const PlayerAvatar(displayName: 'Alice', size: AvatarSize.large),
        theme: testTheme,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == 64.0 && w.height == 64.0,
        ),
        findsWidgets,
      );
    });

    testWidgets('sigil overlay appears when provided', (tester) async {
      await tester.pumpWithTokens(
        const PlayerAvatar(
          displayName: 'Carol',
          size: AvatarSize.medium,
          sigil: Icons.check,
        ),
        theme: testTheme,
      );
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('no sigil when not provided', (tester) async {
      await tester.pumpWithTokens(
        const PlayerAvatar(displayName: 'Dave', size: AvatarSize.medium),
        theme: testTheme,
      );
      // No extra icons should appear
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('consumes tokens from activeThemeProvider', (tester) async {
      await tester.pumpWithTokens(
        const PlayerAvatar(displayName: 'Alice', size: AvatarSize.medium),
        theme: testTheme,
      );
      // TestThemeTokens.onSurface = Color(0xFFFFFFFF) — initials should use it
      final text = tester.widget<Text>(find.text('A'));
      expect(text.style?.color, const Color(0xFFFFFFFF));
    });
  });
}
