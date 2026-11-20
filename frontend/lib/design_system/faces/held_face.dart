import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../layout/space.dart';
import '../primitives/art_picture.dart';
import '../primitives/fit_line.dart';
import '../primitives/paper_card.dart';
import '../primitives/tag_chip.dart';
import '../skin/ground.dart';
import '../skin/ground_scope.dart';
import '../skin/skin.dart';
import 'face_content.dart';

/// Every secret, drawn as the role card it is (S04): a piece of paper with
/// the portrait large across its top, the role's name as the hero line with
/// its team tag beside it, the page's lines under them in the mock's body
/// type, and dots for the pages when there are several. One design for
/// 04's card, "You" on the night board and 08's My night.
///
/// - [fill]: the face takes the whole box it is given (04: the card turns
///   over in place, in the face-down card's own frame); the portrait takes
///   what the words leave.
/// - Otherwise (a face drawn over the screen): as wide as it is given (most
///   of the screen: [widthFor]) and as tall as its words and a portrait of
///   its natural shape need, at most the height it is given; the portrait
///   gives up what the height lacks. Never an empty lower half.
///
/// Its text is set at most [maxTextScale] times larger, and the whole card
/// smaller rather than out of its box when the words leave the portrait less
/// than [minPortraitShare] of the card's width.
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

  /// Which page shows: each new hold shows the next.
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

  /// The least of the card's width the portrait keeps before the whole card
  /// is set smaller instead.
  static const minPortraitShare = 0.3;

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
    final shown = content.pages[page % content.pages.length];
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
                  index: page % content.pages.length,
                  pages: content.pages.length,
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
      label: shown.spoken,
      child: ExcludeSemantics(child: card),
    );
  }
}

/// The portrait over the words, in [height] at most (infinite: no limit),
/// set smaller as a whole when the words leave the portrait too little.
class _Content extends StatelessWidget {
  const _Content({
    required this.page,
    required this.index,
    required this.pages,
    required this.height,
    required this.fill,
  });

  final FacePage page;
  final int index;
  final int pages;
  final double height;
  final bool fill;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: constraints.maxWidth,
        child: _PortraitOverWords(
          height: height,
          fill: fill,
          children: [
            _Portrait(page.portrait),
            _Words(page: page, index: index, pages: pages),
          ],
        ),
      ),
    ),
  );
}

/// The page's name, tag, lines and page dots, in the paper's ink.
class _Words extends StatelessWidget {
  const _Words({required this.page, required this.index, required this.pages});

  final FacePage page;
  final int index;
  final int pages;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ink = context.ground.text;
    final type = skin.typography;
    return Padding(
      // S04: the description sits 8 in from the portrait's edges.
      padding: const EdgeInsets.symmetric(horizontal: Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: Space.sm,
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
                            style: type.heroRole.copyWith(color: ink),
                          ),
                        ),
                ),
                if (page.tag case final tag?) TagChip(tag),
              ],
            ),
          for (final line in page.lines)
            Text(line, style: type.bodyLarge.copyWith(color: ink)),
          if (pages > 1) _Dots(current: index, count: pages),
        ],
      ),
    );
  }
}

/// The face's portrait: a role, or the moon over the sleeping village (a
/// page that saw no card).
class _Portrait extends StatelessWidget {
  const _Portrait(this.portrait);

  final FacePortrait portrait;

  /// Where the sleeping village is cut for a portrait: its moon.
  static const moonFocus = Alignment(-0.55, -1);

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ring = context.ground.hairline;
    return Container(
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(skin.shape.radiusTiny),
        border: Border.all(color: ring, width: skin.shape.ring),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(skin.shape.radiusTiny),
        child: switch (portrait) {
          RoleFacePortrait(:final role) => ArtPicture(
            skin.art.role(role),
            decodeAt: HeldFace.portraitBox,
          ),
          MoonFacePortrait() => ArtPicture(
            skin.art.sleepingVillage,
            focus: moonFocus,
            decodeAt: HeldFace.portraitBox,
          ),
        },
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.current, required this.count});

  final int current;
  final int count;

  @override
  Widget build(BuildContext context) {
    final ground = context.ground;
    return Row(
      spacing: Space.xs,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            width: Space.sm,
            height: Space.sm,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == current ? ground.text : ground.hairline,
            ),
          ),
      ],
    );
  }
}

/// Lays the portrait (first child) over the words (second), [HeldFace.gap]
/// apart: the words at their own height, the portrait as tall as [height]
/// leaves ([fill]) or its natural shape, whichever is less (otherwise), and
/// never less than [HeldFace.minPortraitShare] of the width (then the whole
/// is taller than [height] and the caller sets it smaller).
class _PortraitOverWords extends MultiChildRenderObjectWidget {
  const _PortraitOverWords({
    required this.height,
    required this.fill,
    required super.children,
  });

  final double height;
  final bool fill;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPortraitOverWords(height: height, fill: fill);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderPortraitOverWords renderObject,
  ) => renderObject
    ..height = height
    ..fill = fill;
}

class _Slot extends ContainerBoxParentData<RenderBox> {}

class _RenderPortraitOverWords extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _Slot>,
        RenderBoxContainerDefaultsMixin<RenderBox, _Slot> {
  _RenderPortraitOverWords({required double height, required bool fill})
    : _height = height,
      _fill = fill;

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

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _Slot) child.parentData = _Slot();
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final portrait = firstChild!;
    final words = childAfter(portrait)!;
    words.layout(BoxConstraints.tightFor(width: width), parentUsesSize: true);
    final room = _height - words.size.height - HeldFace.gap;
    final natural = width * HeldFace.portraitShape;
    var tall = _fill && _height.isFinite ? room : math.min(natural, room);
    tall = math.max(tall, width * HeldFace.minPortraitShare);
    portrait.layout(BoxConstraints.tight(Size(width, tall)));
    (portrait.parentData! as _Slot).offset = Offset.zero;
    (words.parentData! as _Slot).offset = Offset(0, tall + HeldFace.gap);
    size = constraints.constrain(
      Size(width, tall + HeldFace.gap + words.size.height),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
