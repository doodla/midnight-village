import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/components/game/game_timer.dart';

import '../../../design_system/test_helpers/pump_with_tokens.dart';
import '../../../design_system/test_helpers/test_theme.dart';

void main() {
  const testTheme = TestThemeTokens();

  // -------------------------------------------------------------------------
  // MM:SS formatting
  // -------------------------------------------------------------------------

  testWidgets('renders "01:05" for Duration(minutes: 1, seconds: 5)',
      (tester) async {
    await tester.pumpWithTokens(
      GameTimer(timeRemaining: const Duration(minutes: 1, seconds: 5)),
      theme: testTheme,
    );

    expect(find.text('01:05'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // Bare seconds formatting (sub-60 s)
  // -------------------------------------------------------------------------

  testWidgets('renders "45" for Duration(seconds: 45)', (tester) async {
    await tester.pumpWithTokens(
      GameTimer(timeRemaining: const Duration(seconds: 45)),
      theme: testTheme,
    );

    expect(find.text('45'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // Urgency color at/below 10 seconds
  // -------------------------------------------------------------------------

  testWidgets('uses urgency color at exactly 10 seconds', (tester) async {
    await tester.pumpWithTokens(
      GameTimer(timeRemaining: const Duration(seconds: 10)),
      theme: testTheme,
    );

    // TestColorTokens.timerUrgent = Color(0xFFFF8800)
    const urgentColor = Color(0xFFFF8800);

    final richText = tester.widget<RichText>(
      find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText() == '10',
      ),
    );

    final style = richText.text.style;
    expect(
      style?.color,
      urgentColor,
      reason: 'Timer should use urgency color at 10 seconds',
    );
  });

  testWidgets('uses urgency color below 10 seconds (5 s)', (tester) async {
    await tester.pumpWithTokens(
      GameTimer(timeRemaining: const Duration(seconds: 5)),
      theme: testTheme,
    );

    const urgentColor = Color(0xFFFF8800);

    final richText = tester.widget<RichText>(
      find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText() == '5',
      ),
    );

    final style = richText.text.style;
    expect(
      style?.color,
      urgentColor,
      reason: 'Timer should use urgency color below 10 seconds',
    );
  });

  // -------------------------------------------------------------------------
  // Negative durations clamp to "0"
  // -------------------------------------------------------------------------

  testWidgets('does not display negative values — shows "0" for -5s',
      (tester) async {
    await tester.pumpWithTokens(
      GameTimer(timeRemaining: const Duration(seconds: -5)),
      theme: testTheme,
    );

    expect(find.text('0'), findsOneWidget);
    expect(find.text('-5'), findsNothing);
  });
}
