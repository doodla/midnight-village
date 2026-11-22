import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../layout/space.dart';
import '../skin/art_set.dart';
import '../skin/skin.dart';
import '../skin/skin_tilt.dart';
import '../teach/hold_cue.dart';
import 'art_picture.dart';
import 'cut_paper.dart';
import 'fit_line.dart';
import 'player_token.dart';

/// [FaceDownCard]'s sizes in the mocks. A card is at most this wide and
/// shrinks, keeping its shape, when its parent is narrower (five players'
/// cards on a 320-wide phone).
enum FaceDownSize {
  /// A player's card in a row (S06): 78 x 106.
  player(Size(78, 106)),

  /// A card on the night board, which takes the room it is given up to
  /// this: the player card's shape, larger where the phone has the height.
  board(Size(96, 130)),

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
/// puts the press-and-hold ring on it while the `hold` cue is taught
/// ([HoldCue]; null or false for none). [cardWidth] sets the card's own width when its
/// name or caption may run wider, across the parent's width (the board's
/// columns).
///
/// A name or caption is never cut short: it wraps between words, on two
/// lines at most, and is set smaller when a word is wider than the space
/// ([FitWords]). [nameSize] sets the name's size and [nameHeight] the room
/// under the token (the night board sets every name at one size that fits
/// them all, in the same room, so a name on two lines moves no card).
class FaceDownCard extends StatelessWidget {
  const FaceDownCard({
    super.key,
    this.size = FaceDownSize.player,
    this.owner,
    this.ownerName,
    this.caption,
    this.selected = false,
    this.dimmed = false,
    this.hold,
    this.tilt = Tilt.none,
    this.cardWidth,
    this.nameSize,
    this.nameHeight,
    this.semanticLabel,
    this.semanticHint,
    this.onTap,
  });

  final FaceDownSize size;
  final TokenId? owner;
  final String? ownerName;
  final String? caption;
  final bool selected;

  /// The card cannot join the pick being made (the night board): its back and
  /// token sit at the skin's dimmed opacity. Its name or caption stays in
  /// full ink, and a tap still reaches it.
  final bool dimmed;
  final bool? hold;
  final Tilt tilt;
  final double? cardWidth;
  final double? nameSize;
  final double? nameHeight;
  final String? semanticLabel;

  /// What a screen reader adds after the label (a dimmed card: a tap still
  /// switches the pick).
  final String? semanticHint;
  final VoidCallback? onTap;

  /// The mock's player card width, which the lying shadow is drawn for.
  static const _shadowWidth = 78.0;

  /// The owner's token takes at most this share of a card's width: the
  /// mocks' 36 on a card 86 or wider, smaller on a small card.
  static const ownerTokenShare = 0.42;

  /// The owner's token under a card [width] wide.
  static double ownerTokenFor(double width) =>
      math.min(TokenSize.card.size, width * ownerTokenShare);

  /// Between the token and the name under it.
  static const nameGap = Space.xxs;

  /// Between a card and its caption.
  static const captionGap = Space.xs;

  /// The hold ring's share of a card back's width.
  static const holdShare = 0.8;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    hint: semanticHint,
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
            final most = cardWidth ?? size.mock.width;
            final width = constraints.hasBoundedWidth
                ? most.clamp(0.0, constraints.maxWidth)
                : most;
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

    final token = ownerTokenFor(width);
    Widget lit(Widget child) => AnimatedOpacity(
      opacity: dimmed ? skin.dimmed : 1,
      duration: Motion.quick,
      curve: Motion.curve,
      child: child,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (owner case final owner?)
          lit(
            Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: token / 2),
                  child: card,
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Center(
                    child: SizedBox.square(
                      dimension: token,
                      child: FittedBox(
                        child: PlayerToken(
                          owner,
                          size: TokenSize.card,
                          ringColor: selected ? ground.selection : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          lit(card),
        if (ownerName case final name?) ...[
          const SizedBox(height: nameGap),
          if (nameHeight case final height?)
            SizedBox(
              height: height,
              child: Align(
                alignment: Alignment.topCenter,
                child: _name(context, name),
              ),
            )
          else
            _name(context, name),
        ],
        if (caption case final caption?) ...[
          const SizedBox(height: captionGap),
          FitWords(
            caption,
            textAlign: TextAlign.center,
            maxLines: 2,
            // In full ink: "Left", "Middle", "Right" name what a player
            // taps (cold read: too faint in the quiet tone).
            style: skin.typography.caption.copyWith(color: ground.text),
          ),
        ],
      ],
    );
  }

  /// The owner's name under the token.
  Widget _name(BuildContext context, String name) => FitWords(
    name,
    textAlign: TextAlign.center,
    maxLines: 2,
    style: context.skin.typography.nameSmall.copyWith(
      fontSize: nameSize,
      color: context.ground.text,
    ),
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
            // Over the card's eye, clear of the token on its lower edge.
            if (hold case final teaching? when teaching)
              Padding(
                padding: EdgeInsets.only(
                  bottom: owner == null ? 0 : ownerTokenFor(width) / 2,
                ),
                child: Center(
                  child: HoldCue(teaching: teaching, size: width * holdShare),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The one card a screen is about: the back in a paper frame, lifted, with
  /// the hold ring on it while the hold is taught (04).
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
