import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../layout/space.dart';
import '../models/role.dart';
import '../skin/card_back_scope.dart';
import '../skin/dress.dart';
import '../skin/dress_style.dart';
import '../skin/werewolf_portrait.dart';
import '../skin/art_set.dart';
import '../skin/skin.dart';
import '../skin/skin_tilt.dart';
import '../teach/hold_cue.dart';
import '../skin/elevation.dart';
import 'art_picture.dart';
import 'cut_paper.dart';
import 'deckled_paper.dart';
import 'paper_light.dart';
import 'paper_mark.dart';
import 'fit_line.dart';
import 'card_back_paper.dart';
import 'hold_to_reveal.dart' show HoldPress;
import 'player_token.dart';
import 'text_backing.dart';

part 'face_down_card_words.dart';

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
///
/// Touch (the night board): the frame a finger lands the card dips [dip] and
/// its shadow stays where it was; a pick lifts it [lift] with the selection's
/// outline, a soft glow of the ground's light ([GroundElevation.glow]) and a
/// deeper hard shadow. Every card does this, whatever it is and whether or
/// not a pick can take it, so no role shows in how a board answers a touch.
/// Under reduce motion each is a cut to its end state.
class FaceDownCard extends StatefulWidget {
  const FaceDownCard({
    super.key,
    this.size = FaceDownSize.player,
    this.owner,
    this.ownerName,
    this.caption,
    this.selected = false,
    this.dimmed = false,
    this.tapExtra = 0,
    this.hold,
    this.face,
    this.tilt = Tilt.none,
    this.cardWidth,
    this.cardHeight,
    this.nameSize,
    this.nameHeight,
    this.youName = false,
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

  /// A tap reaches this much below the card and its caption (blank, inside
  /// the card's own cell: the night board's table cards take it from the
  /// strip's padding, so a small card is still a thumb's height).
  final double tapExtra;
  final bool? hold;

  /// The role this card shows face up, its portrait and its name (the night
  /// board's own card, "You": the role this phone was dealt, which it has
  /// seen). Null: the card's back. A face-up card takes no hold ring, and
  /// lifts, rings and shadows as a back does.
  final RoleId? face;
  final Tilt tilt;
  final double? cardWidth;

  /// The hero card's own height, when the screen gives it the room it has
  /// (04: the card takes the height between the title and the foot, so the
  /// portrait on its face is as large as the phone allows). The back keeps
  /// its own shape, whole, centred on the paper. Null: 3 by 4.
  final double? cardHeight;
  final double? nameSize;
  final double? nameHeight;

  /// The name under the card is "You": the table's own tag, not a name.
  final bool youName;
  final String? semanticLabel;

  /// What a screen reader adds after the label (a dimmed card: a tap still
  /// switches the pick).
  final String? semanticHint;
  final VoidCallback? onTap;

  /// The mock's player card width, which the lying shadow is drawn for.
  static const _shadowWidth = 78.0;

  /// How far a picked card lifts off the table.
  static const lift = Space.sm;

  /// How far a card dips under a finger.
  static const dip = 2.0;

  /// The picked card's soft light: its blur and its spread.
  static const glowBlur = 22.0;
  static const glowSpread = 2.0;

  /// The owner's token takes at most this share of a card's width: the
  /// mocks' 36 on a card 86 or wider, smaller on a small card.
  static const ownerTokenShare = 0.42;

  /// A card wider than the mocks' board card (96) lets its token grow by
  /// this share of the extra width, so a large card is not a small token on
  /// a big back.
  static const ownerTokenGrowth = 0.15;

  /// The owner's token under a card [width] wide.
  static double ownerTokenFor(double width) => math.min(
    TokenSize.card.size +
        math.max(0, width - FaceDownSize.board.mock.width) * ownerTokenGrowth,
    width * ownerTokenShare,
  );

  /// Between the token and the name under it.
  static const nameGap = Space.xxs;

  /// Between a card and its caption.
  static const captionGap = Space.xs;

  /// A face-up card's role name sits this far above the token's top.
  static const faceNameLift = Space.xxs;

  /// How far a dressed name's plate reaches past its words, sideways and up
  /// and down; the board's columns leave room for twice the first.
  static const nameBleed = 4.0;
  static const nameBleedUp = 3.0;

  /// How far the text size grows a face-up card's role name.
  static const roleNameScale = 1.6;

  /// The hold ring's share of a card back's width.
  static const holdShare = 0.8;

  @override
  State<FaceDownCard> createState() => _FaceDownCardState();
}

class _FaceDownCardState extends State<FaceDownCard> with _FaceDownCardWords {
  /// A finger is on the card.
  var _down = false;

  void _touch(bool down) {
    if (_down != down && mounted) setState(() => _down = down);
  }

  FaceDownSize get size => widget.size;

  @override
  Widget build(BuildContext context) {
    // Going down is `press`, coming back up and a pick `quick`; no time at
    // all under reduce motion.
    final duration = Motion.within(
      context,
      _down ? Motion.press : Motion.quick,
    );
    final dip = _down && widget.onTap != null ? FaceDownCard.dip : 0.0;
    return Semantics(
      label: widget.semanticLabel,
      hint: widget.semanticHint,
      button: widget.onTap != null,
      selected: widget.selected,
      excludeSemantics: widget.semanticLabel != null,
      // Its own layer: a lift or a dip moves this card's picture, and never
      // repaints the paper round it (`paint_cache_test.dart`).
      child: RepaintBoundary(
        child: Listener(
          // The press answers the frame the finger lands, not when the tap is
          // recognised (a card under a hold's cover waits for neither).
          onPointerDown: (_) => _touch(true),
          onPointerUp: (_) => _touch(false),
          onPointerCancel: (_) => _touch(false),
          child: GestureDetector(
            onTap: widget.onTap,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: duration,
              curve: Motion.curve,
              transform: Matrix4.translationValues(
                0,
                (widget.selected ? -FaceDownCard.lift : 0) + dip,
                0,
              ),
              // A pick lifts the card as one picture: its paper is painted
              // once, not again each frame of the lift.
              child: RepaintBoundary(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final most = widget.cardWidth ?? size.mock.width;
                    final width = constraints.hasBoundedWidth
                        ? most.clamp(0.0, constraints.maxWidth)
                        : most;
                    final column = _column(context, width, duration, dip);
                    return widget.tapExtra == 0
                        ? column
                        : Padding(
                            padding: EdgeInsets.only(bottom: widget.tapExtra),
                            child: column,
                          );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _column(
    BuildContext context,
    double width,
    Duration duration,
    double dip,
  ) {
    final selected = widget.selected;
    final owner = widget.owner;
    final ownerName = widget.ownerName;
    final caption = widget.caption;
    final skin = context.skin;
    final ground = context.ground;
    final height =
        widget.cardHeight ?? width * size.mock.height / size.mock.width;
    final angle = skin.tilt.angle(widget.tilt);
    Widget card = SizedBox(
      width: width,
      height: height,
      child: size == FaceDownSize.hero
          ? _hero(context, width)
          : _back(
              context,
              width,
              duration,
              dip,
              foot: owner != null && widget.face != null
                  ? _roleFoot(context, widget.face!, width)
                  : 0,
            ),
    );
    if (angle != 0) card = Transform.rotate(angle: angle, child: card);
    // A pick wears the mark on its corner.
    card = PaperMarkCorner(shown: selected, child: card);

    final token = FaceDownCard.ownerTokenFor(width);
    Widget lit(Widget child) => AnimatedOpacity(
      opacity: widget.dimmed ? skin.dimmed : 1,
      duration: duration,
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
                // Held, the role's own card is shown over it: its slip would
                // only peek out from under that.
                if (widget.face case final role? when !HoldPress.of(context))
                  _roleName(context, role, width, bottom: token),
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
          const SizedBox(height: FaceDownCard.nameGap),
          if (widget.nameHeight case final height?)
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
          const SizedBox(height: FaceDownCard.captionGap),
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

  /// The card back in its ring, lying on the table; picked, it is lifted: a
  /// deeper hard shadow, the ground's soft light and the selection's ring,
  /// each tweened with the lift. [dip] is how far a finger has pressed it
  /// down: the shadow stays where it was.
  Widget _back(
    BuildContext context,
    double width,
    Duration duration,
    double dip, {
    double foot = 0,
  }) {
    final skin = context.skin;
    final ground = context.ground;
    final selected = widget.selected;
    final radius = BorderRadius.circular(skin.shape.radius);
    if (context.dress.isPaper) {
      // Paper layers, no ring and no glow: lifted, it casts a deeper shadow.
      final lying = selected
          ? ground.elevation.selected
          : ground.elevation.lying.scaled(width / FaceDownCard._shadowWidth);
      return AnimatedContainer(
        duration: duration,
        curve: Motion.curve,
        // A role's name goes UNDER its portrait, as on the held card and the
        // sheet (one layout for a role's name, everywhere): the portrait stops
        // above the slip's room, the slip is never laid over the face.
        padding: EdgeInsets.only(bottom: foot),
        child: CardBackPaper(
          id: widget.face?.name ?? widget.owner ?? 'back',
          elevation: dip > 0 ? lying.lowered(dip) : lying,
          face: widget.face,
          over: _hold(context, width),
        ),
      );
    }
    final base = selected
        ? ground.elevation.selected
        : ground.elevation.lying.scaled(width / FaceDownCard._shadowWidth);
    final glow = ground.elevation.glow;
    return AnimatedContainer(
      duration: duration,
      curve: Motion.curve,
      decoration:
          cutPaper(
            context,
            fill: ground.ground,
            radius: radius,
            elevation: dip > 0 ? base.lowered(dip) : base,
          ).copyWith(
            boxShadow: [
              // Under the hard shadow, and always in the list so it fades in
              // and out with the pick instead of switching (the shadows are
              // blended pair by pair). Unpicked it is a clear shadow with no
              // blur, which costs nothing to paint: only a picked card, and
              // one still fading, paints the soft light.
              if (glow != null)
                selected
                    ? BoxShadow(
                        color: glow,
                        blurRadius: FaceDownCard.glowBlur,
                        spreadRadius: FaceDownCard.glowSpread,
                      )
                    : BoxShadow(color: glow.withValues(alpha: 0)),
              ...(dip > 0 ? base.lowered(dip) : base).litBy(context),
            ],
          ),
      foregroundDecoration: frameRing(
        context,
        color: selected ? ground.selection : ground.hairline,
        width: selected ? skin.shape.selectedRing : skin.shape.ring,
        radius: radius,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.face case final role?)
              ArtPicture(context.roleArt(role))
            else
              ArtPicture(context.cardBack),
            // Over the card's eye, clear of the token on its lower edge.
            if (_hold(context, width) case final over?) over,
          ],
        ),
      ),
    );
  }

  /// The hold ring over the card's eye, clear of the token on its lower edge.
  Widget? _hold(BuildContext context, double width) {
    if (widget.hold case final teaching? when teaching) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: widget.owner == null
              ? 0
              : FaceDownCard.ownerTokenFor(width) / 2,
        ),
        child: Center(
          child: HoldCue(
            teaching: teaching,
            size: width * FaceDownCard.holdShare,
          ),
        ),
      );
    }
    return null;
  }

  /// The one card a screen is about: the back in a paper frame, lifted, with
  /// the hold ring on it while the hold is taught (04).
  Widget _hero(BuildContext context, double width) {
    final skin = context.skin;
    final ground = context.ground;
    final scale = width / size.mock.width;
    if (context.dress.isPaper) {
      // A deckled paper card like the face's, the back laid on it in paper
      // layers.
      return DecoratedBox(
        decoration: deckledPaper(
          context,
          fill: ground.paper,
          id: #heroBack,
          elevation: ground.elevation.heroSlab,
          depth: skin.parts.pinnedDepth,
          step: skin.parts.pinnedStep,
          edgeLine: false,
          side: BorderSide.none,
        ),
        child: Padding(
          padding: EdgeInsets.all(Space.smPlus * scale),
          child: _wholeBack(
            context,
            CardBackPaper(
              id: #hero,
              elevation: ground.elevation.badge,
              over: widget.hold == null
                  ? null
                  : Center(
                      child: HoldCue(
                        teaching: widget.hold!,
                        size: HoldCue.maxSize * scale,
                      ),
                    ),
            ),
          ),
        ),
      );
    }
    return DecoratedBox(
      decoration: cutPaper(
        context,
        fill: ground.paper,
        radius: BorderRadius.circular(skin.shape.radius),
        elevation: ground.elevation.heroSlab,
      ),
      child: Padding(
        padding: EdgeInsets.all(Space.smPlus * scale),
        child: _wholeBack(
          context,
          Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(skin.shape.radiusTiny),
                child: ArtPicture(context.cardBack),
              ),
              if (widget.hold case final teaching?)
                Center(
                  child: HoldCue(
                    teaching: teaching,
                    size: HoldCue.maxSize * scale,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// The back picture in a hero card given its own height ([cardHeight]):
  /// whole, in its own shape, as large as the paper allows, centred (the
  /// paper equal on both sides). In the mock's 3 by 4 card it fills it.
  Widget _wholeBack(BuildContext context, Widget back) =>
      widget.cardHeight == null
      ? back
      : Center(
          child: AspectRatio(
            aspectRatio: context.cardBack.pixels.aspectRatio,
            child: back,
          ),
        );
}
