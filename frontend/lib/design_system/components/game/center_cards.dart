import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:midnight_village/design_system/components/game/role_card.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/tokens/app_tokens_provider.dart';

/// Displays the center cards — typically face-down during play,
/// optionally revealed during Seer peek or at game end.
class CenterCards extends ConsumerWidget {
  final int count;
  final List<RoleId>? revealedRoles;

  const CenterCards({
    super.key,
    this.count = 3,
    this.revealedRoles,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(activeThemeProvider);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isRevealed = revealedRoles != null && index < revealedRoles!.length;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s / 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RoleCard(
                role: isRevealed ? revealedRoles![index] : RoleId.villager,
                isFaceUp: isRevealed,
                width: 80.0,
              ),
              SizedBox(height: tokens.spacing.xs),
              Text(
                'Center ${index + 1}',
                style: tokens.typography.caption.copyWith(
                  color: tokens.colors.onSurface,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
