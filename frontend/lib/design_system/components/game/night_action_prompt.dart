import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:midnight_village/design_system/components/core/primary_button.dart';
import 'package:midnight_village/design_system/components/game/center_cards.dart';
import 'package:midnight_village/design_system/components/game/game_timer.dart';
import 'package:midnight_village/design_system/components/game/player_circle.dart';
import 'package:midnight_village/design_system/components/game/role_card.dart';
import 'package:midnight_village/design_system/models/night_action.dart';
import 'package:midnight_village/design_system/models/player_display.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/tokens/app_tokens.dart';
import 'package:midnight_village/design_system/tokens/app_tokens_provider.dart';

// ---------------------------------------------------------------------------
// Layout constants — dp values for spacing/sizing, not visual tokens.
// ---------------------------------------------------------------------------

/// Vertical gap between the role identity strip and the action area.
const double _kSectionGap = 24.0;

/// Vertical gap between the action area and the timer row.
const double _kTimerGap = 32.0;

/// Minimum tap-target height for action areas that have no interactive child.
const double _kMinActionHeight = 120.0;

// ---------------------------------------------------------------------------
// Public widget
// ---------------------------------------------------------------------------

/// The main night-phase action screen: role identity at top, action-specific
/// UI in the middle, countdown timer at the bottom.
///
/// Manages selection state internally and fires [onActionSubmitted] only after
/// the player taps a confirm/acknowledge/continue button, preventing accidental
/// submissions.
///
/// If [onSkip] is non-null, a secondary "Skip" button is shown alongside the
/// confirm action.
class NightActionPrompt extends ConsumerStatefulWidget {
  /// What kind of night action this player must perform.
  final NightActionType actionType;

  /// The player's current role (used for identity display and seeTeam copy).
  final RoleId playerRole;

  /// All players in the game (for player-selection UIs).
  /// For [NightActionType.seeTeam] this list contains only the visible
  /// teammates (the server has already scoped it).
  final List<PlayerDisplay> players;

  /// Number of center cards to display in center-card selection UIs.
  final int centerCardCount;

  /// Remaining time for the night action.
  final Duration timeRemaining;

  /// Called when the player confirms their action selection.
  final ValueChanged<NightActionSelection> onActionSubmitted;

  /// Optional skip callback. When non-null a "Skip" button is shown.
  final VoidCallback? onSkip;

  const NightActionPrompt({
    super.key,
    required this.actionType,
    required this.playerRole,
    required this.players,
    required this.centerCardCount,
    required this.timeRemaining,
    required this.onActionSubmitted,
    this.onSkip,
  });

  @override
  ConsumerState<NightActionPrompt> createState() => _NightActionPromptState();
}

class _NightActionPromptState extends ConsumerState<NightActionPrompt> {
  // -------------------------------------------------------------------------
  // Shared selection state
  // -------------------------------------------------------------------------

  /// For single-player-target actions (peekPlayer, swapWithPlayer).
  String? _selectedPlayerId;

  /// For two-player-target actions (swapOthers).
  final List<String> _selectedPlayerIds = [];

  /// For center-card-target actions (peekCenter, swapWithCenter).
  List<int> _selectedCardIndices = [];

  // -------------------------------------------------------------------------
  // State helpers
  // -------------------------------------------------------------------------

  void _onSinglePlayerSelected(String playerId) {
    setState(() {
      _selectedPlayerId = _selectedPlayerId == playerId ? null : playerId;
    });
  }

  void _onTwoPlayersSelected(String playerId) {
    setState(() {
      if (_selectedPlayerIds.contains(playerId)) {
        _selectedPlayerIds.remove(playerId);
      } else if (_selectedPlayerIds.length < 2) {
        _selectedPlayerIds.add(playerId);
      }
    });
  }

  void _onCardSelectionChanged(List<int> indices) {
    setState(() {
      _selectedCardIndices = indices;
    });
  }

  /// Rebuild the players list with the selection flag applied from local state.
  List<PlayerDisplay> _playersWithSingleSelection() {
    return widget.players
        .map((p) => p.copyWith(isSelected: p.id == _selectedPlayerId))
        .toList();
  }

  List<PlayerDisplay> _playersWithMultiSelection() {
    return widget.players
        .map((p) => p.copyWith(isSelected: _selectedPlayerIds.contains(p.id)))
        .toList();
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(activeThemeProvider);

    return Padding(
      padding: EdgeInsets.all(tokens.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top: role identity strip.
          _RoleIdentityStrip(role: widget.playerRole, tokens: tokens),

          SizedBox(height: _kSectionGap),

          // Middle: action-specific UI — expands to fill available space.
          Expanded(child: _buildActionArea(tokens)),

          SizedBox(height: _kTimerGap),

          // Bottom: countdown timer.
          GameTimer(timeRemaining: widget.timeRemaining),

          SizedBox(height: tokens.spacing.md),
        ],
      ),
    );
  }

  Widget _buildActionArea(AppTokens tokens) {
    switch (widget.actionType) {
      case NightActionType.peekPlayer:
        return _PeekPlayerAction(
          players: _playersWithSingleSelection(),
          tokens: tokens,
          onPlayerSelected: _onSinglePlayerSelected,
          onConfirm: _selectedPlayerId != null
              ? () => widget.onActionSubmitted(PlayerTarget(_selectedPlayerId!))
              : null,
          onSkip: widget.onSkip,
        );

      case NightActionType.peekCenter:
        return _PeekCenterAction(
          centerCardCount: widget.centerCardCount,
          tokens: tokens,
          onSelectionChanged: _onCardSelectionChanged,
          onConfirm: _selectedCardIndices.length == 2
              ? () => widget.onActionSubmitted(
                  CenterTargets(List.of(_selectedCardIndices)),
                )
              : null,
          onSkip: widget.onSkip,
        );

      case NightActionType.swapWithPlayer:
        return _SwapWithPlayerAction(
          players: _playersWithSingleSelection(),
          tokens: tokens,
          onPlayerSelected: _onSinglePlayerSelected,
          onConfirm: _selectedPlayerId != null
              ? () => widget.onActionSubmitted(PlayerTarget(_selectedPlayerId!))
              : null,
          onSkip: widget.onSkip,
        );

      case NightActionType.swapWithCenter:
        return _SwapWithCenterAction(
          centerCardCount: widget.centerCardCount,
          tokens: tokens,
          onSelectionChanged: _onCardSelectionChanged,
          onConfirm: _selectedCardIndices.length == 1
              ? () => widget.onActionSubmitted(
                  CenterTargets(List.of(_selectedCardIndices)),
                )
              : null,
          onSkip: widget.onSkip,
        );

      case NightActionType.swapOthers:
        return _SwapOthersAction(
          players: _playersWithMultiSelection(),
          tokens: tokens,
          onPlayerSelected: _onTwoPlayersSelected,
          onConfirm: _selectedPlayerIds.length == 2
              ? () => widget.onActionSubmitted(
                  TwoPlayerTargets(
                    _selectedPlayerIds[0],
                    _selectedPlayerIds[1],
                  ),
                )
              : null,
          onSkip: widget.onSkip,
        );

      case NightActionType.seeTeam:
        return _SeeTeamAction(
          role: widget.playerRole,
          teammates: widget.players,
          tokens: tokens,
          onAcknowledge: () => widget.onActionSubmitted(NoAction()),
          onSkip: widget.onSkip,
        );

      case NightActionType.none:
        return _WaitingAction(
          tokens: tokens,
          onContinue: () => widget.onActionSubmitted(NoAction()),
          onSkip: widget.onSkip,
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Role identity strip — shared top section
// ---------------------------------------------------------------------------

class _RoleIdentityStrip extends StatelessWidget {
  final RoleId role;
  final AppTokens tokens;

  const _RoleIdentityStrip({required this.role, required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        RoleCard(roleId: role, small: true),
        SizedBox(width: tokens.spacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Your Role',
                style: tokens.typography.caption.copyWith(
                  color: tokens.colors.onDisabled,
                ),
              ),
              Text(
                role.displayName,
                style: tokens.typography.subheading.copyWith(
                  color: role.teamColor(tokens.colors),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared action-area scaffold
// ---------------------------------------------------------------------------

/// Wraps prompt text, an interactive body, and action buttons in a consistent
/// column layout. All action-type widgets delegate here for structure.
class _ActionScaffold extends StatelessWidget {
  final String promptText;
  final Widget body;
  final String confirmLabel;
  final VoidCallback? onConfirm;
  final VoidCallback? onSkip;
  final AppTokens tokens;

  const _ActionScaffold({
    required this.promptText,
    required this.body,
    required this.confirmLabel,
    required this.onConfirm,
    required this.onSkip,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Prompt text.
        Text(
          promptText,
          style: tokens.typography.body.copyWith(
            color: tokens.colors.onBackground,
          ),
          textAlign: TextAlign.center,
        ),

        SizedBox(height: tokens.spacing.lg),

        // Interactive content.
        Expanded(child: Center(child: body)),

        SizedBox(height: tokens.spacing.lg),

        // Confirm button — disabled until a valid selection exists.
        PrimaryButton(label: confirmLabel, onPressed: onConfirm),

        // Optional skip button.
        if (onSkip != null) ...[
          SizedBox(height: tokens.spacing.sm),
          PrimaryButton.outlined(label: 'Skip', onPressed: onSkip),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// peekPlayer — Seer option A
// ---------------------------------------------------------------------------

class _PeekPlayerAction extends StatelessWidget {
  final List<PlayerDisplay> players;
  final AppTokens tokens;
  final ValueChanged<String> onPlayerSelected;
  final VoidCallback? onConfirm;
  final VoidCallback? onSkip;

  const _PeekPlayerAction({
    required this.players,
    required this.tokens,
    required this.onPlayerSelected,
    required this.onConfirm,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return _ActionScaffold(
      promptText: 'Choose a player to look at their card',
      confirmLabel: 'Confirm',
      onConfirm: onConfirm,
      onSkip: onSkip,
      tokens: tokens,
      body: PlayerCircle(
        players: players,
        maxSelections: 1,
        onPlayerSelected: onPlayerSelected,
        showStatus: false,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// peekCenter — Seer option B / lone werewolf
// ---------------------------------------------------------------------------

class _PeekCenterAction extends StatelessWidget {
  final int centerCardCount;
  final AppTokens tokens;
  final ValueChanged<List<int>> onSelectionChanged;
  final VoidCallback? onConfirm;
  final VoidCallback? onSkip;

  const _PeekCenterAction({
    required this.centerCardCount,
    required this.tokens,
    required this.onSelectionChanged,
    required this.onConfirm,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return _ActionScaffold(
      promptText: 'Choose 2 center cards to look at',
      confirmLabel: 'Confirm',
      onConfirm: onConfirm,
      onSkip: onSkip,
      tokens: tokens,
      body: CenterCards(
        cardCount: centerCardCount,
        maxSelections: 2,
        onSelectionChanged: onSelectionChanged,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// swapWithPlayer — Robber
// ---------------------------------------------------------------------------

class _SwapWithPlayerAction extends StatelessWidget {
  final List<PlayerDisplay> players;
  final AppTokens tokens;
  final ValueChanged<String> onPlayerSelected;
  final VoidCallback? onConfirm;
  final VoidCallback? onSkip;

  const _SwapWithPlayerAction({
    required this.players,
    required this.tokens,
    required this.onPlayerSelected,
    required this.onConfirm,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return _ActionScaffold(
      promptText: 'Choose a player to swap cards with',
      confirmLabel: 'Confirm',
      onConfirm: onConfirm,
      onSkip: onSkip,
      tokens: tokens,
      body: PlayerCircle(
        players: players,
        maxSelections: 1,
        onPlayerSelected: onPlayerSelected,
        showStatus: false,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// swapWithCenter — Drunk
// ---------------------------------------------------------------------------

class _SwapWithCenterAction extends StatelessWidget {
  final int centerCardCount;
  final AppTokens tokens;
  final ValueChanged<List<int>> onSelectionChanged;
  final VoidCallback? onConfirm;
  final VoidCallback? onSkip;

  const _SwapWithCenterAction({
    required this.centerCardCount,
    required this.tokens,
    required this.onSelectionChanged,
    required this.onConfirm,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return _ActionScaffold(
      promptText: 'Choose a center card to swap your card with',
      confirmLabel: 'Confirm',
      onConfirm: onConfirm,
      onSkip: onSkip,
      tokens: tokens,
      body: CenterCards(
        cardCount: centerCardCount,
        maxSelections: 1,
        onSelectionChanged: onSelectionChanged,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// swapOthers — Troublemaker
// ---------------------------------------------------------------------------

class _SwapOthersAction extends StatelessWidget {
  final List<PlayerDisplay> players;
  final AppTokens tokens;
  final ValueChanged<String> onPlayerSelected;
  final VoidCallback? onConfirm;
  final VoidCallback? onSkip;

  const _SwapOthersAction({
    required this.players,
    required this.tokens,
    required this.onPlayerSelected,
    required this.onConfirm,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return _ActionScaffold(
      promptText: 'Choose 2 players to swap their cards',
      confirmLabel: 'Confirm',
      onConfirm: onConfirm,
      onSkip: onSkip,
      tokens: tokens,
      body: PlayerCircle(
        players: players,
        maxSelections: 2,
        onPlayerSelected: onPlayerSelected,
        showStatus: false,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// seeTeam — Werewolf, Mason, Minion
// ---------------------------------------------------------------------------

class _SeeTeamAction extends StatelessWidget {
  final RoleId role;
  final List<PlayerDisplay> teammates;
  final AppTokens tokens;
  final VoidCallback onAcknowledge;
  final VoidCallback? onSkip;

  const _SeeTeamAction({
    required this.role,
    required this.teammates,
    required this.tokens,
    required this.onAcknowledge,
    required this.onSkip,
  });

  String _promptText() {
    if (role == RoleId.werewolf) {
      return teammates.isEmpty
          ? 'You are the lone werewolf'
          : 'These are your fellow werewolves';
    }
    if (role == RoleId.mason) return 'These are your fellow masons';
    if (role == RoleId.minion) {
      return 'These are the werewolves (they don\'t know you)';
    }
    return 'Your team members';
  }

  @override
  Widget build(BuildContext context) {
    final String promptText = _promptText();
    final bool isLoneWerewolf = role == RoleId.werewolf && teammates.isEmpty;

    return _ActionScaffold(
      promptText: promptText,
      confirmLabel: 'Acknowledge',
      onConfirm: onAcknowledge,
      onSkip: onSkip,
      tokens: tokens,
      body: isLoneWerewolf
          ? _LoneWerewolfMessage(tokens: tokens)
          : _TeammateList(teammates: teammates, tokens: tokens),
    );
  }
}

/// Message shown when a werewolf has no fellow werewolves.
class _LoneWerewolfMessage extends StatelessWidget {
  final AppTokens tokens;

  const _LoneWerewolfMessage({required this.tokens});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _kMinActionHeight),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.remove_red_eye_outlined,
              size: 48,
              color: tokens.colors.werewolfTeam,
            ),
            SizedBox(height: tokens.spacing.md),
            Text(
              'No other werewolves.',
              style: tokens.typography.body.copyWith(
                color: tokens.colors.werewolfTeam,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// List of revealed teammate names.
class _TeammateList extends StatelessWidget {
  final List<PlayerDisplay> teammates;
  final AppTokens tokens;

  const _TeammateList({required this.teammates, required this.tokens});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _kMinActionHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final PlayerDisplay teammate in teammates)
            Padding(
              padding: EdgeInsets.symmetric(vertical: tokens.spacing.xs),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.md,
                  vertical: tokens.spacing.sm,
                ),
                decoration: BoxDecoration(
                  color: tokens.colors.surface,
                  borderRadius: tokens.radius.medium,
                  border: Border.all(color: tokens.colors.outline),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person,
                      size: 20,
                      color: tokens.colors.onSurface,
                    ),
                    SizedBox(width: tokens.spacing.sm),
                    Text(
                      teammate.displayName,
                      style: tokens.typography.body.copyWith(
                        color: tokens.colors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// none — Villager, Tanner, Hunter
// ---------------------------------------------------------------------------

class _WaitingAction extends StatelessWidget {
  final AppTokens tokens;
  final VoidCallback onContinue;
  final VoidCallback? onSkip;

  const _WaitingAction({
    required this.tokens,
    required this.onContinue,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return _ActionScaffold(
      promptText: 'The night is in progress. Close your eyes and wait.',
      confirmLabel: 'Continue',
      onConfirm: onContinue,
      onSkip: onSkip,
      tokens: tokens,
      body: _AtmosphericWaiting(tokens: tokens),
    );
  }
}

/// Atmospheric waiting screen body — decorative icon + flavour text.
class _AtmosphericWaiting extends StatelessWidget {
  final AppTokens tokens;

  const _AtmosphericWaiting({required this.tokens});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _kMinActionHeight),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.nights_stay_outlined,
              size: 64,
              color: tokens.colors.villageTeam,
            ),
            SizedBox(height: tokens.spacing.md),
            Text(
              'The village sleeps…',
              style: tokens.typography.subheading.copyWith(
                color: tokens.colors.onBackground.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
