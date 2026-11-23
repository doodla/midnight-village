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
/// its longest line and both ends need (the ends may run past the screen's
/// edges, the words never do), turned a little. Bone with ink words; red
/// (the Werewolf team won, or the Tanner) with bone words. The words are the
/// 24 pt headline, centred: a line wider than the room (the screen less its
/// margins) is broken between words, balanced, into at most three lines; a
/// third line or larger text makes the middle taller (`heightOf`) and the ends
/// stay as they are. When even three lines will not take a sentence, the next of [forms]
/// (shorter, by the caller's rule) is tried; a name is never cut, and a word
/// wider than the room keeps the headline's size but stops growing with the
/// phone's text size. On a plain screen it is its words.
class BannerSlice extends StatelessWidget {
  /// [lines] as they are: each line is kept when they all fit the room, and
  /// otherwise the same words are broken again.
  const BannerSlice({
    super.key,
    required List<String> lines,
    this.red = false,
    this.angle = turn,
  }) : _forms = null,
       _minLines = null,
       _given = lines;

  /// A sentence in [forms], longest first, broken into [minLines] to three
  /// lines (two for a sentence of two parts; one is allowed for a short one).
  const BannerSlice.sentences({
    super.key,
    required List<String> forms,
    int minLines = 1,
    this.red = false,
    this.angle = turn,
  }) : _forms = forms,
       _minLines = minLines,
       _given = null;

  final List<String>? _forms;
  final int? _minLines;
  final List<String>? _given;

  List<String> get forms => _forms ?? [_given!.join(' ')];
  int get minLines => _minLines ?? _given!.length;
  final bool red;

  final double angle;

  /// Two lines of the headline at its own size: the paper round them is the
  /// art's, as drawn.
  static const height = 128.0;

  /// The most lines.
  static const mostLines = 3;

  /// The room the words have beside the screen's edges, each side.
  static const margin = Space.lg + Space.xxs;

  static const turn = -1.2 * math.pi / 180;

  /// How tall a banner of [set] is in [style]: [height] for two lines at the
  /// headline's own size, and as much taller as its words are past that (a
  /// third line, a larger text size): the paper above and below the words
  /// stays as drawn and the middle stretches. Never clips its words.
  static double heightOf(
    BannerFit set,
    TextStyle style,
    TextDirection direction,
  ) {
    // A line's height at the headline's own size; the words are drawn at
    // [BannerFit.factor] times it.
    final p = TextPainter(
      text: TextSpan(style: style),
      textDirection: direction,
      textScaler: TextScaler.noScaling,
    );
    final line = p.preferredLineHeight;
    p.dispose();
    final paper = height - 2 * line;
    return math.max(height, set.lines.length * line * set.factor + paper);
  }

  /// How [forms] are set at [room] wide in [style] at [scale] (the phone's
  /// text size): the lines, and the largest text size the words keep. Public
  /// so the screen can reserve the banner's height before it draws.
  static BannerFit fit({
    required List<String> forms,
    required int minLines,
    required double room,
    required TextStyle style,
    required TextDirection direction,
    required double scale,
    List<String>? given,
  }) {
    final widths = <String, double>{};
    double width(String text) => widths.putIfAbsent(text, () {
      final p = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: direction,
        textScaler: TextScaler.noScaling,
        maxLines: 1,
      )..layout();
      final w = p.width;
      p.dispose();
      return w;
    });
    List<String> wordsOf(String form) =>
        form.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final widest = [
      for (final form in forms)
        for (final word in wordsOf(form)) width(word),
    ].fold(0.0, math.max);
    // A word wider than the room stops the text growing, never below 24.
    var factor = scale;
    if (widest * scale > room) factor = math.max(1.0, room / widest);
    factor = math.min(factor, scale);
    double drawn(String line) => width(line) * factor;
    if (given != null && given.every((l) => drawn(l) <= room)) {
      return BannerFit(given, factor, scale);
    }
    List<String>? lastTry;
    for (final form in forms) {
      final words = wordsOf(form);
      for (var n = math.min(minLines, mostLines); n <= mostLines; n++) {
        if (n > words.length) break;
        final lines = _balanced(words, n, drawn);
        lastTry = lines;
        if (lines.every((l) => drawn(l) <= room)) {
          return BannerFit(lines, factor, scale);
        }
      }
    }
    return BannerFit(lastTry ?? [forms.last], factor, scale);
  }

  /// [words] in [n] lines whose widest is the narrowest possible.
  static List<String> _balanced(
    List<String> words,
    int n,
    double Function(String) width,
  ) {
    String join(int from, int to) => words.sublist(from, to).join(' ');
    List<String>? best;
    var bestWidth = double.infinity;
    void tryCuts(List<int> cuts) {
      final all = [0, ...cuts, words.length];
      final lines = [for (var i = 0; i < n; i++) join(all[i], all[i + 1])];
      final widest = lines.map(width).fold(0.0, math.max);
      if (widest < bestWidth - 0.01) {
        bestWidth = widest;
        best = lines;
      }
    }

    if (n == 1) {
      tryCuts(const []);
    } else if (n == 2) {
      for (var i = 1; i < words.length; i++) {
        tryCuts([i]);
      }
    } else {
      for (var i = 1; i < words.length - 1; i++) {
        for (var j = i + 1; j < words.length; j++) {
          tryCuts([i, j]);
        }
      }
    }
    return best ?? [words.join(' ')];
  }

  @override
  Widget build(BuildContext context) {
    final style = context.skin.typography.screenTitle;
    return LayoutBuilder(
      builder: (context, constraints) {
        final room = constraints.hasBoundedWidth
            ? constraints.maxWidth - 2 * margin
            : double.infinity;
        final set = fit(
          forms: forms,
          minLines: minLines,
          room: room,
          style: style,
          direction: Directionality.of(context),
          scale: MediaQuery.textScalerOf(context).scale(1),
          given: _given,
        );
        return _build(context, set);
      },
    );
  }

  Widget _build(BuildContext context, BannerFit set) {
    final lines = set.lines;
    final skin = context.skin;
    final paper = context.dress.isPaper;
    final art = red ? SliceArt.bannerRed : SliceArt.banner;
    final style = skin.typography.screenTitle.copyWith(
      color: paper
          ? (red ? skin.night.text : skin.paper.text)
          : context.ground.text,
    );
    Widget words = Column(
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
    if (set.factor < set.scale) {
      words = MediaQuery.withClampedTextScaling(
        maxScaleFactor: set.factor,
        child: words,
      );
    }
    final h = heightOf(
      set,
      skin.typography.screenTitle,
      Directionality.of(context),
    );
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
                        slice: h > height + 0.5 ? SliceArt.bannerTall : null,
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

/// How a banner's words are set: the [lines], and the text scale they are
/// drawn at ([factor], at most the phone's own [scale]).
@immutable
class BannerFit {
  const BannerFit(this.lines, this.factor, this.scale);

  final List<String> lines;
  final double factor;
  final double scale;
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
