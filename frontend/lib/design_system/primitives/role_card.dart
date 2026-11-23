import 'paper_light.dart';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../layout/space.dart';
import '../models/role.dart';
import '../skin/dress.dart';
import '../skin/skin.dart';
import '../skin/werewolf_portrait.dart';
import '../skin/skin_tilt.dart';
import 'art_picture.dart';
import 'count_badge.dart';
import 'cut_paper.dart';
import 'text_backing.dart';
import 'fit_line.dart';

/// [RoleCard]'s sizes. The thumbnails are at most their mock size and
/// shrink, keeping their shape, when their parent is narrower.
enum RoleCardSize {
  /// In the deck strip at the table (S02): 30 x 40.
  thumbSmall(Size(30, 40)),

  /// In the deck strip of the talk (S08): 50 x 68.
  mini(Size(50, 68)),

  /// A card in the deck builder's grid, named underneath; as wide as its
  /// parent allows.
  small(null);

  const RoleCardSize(this.thumbnail);

  /// A thumbnail's mock size; null for the card that fills its parent.
  final Size? thumbnail;
}

/// A role as a picture, in the deck. [count] is how many are in it (shown
/// when it says something: above 1).
/// A small card that is not [lit] is in the box, not the deck: dimmed; a lit
/// one takes the selection's outline. The name is never broken: a long name
/// ("Doppelganger") is set smaller instead. Holding one opens the role sheet
/// ([onLongPress]; its words are the role text, `RoleSheetBody`).
/// In the grid, [onRemove] puts a minus on a lit card's corner that takes
/// one out (a tap on the card puts one in): both said by doing, no words;
/// [removeLabel] is what a screen reader says for it.
///
/// A hold is a press of [holdDelay]: shorter is a tap.
class RoleCard extends StatelessWidget {
  const RoleCard({
    super.key,
    required this.role,
    this.size = RoleCardSize.small,
    this.count = 0,
    this.lit = true,
    this.onTap,
    this.onLongPress,
    this.onRemove,
    this.removeLabel,
  });

  final RoleId role;
  final RoleCardSize size;
  final int count;
  final bool lit;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onRemove;
  final String? removeLabel;

  /// How long a press lasts before it is a hold ([onLongPress]): shorter is
  /// a tap. Not the platform's half second: in the owner's recording (22
  /// November 2026) presses of 0.40 and 0.43 s on 03 read nothing and looked
  /// broken, while the owner's taps lasted under 0.1 s.
  static const holdDelay = Duration(milliseconds: 300);

  /// The minus's touch area (the reading floor's 44) and its disc.
  static const removeTarget = Sizes.touch;
  static const _removeDisc = BadgeSize.large;

  /// Width over height of a portrait in the grid (the mocks' 76.5 x 100).
  static const _gridAspect = 0.765;

  /// Width over height of a grid cell: the portrait and its name under it
  /// (S03, three across).
  static const gridCellAspect = Sizes.roleGridCell;

  @override
  Widget build(BuildContext context) {
    final card = Semantics(
      label: role.displayName,
      button: onTap != null,
      selected: size == RoleCardSize.small && onTap != null ? lit : null,
      excludeSemantics: true,
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: {
          if (onTap case final onTap?)
            TapGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                  () => TapGestureRecognizer(debugOwner: this),
                  (recognizer) => recognizer.onTap = onTap,
                ),
          if (onLongPress case final onLongPress?)
            LongPressGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                  LongPressGestureRecognizer
                >(
                  () => LongPressGestureRecognizer(
                    duration: holdDelay,
                    debugOwner: this,
                  ),
                  (recognizer) => recognizer.onLongPress = onLongPress,
                ),
        },
        child: switch (size.thumbnail) {
          final thumbnail? => _thumbnail(context, thumbnail),
          null => _small(context),
        },
      ),
    );
    final remove = onRemove;
    if (remove == null || !lit || size.thumbnail != null) return card;
    return Stack(
      children: [
        card,
        // Inside the card's corner, so the whole 44 is hit-testable.
        Positioned(
          left: 0,
          top: 0,
          width: removeTarget,
          height: removeTarget,
          child: _Minus(onTap: remove, label: removeLabel),
        ),
      ],
    );
  }

  Widget _portrait(
    BuildContext context, {
    required double radius,
    required Color ringColor,
    required double ringWidth,
  }) {
    final skin = context.skin;
    final corners = BorderRadius.circular(radius);
    return AnimatedOpacity(
      duration: Motion.quick,
      opacity: lit ? 1 : skin.dimmed,
      child: Container(
        // Dressed up, a card lying on the table casts its paper shadow while
        // it is in.
        decoration: context.dress.isPaper
            ? BoxDecoration(
                borderRadius: corners,
                boxShadow: lit
                    ? context.ground.elevation.card.litBy(context)
                    : null,
              )
            : null,
        foregroundDecoration: frameRing(
          context,
          color: ringColor,
          width: ringWidth,
          radius: corners,
        ),
        child: ClipRRect(
          borderRadius: corners,
          child: ArtPicture(context.roleArt(role)),
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
              ),
              if (count > 1)
                Positioned(
                  right: -Space.xs,
                  top: -Space.xs,
                  child: CountBadge(count),
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
    // Set down by hand: the card turned a little, the same every build, from
    // its role; its name stays level.
    final angle = skin.tilt.angle(Tilt.seededCard(role.name));
    Widget turned(Widget card) =>
        angle == 0 ? card : Transform.rotate(angle: angle, child: card);
    final portrait = turned(
      AspectRatio(
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
            ),
            if (lit && count > 1)
              Positioned(
                right: -5,
                top: -7,
                child: CountBadge(count, size: BadgeSize.large),
              ),
          ],
        ),
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
          // Dressed up the name may pass over the village or the moon: it
          // keeps a backing (a plain screen's is nothing).
          TextBacking(
            child: FitLine(
              role.displayName,
              style: skin.typography.badge.copyWith(
                color: lit ? ground.text : ground.faintText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The grid card's minus: a disc in the ground's ink with a minus in it,
/// lifted like the count badge, never amber.
class _Minus extends StatelessWidget {
  const _Minus({required this.onTap, this.label});

  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final ground = context.ground;
    final side = RoleCard._removeDisc.size;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(Space.xs),
            child: Container(
              width: side,
              height: side,
              decoration: BoxDecoration(
                color: ground.mark,
                shape: BoxShape.circle,
                boxShadow: ground.elevation.badge.litBy(context),
              ),
              child: Icon(
                Icons.remove,
                size: side * Sizes.glyphInDisc,
                color: ground.onMark,
              ),
            ),
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

  /// The count's cards (S10): the dead player's when alone, the card they
  /// were dealt beside it, and both when several die.
  static const deadNow = 112.0;
  static const deadDealt = 72.0;
  static const deadNowSmall = 64.0;
  static const deadDealtSmall = 40.0;

  /// A line of the night on 11 (its role), and the folded night's strip.
  static const line = 36.0;
  static const strip = 30.0;

  /// The most of its band the winner's portrait takes (S11: about a third).
  static const winnerShare = 0.36;

  /// Width to height of every portrait.
  static const aspect = 3 / 4;

  final RoleId role;
  final double width;
  final bool framed;
  final bool arched;
  final Tilt tilt;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    final picture = ArtPicture(context.roleArt(role));
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
          child: AspectRatio(aspectRatio: aspect, child: picture),
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
                boxShadow: ground.elevation.heroSlab.litBy(context),
              )
            : null,
        foregroundDecoration: framed
            ? frameRing(
                context,
                color: ground.text,
                width: skin.shape.ring,
                radius: corners,
              )
            : null,
        child: ClipRRect(
          borderRadius: corners,
          child: AspectRatio(aspectRatio: aspect, child: picture),
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
