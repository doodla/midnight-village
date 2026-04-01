import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/components/core/mv_dialog.dart';
import '../../../design_system/components/core/primary_button.dart';
import '../../../design_system/components/game/game_timer.dart';
import '../../../design_system/components/game/role_token_list.dart';
import '../../../design_system/models/role.dart';
import '../../../design_system/tokens/app_tokens_provider.dart';
import '../domain/night_state.dart';
import 'timer_provider.dart';

// ---------------------------------------------------------------------------
// Layout constants
// ---------------------------------------------------------------------------

const double _kSectionGap = 24.0;

/// Discussion phase view — the social screen players see while talking in person.
///
/// Shows a prominent countdown timer, the roles in play (public info to help
/// discussion), and a host-only "End Discussion" control with confirmation.
///
/// The ambient background is provided by the parent [GameContainerScreen].
class DiscussionView extends ConsumerWidget {
  /// Server-provided deadline for the discussion phase timer.
  final DateTime? deadline;

  /// Roles present in the current game (public info shown to all players).
  final List<RoleInGame> rolesInGame;

  /// Whether the current player is the game host.
  final bool isHost;

  /// Called when the host confirms ending the discussion early.
  final VoidCallback onEndDiscussion;

  const DiscussionView({
    super.key,
    required this.deadline,
    required this.rolesInGame,
    required this.isHost,
    required this.onEndDiscussion,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(activeThemeProvider);
    final timerAsync = ref.watch(gameTimerProvider(deadline));
    final timeRemaining = timerAsync.asData?.value ?? Duration.zero;

    return Padding(
      padding: EdgeInsets.all(tokens.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Prominent countdown timer.
          GameTimer(timeRemaining: timeRemaining),

          SizedBox(height: _kSectionGap),

          // Roles in play — public info to help discussion.
          Text(
            'Roles in this game',
            style: tokens.typography.subheading.copyWith(
              color: tokens.colors.onBackground,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: tokens.spacing.sm),

          Center(child: RoleTokenList(rolesInGame: _toRoleIdList(rolesInGame))),

          const Spacer(),

          // Host-only "End Discussion" control.
          if (isHost)
            PrimaryButton(
              label: 'End Discussion',
              onPressed: () => _showEndDiscussionDialog(context),
            ),

          SizedBox(height: tokens.spacing.md),
        ],
      ),
    );
  }

  /// Converts a list of [RoleInGame] entries (with string role IDs and counts)
  /// to a flat list of [RoleId] enum values for [RoleTokenList].
  List<RoleId> _toRoleIdList(List<RoleInGame> roles) {
    return roles.expand((r) {
      final roleId = RoleId.values.byName(r.role);
      return List.generate(r.count, (_) => roleId);
    }).toList();
  }

  void _showEndDiscussionDialog(BuildContext context) {
    MvDialog.show(
      context,
      MvDialog.confirmation(
        title: 'End Discussion Early?',
        body: 'End discussion early? Players are still talking.',
        confirmLabel: 'End Early',
        onConfirm: () {
          Navigator.of(context).pop();
          onEndDiscussion();
        },
        onCancel: () => Navigator.of(context).pop(),
      ),
    );
  }
}
