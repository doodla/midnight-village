import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/components/foundation/village_app_bar.dart';
import 'package:midnight_village/design_system/tokens/app_tokens_provider.dart';
import 'package:midnight_village/design_system/tokens/theme_bridge.dart';

import '../../test_helpers/pump_with_tokens.dart';
import '../../test_helpers/test_theme.dart';

void main() {
  const testTheme = TestThemeTokens();

  group('VillageAppBar', () {
    group('brand variant', () {
      testWidgets('shows castle icon and Midnight Village title',
          (tester) async {
        await tester.pumpWithTokens(
          Scaffold(appBar: VillageAppBar.brand()),
          theme: testTheme,
        );
        expect(find.text('Midnight Village'), findsOneWidget);
        expect(find.byIcon(Icons.castle), findsOneWidget);
      });

      testWidgets('renders trailing widget when provided', (tester) async {
        await tester.pumpWithTokens(
          Scaffold(
            appBar: VillageAppBar.brand(
              trailing: const Icon(Icons.settings),
            ),
          ),
          theme: testTheme,
        );
        expect(find.byIcon(Icons.settings), findsOneWidget);
      });
    });

    group('back variant', () {
      testWidgets('shows back arrow and custom title', (tester) async {
        await tester.pumpWithTokens(
          Scaffold(appBar: VillageAppBar.back(title: 'Lobby')),
          theme: testTheme,
        );
        expect(find.text('Lobby'), findsOneWidget);
        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      });

      testWidgets('back arrow pops navigator', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [activeThemeProvider.overrideWithValue(testTheme)],
            child: MaterialApp(
              theme: generateThemeData(testTheme),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => Scaffold(
                          appBar: VillageAppBar.back(title: 'Detail'),
                          body: const Text('Detail Body'),
                        ),
                      ),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );

        // Navigate to the detail page
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.text('Detail Body'), findsOneWidget);

        // Tap back arrow
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        expect(find.text('Open'), findsOneWidget);
        expect(find.text('Detail Body'), findsNothing);
      });
    });

    group('phase variant', () {
      testWidgets('shows phase label', (tester) async {
        await tester.pumpWithTokens(
          Scaffold(appBar: VillageAppBar.phase(label: 'DISCUSSION')),
          theme: testTheme,
        );
        expect(find.text('DISCUSSION'), findsOneWidget);
      });

      testWidgets('renders timer in trailing slot', (tester) async {
        await tester.pumpWithTokens(
          Scaffold(
            appBar: VillageAppBar.phase(
              label: 'VOTING',
              trailing: const Text('2:30'),
            ),
          ),
          theme: testTheme,
        );
        expect(find.text('2:30'), findsOneWidget);
      });

      testWidgets('has no leading widget', (tester) async {
        await tester.pumpWithTokens(
          Scaffold(appBar: VillageAppBar.phase(label: 'NIGHT')),
          theme: testTheme,
        );
        // No back arrow or castle icon
        expect(find.byIcon(Icons.arrow_back), findsNothing);
        expect(find.byIcon(Icons.castle), findsNothing);
      });
    });

    group('minimal variant', () {
      testWidgets('shows role name', (tester) async {
        await tester.pumpWithTokens(
          Scaffold(appBar: VillageAppBar.minimal(roleName: 'SEER')),
          theme: testTheme,
        );
        expect(find.text('SEER'), findsOneWidget);
      });

      testWidgets('shows icon when provided', (tester) async {
        await tester.pumpWithTokens(
          Scaffold(
            appBar: VillageAppBar.minimal(
              roleName: 'WEREWOLF',
              icon: Icons.visibility,
            ),
          ),
          theme: testTheme,
        );
        expect(find.text('WEREWOLF'), findsOneWidget);
        expect(find.byIcon(Icons.visibility), findsOneWidget);
      });
    });

    testWidgets('does not overflow at 320dp width', (tester) async {
      await tester.pumpWithTokens(
        SizedBox(
          width: 320,
          child: Scaffold(appBar: VillageAppBar.brand()),
        ),
        theme: testTheme,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
