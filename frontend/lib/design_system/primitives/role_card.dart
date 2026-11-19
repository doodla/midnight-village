import 'package:flutter/material.dart';

import '../models/role.dart';
import '../skin/skin.dart';
import 'count_badge.dart';
import 'cut_paper.dart';
import 'fit_line.dart';
import 'paper_card.dart';
import 'tag_chip.dart';

/// [RoleCard]'s sizes.
enum RoleCardSize {
  /// A thumbnail in a row of the deck (the talk screen's "in the deck").
  mini,

  /// A card in the deck builder's grid, named underneath; as wide as its
  /// parent allows.
  small,

  /// The card itself: portrait, name, team and what it does.
  large,
}

/// A role as a picture. [count] is how many are in the deck (shown when it
/// says something: above 1 on a mini card, above 0 on a small one). A small
/// card that is not [lit] is in the box, not the deck: dimmed. The name is
/// never broken: a long name ("Doppelganger") is set smaller instead.
class RoleCard extends StatelessWidget {
  const RoleCard({
    super.key,
    required this.role,
    this.size = RoleCardSize.small,
    this.count = 0,
    this.lit = true,
    this.team,
    this.description,
    this.semanticLabel,
    this.onTap,
    this.onLongPress,
  });

  final RoleId role;
  final RoleCardSize size;
  final int count;
  final bool lit;

  /// The large card's team tag ("Village team"); a Werewolf-team role's tag
  /// is drawn as danger.
  final String? team;

  /// The large card's text: what the role does.
  final String? description;

  /// Read out instead of the role's name.
  final String? semanticLabel;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  static const _miniSize = Size(50, 68);

  /// Width over height of a portrait in the grid (the mocks' 76.5 x 100).
  static const _gridAspect = 0.765;

  /// Width over height of the large card's portrait (286 x 318).
  static const _largeAspect = 0.9;

  @override
  Widget build(BuildContext context) {
    final card = switch (size) {
      RoleCardSize.mini => _mini(context),
      RoleCardSize.small => _small(context),
      RoleCardSize.large => _large(context),
    };
    return Semantics(
      label: semanticLabel ?? role.displayName,
      button: onTap != null,
      selected: size == RoleCardSize.small && onTap != null ? lit : null,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: card,
      ),
    );
  }

  Widget _portrait(
    BuildContext context, {
    required double radius,
    Color? ringColor,
    double ringWidth = 0,
    bool dim = false,
  }) {
    final skin = context.skin;
    final corners = BorderRadius.circular(radius);
    final image = skin.art.role(role);
    return AnimatedOpacity(
      duration: skin.motion.quick,
      opacity: dim ? skin.dimmed : 1,
      child: Container(
        foregroundDecoration: ringColor == null
            ? null
            : ringDecoration(
                color: ringColor,
                width: ringWidth,
                radius: corners,
              ),
        child: ClipRRect(
          borderRadius: corners,
          child: Image(
            image: image.provider,
            fit: BoxFit.cover,
            alignment: image.focus,
          ),
        ),
      ),
    );
  }

  Widget _mini(BuildContext context) {
    final skin = context.skin;
    return SizedBox.fromSize(
      size: _miniSize,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          _portrait(
            context,
            radius: skin.shape.radiusSmall,
            ringColor: context.ground.text,
            ringWidth: skin.shape.ring,
            dim: !lit,
          ),
          if (count > 1)
            Positioned(
              right: -skin.spacing.xs,
              top: -skin.spacing.xs,
              child: CountBadge('×$count'),
            ),
        ],
      ),
    );
  }

  Widget _small(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    final portrait = AspectRatio(
      aspectRatio: _gridAspect,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          _portrait(
            context,
            radius: skin.shape.radius,
            ringColor: lit ? ground.selection : ground.hairline,
            ringWidth: lit ? skin.shape.selectedRing : skin.shape.ring,
            dim: !lit,
          ),
          if (lit && count > 0)
            Positioned(
              right: -skin.spacing.xs,
              top: -skin.spacing.sm,
              child: CountBadge('$count', size: 24, lifted: true),
            ),
        ],
      ),
    );
    // In a cell of fixed height (a grid) the portrait gives way to the name.
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (constraints.hasBoundedHeight)
            Flexible(child: portrait)
          else
            portrait,
          SizedBox(height: skin.spacing.xs),
          FitLine(
            role.displayName,
            style: skin.typography.badge.copyWith(
              color: lit ? ground.text : ground.faintText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _large(BuildContext context) {
    final skin = context.skin;
    return PaperCard(
      lift: PaperLift.heroSlab,
      tilted: true,
      padding: EdgeInsets.fromLTRB(
        skin.spacing.md,
        skin.spacing.md,
        skin.spacing.md,
        skin.spacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: _largeAspect,
            child: _portrait(context, radius: skin.shape.radiusTiny),
          ),
          SizedBox(height: skin.spacing.md),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: skin.spacing.sm),
            // The tag goes under the name when both do not fit on a line.
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: skin.spacing.sm,
              runSpacing: skin.spacing.sm,
              children: [
                FitLine(role.displayName, style: skin.typography.display),
                if (team case final team?)
                  TagChip(team, danger: role.team == TeamId.werewolf),
              ],
            ),
          ),
          if (description case final description?) ...[
            SizedBox(height: skin.spacing.md),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: skin.spacing.sm),
              child: Text(description, style: skin.typography.bodyLarge),
            ),
          ],
        ],
      ),
    );
  }
}
