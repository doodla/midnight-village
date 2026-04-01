import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design_system/components/core/mv_error.dart';
import '../../../design_system/components/core/mv_loading.dart';
import '../../../design_system/components/foundation/atmospheric_background.dart';
import '../../../design_system/components/foundation/player_avatar.dart';
import '../../../design_system/components/game/game_results.dart';
import '../../../design_system/components/game/night_action_prompt.dart';
import '../../../design_system/components/game/phase_indicator.dart';
import '../../../design_system/components/game/vote_submission.dart';
import '../../../design_system/models/avatar_size.dart';
import '../../../design_system/models/game_phase.dart';
import '../../../design_system/models/game_result.dart';
import '../../../design_system/models/night_action.dart';
import '../../../design_system/models/player_display.dart';
import '../../../design_system/models/role.dart';
import '../../../design_system/tokens/app_tokens_provider.dart';
import '../domain/game_session_state.dart';
import '../domain/night_state.dart';
import '../domain/voting_state.dart';
import 'discussion_view.dart';
import 'game_notifier.dart';
import 'lone_werewolf_peek_view.dart';
import 'night_result_view.dart';
import 'night_waiting_view.dart';
import 'role_reveal_view.dart';
import 'seer_choice_view.dart';
import 'timer_provider.dart';

/// Number of center cards in ONUW. Used when building NightActionPrompt.
const int _kCenterCardCount = 3;

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
      'night' => _buildNightView(gameState, ref),
      'discussion' => DiscussionView(
        key: const ValueKey('discussion'),
        deadline: gameState.deadline,
        rolesInGame: gameState.rolesInGame,
        isHost: gameState.isHost,
        onEndDiscussion: () =>
            ref.read(gameProvider(gameId).notifier).endDiscussion(),
      ),
      'voting' => _buildVotingView(ref, gameState),
      'results' => _buildResultsView(context, gameState.results),
      _ => _PlaceholderView(
        key: ValueKey('unknown-${gameState.phase}'),
        label: 'Unknown phase: ${gameState.phase}',
      ),
    };
  }

  Widget _buildNightView(GameSessionState gameState, WidgetRef ref) {
    final notifier = ref.read(gameProvider(gameId).notifier);

    return switch (gameState.nightSubView) {
      NightSubView.roleReveal => RoleRevealView(
        key: const ValueKey('night-role-reveal'),
        roleId: _parseRoleId(gameState.yourRole.originalRole),
        onComplete: notifier.onRoleRevealComplete,
      ),
      NightSubView.waiting => NightWaitingView(
        key: const ValueKey('night-waiting'),
        deadline: gameState.deadline,
      ),
      NightSubView.seerChoice when gameState.actionPrompt != null =>
        SeerChoiceView(
          key: const ValueKey('night-seer-choice'),
          roleId: _parseRoleId(gameState.actionPrompt!.roleActingAs),
          roleActingAs: gameState.actionPrompt!.roleActingAs,
          onActionTypeSelected: notifier.selectSeerChoice,
        ),
      NightSubView.actionPrompt when gameState.actionPrompt != null =>
        _buildActionPromptView(gameState, ref),
      NightSubView.actionResult when gameState.lastActionResult != null =>
        NightResultView(
          key: const ValueKey('night-action-result'),
          result: gameState.lastActionResult!,
          players: gameState.players,
          onLoneWerewolfDetected: notifier.transitionToLoneWerewolfPeek,
        ),
      NightSubView.loneWerewolfPeek => LoneWerewolfPeekView(
        key: const ValueKey('night-lone-werewolf'),
        centerCardCount: _kCenterCardCount,
        onSubmit: (actionType, targets) =>
            notifier.submitAction(actionType, targets),
      ),
      // Fallback when required state is not yet available.
      _ => NightWaitingView(
        key: const ValueKey('night-waiting-fallback'),
        deadline: gameState.deadline,
      ),
    };
  }

  Widget _buildActionPromptView(GameSessionState gameState, WidgetRef ref) {
    final prompt = gameState.actionPrompt!;
    final actionType = _parseActionType(prompt.actionTypes.first);
    final playerRole = _parseRoleId(gameState.yourRole.originalRole);
    final notifier = ref.read(gameProvider(gameId).notifier);

    final players = _buildPlayerDisplayList(
      actionType: actionType,
      prompt: prompt,
      allPlayers: gameState.players,
    );

    final timerAsync = ref.watch(gameTimerProvider(gameState.deadline));
    final timeRemaining = timerAsync.asData?.value ?? Duration.zero;

    return NightActionPrompt(
      key: const ValueKey('night-action-prompt'),
      actionType: actionType,
      playerRole: playerRole,
      players: players,
      centerCardCount: _kCenterCardCount,
      timeRemaining: timeRemaining,
      onActionSubmitted: (selection) =>
          _handleActionSubmitted(selection, prompt.actionTypes.first, notifier),
    );
  }

  List<PlayerDisplay> _buildPlayerDisplayList({
    required NightActionType actionType,
    required ActionPrompt prompt,
    required List<GamePlayer> allPlayers,
  }) {
    if (actionType == NightActionType.seeTeam) {
      final teamTargets = prompt.validTargets['see_team'];
      if (teamTargets is List) {
        final teammateIds = teamTargets.map((e) => e.toString()).toSet();
        return allPlayers
            .where((p) => teammateIds.contains(p.playerId.toString()))
            .map(_playerToDisplay)
            .toList();
      }
    }
    return allPlayers.map(_playerToDisplay).toList();
  }

  PlayerDisplay _playerToDisplay(GamePlayer player) => PlayerDisplay(
    id: player.playerId.toString(),
    displayName: player.displayName,
  );

  void _handleActionSubmitted(
    NightActionSelection selection,
    String actionTypeStr,
    GameNotifier notifier,
  ) {
    final targets = switch (selection) {
      PlayerTarget(:final playerId) => <String, dynamic>{
        'player_id': int.tryParse(playerId) ?? playerId,
      },
      CenterTargets(:final indices) when indices.length == 1 =>
        <String, dynamic>{'center_index': indices.first},
      CenterTargets(:final indices) => <String, dynamic>{
        'center_indices': indices,
      },
      TwoPlayerTargets(:final player1Id, :final player2Id) => <String, dynamic>{
        'player_ids': [
          int.tryParse(player1Id) ?? player1Id,
          int.tryParse(player2Id) ?? player2Id,
        ],
      },
      NoAction() => <String, dynamic>{},
    };
    notifier.submitAction(actionTypeStr, targets);
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

RoleId _parseRoleId(String role) => switch (role.toLowerCase()) {
  'werewolf' => RoleId.werewolf,
  'minion' => RoleId.minion,
  'villager' => RoleId.villager,
  'seer' => RoleId.seer,
  'robber' => RoleId.robber,
  'troublemaker' => RoleId.troublemaker,
  'drunk' => RoleId.drunk,
  'insomniac' => RoleId.insomniac,
  'mason' => RoleId.mason,
  'hunter' => RoleId.hunter,
  'tanner' => RoleId.tanner,
  'doppelganger' => RoleId.doppelganger,
  _ => RoleId.villager,
};

NightActionType _parseActionType(String type) => switch (type) {
  'peek_player' => NightActionType.peekPlayer,
  'peek_center' => NightActionType.peekCenter,
  'swap_with_player' => NightActionType.swapWithPlayer,
  'swap_with_center' => NightActionType.swapWithCenter,
  'swap_others' => NightActionType.swapOthers,
  'see_team' => NightActionType.seeTeam,
  _ => NightActionType.none,
};

// ---------------------------------------------------------------------------
// Voting active view
// ---------------------------------------------------------------------------

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
        Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.md),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: tokens.spacing.sm,
            runSpacing: tokens.spacing.xs,
            children: players.map((player) {
              final voted = voteProgress.playerVoted[player.playerId] ?? false;
              return Semantics(
                label: voted
                    ? '${player.displayName} voted'
                    : player.displayName,
                excludeSemantics: true,
                child: PlayerAvatar(
                  displayName: player.displayName,
                  size: AvatarSize.small,
                  sigil: voted ? Icons.check : null,
                ),
              );
            }).toList(),
          ),
        ),
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
// Vote reveal intermediate view
// ---------------------------------------------------------------------------

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
// Placeholder view
// ---------------------------------------------------------------------------

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
