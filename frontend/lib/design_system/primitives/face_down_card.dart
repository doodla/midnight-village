import 'package:flutter/material.dart';

import '../layout/space.dart';
import '../skin/art_set.dart';
import '../skin/skin.dart';
import '../skin/skin_tilt.dart';
import '../teach/hold_cue.dart';
import 'art_picture.dart';
import 'cut_paper.dart';
import 'player_token.dart';

/// [FaceDownCard]'s sizes in the mocks. A card is at most this wide and
/// shrinks, keeping its shape, when its parent is narrower (five players'
/// cards on a 320-wide phone).
enum FaceDownSize {
  /// A card on the night board (S06): 78 x 106.
  player(Size(78, 106)),

  /// A card dropped on the table (S05): 84 x 112.
  scatter(Size(84, 112)),

  /// The one card a screen is about, in a paper frame (04, 07): as wide as a
  /// phone's column (342 of 390) at most, 3 by 4.
  hero(Size(342, 456));

  const FaceDownSize(this.mock);

  final Size mock;
}

/// A card lying face down: a player's (with their [owner] token and
/// [ownerName] under it) or a center card (with its [caption], "Left").
/// When [selected] it lifts and takes the selection's outline (first-time
/// play spec: a selection is lift plus an outline, never a fill). [hold]
/// puts the thumbprint on it: null for none, else the `hold` cue, teaching
/// or learned ([HoldCue]).
class FaceDownCard extends StatelessWidget {
  const FaceDownCard({
    super.key,
    this.size = FaceDownSize.player,
    this.owner,
    this.ownerName,
    this.caption,
    this.selected = false,
    this.hold,
    this.tilt = Tilt.none,
    this.semanticLabel,
    this.onTap,
  });

  final FaceDownSize size;
  final TokenId? owner;
  final String? ownerName;
  final String? caption;
  final bool selected;
  final bool? hold;
  final Tilt tilt;
  final String? semanticLabel;
  final VoidCallback? onTap;

  /// The mock's player card width, which the lying shadow is drawn for.
  static const _shadowWidth = 78.0;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    button: onTap != null,
    selected: selected,
    excludeSemantics: semanticLabel != null,
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: Motion.quick,
        curve: Motion.curve,
        transform: Matrix4.translationValues(0, selected ? -Space.sm : 0, 0),
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
  );

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
          _under(name, skin.typography.nameSmall.copyWith(color: ground.text)),
        ],
        if (caption case final caption?) ...[
          const SizedBox(height: Space.xs),
          _under(
            caption,
            skin.typography.caption.copyWith(color: ground.quietText),
          ),
        ],
      ],
    );
  }

  /// A name or caption under the card, one line, cut short when long.
  Widget _under(String text, TextStyle style) => Text(
    text,
    textAlign: TextAlign.center,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: style,
  );

  /// The card back in its ring, lying on the table.
  Widget _back(BuildContext context, double width) {
    final skin = context.skin;
    final ground = context.ground;
    final radius = BorderRadius.circular(skin.shape.radius);
    final lift = selected
        ? ground.elevation.selected
        : ground.elevation.lying.scaled(width / _shadowWidth);
    return Container(
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
        child: Stack(
          fit: StackFit.expand,
          children: [
            ArtPicture(skin.art.cardBack),
            if (hold case final teaching?)
              Padding(
                padding: const EdgeInsets.all(Space.xxs),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: HoldCue(
                    teaching: teaching,
                    size: width * 0.45,
                    wordAbove: true,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The one card a screen is about: the back in a paper frame, lifted, with
  /// the thumbprint on it (04, 07).
  Widget _hero(BuildContext context, double width) {
    final skin = context.skin;
    final ground = context.ground;
    final scale = width / size.mock.width;
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
            if (hold case final teaching?)
              Center(
                child: HoldCue(
                  teaching: teaching,
                  size: HoldCue.maxSize * scale,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
