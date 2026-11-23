import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../layout/space.dart';
import '../primitives/art_picture.dart';
import '../primitives/fit_line.dart';
import '../primitives/paper_card.dart';
import '../primitives/tag_chip.dart';
import '../skin/dress.dart';
import '../skin/ground.dart';
import '../skin/ground_scope.dart';
import '../skin/skin.dart';
import '../skin/werewolf_portrait.dart';
import 'face_content.dart';

/// Every secret, drawn as the role card it is (S04): a piece of paper with
/// the portrait large across its top, the role's name as the hero line with
/// its team tag beside it, the page's lines under them in the mock's body
/// type. A face of several pages (My night, "You" after window 1) shows them
/// all at once, stacked: the first page as above, each other page under it
/// as a row, a small portrait beside its words, so nothing waits behind a
/// gesture nobody finds (cold read on the real screens: two dots and no way
/// to the second page). One design for 04's card, "You" on the night board
/// and 08's My night.
///
/// - [fill]: the face takes the whole box it is given (04: the card turns
///   over in place, in the face-down card's own frame); the portrait takes
///   what the words leave.
/// - Otherwise (a face drawn over the screen): as wide as it is given (most
///   of the screen: [widthFor]) and as tall as its words and a portrait of
///   its natural shape need, at most the height it is given; the portrait
///   gives up what the height lacks. Never an empty lower half.
///
/// Its text is set at most [maxTextScale] times larger. When the words leave
/// the portrait less than [minPortraitShare] of the card's width, they step
/// down to a compact type still at the reading floor (the name as a heading,
/// the lines at 16); only when even that leaves too little is the whole card
/// set smaller. The portrait is never a strip, and a short portrait is cut
/// around the role's face (`ArtSet.portraitCrop`), never through it. Lines
/// are balanced, so no paragraph ends on one word alone.
///
/// Hidden information: the words are left out of what a screen reader reads
/// unless the player asked for them ([announce], the explicit activation).
/// The portrait is always decoded at [portraitBox] (precached at start), so a
/// reveal fetches nothing.
class HeldFace extends StatelessWidget {
  const HeldFace({
    super.key,
    required this.content,
    required this.page,
    this.announce = false,
    this.fill = false,
  });

  final FaceContent content;

  /// Which page is first: kept for the hold count; a face of several pages
  /// always shows them all, the first one large.
  final int page;

  /// Read the page aloud (the player activated the face with a screen
  /// reader, a switch or the keyboard).
  final bool announce;

  /// Fill the box given (04, in place) rather than follow the words.
  final bool fill;

  /// The widest a face drawn over the screen gets (a tablet).
  static const maxWidth = 420.0;

  /// A portrait's natural shape, height over width (S04: 318 over 286).
  static const portraitShape = 1.1;

  /// The least of the card's width the portrait keeps (its height): enough
  /// for any role's face, whole. The words step down first, then the whole
  /// card is set smaller.
  static const minPortraitShare = 0.55;

  /// The same with other pages stacked under the first: the first page's
  /// portrait gives up more, so the pages stay at the reading floor.
  static const minStackedPortraitShare = 0.35;

  /// Faces cap their own text scale.
  static const maxTextScale = 1.6;

  /// The paper around the card's content (S04: 12, 12 and 20 below).
  static const padding = EdgeInsets.fromLTRB(
    Space.md,
    Space.md,
    Space.md,
    Space.lgPlus,
  );

  /// Between the portrait, the name and the lines (S04: 12).
  static const gap = Space.md;

  /// A face drawn over a screen [screenWidth] wide: the gutters left out.
  static double widthFor(double screenWidth) =>
      math.min(maxWidth, screenWidth - 2 * Space.gutter);

  /// The box every face's portrait is decoded for (the largest it is drawn).
  static Size get portraitBox {
    final width = maxWidth - padding.horizontal;
    return Size(width, width * portraitShape);
  }

  @override
  Widget build(BuildContext context) {
    final shown = content.pages.first;
    final more = content.pages.skip(1).toList();
    final card = GroundScope(
      ground: GroundKind.night,
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: maxTextScale,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.hasBoundedWidth
                ? constraints.maxWidth
                : widthFor(MediaQuery.sizeOf(context).width);
            return SizedBox(
              width: width,
              height: fill && constraints.hasBoundedHeight
                  ? constraints.maxHeight
                  : null,
              child: PaperCard(
                lift: PaperLift.heroSlab,
                padding: padding,
                child: _Content(
                  page: shown,
                  more: more,
                  height: constraints.maxHeight - padding.vertical,
                  fill: fill,
                ),
              ),
            );
          },
        ),
      ),
    );
    if (!announce) return ExcludeSemantics(child: card);
    return Semantics(
      container: true,
      liveRegion: true,
      label: [for (final p in content.pages) p.spoken].join('. '),
      child: ExcludeSemantics(child: card),
    );
  }
}

/// The portrait over the words, in [height] at most (infinite: no limit).
/// The words are in the mock's type; when that leaves the portrait less
/// than its least share, the next frame sets them in the compact type (one
/// set of words in the tree, never both), and when even that is too tall the
/// whole is set smaller.
class _Content extends StatefulWidget {
  const _Content({
    required this.page,
    required this.more,
    required this.height,
    required this.fill,
  });

  final FacePage page;

  /// The face's other pages, stacked under [page].
  final List<FacePage> more;
  final double height;
  final bool fill;

  @override
  State<_Content> createState() => _ContentState();
}

class _ContentState extends State<_Content> {
  /// The words are compact, for the room this was found in.
  Object? _compactFor;

  /// What the choice depends on: the page, the room, the text size.
  Object _room(double width) => (
    widget.page.spoken,
    widget.more.length,
    widget.height,
    widget.fill,
    width,
    MediaQuery.textScalerOf(context),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final room = _room(constraints.maxWidth);
      final compact = _compactFor == room;
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: constraints.maxWidth,
          child: _PortraitOverWords(
            height: widget.height,
            fill: widget.fill,
            least: widget.more.isEmpty
                ? HeldFace.minPortraitShare
                : HeldFace.minStackedPortraitShare,
            onCramped: compact
                ? null
                : () => WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _compactFor = room);
                  }),
            children: [
              _Portrait(widget.page.portrait),
              _Words(page: widget.page, more: widget.more, compact: compact),
            ],
          ),
        ),
      );
    },
  );
}

/// The page's name, tag and lines, then the face's other pages as rows, in
/// the paper's ink: in the mock's type, or [compact] (a heading-size name,
/// 16 px lines, closer).
class _Words extends StatelessWidget {
  const _Words({required this.page, required this.more, required this.compact});

  final FacePage page;
  final List<FacePage> more;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ink = context.ground.text;
    final type = skin.typography;
    final name = compact ? type.headline : type.heroRole;
    final body = compact ? type.body : type.bodyLarge;
    return Padding(
      // S04: the description sits 8 in from the portrait's edges.
      padding: const EdgeInsets.symmetric(horizontal: Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: compact ? Space.xs : Space.sm,
        children: [
          if (page.name != null || page.tag != null)
            Row(
              spacing: Space.md,
              children: [
                Expanded(
                  child: page.name == null
                      ? const SizedBox.shrink()
                      : Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: FitLine(
                            page.name!,
                            style: name.copyWith(color: ink),
                          ),
                        ),
                ),
                if (page.tag case final tag?) TagChip(tag),
              ],
            ),
          for (final line in page.lines)
            _Balanced(line, style: body.copyWith(color: ink)),
          for (final other in more) _PageRow(other),
        ],
      ),
    );
  }
}

/// Another page of the face, under the first: a hairline, then its small
/// portrait beside its name and lines (at the reading floor).
class _PageRow extends StatelessWidget {
  const _PageRow(this.page);

  final FacePage page;

  /// The small portrait's width.
  static const portrait = 56.0;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    final type = skin.typography;
    return Container(
      padding: const EdgeInsets.only(top: Space.sm),
      // Dressed up the paper has no rule: the room above the words is it.
      decoration: context.dress.isPaper
          ? null
          : BoxDecoration(
              border: Border(
                top: BorderSide(color: ground.hairline, width: skin.shape.ring),
              ),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: Space.md,
        children: [
          SizedBox(
            width: portrait,
            height: portrait * HeldFace.portraitShape,
            child: _Portrait(page.portrait),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: Space.xxs,
              children: [
                if (page.name case final name?)
                  FitLine(
                    name,
                    style: type.heading.copyWith(color: ground.text),
                  ),
                // Beside the small portrait: wraps between words, never
                // inside one ("Dealt: Doppelganger" at large text).
                for (final line in page.lines)
                  FitWords(line, style: type.body.copyWith(color: ground.text)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A paragraph that never ends on one word alone (a widow): set at the full
/// width, and only when its last line would hold a single word, as narrow
/// as it can be in the same number of lines (CSS's `text-wrap: balance`),
/// which brings a word or two down to keep it company.
class _Balanced extends StatelessWidget {
  const _Balanced(this.text, {required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textScaler: scaler,
          textDirection: Directionality.of(context),
        );
        final width = constraints.hasBoundedWidth
            ? FitWords.widowFreeWidth(painter, constraints.maxWidth)
            : null;
        painter.dispose();
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: SizedBox(
            // A hair over the measured width: the paragraph lays out as
            // measured, whatever the rounding.
            width: width == null
                ? null
                : math.min(constraints.maxWidth, width + 0.5),
            child: Text(text, style: style),
          ),
        );
      },
    );
  }
}

/// The face's portrait: a role, cut around its face; or the moon over the
/// sleeping village (a page that saw no card).
class _Portrait extends StatelessWidget {
  const _Portrait(this.portrait);

  final FacePortrait portrait;

  /// Where the sleeping village is cut for a portrait: its moon.
  static const moonFocus = Alignment(-0.55, -1);

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final radius = BorderRadius.circular(skin.shape.radiusTiny);
    return Container(
      // Dressed up the portrait has no frame (its shadow is its edge).
      foregroundDecoration: context.dress.isPaper
          ? null
          : BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: context.ground.hairline,
                width: skin.shape.ring,
              ),
            ),
      child: ClipRRect(
        borderRadius: radius,
        child: LayoutBuilder(
          builder: (context, box) => switch (portrait) {
            RoleFacePortrait(:final role) => ArtPicture(
              context.roleArt(role),
              focus: skin.art.portraitCrop(role, box.biggest),
              decodeAt: HeldFace.portraitBox,
            ),
            MoonFacePortrait() => ArtPicture(
              skin.art.sleepingVillage,
              focus: moonFocus,
              decodeAt: HeldFace.portraitBox,
            ),
          },
        ),
      ),
    );
  }
}

/// Lays the portrait (first child) over the words (second), [HeldFace.gap]
/// apart. The portrait is as tall as [height] leaves ([fill]) or its
/// natural shape, whichever is less (otherwise), and never less than
/// [HeldFace.minPortraitShare] of the width: when the words leave it less,
/// [onCramped] is told (the words step down), and the whole is taller than
/// [height] (the caller sets it smaller).
class _PortraitOverWords extends MultiChildRenderObjectWidget {
  const _PortraitOverWords({
    required this.height,
    required this.fill,
    required this.least,
    required this.onCramped,
    required super.children,
  });

  final double height;
  final bool fill;

  /// The least share of the width the portrait keeps.
  final double least;
  final VoidCallback? onCramped;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPortraitOverWords(
        height: height,
        fill: fill,
        least: least,
        onCramped: onCramped,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderPortraitOverWords renderObject,
  ) => renderObject
    ..height = height
    ..fill = fill
    ..least = least
    ..onCramped = onCramped;
}

class _Slot extends ContainerBoxParentData<RenderBox> {}

class _RenderPortraitOverWords extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _Slot>,
        RenderBoxContainerDefaultsMixin<RenderBox, _Slot> {
  _RenderPortraitOverWords({
    required double height,
    required bool fill,
    required double least,
    this.onCramped,
  }) : _height = height,
       _fill = fill,
       _least = least;

  double _least;
  set least(double value) {
    if (value == _least) return;
    _least = value;
    markNeedsLayout();
  }

  double _height;
  set height(double value) {
    if (value == _height) return;
    _height = value;
    markNeedsLayout();
  }

  bool _fill;
  set fill(bool value) {
    if (value == _fill) return;
    _fill = value;
    markNeedsLayout();
  }

  VoidCallback? onCramped;

  RenderBox get _portrait => firstChild!;
  RenderBox get _words => childAfter(_portrait)!;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _Slot) child.parentData = _Slot();
  }

  /// The portrait's height for [width] under words [words] tall, and
  /// whether that is the least it keeps (the words cramp it).
  (double, bool) _portraitFor(double width, double words) {
    final least = width * _least;
    final room = _height - words - HeldFace.gap;
    final wanted = _fill && _height.isFinite
        ? room
        : math.min(width * HeldFace.portraitShape, room);
    return wanted < least ? (least, true) : (wanted, false);
  }

  double _heightFor(double width, double words) =>
      _portraitFor(width, words).$1 + HeldFace.gap + words;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final words = _words
        .getDryLayout(BoxConstraints.tightFor(width: width))
        .height;
    return constraints.constrain(Size(width, _heightFor(width, words)));
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    _words.layout(BoxConstraints.tightFor(width: width), parentUsesSize: true);
    final (portrait, cramped) = _portraitFor(width, _words.size.height);
    if (cramped) onCramped?.call();
    _portrait.layout(BoxConstraints.tight(Size(width, portrait)));
    (_portrait.parentData! as _Slot).offset = Offset.zero;
    (_words.parentData! as _Slot).offset = Offset(0, portrait + HeldFace.gap);
    size = constraints.constrain(
      Size(width, portrait + HeldFace.gap + _words.size.height),
    );
  }

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _words.getMaxIntrinsicWidth(double.infinity);

  @override
  double computeMinIntrinsicHeight(double width) =>
      _heightFor(width, _words.getMinIntrinsicHeight(width));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _heightFor(width, _words.getMaxIntrinsicHeight(width));

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
