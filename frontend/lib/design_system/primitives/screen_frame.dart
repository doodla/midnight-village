import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../layout/space.dart';
import '../skin/art_set.dart';
import '../skin/ground.dart';
import '../skin/ground_scope.dart';
import '../skin/skin.dart';
import '../skin/system_bars.dart';
import 'art_picture.dart';
import 'layered_art.dart';
import 'scene_arrival.dart';

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
  fill(height: 330, bodyTop: 282, fadeFrom: 160),

  /// A quiet strip behind a title (S06 the night board): 170 tall, the body
  /// from the top margin (where a screen with no picture starts it), the
  /// picture under a veil of the ground so the title is the loudest thing,
  /// fading from 100.
  strip(height: 170, bodyTop: Space.screenTop, fadeFrom: 100, veil: 0.5);

  const TopArtLayout({
    required this.height,
    required this.bodyTop,
    required this.fadeFrom,
    this.veil = 0,
  });

  final double height;
  final double bodyTop;
  final double fadeFrom;

  /// How much of the ground lies over the whole picture (0 none), for a
  /// picture that must stay behind what is written on it.
  final double veil;
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
    this.topScene,
    this.topSceneFrom,
    this.topArtExtra = 0,
    this.topArtLayout = TopArtLayout.scene,
    this.topSlot,
    this.actionGap = Space.mdPlus,
    this.fitsHeight = false,
    this.minBodyHeight,
  }) : assert(
         topArt == null || topSlot == null,
         'A screen has a top picture or a top band, not both.',
       ),
       assert(
         topScene == null || (topArt == null && topSlot == null),
         'A screen has a top picture, a layered one or a top band, only one.',
       ),
       assert(
         topScene == null ||
             topArtLayout == TopArtLayout.backdrop ||
             topArtLayout == TopArtLayout.strip,
         'A layered top picture is a backdrop or a strip.',
       );

  /// The widest the phone layout gets.
  static const maxWidth = 440.0;

  /// How far, of its own height, a top picture comes down into place when a
  /// scene brings the screen in, beyond what the screen itself travels.
  static const arrivalTravel = 0.3;

  final GroundKind ground;
  final Widget body;

  /// Stacked at the bottom, full width, primary action first (or the
  /// progress line under it, as the mocks have).
  final List<Widget> actions;

  /// A picture across the top, under the status bar, fading into the ground.
  final ArtImage? topArt;

  /// The same, drawn in layers ([LayeredArt]): at rest the flat picture it
  /// was cut from; a scene that brings the screen in moves its layers.
  final LayeredSceneId? topScene;

  /// With [topScene] as a strip: the canvas row it starts at
  /// ([LayeredArt.from]).
  final double? topSceneFrom;

  /// A picture taller than its layout by this much (the body does not move):
  /// where a screen has air to spare, the picture takes it.
  final double topArtExtra;
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

  /// With [fitsHeight] under a [topSlot]: the least height the body is
  /// given. Where the slot leaves less (a short phone, large text), the
  /// slot and the body scroll together, the body at this height, rather
  /// than overflow.
  final double? minBodyHeight;

  @override
  Widget build(BuildContext context) {
    final colors = context.skin.ground(ground);
    final safeTop = MediaQuery.paddingOf(context).top;
    final art = topArt;
    final scene = topScene;
    final slot = topSlot;

    const padded = EdgeInsets.symmetric(horizontal: Space.gutter);
    // With no actions (which keep clear of the navigation bar themselves),
    // the body's end stays above it: the screen runs under the bars.
    final bottom = actions.isEmpty
        ? Space.screenBottom + MediaQuery.paddingOf(context).bottom
        : Space.md;
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
    if (art != null || scene != null) {
      final layout = topArtLayout;
      top = Stack(
        children: [
          SizedBox(
            height: layout.height + topArtExtra + safeTop,
            width: double.infinity,
            // Brought in by a scene (the dusk), the picture travels further
            // than the screen: it comes down into place from above, its moon
            // arriving last.
            child: ArrivalShift(
              travel: -arrivalTravel,
              child: _TopArt(
                picture: art != null
                    ? ArtPicture(art)
                    : LayeredArt(scene!, from: topSceneFrom),
                fadeTo: colors.ground,
                fadeFrom:
                    (layout.fadeFrom + topArtExtra + safeTop) /
                    (layout.height + topArtExtra + safeTop),
                veil: layout.veil,
              ),
            ),
          ),
          Padding(
            padding: padded.copyWith(top: layout.bodyTop + safeTop),
            child: body,
          ),
        ],
      );
    } else if (slot != null && fitsHeight && minBodyHeight != null) {
      final under = Padding(
        padding: padded.copyWith(top: Space.lg),
        child: body,
      );
      return _frame(
        context,
        colors,
        Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: LayoutBuilder(
            builder: (context, box) => _ScrollBody(
              fadeTo: colors.ground,
              bottom: 0,
              child: _SlotThenRest(
                viewport: box.maxHeight,
                minRest: minBodyHeight! + Space.lg,
                children: [slot, under],
              ),
            ),
          ),
        ),
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemBarsOver(colors),
      child: _scaffold(colors, main),
    );
  }

  Widget _scaffold(Ground colors, Widget main) {
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
  /// the real screens), never a line cut at the edge. Never taller than
  /// what is still below: a body a few pixels too tall (a held box's lift)
  /// does not grey out its last row (playtest: the Troublemaker chip on 08
  /// read as not in play).
  static const fade = Space.xxl * 2;

  @override
  State<_ScrollBody> createState() => _ScrollBodyState();
}

class _ScrollBodyState extends State<_ScrollBody> {
  final _scroll = ScrollController();

  /// How much of the body is below the edge, up to the fade's height.
  var _below = 0.0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool _measure(ScrollMetricsNotification note) {
    // Only the last of it changes the fade: no rebuild per scrolled pixel.
    final below = math.min(note.metrics.extentAfter, _ScrollBody.fade);
    if (below != _below) setState(() => _below = below);
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
      if (_below > 0)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: _below,
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

/// A top slot at its own height, then the rest of [viewport] for the
/// body, never less than [minRest]: one screen when they fit; taller, to
/// scroll, when the slot leaves too little (never an overflow).
class _SlotThenRest extends MultiChildRenderObjectWidget {
  const _SlotThenRest({
    required this.viewport,
    required this.minRest,
    required super.children,
  });

  final double viewport;
  final double minRest;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSlotThenRest(viewport: viewport, minRest: minRest);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSlotThenRest renderObject,
  ) => renderObject
    ..viewport = viewport
    ..minRest = minRest;
}

class _SlotThenRestData extends ContainerBoxParentData<RenderBox> {}

class _RenderSlotThenRest extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _SlotThenRestData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _SlotThenRestData> {
  _RenderSlotThenRest({required double viewport, required double minRest})
    : _viewport = viewport,
      _minRest = minRest;

  double _viewport;
  set viewport(double value) {
    if (value == _viewport) return;
    _viewport = value;
    markNeedsLayout();
  }

  double _minRest;
  set minRest(double value) {
    if (value == _minRest) return;
    _minRest = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _SlotThenRestData) {
      child.parentData = _SlotThenRestData();
    }
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final slot = firstChild!;
    final rest = childAfter(slot)!;
    slot.layout(
      BoxConstraints(minWidth: width, maxWidth: width),
      parentUsesSize: true,
    );
    final restHeight = math.max(_viewport - slot.size.height, _minRest);
    rest.layout(BoxConstraints.tightFor(width: width, height: restHeight));
    (slot.parentData! as _SlotThenRestData).offset = Offset.zero;
    (rest.parentData! as _SlotThenRestData).offset = Offset(
      0,
      slot.size.height,
    );
    size = constraints.constrain(Size(width, slot.size.height + restHeight));
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
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
            picture: ArtPicture(art),
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
    required this.picture,
    required this.fadeTo,
    required this.fadeFrom,
    this.veil = 0,
  });

  final Widget picture;
  final Color fadeTo;

  /// The share of [fadeTo] laid over the whole picture.
  final double veil;

  /// Where the fade starts, as a fraction of the height.
  final double fadeFrom;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      picture,
      if (veil > 0) ColoredBox(color: fadeTo.withValues(alpha: veil)),
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
