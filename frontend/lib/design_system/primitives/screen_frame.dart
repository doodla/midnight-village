import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../layout/space.dart';
import '../skin/art_set.dart';
import '../skin/ground.dart';
import '../skin/ground_scope.dart';
import '../skin/skin.dart';
import 'art_picture.dart';

/// How a picture sits across the top of a screen, from the mocks. All three
/// grow by the status bar's height, so on a phone with a notch the picture
/// still reaches the top and the body still starts below the bar.
enum TopArtLayout {
  /// A scene (S01 Join, S05 the village sleeps): 330 tall, the body from 282,
  /// fading from 160.
  scene(height: 330, bodyTop: 282, fadeFrom: 160),

  /// A strip (S02 the table): 180 tall, the body from 118, fading from 80.
  banner(height: 180, bodyTop: 118, fadeFrom: 80),

  /// A backdrop behind the whole top of the screen (S04 your card): 520 tall,
  /// the body from 52, fading from 300.
  backdrop(height: 520, bodyTop: 52, fadeFrom: 300),

  /// A scene that takes all the height the body leaves (S01 Join): at least
  /// [scene]'s, the body at its foot over the last of its fade, so a tall
  /// phone shows more of the village instead of an empty lower half. The
  /// body still scrolls when it cannot fit.
  fill(height: 330, bodyTop: 282, fadeFrom: 160);

  const TopArtLayout({
    required this.height,
    required this.bodyTop,
    required this.fadeFrom,
  });

  final double height;
  final double bodyTop;
  final double fadeFrom;
}

/// A whole screen, laid out as a stack (design brief section 3, rule 6): an
/// optional top (a picture behind the body's start, or a band in
/// [topSlot]), the [body] (scrolling when it does not fit, with the ground
/// fading in over its lower edge while there is more below), and [actions]
/// pinned to the bottom. Each part starts where the one above ends, so larger
/// text pushes things down instead of overlapping. On a wide screen the phone
/// layout is centred and the ground fills the rest.
///
/// Screens never build their own Scaffold: anything that must run edge to
/// edge at the top (the sun, the vote's band, the count's band) goes in
/// [topSlot], which scrolls with the body and reaches under the status bar.
class ScreenFrame extends StatelessWidget {
  const ScreenFrame({
    super.key,
    required this.ground,
    required this.body,
    this.actions = const [],
    this.topArt,
    this.topArtLayout = TopArtLayout.scene,
    this.topSlot,
    this.actionGap = Space.mdPlus,
    this.fitsHeight = false,
  }) : assert(
         topArt == null || topSlot == null,
         'A screen has a top picture or a top band, not both.',
       );

  /// The widest the phone layout gets.
  static const maxWidth = 440.0;

  final GroundKind ground;
  final Widget body;

  /// Stacked at the bottom, full width, primary action first (or the
  /// progress line under it, as the mocks have).
  final List<Widget> actions;

  /// A picture across the top, under the status bar, fading into the ground.
  final ArtImage? topArt;
  final TopArtLayout topArtLayout;

  /// A full-width part above the body (`TimerBand`, `Band`), under the status
  /// bar; it lays out its own safe-area inset.
  final Widget? topSlot;

  /// Between the pinned actions.
  final double actionGap;

  /// The body is given the height above the actions and does not scroll: a
  /// body that sizes itself to that height (the night board, whose every
  /// card must be on screen).
  final bool fitsHeight;

  @override
  Widget build(BuildContext context) {
    final colors = context.skin.ground(ground);
    final safeTop = MediaQuery.paddingOf(context).top;
    final art = topArt;
    final slot = topSlot;

    const padded = EdgeInsets.symmetric(horizontal: Space.gutter);
    final bottom = actions.isEmpty ? Space.screenBottom : Space.md;
    final Widget top;
    if (art != null && topArtLayout == TopArtLayout.fill) {
      // Read here: the Scaffold takes the keyboard out of its body's insets.
      final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
      return _frame(
        context,
        colors,
        LayoutBuilder(
          builder: (context, box) => _ScrollBody(
            fadeTo: colors.ground,
            bottom: bottom,
            child: _FillTop(
              keyboard: keyboard,
              minHeight: box.maxHeight - bottom,
              art: art,
              fadeTo: colors.ground,
              safeTop: safeTop,
              body: Padding(padding: padded, child: body),
            ),
          ),
        ),
      );
    }
    if (art != null) {
      final layout = topArtLayout;
      top = Stack(
        children: [
          SizedBox(
            height: layout.height + safeTop,
            width: double.infinity,
            child: _TopArt(
              art: art,
              fadeTo: colors.ground,
              fadeFrom: (layout.fadeFrom + safeTop) / (layout.height + safeTop),
            ),
          ),
          Padding(
            padding: padded.copyWith(top: layout.bodyTop + safeTop),
            child: body,
          ),
        ],
      );
    } else if (slot != null) {
      final under = Padding(
        padding: padded.copyWith(top: Space.lg),
        child: body,
      );
      top = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        // A body that sizes itself to the height is given what is left
        // under the band.
        children: [
          slot,
          if (fitsHeight) Expanded(child: under) else under,
        ],
      );
    } else {
      top = Padding(
        padding: padded.copyWith(top: Space.screenTop + safeTop),
        child: body,
      );
    }

    return _frame(
      context,
      colors,
      fitsHeight
          ? Padding(
              padding: EdgeInsets.only(bottom: bottom),
              child: top,
            )
          : _ScrollBody(fadeTo: colors.ground, bottom: bottom, child: top),
    );
  }

  /// The screen around [main] (what goes above the pinned actions).
  Widget _frame(BuildContext context, Ground colors, Widget main) {
    return Scaffold(
      backgroundColor: colors.ground,
      body: GroundScope(
        ground: ground,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxWidth),
            // The top runs under the status bar: each kind of top clears it
            // by itself (above).
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: main),
                if (actions.isNotEmpty)
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Space.gutter,
                        Space.xs,
                        Space.gutter,
                        Space.screenBottom,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: actionGap,
                        children: actions,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A part of a `fitsHeight` body that scrolls only when it cannot fit (the
/// vote's rows at ten long names on a small phone at large text), with the
/// same hint as a scrolling body: while there is more below, the ground
/// fades in over its lower edge.
class FadingScroll extends StatelessWidget {
  const FadingScroll({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      _ScrollBody(fadeTo: context.ground.ground, bottom: 0, child: child);
}

/// The body, scrolling when it does not fit. While there is more below, the
/// ground fades in over its lower edge: the board, the list or the text goes
/// on past the button.
class _ScrollBody extends StatefulWidget {
  const _ScrollBody({
    required this.fadeTo,
    required this.bottom,
    required this.child,
  });

  final Color fadeTo;
  final double bottom;
  final Widget child;

  /// How tall the fade is: tall enough that what runs on under the pinned
  /// actions visibly dissolves well before them (11's night, cold read on
  /// the real screens), never a line cut at the edge.
  static const fade = Space.xxl * 2;

  @override
  State<_ScrollBody> createState() => _ScrollBodyState();
}

class _ScrollBodyState extends State<_ScrollBody> {
  final _scroll = ScrollController();
  var _more = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool _measure(ScrollMetricsNotification note) {
    final more = note.metrics.extentAfter > 0;
    if (more != _more) setState(() => _more = more);
    return false;
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      NotificationListener<ScrollMetricsNotification>(
        onNotification: _measure,
        child: NotificationListener<ScrollUpdateNotification>(
          onNotification: (note) => _measure(
            ScrollMetricsNotification(metrics: note.metrics, context: context),
          ),
          child: SingleChildScrollView(
            controller: _scroll,
            padding: EdgeInsets.only(bottom: widget.bottom),
            child: widget.child,
          ),
        ),
      ),
      if (_more)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: _ScrollBody.fade,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [widget.fadeTo.withValues(alpha: 0), widget.fadeTo],
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

/// [TopArtLayout.fill]: the picture takes the height the [body] leaves of
/// [minHeight] (at least down to where the scene's body starts, unless the
/// keyboard is up: then only what the body leaves), and the
/// body sits at its foot, over the last of the fade: the scene's own overlap
/// ([TopArtLayout.height] - [TopArtLayout.bodyTop]) and its fade length.
class _FillTop extends StatelessWidget {
  const _FillTop({
    required this.keyboard,
    required this.minHeight,
    required this.art,
    required this.fadeTo,
    required this.safeTop,
    required this.body,
  });

  /// The keyboard is up: the form keeps to the room above it, the picture
  /// giving up its minimum (only what runs on behind the title is kept).
  final bool keyboard;
  final double minHeight;
  final ArtImage art;
  final Color fadeTo;
  final double safeTop;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    const layout = TopArtLayout.fill;
    final fade = layout.height - layout.fadeFrom;
    return _ArtOverBody(
      // Never taller than the picture is at this width: the whole scene,
      // side to side, never cropped to cover a taller box (what is left
      // over is ground between its fade and the body).
      artAspect: art.pixels.height / art.pixels.width,
      minHeight: minHeight,
      artTop: keyboard ? safeTop : layout.bodyTop + safeTop,
      overlap: layout.height - layout.bodyTop,
      children: [
        LayoutBuilder(
          builder: (context, box) => _TopArt(
            art: art,
            fadeTo: fadeTo,
            fadeFrom: 1 - fade / box.maxHeight,
          ),
        ),
        body,
      ],
    );
  }
}

/// Lays out its second child (the body) at its natural height at the foot
/// of a box at least [minHeight] tall, and its first child (the picture)
/// from the top down to [overlap] below the body's start, at least
/// [artTop] + [overlap] tall and at most its own shape ([artAspect], height
/// over width) at the box's width. The body paints over the picture.
class _ArtOverBody extends MultiChildRenderObjectWidget {
  const _ArtOverBody({
    required this.artAspect,
    required this.minHeight,
    required this.artTop,
    required this.overlap,
    required super.children,
  });

  final double artAspect;
  final double minHeight;
  final double artTop;
  final double overlap;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderArtOverBody(artAspect, minHeight, artTop, overlap);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderArtOverBody renderObject,
  ) => renderObject
    ..artAspect = artAspect
    ..minHeight = minHeight
    ..artTop = artTop
    ..overlap = overlap;
}

class _ArtOverBodyData extends ContainerBoxParentData<RenderBox> {}

class _RenderArtOverBody extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ArtOverBodyData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ArtOverBodyData> {
  _RenderArtOverBody(
    this._artAspect,
    this._minHeight,
    this._artTop,
    this._overlap,
  );

  double _artAspect;
  set artAspect(double value) {
    if (value == _artAspect) return;
    _artAspect = value;
    markNeedsLayout();
  }

  double _minHeight;
  set minHeight(double value) {
    if (value == _minHeight) return;
    _minHeight = value;
    markNeedsLayout();
  }

  double _artTop;
  set artTop(double value) {
    if (value == _artTop) return;
    _artTop = value;
    markNeedsLayout();
  }

  double _overlap;
  set overlap(double value) {
    if (value == _overlap) return;
    _overlap = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ArtOverBodyData) {
      child.parentData = _ArtOverBodyData();
    }
  }

  @override
  void performLayout() {
    final art = firstChild!;
    final body = childAfter(art)!;
    final width = constraints.maxWidth;
    body.layout(BoxConstraints.tightFor(width: width), parentUsesSize: true);
    final bodyHeight = body.size.height;
    final height = constraints.constrainHeight(
      math.max(_minHeight, _artTop + bodyHeight),
    );
    final bodyTop = height - bodyHeight;
    art.layout(
      BoxConstraints.tightFor(
        width: width,
        height: math.min(bodyTop + _overlap, width * _artAspect),
      ),
    );
    (art.parentData! as _ArtOverBodyData).offset = Offset.zero;
    (body.parentData! as _ArtOverBodyData).offset = Offset(0, bodyTop);
    size = Size(width, height);
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

/// The top picture, its lower part fading into the ground.
class _TopArt extends StatelessWidget {
  const _TopArt({
    required this.art,
    required this.fadeTo,
    required this.fadeFrom,
  });

  final ArtImage art;
  final Color fadeTo;

  /// Where the fade starts, as a fraction of the height.
  final double fadeFrom;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      ArtPicture(art),
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [fadeFrom.clamp(0, 1), 1],
            colors: [fadeTo.withValues(alpha: 0), fadeTo],
          ),
        ),
      ),
    ],
  );
}
