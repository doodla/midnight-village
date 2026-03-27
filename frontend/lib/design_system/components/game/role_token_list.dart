import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/tokens/app_tokens_provider.dart';

/// Compact display of which roles are in the current game.
/// Public information shown in lobby and during game.
class RoleTokenList extends ConsumerWidget {
  final List<RoleId> rolesInGame;

  const RoleTokenList({super.key, required this.rolesInGame});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(activeThemeProvider);

    return Wrap(
      spacing: tokens.spacing.xs,
      runSpacing: tokens.spacing.xs,
      children: rolesInGame.map((role) => _RoleBadge(role: role)).toList(),
    );
  }
}

class _RoleBadge extends ConsumerWidget {
  final RoleId role;

  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(activeThemeProvider);
    final teamColor = role.teamColor(tokens.colors);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.sm,
        vertical: tokens.spacing.xs,
      ),
      decoration: BoxDecoration(
        color: tokens.colors.surface,
        borderRadius: tokens.radius.xl,
        border: Border.all(color: teamColor, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(role.placeholderIcon, size: 16.0, color: teamColor),
          SizedBox(width: tokens.spacing.xs),
          Text(
            role.displayName,
            style: tokens.typography.caption.copyWith(
              color: tokens.colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
