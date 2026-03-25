import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/tokens/app_tokens_provider.dart';

/// Layout constants for RoleCard dimensions.
const double _kCardWidthNormal = 80.0;
const double _kCardHeightNormal = 112.0;
const double _kCardWidthSmall = 56.0;
const double _kCardHeightSmall = 80.0;
const double _kCardBorderRadius = 8.0;
const double _kIconSizeNormal = 32.0;
const double _kIconSizeSmall = 22.0;

/// Shows a role card either face-up or face-down.
///
/// When [roleId] is non-null the card is face-up, displaying the role icon
/// and role name in the role's team color. When [roleId] is null the card
/// is face-down using the [AppColorTokens.cardBack] background.
///
/// The [small] flag switches to a compact size variant suitable for inline use
/// (e.g. the role identity strip at the top of [NightActionPrompt]).
class RoleCard extends ConsumerWidget {
  /// The role to display. Pass null to show the card back.
  final RoleId? roleId;

  /// When true, renders in a compact size suitable for inline / header use.
  final bool small;

  const RoleCard({super.key, this.roleId, this.small = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(activeThemeProvider);

    final double cardWidth = small ? _kCardWidthSmall : _kCardWidthNormal;
    final double cardHeight = small ? _kCardHeightSmall : _kCardHeightNormal;
    final double iconSize = small ? _kIconSizeSmall : _kIconSizeNormal;

    if (roleId == null) {
      // Face-down: plain card back.
      return Container(
        width: cardWidth,
        height: cardHeight,
        decoration: BoxDecoration(
          color: tokens.colors.cardBack,
          borderRadius: BorderRadius.circular(_kCardBorderRadius),
          border: Border.all(color: tokens.colors.outline, width: 1.5),
        ),
      );
    }

    final RoleId role = roleId!;
    final Color teamColor = role.teamColor(tokens.colors);

    return Container(
      width: cardWidth,
      height: cardHeight,
      decoration: BoxDecoration(
        color: tokens.colors.surface,
        borderRadius: BorderRadius.circular(_kCardBorderRadius),
        border: Border.all(color: teamColor, width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(role.placeholderIcon, size: iconSize, color: teamColor),
          SizedBox(height: tokens.spacing.xs),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: tokens.spacing.xs),
            child: Text(
              role.displayName,
              style: (small ? tokens.typography.caption : tokens.typography.label)
                  .copyWith(color: teamColor),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
