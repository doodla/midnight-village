import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:midnight_village/design_system/components/core/mv_button.dart';
import 'package:midnight_village/design_system/components/game/role_card.dart';
import 'package:midnight_village/design_system/models/game_result.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/tokens/app_tokens_provider.dart';

/// Displays the end-of-game results screen.
///
/// Shows:
/// - Winning team announcement(s) in team-specific colors
/// - A per-player reveal: name, role (with swap arrows if changed), team dot,
///   eliminated indicator, winner highlight, and a small [RoleCard]
/// - Optional "Play Again" and "Return to Lobby" action buttons
class GameResults extends ConsumerWidget {
  /// The complete game result to display.
  final GameResult result;

  /// If non-null, renders a "Play Again" primary button that calls this.
  final VoidCallback? onPlayAgain;

  /// If non-null, renders a "Return to Lobby" secondary button that calls this.
  final VoidCallback? onReturnToLobby;

  const GameResults({
    super.key,
    required this.result,
    this.onPlayAgain,
    this.onReturnToLobby,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(activeThemeProvider);

    return SingleChildScrollView(
      padding: EdgeInsets.all(tokens.spacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ----------------------------------------------------------------
          // Win announcement
          // ----------------------------------------------------------------
          _WinAnnouncement(winningTeams: result.winningTeams),

          SizedBox(height: tokens.spacing.l),

          // ----------------------------------------------------------------
          // Player reveal list
          // ----------------------------------------------------------------
          Text(
            'Player Roles',
            style: tokens.typography.heading.copyWith(
              color: tokens.colors.onBackground,
            ),
          ),
          SizedBox(height: tokens.spacing.s),
          ...result.players.map(
            (player) => Padding(
              padding: EdgeInsets.only(bottom: tokens.spacing.s),
              child: _PlayerResultRow(player: player),
            ),
          ),

          SizedBox(height: tokens.spacing.l),

          // ----------------------------------------------------------------
          // Action buttons
          // ----------------------------------------------------------------
          if (onPlayAgain != null)
            MvButton(
              label: 'Play Again',
              onPressed: onPlayAgain,
              variant: MvButtonVariant.primary,
            ),

          if (onPlayAgain != null && onReturnToLobby != null)
            SizedBox(height: tokens.spacing.s),

          if (onReturnToLobby != null)
            MvButton(
              label: 'Return to Lobby',
              onPressed: onReturnToLobby,
              variant: MvButtonVariant.secondary,
            ),

          SizedBox(height: tokens.spacing.m),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Win announcement sub-widget
// ---------------------------------------------------------------------------

/// Renders the winning team(s) using [displayHeading] typography.
/// Each team is shown in its own team color on a separate line.
/// If [winningTeams] is empty, shows "Nobody wins!" in [onSurface] color.
class _WinAnnouncement extends ConsumerWidget {
  final List<TeamId> winningTeams;

  const _WinAnnouncement({required this.winningTeams});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(activeThemeProvider);

    if (winningTeams.isEmpty) {
      return Text(
        'Nobody wins!',
        style: tokens.typography.displayHeading.copyWith(
          color: tokens.colors.onSurface,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: winningTeams.map((team) {
        final color = switch (team) {
          TeamId.werewolf => tokens.colors.werewolfTeam,
          TeamId.village => tokens.colors.villageTeam,
          TeamId.independent => tokens.colors.independentTeam,
        };
        final label = switch (team) {
          TeamId.werewolf => 'Werewolves win!',
          TeamId.village => 'Village wins!',
          TeamId.independent => 'Tanner wins!',
        };
        return Text(
          label,
          style: tokens.typography.displayHeading.copyWith(color: color),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Per-player result row
// ---------------------------------------------------------------------------

/// A single row in the player results list.
///
/// Layout (left → right):
///   [team color dot] [RoleCard small] [name + role text + eliminated tag] [winner highlight border]
class _PlayerResultRow extends ConsumerWidget {
  final PlayerResult player;

  const _PlayerResultRow({required this.player});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(activeThemeProvider);

    final teamColor = player.finalRole.teamColor(tokens.colors);
    final roleLabel = _buildRoleLabel(player);

    return Container(
      padding: EdgeInsets.all(tokens.spacing.s),
      decoration: BoxDecoration(
        color: tokens.colors.surface,
        borderRadius: BorderRadius.circular(8.0),
        border: player.isWinner
            ? Border.all(color: tokens.colors.primary, width: 2.0)
            : Border.all(color: tokens.colors.outline, width: 1.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Team color dot.
          Container(
            width: 10.0,
            height: 10.0,
            decoration: BoxDecoration(
              color: teamColor,
              shape: BoxShape.circle,
            ),
          ),

          SizedBox(width: tokens.spacing.s),

          // Small RoleCard (face-up with final role).
          RoleCard(roleId: player.finalRole, small: true),

          SizedBox(width: tokens.spacing.s),

          // Name + role text + eliminated indicator.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Player name row with optional eliminated indicator.
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        player.displayName,
                        style: tokens.typography.subheading.copyWith(
                          color: tokens.colors.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (player.isEliminated) ...[
                      SizedBox(width: tokens.spacing.xs),
                      Text(
                        '(eliminated)',
                        style: tokens.typography.caption.copyWith(
                          color: tokens.colors.error,
                        ),
                      ),
                    ],
                  ],
                ),

                SizedBox(height: tokens.spacing.xs),

                // Role display line.
                Text(
                  roleLabel,
                  style: tokens.typography.caption.copyWith(
                    color: teamColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the role label string for a player:
  /// - Doppelganger who became another role → "Doppelganger (as FinalRole)"
  /// - Role swapped (original != final, not doppelganger) → "OriginalRole → FinalRole"
  /// - No change → just "RoleName"
  String _buildRoleLabel(PlayerResult player) {
    if (player.originalRole == RoleId.doppelganger &&
        player.finalRole != RoleId.doppelganger) {
      return 'Doppelganger (as ${player.finalRole.displayName})';
    }
    if (player.originalRole != player.finalRole) {
      return '${player.originalRole.displayName} → ${player.finalRole.displayName}';
    }
    return player.finalRole.displayName;
  }
}
