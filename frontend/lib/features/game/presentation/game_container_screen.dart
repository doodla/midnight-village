import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/host/host_change.dart';
import '../../../core/host/table_closed.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/router/routes.dart';
import '../../../core/wakelock/wakelock_service.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/auth_notifier.dart';
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
import '../../../design_system/tokens/app_tokens.dart';
import '../../../design_system/tokens/app_tokens_provider.dart';
import '../domain/game_session_state.dart';
import '../domain/night_state.dart';
import '../domain/voting_state.dart';
import '../../../core/websocket/websocket_channel.dart';
import 'away_notice.dart';
import 'discussion_view.dart';
import 'game_notifier.dart';
import 'lone_werewolf_peek_view.dart';
import 'night_result_view.dart';
import 'night_waiting_view.dart';
import 'reconnection_overlay.dart';
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
class GameContainerScreen extends ConsumerStatefulWidget {
  const GameContainerScreen({super.key, required this.gameId, this.lobbyCode});

  final String gameId;

  /// Code of the table this game is played at, when the route knows it. The
  /// results screen needs it to start another game or leave the table.
  final String? lobbyCode;

  @override
  ConsumerState<GameContainerScreen> createState() =>
      _GameContainerScreenState();
}

class _GameContainerScreenState extends ConsumerState<GameContainerScreen>
    with WidgetsBindingObserver {
  late final WakelockService _wakelock;
  bool _closing = false;

  String get gameId => widget.gameId;

  @override
  void initState() {
    super.initState();
    // Keep the screen awake for as long as a game is on screen (the role
    // reveal through the results); it is released in dispose.
    _wakelock = ref.read(wakelockServiceProvider);
    _keepAwake(_wakelock.enable);
    WidgetsBinding.instance.addObserver(this);
    ref.read(gameProvider(gameId).notifier).lobbyCodeHint = widget.lobbyCode;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _keepAwake(_wakelock.disable);
    super.dispose();
  }

  /// Runs a wakelock call without waiting; a platform that refuses is no
  /// reason to disturb the game.
  void _keepAwake(Future<void> Function() call) {
    unawaited(
      call().catchError((Object e) {
        logger.d('Wakelock call failed (ignored): $e');
      }),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // The platform drops the wake lock when the app is backgrounded, and
    // events may have been missed meanwhile: take the lock again and re-read
    // the game from the server.
    _keepAwake(_wakelock.enable);
    unawaited(ref.read(gameProvider(gameId).notifier).refreshState());
  }

  @override
  Widget build(BuildContext context) {
    // The table has moved on to another game (the host's "Play again", here or
    // on another phone): leave for its lobby. This screen, and with it the
    // finished game's state, goes away; the next game opens clean.
    ref.listen(gameProvider(gameId), (previous, next) {
      // The table is gone (its last member left): say so, go home.
      final closed =
          (next.value?.tableClosed ?? false) ||
          (next.hasError && next.error is NotFoundException);
      if (closed) {
        if (!_closing) {
          _closing = true;
          showTableClosedAndGoHome(context);
        }
        return;
      }
      final code = next.value?.playAgainLobbyCode;
      if (code != null && code != previous?.value?.playAgainLobbyCode) {
        context.go(LobbyRoute(code: code).location);
      }
    });

    final asyncState = ref.watch(gameProvider(gameId));
    final viewerId = switch (ref.watch(authProvider)) {
      AuthAuthenticated(:final user) => user.id,
      _ => null,
    };

    // Watch connection state to drive the reconnection overlay.
    final connAsync = ref.watch(gameConnectionStateProvider(gameId));
    final showOverlay =
        connAsync.whenOrNull(
          data: (connState) =>
              connState == WebSocketConnectionState.disconnected ||
              connState == WebSocketConnectionState.reconnecting,
        ) ??
        false;

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
          body: Stack(
            children: [
              AtmosphericBackground(
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
                      // Who is hosting, when that has just changed.
                      HostNoticeLine(text: _hostLine(gameState, viewerId)),
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
              ReconnectionOverlay(isVisible: showOverlay),
            ],
          ),
        );
      },
    );
  }

  /// The quiet line about the host: a refused host action first, else the
  /// latest host change ("Ben is hosting while Ana is away").
  String? _hostLine(GameSessionState state, int? viewerId) {
    if (state.hostActionNotice != null) return state.hostActionNotice;
    final change = state.hostNotice;
    if (change == null) return null;
    String? originalName;
    for (final p in state.players) {
      if (p.playerId == change.originalHostId) originalName = p.displayName;
    }
    return hostChangeLine(
      change: change,
      viewerId: viewerId,
      originalHostName: originalName,
    );
  }

  /// Ends the talk (host). A refusal because the role moved is already said
  /// in the host line, so it needs no error of its own.
  Future<void> _endDiscussion() async {
    try {
      await ref.read(gameProvider(gameId).notifier).endDiscussion();
    } on NoLongerHostException {
      // The notifier has refreshed state and set the plain line.
    }
  }

  /// Builds the appropriate view for the current phase and night sub-view.
  Widget _buildPhaseView(
    BuildContext context,
    WidgetRef ref,
    GameSessionState gameState,
  ) {
    return switch (gameState.phase) {
      'night' => _buildNightView(gameState, ref),
      // The night's results arrive just before the move to discussion. A result
      // the player has not dismissed is shown first, then the discussion.
      'discussion' when gameState.lastActionResult != null =>
        _buildNightResultAfterNight(
          ref,
          gameState,
          lastLabel: 'Continue to discussion',
        ),
      'discussion' => DiscussionView(
        key: const ValueKey('discussion'),
        deadline: gameState.deadline,
        rolesInGame: gameState.rolesInGame,
        isHost: gameState.isHost,
        onEndDiscussion: _endDiscussion,
      ),
      // A night result missed while the phone was away, shown before the vote.
      'voting' when gameState.lastActionResult != null =>
        _buildNightResultAfterNight(
          ref,
          gameState,
          lastLabel: 'Continue to the vote',
        ),
      'voting' => _buildVotingView(ref, gameState),
      'results' => _ResultsView(
        key: const ValueKey('results'),
        gameId: gameId,
        results: gameState.results,
        isHost: gameState.isHost,
      ),
      _ => _PlaceholderView(
        key: ValueKey('unknown-${gameState.phase}'),
        label: 'Unknown phase: ${gameState.phase}',
      ),
    };
  }

  /// A night result shown after the night is over (discussion or vote): the
  /// player reads it, then continues. Missed results queued behind it come one
  /// after another.
  Widget _buildNightResultAfterNight(
    WidgetRef ref,
    GameSessionState gameState, {
    required String lastLabel,
  }) {
    return NightResultView(
      key: const ValueKey('night-action-result'),
      result: gameState.lastActionResult!,
      players: gameState.players,
      continueLabel: gameState.pendingNightResults.isNotEmpty
          ? 'Next'
          : lastLabel,
      onContinue: ref.read(gameProvider(gameId).notifier).dismissNightResult,
    );
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
        // Public to the table: who has dropped. Only the host gets a way on.
        awayNames: [for (final p in gameState.awayPlayers) p.displayName],
        onContinueWithoutThem: gameState.isHost ? notifier.advanceNight : null,
      ),
      NightSubView.seerChoice when gameState.actionPrompt != null =>
        SeerChoiceView(
          key: const ValueKey('night-seer-choice'),
          roleId: _parseRoleId(gameState.actionPrompt!.roleActingAs),
          roleActingAs: gameState.actionPrompt!.roleActingAs,
          onActionTypeSelected: notifier.selectSeerChoice,
          onSkip: gameState.actionPrompt!.canSkip
              ? () => notifier.submitAction(ActionPromptChoices.skipType, {})
              : null,
        ),
      NightSubView.actionPrompt when gameState.actionPrompt != null =>
        _isLoneWerewolfPrompt(gameState.actionPrompt!)
            ? LoneWerewolfPeekView(
                key: const ValueKey('night-lone-werewolf-pre-submit'),
                centerCardCount: _kCenterCardCount,
                onSubmit: (actionType, targets) =>
                    notifier.submitAction(actionType, targets),
              )
            : _buildActionPromptView(gameState, ref),
      NightSubView.actionResult when gameState.lastActionResult != null =>
        NightResultView(
          key: const ValueKey('night-action-result'),
          result: gameState.lastActionResult!,
          players: gameState.players,
          // Something is waiting for the player after this result (the
          // Doppelganger's follow-up prompt, results missed while away, or a
          // window that has since moved on): let them read it first.
          onContinue:
              gameState.actionPrompt != null ||
                  gameState.pendingNightResults.isNotEmpty ||
                  gameState.lastActionResult!.wave < gameState.currentWave
              ? notifier.dismissNightResult
              : null,
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
    final primaryType = prompt.primaryType;
    final actionType = _parseActionType(primaryType);
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
          _handleActionSubmitted(selection, primaryType, notifier),
      // "Do nothing": only where the server offered `skip` in the prompt.
      onSkip: prompt.canSkip
          ? () => notifier.submitAction(ActionPromptChoices.skipType, {})
          : null,
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

    // For player-targeting actions, filter to only the valid targets sent by
    // the server. This excludes the acting player (you can't peek at yourself,
    // swap with yourself, etc.).
    const playerTargetingActions = {
      NightActionType.peekPlayer,
      NightActionType.swapWithPlayer,
      NightActionType.swapOthers,
    };
    if (playerTargetingActions.contains(actionType)) {
      final validIds = prompt.validTargets['player_ids'];
      if (validIds is List) {
        final validIdSet = validIds.map((e) => e.toString()).toSet();
        return allPlayers
            .where((p) => validIdSet.contains(p.playerId.toString()))
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
      onRevealVotesNow: gameState.isHost
          ? ref.read(gameProvider(gameId).notifier).revealVotesNow
          : null,
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

/// Returns true when the action prompt is for a lone Werewolf (or
/// Doppelganger-as-Werewolf) who has no teammates and should be offered
/// the center card peek UI *before* submitting their action.
bool _isLoneWerewolfPrompt(ActionPrompt prompt) {
  if (prompt.actionTypes.firstOrNull != 'see_team') return false;
  if (prompt.roleActingAs.toLowerCase() != 'werewolf') return false;
  final targets = prompt.validTargets['see_team'];
  return targets is List && targets.isEmpty;
}

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

  /// The host's "Reveal votes now". Null for everyone else.
  final Future<void> Function()? onRevealVotesNow;

  const _VotingActiveView({
    super.key,
    required this.gameState,
    required this.onVoteSubmitted,
    this.onRevealVotesNow,
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

    // Exclude the current player from vote targets (spec: no self-votes).
    final authState = ref.watch(authProvider);
    final currentUserId = switch (authState) {
      AuthAuthenticated(:final user) => user.id,
      _ => null,
    };

    final playerDisplays = players
        .where((p) => p.playerId != currentUserId)
        .map(
          (p) => PlayerDisplay(
            id: p.playerId.toString(),
            displayName: p.displayName,
            isSelectable: true,
            status: p.connected
                ? PlayerStatus.active
                : PlayerStatus.disconnected,
          ),
        )
        .toList();

    // The game waits only for players who are away and have not voted. Public
    // information: it says nothing about roles.
    final awayNotVoted = [
      for (final p in players)
        if (!p.connected && !(voteProgress.playerVoted[p.playerId] ?? false))
          p.displayName,
    ];

    // Scrolls when the extra lines (someone away, the host's button) and a
    // large text size leave too little room; otherwise the vote fills the
    // screen as before.
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
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
              if (awayNotVoted.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(
                    left: tokens.spacing.md,
                    right: tokens.spacing.md,
                    bottom: tokens.spacing.sm,
                  ),
                  child: AwayNotice(names: awayNotVoted),
                ),
              if (onRevealVotesNow != null && gameState.hasAwayPlayers)
                Padding(
                  padding: EdgeInsets.only(
                    left: tokens.spacing.md,
                    right: tokens.spacing.md,
                    bottom: tokens.spacing.sm,
                  ),
                  child: HostContinueControl(
                    label: 'Reveal votes now',
                    onPressed: onRevealVotesNow!,
                  ),
                ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: tokens.spacing.md),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: tokens.spacing.sm,
                  runSpacing: tokens.spacing.xs,
                  children: players.map((player) {
                    final voted =
                        voteProgress.playerVoted[player.playerId] ?? false;
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
            ],
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
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
// Results view
// ---------------------------------------------------------------------------

/// The results, with what happens next: the host starts another game ("Play
/// again"), everyone can leave the table, and the others are told they are
/// waiting for the host.
class _ResultsView extends ConsumerStatefulWidget {
  const _ResultsView({
    super.key,
    required this.gameId,
    required this.results,
    required this.isHost,
  });

  final String gameId;
  final GameResult? results;
  final bool isHost;

  @override
  ConsumerState<_ResultsView> createState() => _ResultsViewState();
}

class _ResultsViewState extends ConsumerState<_ResultsView> {
  bool _starting = false;
  String? _error;

  Future<void> _playAgain() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      // On success the notifier points the screen at the lobby.
      await ref.read(gameProvider(widget.gameId).notifier).playAgain();
    } on NotFoundException {
      // The table is gone: say so and go home.
      if (mounted) showTableClosedAndGoHome(context);
    } catch (e) {
      if (mounted) setState(() => _error = _playAgainMessage(e));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  String _playAgainMessage(Object e) => switch (e) {
    NoLongerHostException() => kNoLongerHostMessage,
    ForbiddenException() => 'Only the host can start another game.',
    UnhandledHttpException(statusCode: 409) =>
      'The game is not finished yet. Try again in a moment.',
    _ => 'Could not start another game. Try again.',
  };

  Future<void> _leave() async {
    try {
      await ref.read(gameProvider(widget.gameId).notifier).leaveTable();
    } on NotFoundException {
      // The table is already gone: say so on the way home.
      if (mounted) showTableClosedAndGoHome(context);
      return;
    } catch (e) {
      // Leaving is what the player wants either way; the table sorts itself
      // out on the server.
      logger.w('Leaving the table failed', error: e);
    }
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final results = widget.results;
    if (results == null) {
      return const _PlaceholderView(
        key: ValueKey('results-loading'),
        label: 'Loading results...',
      );
    }
    final tokens = ref.watch(activeThemeProvider);
    return GameResults(
      result: results,
      onPlayAgain: widget.isHost && !_starting ? _playAgain : null,
      returnLabel: 'Leave',
      onReturnToLobby: _leave,
      footer: _buildFooter(tokens),
    );
  }

  Widget? _buildFooter(AppTokens tokens) {
    if (_error != null) {
      return Text(
        _error!,
        key: const ValueKey('play-again-error'),
        style: tokens.typography.body.copyWith(color: tokens.colors.error),
      );
    }
    if (!widget.isHost) {
      return Text(
        'Waiting for the host to start another game.',
        key: const ValueKey('waiting-for-host'),
        style: tokens.typography.body.copyWith(color: tokens.colors.onDisabled),
      );
    }
    return null;
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
