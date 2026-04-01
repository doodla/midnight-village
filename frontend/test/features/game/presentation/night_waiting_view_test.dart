import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/components/game/game_timer.dart';
import 'package:midnight_village/features/game/presentation/night_waiting_view.dart';

import '../../../design_system/test_helpers/pump_with_tokens.dart';

void main() {
  group('NightWaitingView', () {
    testWidgets('displays atmospheric waiting text', (tester) async {
      await tester.pumpWithTokens(const NightWaitingView(deadline: null));

      expect(find.text('The village sleeps\u2026'), findsOneWidget);
    });

    testWidgets('displays GameTimer when deadline is provided', (tester) async {
      // Use a past deadline so the timer stream completes immediately
      // without leaving pending timers.
      final deadline = DateTime.now().subtract(const Duration(seconds: 1));
      await tester.pumpWithTokens(NightWaitingView(deadline: deadline));
      await tester.pump();

      expect(find.byType(GameTimer), findsOneWidget);
    });

    testWidgets('does not display GameTimer when deadline is null', (
      tester,
    ) async {
      await tester.pumpWithTokens(const NightWaitingView(deadline: null));

      expect(find.byType(GameTimer), findsNothing);
    });

    testWidgets('displays night icon', (tester) async {
      await tester.pumpWithTokens(const NightWaitingView(deadline: null));

      expect(find.byIcon(Icons.nights_stay_outlined), findsOneWidget);
    });

    testWidgets('renders without error with null deadline', (tester) async {
      await tester.pumpWithTokens(const NightWaitingView(deadline: null));

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders without error with past deadline', (tester) async {
      // Past deadline resolves immediately with no pending timers.
      final deadline = DateTime.now().subtract(const Duration(seconds: 1));
      await tester.pumpWithTokens(NightWaitingView(deadline: deadline));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
