import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../skin/dress.dart';
import '../skin/end_art.dart';
import '../skin/skin.dart';
import 'art_picture.dart';
import 'deckle.dart';
import 'drawn.dart';
import 'paper_light.dart';

/// How death is marked on the end board, and how much of a card's portrait a
/// mark may hide. A mark is the black corner ribbon ([DeathRibbon], on a card
/// for good), which may cover no more than [maxCover] of a portrait, or the
/// HANGED stamp ([InkStamp], in the reveal's moment only), a narrow plate laid
/// under the face ([stampFits]): the face is seen whatever is pinned to it.
abstract final class DeathMark {
  /// The most of a portrait's area a mark may lie over.
  static const maxCover = 0.35;

  /// How much of a rectangle [mark] lies over [portrait]: its share of the
  /// portrait's area, 0 to 1.
  static double coverOf(Rect portrait, Rect mark) {
    final over = portrait.intersect(mark);
    if (over.width <= 0 || over.height <= 0) return 0;
    return over.width * over.height / (portrait.width * portrait.height);
  }

  /// The ribbon's width on a portrait [portraitWidth] wide: a good third of
  /// it, at least 30 and at most 38 (it reads at arm's length).
  static double ribbonWidth(double portraitWidth) =>
      (portraitWidth * 0.38).clamp(30.0, 38.0);

  /// The ribbon is as tall as its picture says.
  static double ribbonHeight(double width) =>
      width * EndPiece.ribbon.pixels.height / EndPiece.ribbon.pixels.width;

  /// How much of a ribbon is inside the card it is pinned to, along each side:
  /// a little over a quarter, so 92% of it hangs outside, clear of the name.
  static const ribbonInside = 0.28;

  /// How far the ribbon is turned.
  static const ribbonTurn = 14 * math.pi / 180;

  /// Where the ribbon lies for a card at [card], whose portrait is
  /// [portraitWidth] wide: pinned on the top right corner, mostly outside it.
  static Rect ribbonRect(Rect card, double portraitWidth) {
    final width = ribbonWidth(portraitWidth);
    final height = ribbonHeight(width);
    return Rect.fromLTWH(
      card.right - width * ribbonInside,
      card.top - height * (1 - ribbonInside),
      width,
      height,
    );
  }

  /// The stamp is a narrow plate: at most this share of the card it lands on
  /// is its height (the mock's, near enough) ...
  static const stampShare = 0.16;

  /// ... and it lies clear of the face: a portrait's face is in its top
  /// [faceShare] (the portrait is cut with headroom).
  static const faceShare = 0.7;

  /// Where a stamp of size [stamp] lies on [card]: across its lower edge,
  /// centred, hung from the foot of the role's tab ([tabBottom]), so it
  /// covers neither the face nor the role's word.
  static Rect stampRect(Rect card, Size stamp, {required double tabBottom}) =>
      Rect.fromLTWH(
        card.center.dx - stamp.width / 2,
        tabBottom,
        stamp.width,
        stamp.height,
      );

  /// Whether a stamp of size [stamp] may land on [card] (its [portrait], the
  /// foot of its role's tab at [tabBottom]): a narrow plate ([stampShare] of
  /// the card at most), on the card's lower edge, clear of the face
  /// ([faceShare]) and of the role's word.
  static bool stampFits(
    Rect card,
    Rect portrait,
    Size stamp, {
    required double tabBottom,
  }) {
    final at = stampRect(card, stamp, tabBottom: tabBottom);
    return stamp.height <= stampShare * card.height + 0.01 &&
        at.top >= portrait.top + faceShare * portrait.height - 0.01 &&
        at.top >= tabBottom - 0.01 &&
        at.top <= card.bottom &&
        at.bottom >= card.bottom;
  }
}

/// The black ribbon of mourning pinned on a hanged card's top right corner:
/// the one death mark that stays. Paper shows it with a bone edge (so it
/// reads on the Werewolf team's red paper) and a shadow away from the light;
/// plain, it is the picture alone. [width] is the ribbon's (see
/// [DeathMark.ribbonWidth]); it is turned [DeathMark.ribbonTurn].
class DeathRibbon extends StatelessWidget {
  const DeathRibbon({super.key, required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final picture = skin.art.end.piece(EndPiece.ribbon);
    final height = DeathMark.ribbonHeight(width);
    final paper = context.dress.isPaper;
    final lean = PaperLight.of(context);
    Widget copy(Color color) => ColorFiltered(
      colorFilter: ColorFilter.mode(color, BlendMode.srcATop),
      child: ArtPicture(picture),
    );
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Transform.rotate(
          angle: DeathMark.ribbonTurn,
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              fit: StackFit.expand,
              children: [
                if (paper) ...[
                  Transform.translate(
                    offset: Offset(lean * 2.5, 2.5),
                    child: copy(context.ground.shadow),
                  ),
                  Transform.scale(scale: 1.16, child: copy(skin.paper.paper)),
                ],
                ArtPicture(picture),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The word HANGED stamped on a card in the reveal's moment only (it lifts
/// off again as the ribbon is pinned), as the mock draws it: a narrow plate of
/// dark ink with a double bone rule round it, the word in bone in the 12 pt
/// tag face, turned a little, and the stamp's force in bone lines bursting out
/// round it ([burst]). The burst is drawn outside the plate's box: the box is
/// the plate alone. The words are the caller's (`copy.dart`).
class InkStamp extends StatelessWidget {
  const InkStamp({
    super.key,
    required this.label,
    this.burst = true,
    this.turn = -0.07,
    this.width,
  });

  final String label;

  /// The bone lines round the plate.
  final bool burst;

  /// How far it is turned, in radians.
  final double turn;

  /// How wide the plate is (null: as wide as its word and room).
  final double? width;

  /// The room round the word inside the inner rule.
  static const padding = EdgeInsets.symmetric(horizontal: 12, vertical: 2);

  /// The outer rule, the air inside it, and the inner rule.
  static const rule = 1.5;
  static const ruleGap = 2.0;
  static const innerRule = 1.0;

  /// How much of the plate's ink shows (the card a little through it).
  static const plateAlpha = 0.88;

  /// The burst: this many lines, from a little off the plate to as far as
  /// [burstReach] of its size past it.
  static const lines = 22;
  static const burstFrom = 0.12;
  static const burstReach = 0.55;
  static const lineWidth = 2.0;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final bone = skin.paper.paper;
    final style = skin.typography.tag.copyWith(color: bone);
    final radius = BorderRadius.circular(skin.shape.radiusTiny);
    final drawn = DecoratedBox(
      decoration: BoxDecoration(
        color: skin.night.ground.withValues(alpha: plateAlpha),
        borderRadius: radius,
        border: Border.all(color: bone, width: rule),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ruleGap),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: bone, width: innerRule),
          ),
          child: Padding(
            padding: padding,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              textAlign: TextAlign.center,
              style: style,
            ),
          ),
        ),
      ),
    );
    final plate = width == null ? drawn : SizedBox(width: width, child: drawn);
    return ExcludeSemantics(
      child: Transform.rotate(
        angle: turn,
        child: Drawn(
          DrawnKind.inkStamp,
          child: burst
              ? CustomPaint(
                  painter: _BurstPainter(ink: bone, seed: deckleSeed(label)),
                  child: plate,
                )
              : plate,
        ),
      ),
    );
  }
}

/// The stamp's force: bone lines out from round the plate, seeded so they are
/// the same each time, longer across than up and down.
class _BurstPainter extends CustomPainter {
  const _BurstPainter({required this.ink, required this.seed});

  final Color ink;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed);
    final centre = size.center(Offset.zero);
    final paint = Paint()
      ..color = ink
      ..strokeWidth = InkStamp.lineWidth
      ..strokeCap = StrokeCap.round;
    // The plate's own box as an ellipse round it: a line starts a little past
    // the ellipse through the plate's corners and runs out from there.
    final rx = size.width / 2 * math.sqrt2, ry = size.height / 2 * math.sqrt2;
    for (var i = 0; i < InkStamp.lines; i++) {
      final angle =
          2 * math.pi * (i + 0.5 * random.nextDouble()) / InkStamp.lines;
      final dir = Offset(math.cos(angle), math.sin(angle));
      final edge = Offset(dir.dx * rx, dir.dy * ry);
      final from = 1 + InkStamp.burstFrom * random.nextDouble();
      // Long across, short up and down: the plate is narrow, the face above.
      final reach =
          InkStamp.burstReach *
          (0.45 + 0.55 * random.nextDouble()) *
          edge.distance;
      final a = centre + edge * from;
      canvas.drawLine(a, a + dir * reach, paint);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => ink != old.ink || seed != old.seed;
}
