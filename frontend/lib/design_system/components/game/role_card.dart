import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/tokens/app_tokens.dart';
import 'package:midnight_village/design_system/tokens/app_tokens_provider.dart';

/// Displays a game role card, either face-up (showing role info) or
/// face-down (showing a card-back design with no role information).
class RoleCard extends ConsumerWidget {
  final RoleId role;
  final bool isFaceUp;
  final double? width;

  const RoleCard({
    super.key,
    required this.role,
    this.isFaceUp = true,
    this.width,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(activeThemeProvider);
    final cardWidth = width ?? 120.0;

    return SizedBox(
      width: cardWidth,
      child: AspectRatio(
        aspectRatio: 1 / 1.4,
        child: isFaceUp ? _buildFaceUp(tokens, cardWidth) : _buildFaceDown(tokens),
      ),
    );
  }

  Widget _buildFaceUp(AppTokens tokens, double cardWidth) {
    final teamColor = role.teamColor(tokens.colors);

    return Card(
      color: tokens.colors.surface,
      elevation: tokens.elevation.raised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: teamColor, width: 2.0),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 4.0,
            decoration: BoxDecoration(
              color: teamColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10.0)),
            ),
          ),
          const Spacer(),
          Icon(role.placeholderIcon, size: 48.0, color: teamColor),
          SizedBox(height: tokens.spacing.s),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: tokens.spacing.xs),
            child: Text(
              role.displayName,
              style: tokens.typography.subheading.copyWith(
                color: tokens.colors.onSurface,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildFaceDown(AppTokens tokens) {
    return Card(
      color: tokens.colors.cardBack,
      elevation: tokens.elevation.raised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: tokens.colors.outline, width: 1.0),
      ),
      child: Center(
        child: Icon(
          Icons.nightlight_round,
          size: 40.0,
          color: tokens.colors.outline,
        ),
      ),
    );
  }
}
