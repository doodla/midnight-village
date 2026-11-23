import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../copy/copy.dart';
import '../layout/space.dart';
import '../primitives/art_picture.dart';
import '../primitives/paper_piece.dart';
import '../primitives/paper_pin.dart';
import '../primitives/screen_frame.dart';
import '../primitives/story_card.dart';
import '../primitives/twine.dart';
import '../models/role.dart';
import '../skin/dress_style.dart';
import '../skin/skin.dart';
import '../skin/skin_tilt.dart';
import 'night_story.dart';

/// The measures of a story's picture.
abstract final class StoryMetrics {
  /// A portrait's shape, height over width (the held face's).
  static const portraitShape = 1.1;

  /// The widest a portrait gets, and the narrowest before the picture
  /// scrolls.
  static const widest = 150.0;
  static const narrowest = 36.0;
  static const step = 2.0;

  /// Between rows: at least this (a thread and its head), and at most this
  /// more from the height to spare.
  static const rowGap = 36.0;
  static const rowGapMore = 24.0;

  /// Between the cards of a row: two, three or more; a swap between them
  /// (two arcs); a look across.
  static const pairGap = 30.0;
  static const manyGap = 14.0;
  static const swapGap = 72.0;
  static const lookGap = 48.0;

  /// The sleeping village: its share of the width, its shape, its least and
  /// most height.
  static const sceneShare = 0.8;
  static const sceneShape = 0.6;
  static const sceneLeast = 72.0;
  static const sceneMost = 180.0;

  /// The village is cut in to its moon and roofs, the rooftop wolf left out:
  /// drawn this much larger, from this corner.
  static const sceneZoom = 1.65;
  static const sceneFocus = Alignment(-1, -0.84);

  /// The swap's arcs bow this far; the two threads of a swap between rows
  /// stand this far either side of the cards' middle.
  static const bow = 30.0;
  static const apart = 12.0;

  /// A thread starts and ends this far off a card's edge.
  static const off = 3.0;
}

/// A [NightStory] drawn: its cards from the top, the threads between them,
/// and its one sentence on a pinned slip under them (names in the names'
/// face, the sentence wrapping, never cut). The cards are as large as lets
/// the whole fit the room; where even the smallest do not (a short phone,
/// large text) it scrolls. A screen reader hears the sentence, then every
/// card ([NightStory.spoken]).
class NightStoryView extends StatelessWidget {
  const NightStoryView({super.key, required this.story});

  final NightStory story;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label: story.spoken,
    child: ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, box) {
          final plan = StoryPlan.of(context, story, box.biggest);
          final picture = _picture(context, plan);
          return plan.fits ? picture : FadingScroll(child: picture);
        },
      ),
    ),
  );

  Widget _picture(BuildContext context, StoryPlan plan) {
    final skin = context.skin;
    final ink = PaperPiece.inkOf(context, PaperPart.scrap);
    return SizedBox(
      width: plan.size.width,
      height: plan.size.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (plan.scene case final scene?)
            Positioned.fromRect(
              rect: scene,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(skin.shape.radiusTiny),
                // Its moon and roofs, the rooftop wolf left out of the cut.
                child: Transform.scale(
                  scale: StoryMetrics.sceneZoom,
                  alignment: StoryMetrics.sceneFocus,
                  child: ArtPicture(skin.art.sleepingVillage),
                ),
              ),
            ),
          for (final (ref, rect) in plan.cards)
            Positioned.fromRect(
              rect: rect,
              child: Transform.rotate(
                angle: skin.tilt.angle(Tilt.seededRow(story.cardAt(ref).label)),
                child: StoryCardFace(
                  label: story.cardAt(ref).label,
                  role: story.cardAt(ref).role,
                  width: rect.width,
                  windowHeight: plan.window,
                  headerHeight: plan.headers[ref.row],
                  stripHeight: plan.strip,
                ),
              ),
            ),
          for (final (route, kind, head) in plan.threads)
            Positioned.fill(
              child: Twine(route: route, kind: kind, head: head),
            ),
          Positioned.fromRect(
            rect: plan.slip,
            child: PaperPiece(
              part: PaperPart.scrap,
              id: ('story', story.line.text),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  Padding(
                    padding: StoryPlan.slipPadding,
                    // Laid out exactly as the plan measured it (no inherited
                    // style), so it wraps where the plan said.
                    child: Center(
                      child: RichText(
                        text: StoryPlan.sentence(context, story, ink),
                        textAlign: TextAlign.center,
                        textScaler: MediaQuery.textScalerOf(context),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -Space.xxs,
                    child: PaperPin(ink: ink),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Where everything of a story lies in a room: every card's box (by its
/// place), each row's tab height, the window and strip, the threads, the
/// slip, and whether it fits without scrolling.
class StoryPlan {
  StoryPlan._({
    required this.cards,
    required this.headers,
    required this.window,
    required this.strip,
    required this.threads,
    required this.slip,
    required this.scene,
    required this.size,
    required this.fits,
  });

  final List<(StoryRef, Rect)> cards;
  final List<double> headers;
  final double window;
  final double strip;
  final List<(TwineRoute, TwineKind, bool)> threads;
  final Rect slip;
  final Rect? scene;
  final Size size;
  final bool fits;

  static const slipPadding = EdgeInsets.fromLTRB(
    Space.md,
    Space.sm,
    Space.md,
    Space.sm,
  );

  /// The sentence's words: the body's, names in the names' face.
  static TextSpan sentence(BuildContext context, NightStory story, Color ink) {
    final type = context.skin.typography;
    return TextSpan(
      style: type.body.copyWith(color: ink),
      children: [
        for (final part in story.line.parts)
          TextSpan(
            text: part.text,
            style: part.name ? type.name.copyWith(color: ink) : null,
          ),
      ],
    );
  }

  static Size _measure(
    InlineSpan span,
    TextScaler scaler, {
    double maxWidth = double.infinity,
  }) {
    final painter = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      textAlign: TextAlign.center,
    )..layout(maxWidth: maxWidth);
    final size = painter.size;
    painter.dispose();
    return size;
  }

  static int _lines(InlineSpan span, TextScaler scaler, double maxWidth) {
    final painter = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout(maxWidth: maxWidth);
    final lines = painter.computeLineMetrics().length;
    painter.dispose();
    return lines;
  }

  static double _gap(NightStory story, int row) {
    final n = story.rows[row].length;
    for (final link in story.links) {
      if (link.from.row == row && link.to.row == row) {
        return link.kind == StoryLinkKind.swap
            ? StoryMetrics.swapGap
            : StoryMetrics.lookGap;
      }
    }
    return n > 2 ? StoryMetrics.manyGap : StoryMetrics.pairGap;
  }

  static StoryPlan of(BuildContext context, NightStory story, Size room) {
    final type = context.skin.typography;
    final scaler = MediaQuery.textScalerOf(context);
    final width = room.width;
    final inner = width - 2 * Space.sm;
    final nameLine = _measure(
      TextSpan(text: NightCopy.you, style: type.name),
      scaler,
    );
    final strip =
        _measure(
          TextSpan(text: NightCopy.left, style: type.tag),
          scaler,
        ).height +
        Space.xs;
    final inset = StoryCardFace.inset;
    final pad = StoryCardFace.tabPad;
    // The slip's words at the widest it is given.
    final slipWidth = math.min(inner, 360.0);
    final words = sentence(context, story, context.ground.text);
    var text = _measure(
      words,
      scaler,
      maxWidth: slipWidth - slipPadding.horizontal,
    );
    // Wrapped, the lines are evened out: the narrowest width that keeps as
    // many lines (no word left alone on the last).
    final lines = _lines(words, scaler, slipWidth - slipPadding.horizontal);
    if (lines > 1) {
      var low = text.width / lines;
      var high = text.width;
      while (high - low > 1) {
        final mid = (low + high) / 2;
        if (_lines(words, scaler, mid) > lines) {
          low = mid;
        } else {
          high = mid;
        }
      }
      text = _measure(words, scaler, maxWidth: high);
    }
    final slipSize = Size(
      text.width + slipPadding.horizontal + 1,
      text.height + slipPadding.vertical,
    );

    // Per card: the least width its words need, and its tab's lines at a
    // card [cap] wide.
    double needOf(StoryCard card, double cap) {
      final name = _measure(
        TextSpan(text: card.label, style: type.name),
        scaler,
      ).width;
      final role = card.role == null
          ? 0.0
          : _measure(
              TextSpan(text: card.role!.displayName, style: type.tag),
              scaler,
            ).width;
      return math.min(cap, math.max(name + 2 * pad, role + 2 * inset + 2));
    }

    double headerOf(StoryCard card, double cardWidth) {
      final lines = _measure(
        TextSpan(text: card.label, style: type.name),
        scaler,
        maxWidth: math.max(1, cardWidth - 2 * pad),
      ).height;
      return math.max(nameLine.height, lines) + Space.xs;
    }

    final rows = story.rows;
    StoryPlan at(double portrait, {required bool fits}) {
      final widths = <List<double>>[];
      final headers = <double>[];
      var heights = 0.0;
      var portraitUsed = portrait;
      for (final (i, row) in rows.indexed) {
        final gap = _gap(story, i);
        final cap = (inner - gap * (row.length - 1)) / row.length;
        portraitUsed = math.min(portraitUsed, cap - 2 * inset);
      }
      portraitUsed = math.max(StoryMetrics.narrowest, portraitUsed);
      final window = portraitUsed * StoryMetrics.portraitShape;
      for (final (i, row) in rows.indexed) {
        final gap = _gap(story, i);
        final cap = (inner - gap * (row.length - 1)) / row.length;
        final w = [
          for (final card in row)
            math.max(portraitUsed + 2 * inset, needOf(card, cap)),
        ];
        widths.add(w);
        final header = [
          for (final (j, card) in row.indexed) headerOf(card, w[j]),
        ].reduce(math.max);
        headers.add(header);
        heights += StoryCardFace.heightOf(window, header, strip);
      }
      final sceneHeight = story.sleeps
          ? (portraitUsed * 1.4).clamp(
              StoryMetrics.sceneLeast,
              StoryMetrics.sceneMost,
            )
          : 0.0;
      final gaps = rows.length - 1 + (story.sleeps ? 1 : 0);
      final used =
          Space.sm +
          heights +
          sceneHeight +
          gaps * StoryMetrics.rowGap +
          StoryMetrics.rowGap +
          slipSize.height +
          Space.sm;
      final spare = math.max(0.0, room.height - used);
      final rowGap =
          StoryMetrics.rowGap +
          math.min(StoryMetrics.rowGapMore, spare / math.max(1, gaps + 1));
      // Set out the rows, each centred.
      final cards = <(StoryRef, Rect)>[];
      var y = Space.sm;
      for (final (i, row) in rows.indexed) {
        final gap = _gap(story, i);
        final total = widths[i].fold(0.0, (a, b) => a + b);
        var x = (width - total - gap * (row.length - 1)) / 2;
        final h = StoryCardFace.heightOf(window, headers[i], strip);
        for (final (j, _) in row.indexed) {
          cards.add(((row: i, col: j), Rect.fromLTWH(x, y, widths[i][j], h)));
          x += widths[i][j] + gap;
        }
        y += h + rowGap;
      }
      Rect? scene;
      if (story.sleeps) {
        final w = math.min(
          inner * StoryMetrics.sceneShare,
          sceneHeight / StoryMetrics.sceneShape,
        );
        scene = Rect.fromLTWH((width - w) / 2, y, w, sceneHeight);
        y += sceneHeight + rowGap;
      }
      final slip = Rect.fromLTWH(
        (width - slipSize.width) / 2,
        y - rowGap + StoryMetrics.rowGap,
        slipSize.width,
        slipSize.height,
      );
      final rects = {for (final (ref, r) in cards) ref: r};
      return StoryPlan._(
        cards: cards,
        headers: headers,
        window: window,
        strip: strip,
        threads: [for (final l in story.links) ..._threads(l, rects)],
        slip: slip,
        scene: scene,
        size: Size(width, math.max(room.height, slip.bottom + Space.sm)),
        fits: fits,
      );
    }

    for (
      var p = StoryMetrics.widest;
      p >= StoryMetrics.narrowest;
      p -= StoryMetrics.step
    ) {
      final plan = at(p, fits: true);
      if (plan.slip.bottom + Space.sm <= room.height) return plan;
    }
    return at(StoryMetrics.narrowest, fits: false);
  }

  /// The upper arc of a swap between two cards of a row (A to B, a head at
  /// B) and the lower one back.
  static (TwineRoute, TwineRoute) _arcs(Rect a, Rect b) {
    const off = StoryMetrics.off;
    final u1 = Offset(a.right + off, a.top + a.height * 0.36);
    final u2 = Offset(b.left - off, b.top + b.height * 0.36);
    final l1 = Offset(b.left - off, b.top + b.height * 0.68);
    final l2 = Offset(a.right + off, a.top + a.height * 0.68);
    return (
      TwineRoute(
        u1,
        Offset.lerp(u1, u2, 0.5)! - const Offset(0, StoryMetrics.bow),
        u2,
      ),
      TwineRoute(
        l1,
        Offset.lerp(l1, l2, 0.5)! + const Offset(0, StoryMetrics.bow),
        l2,
      ),
    );
  }

  static List<(TwineRoute, TwineKind, bool)> _threads(
    StoryLink link,
    Map<StoryRef, Rect> rects,
  ) {
    const off = StoryMetrics.off;
    final a = rects[link.from]!;
    final b = rects[link.to]!;
    final across = link.from.row == link.to.row;
    TwineRoute straight(Offset p, Offset q) =>
        TwineRoute(p, Offset.lerp(p, q, 0.5)!, q);
    switch (link.kind) {
      case StoryLinkKind.look || StoryLinkKind.see:
        final head = link.kind == StoryLinkKind.look;
        final kind = TwineKind.look;
        if (across) {
          final p = Offset(a.right + off, a.center.dy);
          final q = Offset(b.left - off, b.center.dy);
          return [
            (
              TwineRoute(p, Offset.lerp(p, q, 0.5)! + const Offset(0, 8), q),
              kind,
              head,
            ),
          ];
        }
        final p = Offset(
          a.center.dx + (b.center.dx - a.center.dx) * 0.18,
          a.bottom + off,
        );
        final q = Offset(b.center.dx, b.top - off);
        return [(straight(p, q), kind, head)];
      case StoryLinkKind.swap:
        if (across) {
          final (upper, lower) = _arcs(a, b);
          return [(upper, TwineKind.move, true), (lower, TwineKind.move, true)];
        }
        final dx = b.center.dx - a.center.dx;
        if (dx.abs() < 4) {
          const s = StoryMetrics.apart;
          return [
            (
              straight(
                Offset(a.center.dx - s, a.bottom + off),
                Offset(b.center.dx - s, b.top - off),
              ),
              TwineKind.move,
              true,
            ),
            (
              straight(
                Offset(b.center.dx + s, b.top - off),
                Offset(a.center.dx + s, a.bottom + off),
              ),
              TwineKind.move,
              true,
            ),
          ];
        }
        // To a card off to the side: two bows, one each way.
        final p = Offset(a.center.dx, a.bottom + off);
        final q = Offset(b.center.dx, b.top - off);
        final mid = Offset.lerp(p, q, 0.5)!;
        final line = q - p;
        final normal = Offset(-line.dy, line.dx) / line.distance;
        const bend = StoryMetrics.apart;
        return [
          (TwineRoute(p, mid + normal * bend, q), TwineKind.move, true),
          (TwineRoute(q, mid - normal * bend, p), TwineKind.move, true),
        ];
      case StoryLinkKind.act:
        final c = rects[link.pair]!;
        final (upper, _) = _arcs(b, c);
        final p = Offset(a.center.dx, a.bottom + off);
        return [(straight(p, upper.at(0.5)), TwineKind.move, false)];
    }
  }
}
