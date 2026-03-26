import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/models/game_phase.dart';
import 'package:midnight_village/features/auth/domain/auth_state.dart';
import 'package:midnight_village/features/auth/presentation/auth_notifier.dart';

import '../test_harness.dart';

/// Examples: pumpWithGameState harness
///
/// These tests demonstrate the [pumpWithGameState] pattern. Copy them as a
/// starting point for any test that needs a game in a specific phase with a
/// configured player list. Auth state is also pre-configured — no extra setup
/// is needed for widgets that require login.
void main() {
  group('pumpWithGameState harness', () {
    final fivePlayers = List.generate(
      5,
      (i) => PlayerInfo(id: 'id-$i', name: 'Player $i'),
    );

    testWidgets('provides voting phase and 5 players to the widget tree',
        (tester) async {
      // One call configures phase, players, and auth.
      await tester.pumpWithGameState(
        const _GameStateWidget(),
        phase: GamePhase.voting,
        players: fivePlayers,
      );

      expect(find.text('Voting'), findsOneWidget);
      for (final player in fivePlayers) {
        expect(find.text(player.name), findsOneWidget);
      }
    });

    testWidgets('player count is reflected in the widget', (tester) async {
      final threePlayers = List.generate(
        3,
        (i) => PlayerInfo(id: 'id-$i', name: 'Player $i'),
      );

      await tester.pumpWithGameState(
        const _GameStateWidget(),
        phase: GamePhase.discussion,
        players: threePlayers,
      );

      expect(find.textContaining('3 players'), findsOneWidget);
    });

    testWidgets('each game phase can be independently configured',
        (tester) async {
      for (final phase in GamePhase.values) {
        // Pump a fresh widget for each phase.
        await tester.pumpWidget(const SizedBox.shrink());

        await tester.pumpWithGameState(
          const _GameStateWidget(),
          phase: phase,
          players: fivePlayers,
        );

        expect(find.text(phase.displayName), findsOneWidget);
      }
    });

    testWidgets('custom playerName is forwarded to auth state', (tester) async {
      // pumpWithGameState composes on pumpAuthenticated — the playerName
      // is available anywhere authProvider is watched.
      await tester.pumpWithGameState(
        const _PlayerNameWidget(),
        phase: GamePhase.night,
        players: fivePlayers,
        playerName: 'NightOwl',
      );

      expect(find.text('NightOwl'), findsOneWidget);
    });
  });
}

// ---------------------------------------------------------------------------
// Test widgets
// ---------------------------------------------------------------------------

/// Reads [gameStateProvider] and renders phase + player list.
///
/// Inline test widget — replace with real game widgets once they exist.
class _GameStateWidget extends ConsumerWidget {
  const _GameStateWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameStateProvider);
    return Column(
      children: [
        Text(state.phase.displayName),
        Text('${state.players.length} players'),
        ...state.players.map((p) => Text(p.name)),
      ],
    );
  }
}

/// Reads [authProvider] and renders the current player name.
///
/// Demonstrates that auth state is pre-configured by [pumpWithGameState]
/// without any extra setup.
class _PlayerNameWidget extends ConsumerWidget {
  const _PlayerNameWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    return switch (auth) {
      AuthAuthenticated(:final user) => Text(user.displayName),
      _ => const Text('Not authenticated'),
    };
  }
}
