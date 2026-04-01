import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:midnight_village/design_system/components/game/role_card.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/tokens/app_tokens_provider.dart';
import 'package:midnight_village/features/game/domain/game_session_state.dart';
import 'package:midnight_village/features/game/domain/night_state.dart';

/// Displays the result of a player's night action.
///
/// Reads `result.revealedInfo['action_type']` to determine which result layout
/// to show. The `action_type` key is injected by [GameNotifier._handleActionResult]
/// from the WebSocket event.
///
/// When the result is a lone-werewolf `see_team` result (empty teammates for
/// Werewolf role), [onLoneWerewolfDetected] is called immediately in [build],
/// so the container can transition to [NightSubView.loneWerewolfPeek].
class NightResultView extends ConsumerWidget {
  /// The action result to display.
  final ActionResult result;

  /// All players in the game — used to resolve display names when needed.
  final List<GamePlayer> players;

  /// Called when a lone-werewolf see_team result is detected.
  ///
  /// The [GameContainerScreen] wires this to
  /// [GameNotifier.transitionToLoneWerewolfPeek].
  final VoidCallback? onLoneWerewolfDetected;

  const NightResultView({
    super.key,
    required this.result,
    required this.players,
    this.onLoneWerewolfDetected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(activeThemeProvider);
    final info = result.revealedInfo;
    final actionType = info['action_type'] as String? ?? '';

    return Padding(
      padding: EdgeInsets.all(tokens.spacing.lg),
      child: Center(child: _buildContent(context, actionType, info, tokens)),
    );
  }

  Widget _buildContent(
    BuildContext context,
    String actionType,
    Map<String, dynamic> info,
    dynamic tokens,
  ) {
    return switch (actionType) {
      'peek_player' => _PeekPlayerResult(info: info, tokens: tokens),
      'peek_center' => _PeekCenterResult(info: info, tokens: tokens),
      'swap_with_player' => _SwapWithPlayerResult(info: info, tokens: tokens),
      'swap_with_center' => _SwapWithCenterResult(info: info, tokens: tokens),
      'swap_others' => _SwapOthersResult(info: info, tokens: tokens),
      'see_team' => _SeeTeamResult(
        info: info,
        tokens: tokens,
        onLoneWerewolfDetected: onLoneWerewolfDetected,
      ),
      'insomniac' => _InsomniacResult(info: info, tokens: tokens),
      _ => _UnknownResult(actionType: actionType, tokens: tokens),
    };
  }
}

// ---------------------------------------------------------------------------
// peek_player result
// ---------------------------------------------------------------------------

class _PeekPlayerResult extends StatelessWidget {
  final Map<String, dynamic> info;
  final dynamic tokens;

  const _PeekPlayerResult({required this.info, required this.tokens});

  @override
  Widget build(BuildContext context) {
    final targetName = info['target_name'] as String? ?? 'Unknown';
    final roleStr = info['role'] as String?;
    final roleId = roleStr != null ? _parseRoleId(roleStr) : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'You looked at $targetName\'s card',
          style: tokens.typography.subheading.copyWith(
            color: tokens.colors.onBackground,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: tokens.spacing.xl),
        RoleCard(roleId: roleId),
        if (roleId != null) ...[
          SizedBox(height: tokens.spacing.md),
          Text(
            roleId.displayName,
            style: tokens.typography.body.copyWith(
              color: roleId.teamColor(tokens.colors),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// peek_center result
// ---------------------------------------------------------------------------

class _PeekCenterResult extends StatelessWidget {
  final Map<String, dynamic> info;
  final dynamic tokens;

  const _PeekCenterResult({required this.info, required this.tokens});

  @override
  Widget build(BuildContext context) {
    final rolesList = info['roles'] as List<dynamic>? ?? [];
    final roleIds = rolesList.map((r) => _parseRoleId(r as String)).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'You looked at center cards',
          style: tokens.typography.subheading.copyWith(
            color: tokens.colors.onBackground,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: tokens.spacing.xl),
        Wrap(
          spacing: tokens.spacing.md,
          children: [for (final roleId in roleIds) RoleCard(roleId: roleId)],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// swap_with_player result (Robber)
// ---------------------------------------------------------------------------

class _SwapWithPlayerResult extends StatelessWidget {
  final Map<String, dynamic> info;
  final dynamic tokens;

  const _SwapWithPlayerResult({required this.info, required this.tokens});

  @override
  Widget build(BuildContext context) {
    final targetName = info['target_name'] as String? ?? 'Unknown';
    final newRoleStr = info['new_role'] as String?;
    final newRoleId = newRoleStr != null ? _parseRoleId(newRoleStr) : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'You swapped with $targetName. You are now the',
          style: tokens.typography.subheading.copyWith(
            color: tokens.colors.onBackground,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: tokens.spacing.xl),
        RoleCard(roleId: newRoleId),
        if (newRoleId != null) ...[
          SizedBox(height: tokens.spacing.md),
          Text(
            newRoleId.displayName,
            style: tokens.typography.heading.copyWith(
              color: newRoleId.teamColor(tokens.colors),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// swap_with_center result (Drunk)
// ---------------------------------------------------------------------------

class _SwapWithCenterResult extends StatelessWidget {
  final Map<String, dynamic> info;
  final dynamic tokens;

  const _SwapWithCenterResult({required this.info, required this.tokens});

  @override
  Widget build(BuildContext context) {
    final cardIndex = info['card_index'] as int?;
    final label = cardIndex != null
        ? 'center card ${cardIndex + 1}'
        : 'a center card';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'You swapped your card with $label.',
          style: tokens.typography.subheading.copyWith(
            color: tokens.colors.onBackground,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: tokens.spacing.md),
        Text(
          'Your card may have changed.',
          style: tokens.typography.body.copyWith(
            color: tokens.colors.onBackground.withValues(alpha: 0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// swap_others result (Troublemaker)
// ---------------------------------------------------------------------------

class _SwapOthersResult extends StatelessWidget {
  final Map<String, dynamic> info;
  final dynamic tokens;

  const _SwapOthersResult({required this.info, required this.tokens});

  @override
  Widget build(BuildContext context) {
    final p1 = info['player1_name'] as String? ?? 'Unknown';
    final p2 = info['player2_name'] as String? ?? 'Unknown';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'You swapped $p1 and $p2\'s cards.',
          style: tokens.typography.subheading.copyWith(
            color: tokens.colors.onBackground,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// see_team result (Werewolf, Mason, Minion)
// ---------------------------------------------------------------------------

class _SeeTeamResult extends StatelessWidget {
  final Map<String, dynamic> info;
  final dynamic tokens;
  final VoidCallback? onLoneWerewolfDetected;

  const _SeeTeamResult({
    required this.info,
    required this.tokens,
    this.onLoneWerewolfDetected,
  });

  @override
  Widget build(BuildContext context) {
    final roleActingAs = info['role_acting_as'] as String? ?? '';
    final teammateNames =
        (info['teammate_names'] as List<dynamic>?)?.cast<String>() ?? [];

    final roleUpper = roleActingAs.toUpperCase();
    final isWerewolf = roleUpper.contains('WEREWOLF');
    final isMason = roleUpper.contains('MASON');
    // Minion is the default if not werewolf or mason.

    if (isWerewolf && teammateNames.isEmpty) {
      // Lone Werewolf — trigger transition callback after build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onLoneWerewolfDetected?.call();
      });
      return _buildTeamDisplay(
        headingText: 'You are the lone Werewolf!',
        subText: 'You may peek at one center card.',
        names: const [],
        tokens: tokens,
      );
    }

    if (isWerewolf) {
      return _buildTeamDisplay(
        headingText: 'Your fellow werewolves:',
        subText: null,
        names: teammateNames,
        tokens: tokens,
      );
    }

    if (isMason) {
      if (teammateNames.isEmpty) {
        return _buildTeamDisplay(
          headingText: 'You are the only Mason.',
          subText: null,
          names: const [],
          tokens: tokens,
        );
      }
      return _buildTeamDisplay(
        headingText: 'Your fellow Mason:',
        subText: null,
        names: teammateNames,
        tokens: tokens,
      );
    }

    // Minion.
    if (teammateNames.isEmpty) {
      return _buildTeamDisplay(
        headingText: 'There are no werewolves.',
        subText: 'Good luck!',
        names: const [],
        tokens: tokens,
      );
    }
    return _buildTeamDisplay(
      headingText: 'The werewolves are:',
      subText: null,
      names: teammateNames,
      tokens: tokens,
    );
  }

  Widget _buildTeamDisplay({
    required String headingText,
    required String? subText,
    required List<String> names,
    required dynamic tokens,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          headingText,
          style: tokens.typography.subheading.copyWith(
            color: tokens.colors.onBackground,
          ),
          textAlign: TextAlign.center,
        ),
        if (subText != null) ...[
          SizedBox(height: tokens.spacing.sm),
          Text(
            subText,
            style: tokens.typography.body.copyWith(
              color: tokens.colors.onBackground.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
        if (names.isNotEmpty) ...[
          SizedBox(height: tokens.spacing.lg),
          for (final name in names)
            Padding(
              padding: EdgeInsets.symmetric(vertical: tokens.spacing.xs),
              child: Text(
                name,
                style: tokens.typography.body.copyWith(
                  color: tokens.colors.onBackground,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Insomniac result
// ---------------------------------------------------------------------------

class _InsomniacResult extends StatelessWidget {
  final Map<String, dynamic> info;
  final dynamic tokens;

  const _InsomniacResult({required this.info, required this.tokens});

  @override
  Widget build(BuildContext context) {
    final currentRoleStr = info['current_role'] as String?;
    final currentRoleId = currentRoleStr != null
        ? _parseRoleId(currentRoleStr)
        : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Your card is now:',
          style: tokens.typography.subheading.copyWith(
            color: tokens.colors.onBackground,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: tokens.spacing.xl),
        RoleCard(roleId: currentRoleId),
        if (currentRoleId != null) ...[
          SizedBox(height: tokens.spacing.md),
          Text(
            currentRoleId.displayName,
            style: tokens.typography.heading.copyWith(
              color: currentRoleId.teamColor(tokens.colors),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Fallback for unknown action types
// ---------------------------------------------------------------------------

class _UnknownResult extends StatelessWidget {
  final String actionType;
  final dynamic tokens;

  const _UnknownResult({required this.actionType, required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Action complete.',
      style: tokens.typography.body.copyWith(color: tokens.colors.onBackground),
      textAlign: TextAlign.center,
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

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
