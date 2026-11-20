import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../layout/space.dart';
import '../models/role.dart';
import '../skin/skin.dart';
import '../skin/skin_tilt.dart';
import 'art_picture.dart';
import 'count_badge.dart';
import 'cut_paper.dart';
import 'fit_line.dart';
import 'paper_card.dart';
import 'tag_chip.dart';

/// [RoleCard]'s sizes. The three thumbnails are at most their mock size and
/// shrink, keeping their shape, when their parent is narrower.
enum RoleCardSize {
  /// In the deck link at the table (S02): 30 x 40.
  thumbSmall(Size(30, 40)),

  /// Beside "Your turn" (S06): 44 x 58.
  thumb(Size(44, 58)),

  /// In the deck row of the talk (S08): 50 x 68.
  mini(Size(50, 68)),

  /// A card in the deck builder's grid, named underneath; as wide as its
  /// parent allows.
  small(null),

  /// The card itself: portrait, name, team and what it does.
  large(null);

  const RoleCardSize(this.thumbnail);

  /// A thumbnail's mock size; null for the cards that fill their parent.
  final Size? thumbnail;
}

/// A role as a picture. [count] is how many are in the deck (shown when it
/// says something: above 1 on a thumbnail, above 0 on a small card). A small
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
    this.tilt = Tilt.card,
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

  /// The large card's tilt.
  final Tilt tilt;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// The large card's portrait in the mock (S04: a 310-wide card). The art
  /// for it is precached at this size (`secretArt`).
  static const largePortrait = Size(286, 318);

  /// The large card's width in the mock; it is never wider.
  static const largeWidth = 310.0;

  /// Width over height of a portrait in the grid (the mocks' 76.5 x 100).
  static const _gridAspect = 0.765;

  @override
  Widget build(BuildContext context) {
    final card = switch (size) {
      RoleCardSize.thumbSmall ||
      RoleCardSize.thumb ||
      RoleCardSize.mini => _thumbnail(context, size.thumbnail!),
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
    Color? insetRing,
    bool dim = false,
    bool hero = false,
  }) {
    final skin = context.skin;
    final corners = BorderRadius.circular(radius);
    return AnimatedOpacity(
      duration: Motion.quick,
      opacity: dim ? skin.dimmed : 1,
      child: Container(
        foregroundDecoration: ringColor != null
            ? ringDecoration(
                color: ringColor,
                width: ringWidth,
                radius: corners,
              )
            : insetRing != null
            ? BoxDecoration(
                borderRadius: corners,
                border: Border.all(color: insetRing, width: skin.shape.ring),
              )
            : null,
        child: ClipRRect(
          borderRadius: corners,
          child: ArtPicture(skin.art.role(role, hero: hero)),
        ),
      ),
    );
  }

  Widget _thumbnail(BuildContext context, Size mock) {
    final skin = context.skin;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? mock.width.clamp(0.0, constraints.maxWidth)
            : mock.width;
        return SizedBox(
          width: width,
          height: width * mock.height / mock.width,
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
                  right: -Space.xs,
                  top: -Space.xs,
                  child: CountBadge('×$count'),
                ),
            ],
          ),
        );
      },
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
              right: -5,
              top: -7,
              child: CountBadge('$count', size: BadgeSize.large),
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
          const SizedBox(height: 5),
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
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: largeWidth),
      child: PaperCard(
        lift: PaperLift.heroSlab,
        tilt: tilt,
        padding: const EdgeInsets.fromLTRB(
          Space.md,
          Space.md,
          Space.md,
          Space.lgPlus + 2,
        ),
        child: Builder(
          builder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            spacing: Space.md,
            children: [
              AspectRatio(
                aspectRatio: largePortrait.aspectRatio,
                child: _portrait(
                  context,
                  radius: skin.shape.radiusTiny,
                  // The mock's faint inset line round the picture.
                  insetRing: context.ground.text.withValues(alpha: 0.12),
                  hero: true,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                // The tag goes under the name when both do not fit on a line.
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: Space.sm,
                  runSpacing: Space.sm,
                  children: [
                    FitLine(role.displayName, style: skin.typography.heroRole),
                    if (team case final team?)
                      role.team == TeamId.werewolf
                          ? TagChip.danger(team)
                          : TagChip(team),
                  ],
                ),
              ),
              if (description case final description?)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                  child: Text(description, style: skin.typography.bodyLarge),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A role's portrait alone, 3 by 4, as wide as [width] at most:
/// - plain, set into a card (the dead player's role, S10);
/// - [framed]: ringed in ink and lifted (the role sheet, S03b);
/// - [arched]: in a paper frame with an arched top, tilted (the winner, S11);
///   the arch is as round as the skin's `archRoundness`.
class RolePortrait extends StatelessWidget {
  const RolePortrait({
    super.key,
    required this.role,
    required this.width,
    this.framed = false,
    this.semanticLabel,
  }) : arched = false,
       tilt = Tilt.none;

  const RolePortrait.arched({
    super.key,
    required this.role,
    required this.width,
    this.tilt = Tilt.hero,
    this.semanticLabel,
  }) : arched = true,
       framed = false;

  /// The mocks' widths: the dead player's (S10), the sheet's (S03b) and the
  /// winner's (S11).
  static const count = 120.0;
  static const sheet = 132.0;
  static const winner = 160.0;

  final RoleId role;
  final double width;
  final bool framed;
  final bool arched;
  final Tilt tilt;
  final String? semanticLabel;

  static const _aspect = 3 / 4;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    final picture = ArtPicture(skin.art.role(role));
    final Widget body;
    if (arched) {
      final arch = Radius.circular(
        skin.shape.corner(width, skin.shape.archRoundness, square: 0),
      );
      final top = BorderRadius.vertical(
        top: arch,
        bottom: Radius.circular(skin.shape.radius),
      );
      body = Container(
        padding: const EdgeInsets.all(Space.smPlus),
        decoration: cutPaper(
          context,
          fill: ground.paper,
          radius: top,
          elevation: ground.elevation.slab,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(math.max(0, arch.x - Space.smPlus)),
            bottom: Radius.circular(skin.shape.radiusTiny),
          ),
          child: AspectRatio(aspectRatio: _aspect, child: picture),
        ),
      );
    } else {
      final corners = BorderRadius.circular(
        framed ? skin.shape.radiusSmall : skin.shape.radiusTiny,
      );
      body = Container(
        decoration: framed
            ? BoxDecoration(
                borderRadius: corners,
                boxShadow: ground.elevation.heroSlab.boxShadows,
              )
            : null,
        foregroundDecoration: framed
            ? ringDecoration(
                color: ground.text,
                width: skin.shape.ring,
                radius: corners,
              )
            : null,
        child: ClipRRect(
          borderRadius: corners,
          child: AspectRatio(aspectRatio: _aspect, child: picture),
        ),
      );
    }
    final angle = skin.tilt.angle(tilt);
    return Semantics(
      image: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: angle == 0 ? body : Transform.rotate(angle: angle, child: body),
      ),
    );
  }
}
