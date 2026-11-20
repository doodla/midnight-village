import 'package:flutter/material.dart';

import '../layout/space.dart';
import '../skin/art_set.dart';
import '../skin/skin.dart';
import '../skin/skin_tilt.dart';
import 'art_picture.dart';
import 'cut_paper.dart';
import 'player_token.dart';

/// [FaceDownCard]'s sizes in the mocks. A card is at most this wide and
/// shrinks, keeping its shape, when its parent is narrower (four players'
/// cards on a 320-wide phone).
enum FaceDownSize {
  /// A center card (S06): 62 x 84.
  center(Size(62, 84)),

  /// A player's card (S06): 78 x 106.
  player(Size(78, 106)),

  /// A card dropped on the table to tap while waiting (S05): 84 x 112.
  scatter(Size(84, 112)),

  /// The one card a screen is about, in a paper frame (S07): 270 x 362.
  hero(Size(270, 362));

  const FaceDownSize(this.mock);

  final Size mock;
}

/// A card lying face down: a player's (with their [owner] token and
/// [ownerName] under it) or a center card (with its [caption], "Left").
/// When [selected] it lifts, takes the selection ring and shows [mark] (what
/// tapping it will do: look, swap). [recessed] sets it back (S06's center
/// cards while a player's card is the likelier pick). [holdHint] puts the
/// "hold to flip" disc on a hero card.
class FaceDownCard extends StatelessWidget {
  const FaceDownCard({
    super.key,
    this.size = FaceDownSize.player,
    this.owner,
    this.ownerName,
    this.caption,
    this.selected = false,
    this.recessed = false,
    this.mark,
    this.holdHint,
    this.tilt = Tilt.none,
    this.semanticLabel,
    this.onTap,
  });

  final FaceDownSize size;
  final TokenId? owner;
  final String? ownerName;
  final String? caption;
  final bool selected;
  final bool recessed;
  final IconData? mark;
  final String? holdHint;
  final Tilt tilt;
  final String? semanticLabel;
  final VoidCallback? onTap;

  /// The mock's player card width, which the lying shadow is drawn for.
  static const _shadowWidth = 78.0;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      selected: selected,
      excludeSemantics: semanticLabel != null,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedOpacity(
          duration: Motion.quick,
          opacity: recessed && !selected ? skin.recessed : 1,
          child: AnimatedContainer(
            duration: Motion.quick,
            curve: Motion.curve,
            transform: Matrix4.translationValues(
              0,
              selected ? -Space.sm : 0,
              0,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.hasBoundedWidth
                    ? size.mock.width.clamp(0.0, constraints.maxWidth)
                    : size.mock.width;
                return _column(context, width);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _column(BuildContext context, double width) {
    final skin = context.skin;
    final ground = context.ground;
    final height = width * size.mock.height / size.mock.width;
    final angle = skin.tilt.angle(tilt);
    Widget card = SizedBox(
      width: width,
      height: height,
      child: size == FaceDownSize.hero
          ? _hero(context, width)
          : _back(context, width),
    );
    if (angle != 0) card = Transform.rotate(angle: angle, child: card);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (owner case final owner?)
          Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: TokenSize.card.size / 2),
                child: card,
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Center(
                  child: PlayerToken(
                    owner,
                    size: TokenSize.card,
                    ringColor: selected ? ground.selection : null,
                  ),
                ),
              ),
            ],
          )
        else
          card,
        if (ownerName case final name?) ...[
          const SizedBox(height: Space.xxs),
          SizedBox(
            width: width,
            child: Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: skin.typography.nameSmall.copyWith(
                color: selected ? ground.selection : ground.text,
              ),
            ),
          ),
        ],
        if (caption case final caption?) ...[
          const SizedBox(height: Space.xs),
          SizedBox(
            width: width,
            child: Text(
              caption,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: skin.typography.badge.copyWith(
                color: selected ? ground.selection : ground.quietText,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// The card back in its ring, lying on the table.
  Widget _back(BuildContext context, double width) {
    final skin = context.skin;
    final ground = context.ground;
    final radius = BorderRadius.circular(skin.shape.radius);
    final lift = selected
        ? ground.elevation.selected
        : ground.elevation.lying.scaled(width / _shadowWidth);
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: cutPaper(
            context,
            fill: ground.ground,
            radius: radius,
            elevation: lift,
          ),
          foregroundDecoration: ringDecoration(
            color: selected ? ground.selection : ground.hairline,
            width: selected ? skin.shape.selectedRing : skin.shape.ring,
            radius: radius,
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: ArtPicture(skin.art.cardBack),
          ),
        ),
        if (selected && mark != null)
          // The mock's disc: 40 of the card's 78, its top 38 of 106 down.
          Positioned(
            left: 0,
            right: 0,
            top: width * 38 / 78,
            child: Center(
              child: Container(
                width: width * 40 / 78,
                height: width * 40 / 78,
                decoration: BoxDecoration(
                  color: ground.mark,
                  shape: BoxShape.circle,
                  boxShadow: ground.elevation.badge.boxShadows,
                ),
                child: Icon(mark, color: ground.onMark, size: width / 3),
              ),
            ),
          ),
      ],
    );
  }

  /// The one card a screen is about: the back in a paper frame, lifted, with
  /// the hold hint over it (S07).
  Widget _hero(BuildContext context, double width) {
    final skin = context.skin;
    final ground = context.ground;
    final night = skin.night;
    final scale = width / size.mock.width;
    final disc = 132 * scale;
    return DecoratedBox(
      decoration: cutPaper(
        context,
        fill: ground.paper,
        radius: BorderRadius.circular(skin.shape.radius),
        elevation: ground.elevation.heroSlab,
      ),
      child: Padding(
        padding: EdgeInsets.all(Space.smPlus * scale),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(skin.shape.radiusTiny),
              child: ArtPicture(skin.art.cardBack),
            ),
            if (holdHint case final hint?)
              Center(
                child: Container(
                  width: disc,
                  height: disc,
                  padding: const EdgeInsets.all(Space.sm),
                  decoration: BoxDecoration(
                    // The mock's veil: the night at 86%, so the back shows
                    // through a little. It covers the back, never a secret.
                    color: night.ground.withValues(alpha: 0.86),
                    shape: BoxShape.circle,
                  ),
                  foregroundDecoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: night.selection,
                      width: skin.shape.selectedRing,
                      strokeAlign: BorderSide.strokeAlignOutside,
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      spacing: Space.xs,
                      children: [
                        Icon(
                          Icons.touch_app_outlined,
                          color: night.selection,
                          size: 34,
                        ),
                        Text(
                          hint,
                          textAlign: TextAlign.center,
                          style: skin.typography.action.copyWith(
                            color: night.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
