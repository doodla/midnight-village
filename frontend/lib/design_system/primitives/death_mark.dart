import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../skin/dress.dart';
import '../skin/end_art.dart';
import '../skin/skin.dart';
import 'art_picture.dart';
import 'deckle.dart';
import 'paper_light.dart';

/// How death is marked on the end board, and how much of a card's portrait a
/// mark may hide. A mark is the black corner ribbon ([DeathRibbon], on a card
/// for good) or the HANGED stamp ([InkStamp], in the reveal's slam frame only):
/// neither may cover more than [maxCover] of a portrait, so the face is seen
/// whatever is pinned to it.
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

  /// The ribbon's width on a portrait [portraitWidth] wide: a third of it,
  /// at least 24 and at most 34.
  static double ribbonWidth(double portraitWidth) =>
      (portraitWidth * 0.34).clamp(24.0, 34.0);

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

  /// Where the stamp lies over a portrait: centred across it and on its lower
  /// third, where a face has the least.
  static Rect stampRect(Rect portrait, Size stamp) => Rect.fromCenter(
    center: Offset(portrait.center.dx, portrait.top + portrait.height * 2 / 3),
    width: stamp.width,
    height: stamp.height,
  );

  /// Whether a stamp of size [stamp] may be laid on [portrait]: it hides no
  /// more than [maxCover] of it.
  static bool stampFits(Rect portrait, Size stamp) =>
      coverOf(portrait, stampRect(portrait, stamp)) <= maxCover;
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

/// The word HANGED, stamped in ink on a card for the reveal's slam frame only
/// (it lifts off again as the ribbon is pinned): a block of dark ink with the
/// word knocked out of it in bone, in the 12 pt tag face, turned a little,
/// with the ink's burst spattered round it ([burst]). No border or outline: an
/// ink block and its word. The words are the caller's (`copy.dart`).
class InkStamp extends StatelessWidget {
  const InkStamp({
    super.key,
    required this.label,
    this.burst = true,
    this.turn = -0.12,
  });

  final String label;

  /// The ink's spatter round the block.
  final bool burst;

  /// How far it is turned, in radians.
  final double turn;

  /// The room round the word on the block.
  static const padding = EdgeInsets.symmetric(horizontal: 10, vertical: 5);

  /// How far the burst reaches past the block, as a share of its size.
  static const burstReach = 0.45;

  /// The spikes of the burst.
  static const spikes = 14;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ink = skin.night.ground;
    final style = skin.typography.tag.copyWith(color: skin.night.text);
    final block = DecoratedBox(
      decoration: BoxDecoration(
        color: ink,
        borderRadius: BorderRadius.circular(skin.shape.radiusTiny),
      ),
      child: Padding(
        padding: padding,
        child: Text(label, maxLines: 1, softWrap: false, style: style),
      ),
    );
    return ExcludeSemantics(
      child: Transform.rotate(
        angle: turn,
        child: burst
            ? CustomPaint(
                painter: _BurstPainter(
                  ink: ink.withValues(alpha: 0.45),
                  reach: burstReach,
                  seed: deckleSeed(label),
                ),
                child: Padding(padding: const EdgeInsets.all(6), child: block),
              )
            : block,
      ),
    );
  }
}

/// The ink's spatter: a jagged filled star round the block, from a seed, so it
/// is the same each time.
class _BurstPainter extends CustomPainter {
  const _BurstPainter({
    required this.ink,
    required this.reach,
    required this.seed,
  });

  final Color ink;
  final double reach;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed);
    final centre = size.center(Offset.zero);
    final path = Path();
    const n = InkStamp.spikes * 2;
    for (var i = 0; i < n; i++) {
      final angle = 2 * math.pi * i / n;
      // The block's own box, grown: a point on an ellipse a little past it.
      final spike = i.isEven;
      final grow = spike ? 1 + reach * (0.6 + 0.4 * random.nextDouble()) : 1.0;
      final point =
          centre +
          Offset(
            math.cos(angle) * size.width / 2 * grow,
            math.sin(angle) * size.height / 2 * grow,
          );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(path..close(), Paint()..color = ink);
  }

  @override
  bool shouldRepaint(_BurstPainter old) =>
      ink != old.ink || reach != old.reach || seed != old.seed;
}
