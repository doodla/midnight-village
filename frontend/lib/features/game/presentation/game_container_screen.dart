import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/components/core/mv_error.dart';
import '../../../design_system/components/core/mv_loading.dart';
import '../../../design_system/components/foundation/atmospheric_background.dart';
import '../../../design_system/components/game/night_action_prompt.dart';
import '../../../design_system/components/game/phase_indicator.dart';
import '../../../design_system/models/game_phase.dart';
import '../../../design_system/models/night_action.dart';
import '../../../design_system/models/player_display.dart';
import '../../../design_system/models/role.dart';
import '../domain/game_session_state.dart';
import '../domain/night_state.dart';
import 'game_notifier.dart';
import 'lone_werewolf_peek_view.dart';
import 'night_result_view.dart';
import 'night_waiting_view.dart';
import 'role_reveal_view.dart';
import 'seer_choice_view.dart';
import 'timer_provider.dart';

/// Number of center cards in ONUW. Used when building NightActionPrompt.
const int _kCenterCardCount = 3;

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
                      child: _buildPhaseView(gameState, ref),
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

  /// Builds the appropriate view for the current phase.
  Widget _buildPhaseView(GameSessionState gameState, WidgetRef ref) {
    return switch (gameState.phase) {
      'night' => _buildNightView(gameState, ref),
      'discussion' => const _PlaceholderView(
        key: ValueKey('discussion'),
        label: 'Discussion Phase',
      ),
      'voting' => const _PlaceholderView(
        key: ValueKey('voting'),
        label: 'Voting Phase',
      ),
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

    // For seeTeam, filter players to teammates only (from validTargets).
    final players = _buildPlayerDisplayList(
      actionType: actionType,
      prompt: prompt,
      allPlayers: gameState.players,
    );

    // Read current timer value from the deadline-based timer provider.
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

  /// Builds the player display list for the given action type.
  ///
  /// For [NightActionType.seeTeam], only players listed in
  /// `validTargets['see_team']` are shown (server-scoped teammates).
  /// For other actions, all players are included.
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

  /// Translates a [NightActionSelection] to [GameNotifier.submitAction] params.
  void _handleActionSubmitted(
    NightActionSelection selection,
    String actionTypeStr,
    GameNotifier notifier,
  ) {
    final targets = switch (selection) {
      PlayerTarget(:final playerId) => <String, dynamic>{
        'target_player_id': int.tryParse(playerId) ?? playerId,
      },
      CenterTargets(:final indices) when indices.length == 1 =>
        <String, dynamic>{'center_index': indices.first},
      CenterTargets(:final indices) => <String, dynamic>{
        'center_indices': indices,
      },
      TwoPlayerTargets(:final player1Id, :final player2Id) => <String, dynamic>{
        'player1_id': int.tryParse(player1Id) ?? player1Id,
        'player2_id': int.tryParse(player2Id) ?? player2Id,
      },
      NoAction() => <String, dynamic>{},
    };
    notifier.submitAction(actionTypeStr, targets);
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

/// Parses a server-provided role string to a [RoleId].
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

/// Maps an action type string from the server to [NightActionType].
NightActionType _parseActionType(String type) => switch (type) {
  'peek_player' => NightActionType.peekPlayer,
  'peek_center' => NightActionType.peekCenter,
  'swap_with_player' => NightActionType.swapWithPlayer,
  'swap_with_center' => NightActionType.swapWithCenter,
  'swap_others' => NightActionType.swapOthers,
  'see_team' => NightActionType.seeTeam,
  _ => NightActionType.none,
};

/// Placeholder view used for phases not yet implemented.
///
/// Will be replaced by real view implementations in WP09, WP10.
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
