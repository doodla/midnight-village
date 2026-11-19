import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:midnight_village/design_system/components/core/primary_button.dart';
import 'package:midnight_village/design_system/components/game/game_timer.dart';
import 'package:midnight_village/design_system/components/game/player_circle.dart';
import 'package:midnight_village/design_system/models/player_display.dart';
import 'package:midnight_village/design_system/tokens/app_tokens.dart';
import 'package:midnight_village/design_system/tokens/app_tokens_provider.dart';

// ---------------------------------------------------------------------------
// Layout constants — dp values for layout/sizing, not visual tokens.
// ---------------------------------------------------------------------------

/// Vertical gap between the header and the player selection area.
const double _kHeaderGap = 24.0;

/// Vertical gap between the player circle and the timer row.
const double _kTimerGap = 32.0;

/// Size of the confirmation check icon in the post-vote state.
const double _kCheckIconSize = 64.0;

/// Vertical gap between icon and confirmation text in post-vote state.
const double _kConfirmationGap = 16.0;

// ---------------------------------------------------------------------------
// Public widget
// ---------------------------------------------------------------------------

/// Voting phase UI — manages target selection pre-vote and shows a privacy-safe
/// confirmation screen once the vote is locked.
///
/// ## Privacy guarantee (post-vote)
/// When [isLocked] is `true`, only a generic "Vote submitted" message and check
/// icon are rendered. The target player's name is intentionally NOT displayed
/// prominently because players sit together; someone glancing at the phone must
/// not learn who was voted for.
///
/// ## Internal state
/// Selected target ID is managed internally. The parent widget controls
/// [isLocked] externally; once locked, any internal selection is irrelevant.
class VoteSubmission extends ConsumerStatefulWidget {
  /// All players in the game. The widget applies selection state internally.
  final List<PlayerDisplay> players;

  /// Remaining time in the voting phase. Timer is displayed in both states.
  final Duration timeRemaining;

  /// Called with the selected player's ID when "Lock in your vote" is tapped.
  final ValueChanged<String> onVoteSubmitted;

  /// When `true`, displays the post-vote confirmation screen.
  /// When `false`, displays the voting selection UI.
  final bool isLocked;

  const VoteSubmission({
    super.key,
    required this.players,
    required this.timeRemaining,
    required this.onVoteSubmitted,
    required this.isLocked,
  });

  @override
  ConsumerState<VoteSubmission> createState() => _VoteSubmissionState();
}

class _VoteSubmissionState extends ConsumerState<VoteSubmission> {
  /// The ID of the currently selected player target. Null means no selection.
  String? _selectedPlayerId;

  void _onPlayerSelected(String playerId) {
    setState(() {
      // Tapping the already-selected player deselects them.
      _selectedPlayerId = _selectedPlayerId == playerId ? null : playerId;
    });
  }

  /// Players list with selection state applied from internal state.
  List<PlayerDisplay> get _playersWithSelection {
    return widget.players
        .map((p) => p.copyWith(isSelected: p.id == _selectedPlayerId))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(activeThemeProvider);

    return Padding(
      padding: EdgeInsets.all(tokens.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Main content area — expands to fill available vertical space.
          Expanded(
            child: widget.isLocked
                ? _VoteLockedView(tokens: tokens)
                : _VoteSelectionView(
                    players: _playersWithSelection,
                    tokens: tokens,
                    selectedPlayerId: _selectedPlayerId,
                    onPlayerSelected: _onPlayerSelected,
                    onConfirm: _selectedPlayerId != null
                        ? () => widget.onVoteSubmitted(_selectedPlayerId!)
                        : null,
                  ),
          ),

          SizedBox(height: _kTimerGap),

          // Timer is always visible — other players may still be voting.
          GameTimer(timeRemaining: widget.timeRemaining),

          SizedBox(height: tokens.spacing.md),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pre-vote: selection view
// ---------------------------------------------------------------------------

class _VoteSelectionView extends StatelessWidget {
  final List<PlayerDisplay> players;
  final String? selectedPlayerId;
  final ValueChanged<String> onPlayerSelected;

  /// Null when no player is selected — disables the confirm button.
  final VoidCallback? onConfirm;

  final AppTokens tokens;

  const _VoteSelectionView({
    required this.players,
    required this.selectedPlayerId,
    required this.onPlayerSelected,
    required this.onConfirm,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header instruction.
        Text(
          'Vote for who you think is a werewolf',
          style: tokens.typography.body.copyWith(
            color: tokens.colors.onBackground,
          ),
          textAlign: TextAlign.center,
        ),

        SizedBox(height: _kHeaderGap),

        // Player circle — expands to fill remaining space.
        Expanded(
          child: Center(
            child: PlayerCircle(
              players: players,
              maxSelections: 1,
              onPlayerSelected: onPlayerSelected,
              // Shows a dropped phone ("away"); everyone else looks as before.
              showStatus: true,
            ),
          ),
        ),

        SizedBox(height: tokens.spacing.lg),

        // Confirm button — disabled until a player is selected.
        PrimaryButton(label: 'Lock in your vote', onPressed: onConfirm),

        SizedBox(height: tokens.spacing.sm),

        // Warning text below the button.
        Text(
          'Your vote cannot be changed once submitted',
          style: tokens.typography.caption.copyWith(
            color: tokens.colors.onDisabled,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Post-vote: privacy-safe confirmation view
// ---------------------------------------------------------------------------

/// Shown after [VoteSubmission.isLocked] becomes `true`.
///
/// Deliberately generic — no player name is displayed prominently so that
/// someone glancing at the screen cannot learn the vote target.
class _VoteLockedView extends StatelessWidget {
  final AppTokens tokens;

  const _VoteLockedView({required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Check icon — indicates success without revealing who was voted for.
          Icon(
            Icons.check_circle,
            size: _kCheckIconSize,
            color: tokens.colors.primary,
          ),

          SizedBox(height: _kConfirmationGap),

          // Generic confirmation message — no target name.
          Text(
            'Vote submitted',
            style: tokens.typography.subheading.copyWith(
              color: tokens.colors.onBackground,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: tokens.spacing.sm),

          Text(
            'Your vote has been submitted.',
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
