// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/auth/domain/auth_state.dart';
import 'package:midnight_village/features/auth/presentation/auth_notifier.dart';

import '../test_harness.dart';

/// Examples: pumpAuthenticated harness
///
/// These tests demonstrate the [pumpAuthenticated] pattern. Copy them as a
/// starting point for any test that needs a logged-in user. The harness
/// injects [AuthState.authenticated] directly — no token storage, no network,
/// no notifier lifecycle to manage.
void main() {
  group('pumpAuthenticated harness', () {
    testWidgets('provides authenticated user state to the widget tree', (
      tester,
    ) async {
      // 3-line setup — the harness handles all auth plumbing.
      await tester.pumpAuthenticated(
        const _UserNameWidget(),
        playerName: 'TestHero',
      );

      expect(find.text('TestHero'), findsOneWidget);
    });

    testWidgets('defaults to "TestPlayer" when no playerName is supplied', (
      tester,
    ) async {
      await tester.pumpAuthenticated(const _UserNameWidget());

      expect(find.text('TestPlayer'), findsOneWidget);
    });

    testWidgets('accepts extra overrides for test-specific customisation', (
      tester,
    ) async {
      // Stack additional provider overrides on top of the auth harness.
      // Use the overrides list for OTHER providers (not authProvider itself —
      // pumpAuthenticated already manages that).
      await tester.pumpAuthenticated(
        const _UserNameWidget(),
        playerName: 'OverrideHero',
        overrides: const [
          // Any extra provider can be overridden here, e.g.:
          // someProvider.overrideWithValue(fakeValue),
        ],
      );

      expect(find.text('OverrideHero'), findsOneWidget);
    });
  });
}

// ---------------------------------------------------------------------------
// Test widget
// ---------------------------------------------------------------------------

/// Reads [authProvider] and renders the user's display name.
///
/// Use this inline widget pattern in tests that don't yet have a real app
/// widget to test against. The harness API is identical regardless of
/// which widget is pumped.
class _UserNameWidget extends ConsumerWidget {
  const _UserNameWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    return switch (auth) {
      AuthAuthenticated(:final user) => Text(user.displayName),
      _ => const Text('Not authenticated'),
    };
  }
}
