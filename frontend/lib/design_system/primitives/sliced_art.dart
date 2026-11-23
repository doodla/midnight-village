import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../layout/space.dart';
import '../skin/dress.dart';
import '../skin/end_art.dart';
import '../skin/skin.dart';
import 'paper_grain.dart';

/// A picture cut in slices that stretch, drawn with its ends and corners at
/// the size the board shows them and only the middle stretched: a nine-slice
/// ([BoardFrame]) or a three-slice (a banner, a roof: the same with a middle
/// that runs the whole height). Flutter's own `centerSlice`, with the scale
/// that makes one logical pixel of end of `art.pixelsPerPoint` file pixels, so
/// an end is the same size at every width and height; nothing is distorted.
class SlicedArt extends StatelessWidget {
  const SlicedArt({super.key, required this.art, this.slice, this.size});

  final SliceArt art;

  /// Another cut of the same picture (a banner of three lines).
  final Rect? slice;

  /// How big it is drawn; as big as its parent allows when null.
  final Size? size;

  @override
  Widget build(BuildContext context) {
    final path = context.skin.art.end.piece(art.piece).path;
    return Image(
      image: ExactAssetImage(path, scale: art.pixelsPerPoint),
      // Flutter reads a slice in the picture's logical pixels (its pixels over
      // the scale), so the ends stay `pixelsPerPoint` pixels to the point.
      centerSlice: art.inPoints(slice),
      width: size?.width,
      height: size?.height,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
      gaplessPlayback: true,
      errorBuilder: (context, error, stack) => const SizedBox.shrink(),
    );
  }
}

/// The result in one sentence, on a swallowtail banner of cut paper that
/// stretches with its words: an end, a middle, an end, 128 tall, as wide as
/// its longest line and both ends need (it may run past the screen's edges),
/// turned a little. Bone with ink words; red (when you lost) with bone words.
/// The words are the 24 pt headline, centred, a line each; a third line makes
/// the middle taller ([extraLine]) and the ends stay as they are. On a plain
/// screen it is its words.
class BannerSlice extends StatelessWidget {
  const BannerSlice({
    super.key,
    required this.lines,
    this.red = false,
    this.angle = turn,
  });

  /// The words, a line each (at most three).
  final List<String> lines;
  final bool red;

  /// How far it is turned (a test lays it square).
  final double angle;

  /// How tall the banner is at rest.
  static const height = 128.0;

  /// How much taller a third line makes it.
  static const extraLine = 30.0;

  /// How far it is turned: a degree and a fifth to the left.
  static const turn = -1.2 * math.pi / 180;

  /// The banner's height for [lines] lines.
  static double heightFor(int lines) =>
      height + (lines > 2 ? (lines - 2) * extraLine : 0);

  @override
  Widget build(BuildContext context) {
    assert(lines.isNotEmpty && lines.length <= 3, 'one to three lines');
    final skin = context.skin;
    final paper = context.dress.isPaper;
    final art = red ? SliceArt.bannerRed : SliceArt.banner;
    final style = skin.typography.screenTitle.copyWith(
      color: paper
          ? (red ? skin.night.text : skin.paper.text)
          : context.ground.text,
    );
    final words = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final line in lines)
          Text(
            line,
            textAlign: TextAlign.center,
            maxLines: 1,
            softWrap: false,
            style: style,
          ),
      ],
    );
    final h = heightFor(lines.length);
    if (!paper) {
      return Semantics(
        label: lines.join(' '),
        excludeSemantics: true,
        child: SizedBox(
          height: h,
          child: Center(child: words),
        ),
      );
    }
    final ends = art.ends;
    return Semantics(
      label: lines.join(' '),
      excludeSemantics: true,
      child: SizedBox(
        height: h,
        child: OverflowBox(
          minWidth: 0,
          maxWidth: double.infinity,
          child: Transform.rotate(
            angle: angle,
            child: IntrinsicWidth(
              child: SizedBox(
                height: h,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Positioned, so the picture's own size is no part of how
                    // wide the banner is: its words and both ends are.
                    Positioned.fill(
                      child: SlicedArt(
                        art: art,
                        slice: lines.length > 2 ? SliceArt.bannerTall : null,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(
                        left: ends.left + Space.sm,
                        right: ends.right + Space.sm,
                      ),
                      child: Center(child: words),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The board's frame: felt (the ground's panel, with the paper's grain) held in
/// a nine-slice frame of coarse planks about 19 pt thick, [child] laid in the
/// felt, clear of the frame. Whatever size it is given, the corners and the
/// planks' width are the same; only the planks' length stretches.
class BoardFrame extends StatelessWidget {
  const BoardFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ends = SliceArt.frame.ends;
    final felt = DecoratedBox(
      decoration: BoxDecoration(
        color: context.ground.panel,
        image: PaperGrain.image,
      ),
    );
    if (!context.dress.isPaper) return child;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: Padding(padding: ends * 0.5, child: felt),
        ),
        Padding(padding: ends, child: child),
        const Positioned.fill(
          child: IgnorePointer(child: SlicedArt(art: SliceArt.frame)),
        ),
      ],
    );
  }
}

/// The board's roof: a strip of shingles, 30 tall, its middle stretching in
/// width only, the ends as drawn.
class BoardRoof extends StatelessWidget {
  const BoardRoof({super.key, this.width});

  final double? width;

  @override
  Widget build(BuildContext context) {
    if (!context.dress.isPaper) return const SizedBox.shrink();
    return SlicedArt(
      art: SliceArt.roof,
      size: Size(width ?? double.infinity, SliceArt.roof.natural.height),
    );
  }
}
