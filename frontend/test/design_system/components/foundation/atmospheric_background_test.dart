import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/components/foundation/atmospheric_background.dart';
import 'package:midnight_village/design_system/models/game_phase.dart';
import 'package:midnight_village/design_system/tokens/app_decorations.dart';
import 'package:midnight_village/design_system/tokens/app_shadows.dart';

import '../../../design_system/test_helpers/pump_with_tokens.dart';
import '../../../design_system/test_helpers/test_theme.dart';

void main() {
  const testTheme = TestThemeTokens();

  group('AtmosphericBackground – phase backgrounds', () {
    Future<void> pumpPhase(WidgetTester tester, GamePhase phase) async {
      await tester.pumpWithTokens(
        AtmosphericBackground(
          phase: phase,
          showNoiseOverlay: false,
          showGlow: false,
          child: const SizedBox(),
        ),
        theme: testTheme,
      );
    }

    testWidgets('renders night phase background color', (tester) async {
      await pumpPhase(tester, GamePhase.night);

      // TestColorTokens.nightBg = Color(0xFF000011)
      expect(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == const Color(0xFF000011),
        ),
        findsOneWidget,
        reason: 'Should render nightBg color from tokens',
      );
    });

    testWidgets('renders lobby phase background color', (tester) async {
      await pumpPhase(tester, GamePhase.lobby);

      // TestColorTokens.lobbyBg = Color(0xFF000022)
      expect(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == const Color(0xFF000022),
        ),
        findsOneWidget,
        reason: 'Should render lobbyBg color from tokens',
      );
    });

    testWidgets('renders discussion phase background color', (tester) async {
      await pumpPhase(tester, GamePhase.discussion);

      // TestColorTokens.discussionBg = Color(0xFF000033)
      expect(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == const Color(0xFF000033),
        ),
        findsOneWidget,
        reason: 'Should render discussionBg color from tokens',
      );
    });

    testWidgets('renders voting phase background color', (tester) async {
      await pumpPhase(tester, GamePhase.voting);

      // TestColorTokens.votingBg = Color(0xFF000044)
      expect(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == const Color(0xFF000044),
        ),
        findsOneWidget,
        reason: 'Should render votingBg color from tokens',
      );
    });

    testWidgets('renders results phase background color', (tester) async {
      await pumpPhase(tester, GamePhase.results);

      // TestColorTokens.resultsBg = Color(0xFF000055)
      expect(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == const Color(0xFF000055),
        ),
        findsOneWidget,
        reason: 'Should render resultsBg color from tokens',
      );
    });
  });

  group('AtmosphericBackground – overlay effects', () {
    testWidgets('shows noise overlay when enabled', (tester) async {
      await tester.pumpWithTokens(
        AtmosphericBackground(
          phase: GamePhase.night,
          showNoiseOverlay: true,
          showGlow: false,
          child: const SizedBox(),
        ),
        theme: testTheme,
      );

      // Noise overlay is wrapped in Opacity
      expect(
        find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0.03),
        findsOneWidget,
        reason: 'Noise overlay should be present with 3% opacity',
      );
    });

    testWidgets('hides noise overlay when disabled', (tester) async {
      await tester.pumpWithTokens(
        AtmosphericBackground(
          phase: GamePhase.night,
          showNoiseOverlay: false,
          showGlow: false,
          child: const SizedBox(),
        ),
        theme: testTheme,
      );

      expect(
        find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0.03),
        findsNothing,
        reason: 'Noise overlay should be absent when disabled',
      );
    });

    testWidgets('shows glow effect when enabled', (tester) async {
      await tester.pumpWithTokens(
        AtmosphericBackground(
          phase: GamePhase.night,
          showNoiseOverlay: false,
          showGlow: true,
          child: const SizedBox(),
        ),
        theme: testTheme,
      );

      // Glow uses DecoratedBox with a gradient
      expect(find.byType(DecoratedBox), findsWidgets);
    });

    testWidgets('hides glow effect when disabled', (tester) async {
      await tester.pumpWithTokens(
        AtmosphericBackground(
          phase: GamePhase.night,
          showNoiseOverlay: false,
          showGlow: false,
          child: const SizedBox(),
        ),
        theme: testTheme,
      );

      expect(find.byType(DecoratedBox), findsNothing);
    });
  });

  group('AtmosphericBackground – child rendering', () {
    testWidgets('renders child widget on top', (tester) async {
      await tester.pumpWithTokens(
        AtmosphericBackground(
          phase: GamePhase.lobby,
          showNoiseOverlay: false,
          showGlow: false,
          child: const Text('Hello Village'),
        ),
        theme: testTheme,
      );

      expect(find.text('Hello Village'), findsOneWidget);
    });

    testWidgets('wraps child in RepaintBoundary', (tester) async {
      await tester.pumpWithTokens(
        AtmosphericBackground(
          phase: GamePhase.lobby,
          showNoiseOverlay: false,
          showGlow: false,
          child: const Text('child'),
        ),
        theme: testTheme,
      );

      expect(find.byType(RepaintBoundary), findsWidgets);
    });

    testWidgets('consumes tokens from activeThemeProvider', (tester) async {
      await tester.pumpWithTokens(
        AtmosphericBackground(
          phase: GamePhase.voting,
          showNoiseOverlay: false,
          showGlow: false,
          child: const SizedBox(),
        ),
        theme: testTheme,
      );

      // TestColorTokens.votingBg = Color(0xFF000044) — distinct from real theme
      expect(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == const Color(0xFF000044),
        ),
        findsOneWidget,
        reason: 'Should consume votingBg from the injected test theme',
      );
    });
  });

  group('Decorative Effects', () {
    testWidgets('AppShadows.fireGlow renders on container', (tester) async {
      await tester.pumpWithTokens(
        Container(
          decoration: const BoxDecoration(boxShadow: AppShadows.fireGlow),
          child: const SizedBox(width: 100, height: 100),
        ),
        theme: testTheme,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('AppShadows.selectionGlow renders on container', (
      tester,
    ) async {
      await tester.pumpWithTokens(
        Container(
          decoration: const BoxDecoration(boxShadow: AppShadows.selectionGlow),
          child: const SizedBox(width: 100, height: 100),
        ),
        theme: testTheme,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('AppShadows.dangerGlow renders on container', (tester) async {
      await tester.pumpWithTokens(
        Container(
          decoration: const BoxDecoration(boxShadow: AppShadows.dangerGlow),
          child: const SizedBox(width: 100, height: 100),
        ),
        theme: testTheme,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('AppDecorations.visionGlow renders on container', (
      tester,
    ) async {
      await tester.pumpWithTokens(
        Container(
          foregroundDecoration: BoxDecoration(
            gradient: AppDecorations.visionGlow,
          ),
          child: const SizedBox(width: 100, height: 100),
        ),
        theme: testTheme,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('AppDecorations.bloodVignette renders on container', (
      tester,
    ) async {
      await tester.pumpWithTokens(
        Container(
          foregroundDecoration: BoxDecoration(
            gradient: AppDecorations.bloodVignette,
          ),
          child: const SizedBox(width: 100, height: 100),
        ),
        theme: testTheme,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('AppDecorations.candleGlow renders on container', (
      tester,
    ) async {
      await tester.pumpWithTokens(
        Container(
          foregroundDecoration: BoxDecoration(
            gradient: AppDecorations.candleGlow,
          ),
          child: const SizedBox(width: 100, height: 100),
        ),
        theme: testTheme,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
