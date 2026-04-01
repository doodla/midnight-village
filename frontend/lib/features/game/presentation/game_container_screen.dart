import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design_system/components/core/mv_error.dart';
import '../../../design_system/components/core/mv_loading.dart';
import '../../../design_system/components/foundation/atmospheric_background.dart';
import '../../../design_system/components/game/game_results.dart';
import '../../../design_system/components/game/phase_indicator.dart';
import '../../../design_system/models/game_phase.dart';
import '../../../design_system/models/game_result.dart';
import '../domain/night_state.dart';
import 'game_notifier.dart';

/// Phase-switching shell that renders the correct sub-view based on the
/// current game phase and night sub-view state.
///
/// This is the game's "router" -- but it's a widget, not a URL router (R6).
/// Phase transitions are driven by WebSocket events via [GameNotifier].
/// The [NightSubView] enum gives fine-grained control over which night view
/// to show.
class GameContainerScreen extends ConsumerWidget {
  const GameContainerScreen({super.key, required this.gameId});

  final String gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(gameProvider(gameId));

    return asyncState.when(
      loading: () => const Scaffold(body: MvLoading()),
      error: (error, stack) => Scaffold(
        body: MvError(
          message: 'Failed to load game',
          onRetry: () => ref.invalidate(gameProvider(gameId)),
        ),
      ),
      data: (gameState) {
        final gamePhase = _parseGamePhase(gameState.phase);

        return Scaffold(
          body: AtmosphericBackground(
            phase: gamePhase,
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: PhaseIndicator(currentPhase: gamePhase),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: _buildPhaseView(
                        context,
                        gameState.phase,
                        gameState.nightSubView,
                        gameState.results,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Builds the appropriate view for the current phase and night sub-view.
  Widget _buildPhaseView(
    BuildContext context,
    String phase,
    NightSubView nightSubView,
    GameResult? results,
  ) {
    return switch (phase) {
      'night' => _buildNightView(nightSubView),
      'discussion' => const _PlaceholderView(
        key: ValueKey('discussion'),
        label: 'Discussion Phase',
      ),
      'voting' => const _PlaceholderView(
        key: ValueKey('voting'),
        label: 'Voting Phase',
      ),
      'results' => _buildResultsView(context, results),
      _ => _PlaceholderView(
        key: ValueKey('unknown-$phase'),
        label: 'Unknown phase: $phase',
      ),
    };
  }

  Widget _buildResultsView(BuildContext context, GameResult? results) {
    if (results == null) {
      return const _PlaceholderView(
        key: ValueKey('results-loading'),
        label: 'Loading results...',
      );
    }
    return GameResults(
      key: const ValueKey('results'),
      result: results,
      onReturnToLobby: () => context.go('/'),
    );
  }

  Widget _buildNightView(NightSubView subView) {
    return switch (subView) {
      NightSubView.waiting => const _PlaceholderView(
        key: ValueKey('night-waiting'),
        label: 'Night Waiting',
      ),
      NightSubView.seerChoice => const _PlaceholderView(
        key: ValueKey('night-seer-choice'),
        label: 'Seer Choice',
      ),
      NightSubView.actionPrompt => const _PlaceholderView(
        key: ValueKey('night-action-prompt'),
        label: 'Night Action',
      ),
      NightSubView.actionResult => const _PlaceholderView(
        key: ValueKey('night-action-result'),
        label: 'Action Result',
      ),
      NightSubView.loneWerewolfPeek => const _PlaceholderView(
        key: ValueKey('night-lone-werewolf'),
        label: 'Lone Werewolf Peek',
      ),
      NightSubView.roleReveal => const _PlaceholderView(
        key: ValueKey('night-role-reveal'),
        label: 'Role Reveal',
      ),
    };
  }

  /// Parses a phase string from the server into a [GamePhase] enum.
  GamePhase _parseGamePhase(String phase) {
    return switch (phase) {
      'night' => GamePhase.night,
      'discussion' => GamePhase.discussion,
      'voting' => GamePhase.voting,
      'results' => GamePhase.results,
      _ => GamePhase.lobby,
    };
  }
}

/// Placeholder view used for phases not yet implemented.
///
/// Will be replaced by real view implementations in WP08, WP09, WP10.
class _PlaceholderView extends StatelessWidget {
  const _PlaceholderView({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(color: Colors.white70),
      ),
    );
  }
}
