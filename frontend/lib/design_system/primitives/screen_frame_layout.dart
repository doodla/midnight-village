part of 'screen_frame.dart';

// How `ScreenFrame` lays its body out: the fading scroll, the slot above the rest, and
// the art drawn over or above the body. Part of screen_frame.dart.

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
/// [minHeight], and the body sits at its foot, over the last of the fade:
/// the scene's own overlap ([TopArtLayout.height] - [TopArtLayout.bodyTop])
/// and its fade length. The picture is decoration and gives way first, by
/// rule: a body that needs the room (a short phone, large text, the keyboard
/// up) pushes it up and off the top, never the body down past the foot; only
/// the status bar's height is kept, so the body never starts under it.
class _FillTop extends StatelessWidget {
  const _FillTop({
    required this.minHeight,
    required this.art,
    required this.fadeTo,
    required this.safeTop,
    required this.body,
  });

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
      artTop: safeTop,
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
  Widget build(BuildContext context) {
    // Dressed up, the ground under the picture is the mood (a lit pool, a
    // vignette), never one flat colour: the picture's own paper thins away
    // into it, so no seam shows where the picture ends and the form lies on
    // its foreground. One still picture, the fade done once in it: a frame
    // draws the picture, never the mask.
    if (context.dress.isPaper && veil == 0) {
      return Still(
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [fadeFrom.clamp(0, 1), 1],
            colors: [fadeTo, fadeTo.withValues(alpha: 0)],
          ).createShader(rect),
          child: picture,
        ),
      );
    }
    return _plain();
  }

  Widget _plain() => Stack(
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
