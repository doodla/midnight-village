import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/game/presentation/reconnection_overlay.dart';

import '../../../design_system/test_helpers/pump_with_tokens.dart';

void main() {
  group('ReconnectionOverlay', () {
    testWidgets('renders spinner and text when isVisible is true', (
      tester,
    ) async {
      await tester.pumpWithTokens(
        const Stack(children: [ReconnectionOverlay(isVisible: true)]),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Reconnecting...'), findsOneWidget);
    });

    testWidgets('renders nothing when isVisible is false', (tester) async {
      await tester.pumpWithTokens(
        const Stack(children: [ReconnectionOverlay(isVisible: false)]),
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Reconnecting...'), findsNothing);
    });

    testWidgets('does not render overlay content when not visible', (
      tester,
    ) async {
      await tester.pumpWithTokens(
        const Stack(children: [ReconnectionOverlay(isVisible: false)]),
      );

      // The overlay widget itself should render only a SizedBox.shrink,
      // so there should be no Positioned child.
      final overlayFinder = find.byType(ReconnectionOverlay);
      expect(overlayFinder, findsOneWidget);

      // No Positioned.fill descendant within the overlay
      expect(
        find.descendant(of: overlayFinder, matching: find.byType(Positioned)),
        findsNothing,
      );
    });

    testWidgets('uses Positioned.fill to cover entire parent', (tester) async {
      await tester.pumpWithTokens(
        const Stack(children: [ReconnectionOverlay(isVisible: true)]),
      );

      // Find the Positioned that is a descendant of ReconnectionOverlay
      final overlayFinder = find.byType(ReconnectionOverlay);
      final positionedFinder = find.descendant(
        of: overlayFinder,
        matching: find.byType(Positioned),
      );
      expect(positionedFinder, findsOneWidget);

      final positioned = tester.widget<Positioned>(positionedFinder);
      expect(positioned.left, 0.0);
      expect(positioned.top, 0.0);
      expect(positioned.right, 0.0);
      expect(positioned.bottom, 0.0);
    });

    testWidgets('has a semi-transparent background', (tester) async {
      await tester.pumpWithTokens(
        const Stack(children: [ReconnectionOverlay(isVisible: true)]),
      );

      // Find the ColoredBox within the overlay
      final overlayFinder = find.byType(ReconnectionOverlay);
      final coloredBoxFinder = find.descendant(
        of: overlayFinder,
        matching: find.byType(ColoredBox),
      );
      expect(coloredBoxFinder, findsOneWidget);

      final coloredBox = tester.widget<ColoredBox>(coloredBoxFinder);
      // The alpha should be less than 1.0 (semi-transparent)
      expect(coloredBox.color.a, lessThan(1.0));
      // But not fully transparent
      expect(coloredBox.color.a, greaterThan(0.0));
    });

    testWidgets('transitions from visible to hidden', (tester) async {
      await tester.pumpWithTokens(
        const Stack(children: [ReconnectionOverlay(isVisible: true)]),
      );
      expect(find.text('Reconnecting...'), findsOneWidget);

      await tester.pumpWithTokens(
        const Stack(children: [ReconnectionOverlay(isVisible: false)]),
      );
      expect(find.text('Reconnecting...'), findsNothing);
    });

    testWidgets('transitions from hidden to visible', (tester) async {
      await tester.pumpWithTokens(
        const Stack(children: [ReconnectionOverlay(isVisible: false)]),
      );
      expect(find.text('Reconnecting...'), findsNothing);

      await tester.pumpWithTokens(
        const Stack(children: [ReconnectionOverlay(isVisible: true)]),
      );
      expect(find.text('Reconnecting...'), findsOneWidget);
    });
  });
}
