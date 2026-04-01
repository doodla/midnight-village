import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/components/core/mv_error.dart';
import '../../../design_system/components/core/mv_loading.dart';
import '../../../design_system/components/game/phase_indicator.dart';
import '../../../design_system/components/game/vote_submission.dart';
import '../../../design_system/components/foundation/atmospheric_background.dart';
import '../../../design_system/models/game_phase.dart';
import '../../../design_system/models/player_display.dart';
import '../../../design_system/tokens/app_tokens_provider.dart';
import '../domain/game_session_state.dart';
import '../domain/night_state.dart';
import '../domain/voting_state.dart';
import 'discussion_view.dart';
import 'game_notifier.dart';
import 'timer_provider.dart';

// ---------------------------------------------------------------------------
// Layout constants
// ---------------------------------------------------------------------------

const double _kVoteProgressGap = 12.0;
const double _kTallyHeaderGap = 8.0;

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
                      child: _buildPhaseView(context, ref, gameState),
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
    WidgetRef ref,
    GameSessionState gameState,
  ) {
    return switch (gameState.phase) {
      'night' => _buildNightView(gameState.nightSubView),
      'discussion' => DiscussionView(
        key: const ValueKey('discussion'),
        deadline: gameState.deadline,
        rolesInGame: gameState.rolesInGame,
        isHost: gameState.isHost,
        onEndDiscussion: () =>
            ref.read(gameProvider(gameId).notifier).endDiscussion(),
      ),
      'voting' => _buildVotingView(ref, gameState),
      'results' => const _PlaceholderView(
        key: ValueKey('results'),
        label: 'Results',
      ),
      _ => _PlaceholderView(
        key: ValueKey('unknown-${gameState.phase}'),
        label: 'Unknown phase: ${gameState.phase}',
      ),
    };
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

  /// Builds the voting phase view.
  ///
  /// If [voteRevealData] is present, shows the intermediate tally
  /// (who voted for whom, without elimination data). Otherwise shows
  /// VoteSubmission for target selection and a vote progress indicator.
  Widget _buildVotingView(WidgetRef ref, GameSessionState gameState) {
    if (gameState.voteRevealData != null) {
      return _VoteRevealIntermediateView(
        key: const ValueKey('vote-reveal-intermediate'),
        voteRevealData: gameState.voteRevealData!,
        players: gameState.players,
      );
    }

    return _VotingActiveView(
      key: const ValueKey('voting-active'),
      gameState: gameState,
      onVoteSubmitted: (targetPlayerId) =>
          ref.read(gameProvider(gameId).notifier).submitVote(targetPlayerId),
    );
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

// ---------------------------------------------------------------------------
// Voting active view — VoteSubmission + progress indicator
// ---------------------------------------------------------------------------

/// Shown during the voting phase before votes are revealed.
///
/// Shows who has voted (without targets) and the target selection widget.
class _VotingActiveView extends ConsumerWidget {
  final GameSessionState gameState;
  final void Function(int targetPlayerId) onVoteSubmitted;

  const _VotingActiveView({
    super.key,
    required this.gameState,
    required this.onVoteSubmitted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(activeThemeProvider);
    final timerAsync = ref.watch(gameTimerProvider(gameState.deadline));
    final timeRemaining = timerAsync.asData?.value ?? Duration.zero;

    final players = gameState.players;
    final voteProgress = gameState.voteProgress;
    final votedCount = voteProgress.playerVoted.values.where((v) => v).length;
    final totalPlayers = players.length;

    final playerDisplays = players
        .map(
          (p) => PlayerDisplay(
            id: p.playerId.toString(),
            displayName: p.displayName,
            isSelectable: true,
          ),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Vote progress indicator — shows count without revealing targets.
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.md,
            vertical: _kVoteProgressGap,
          ),
          child: Text(
            '$votedCount of $totalPlayers voted',
            style: tokens.typography.subheading.copyWith(
              color: tokens.colors.onBackground,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        // VoteSubmission widget wired to game notifier.
        Expanded(
          child: VoteSubmission(
            players: playerDisplays,
            timeRemaining: timeRemaining,
            onVoteSubmitted: (playerIdStr) {
              final id = int.tryParse(playerIdStr);
              if (id != null) onVoteSubmitted(id);
            },
            isLocked: gameState.hasVoted || voteProgress.currentPlayerVoted,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Vote reveal intermediate view — tally before elimination data arrives
// ---------------------------------------------------------------------------

/// Shown after the `vote_reveal` WebSocket event, before `game_results`.
///
/// Displays the intermediate state: who voted for whom and the vote count
/// tally. Does NOT render [VoteReveal] because that widget shows
/// "No one was eliminated!" when elimination data is absent — misleading.
class _VoteRevealIntermediateView extends ConsumerWidget {
  final VoteRevealData voteRevealData;
  final List<GamePlayer> players;

  const _VoteRevealIntermediateView({
    super.key,
    required this.voteRevealData,
    required this.players,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(activeThemeProvider);

    // Build ID → name lookup from the player list.
    final nameById = <String, String>{
      for (final p in players) p.playerId.toString(): p.displayName,
    };

    return SingleChildScrollView(
      padding: EdgeInsets.all(tokens.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Votes',
            style: tokens.typography.heading.copyWith(
              color: tokens.colors.onBackground,
            ),
          ),
          SizedBox(height: _kTallyHeaderGap),

          // Per-voter entry: "Alice voted for Bob" or "Alice abstained".
          ...voteRevealData.votes.entries.map((entry) {
            final voterName = nameById[entry.key] ?? entry.key;
            if (entry.value == null) {
              return Padding(
                padding: EdgeInsets.only(bottom: tokens.spacing.xs),
                child: Text(
                  '$voterName abstained',
                  style: tokens.typography.body.copyWith(
                    color: tokens.colors.onBackground,
                  ),
                ),
              );
            }
            final targetName =
                nameById[entry.value.toString()] ?? entry.value.toString();
            return Padding(
              padding: EdgeInsets.only(bottom: tokens.spacing.xs),
              child: Text(
                '$voterName voted for $targetName',
                style: tokens.typography.body.copyWith(
                  color: tokens.colors.onBackground,
                ),
              ),
            );
          }),

          SizedBox(height: tokens.spacing.lg),

          // Tally section.
          Text(
            'Tally',
            style: tokens.typography.heading.copyWith(
              color: tokens.colors.onBackground,
            ),
          ),
          SizedBox(height: _kTallyHeaderGap),

          ...(voteRevealData.tally.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .map((entry) {
                final playerName = nameById[entry.key] ?? entry.key;
                return Padding(
                  padding: EdgeInsets.only(bottom: tokens.spacing.xs),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          playerName,
                          style: tokens.typography.body.copyWith(
                            color: tokens.colors.onBackground,
                          ),
                        ),
                      ),
                      Text(
                        '${entry.value}',
                        style: tokens.typography.body.copyWith(
                          color: tokens.colors.onBackground,
                        ),
                      ),
                    ],
                  ),
                );
              }),

          SizedBox(height: tokens.spacing.md),

          // Calculating results indicator.
          Text(
            'Calculating results...',
            style: tokens.typography.caption.copyWith(
              color: tokens.colors.onDisabled,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Placeholder view (used for phases not yet implemented)
// ---------------------------------------------------------------------------

/// Placeholder view used for phases not yet implemented.
///
/// Will be replaced by real view implementations in WP08, WP10.
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
