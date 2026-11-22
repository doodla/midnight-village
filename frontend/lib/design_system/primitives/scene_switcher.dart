import 'package:flutter/widgets.dart';

import '../layout/space.dart';
import '../skin/skin.dart';
import 'band.dart';
import 'screen_frame.dart';

/// The two scene changes of the game, the moments every phone at a table
/// shares. Both are the same gesture: the old world sinks away down the
/// screen on a paper edge and the new one, whole and live where it will rest,
/// rises the last few pixels into its place wearing its own picture.
enum SceneKind {
  /// The deal to the night: the table's screen sinks; the card's own village
  /// and moon rise into their place.
  dusk,

  /// The night to the talk: the night sinks; the talk's own dawn rooftops,
  /// the sun with them, rise into their place.
  dawn;

  /// How far the arriving screen rises into place, of the screen's height:
  /// the rooftops and the sun of the dawn more than the dusk's moon.
  double get rise => switch (this) {
    SceneKind.dusk => 0.04,
    SceneKind.dawn => 0.08,
  };
}

/// Shows [child] and, when [stage] changes, takes the change over: a crossfade
/// ([Motion.settle]) unless [sceneBetween] names a [SceneKind] for it, then
/// that scene ([Motion.scene]). Reduce motion: an instant cut.
///
/// A scene is made of nothing but the two screens: the arriving one is whole
/// and opaque in its place under the leaving one, which sinks away down the
/// screen on a hard paper edge (a lip and its shadow); the arriving one
/// rises the last few pixels. No picture of its own, no dissolve, no layer
/// seen through another.
///
/// Nothing in here waits or blocks. The arriving screen is in the tree and
/// takes touches from the first frame, where it will rest (its slide does not
/// move what a touch lands on), even while the leaving screen still covers
/// it; the leaving screen and the lip are for the eyes only (no touch, no
/// semantics), and everything that moves is a slide of a layer already
/// painted.
///
/// A change that comes while a scene runs (the night's "village sleeps" wait
/// giving way to the card) swaps the arriving screen in place and lets the
/// scene finish; it never restarts it.
class SceneSwitcher<T> extends StatefulWidget {
  const SceneSwitcher({
    super.key,
    required this.stage,
    required this.child,
    required this.sceneBetween,
  });

  /// Which screen [child] is: a change is a new screen (equal stages are the
  /// same screen, whose [child] only has new values).
  final T stage;
  final Widget child;

  /// The scene for a change from one stage to the next; null is a crossfade.
  final SceneKind? Function(T from, T to) sceneBetween;

  /// The share of a scene the leaving screen takes to clear the screen (the
  /// rest it holds still): the arriving screen's primary button, near the
  /// foot, is uncovered before 60% of [Motion.scene].
  static const move = 0.85;

  /// The thickness of the paper edge and of the shadow it casts.
  static const lip = 3.0;
  static const shadow = 8.0;

  @override
  State<SceneSwitcher<T>> createState() => _SceneSwitcherState<T>();
}

/// A screen on its way out.
class _Leaving {
  const _Leaving(this.id, this.child, this.opacity, this.slide);

  final int id;
  final Widget child;
  final Animation<double> opacity;
  final Animation<Offset> slide;
}

class _SceneSwitcherState<T> extends State<SceneSwitcher<T>>
    with SingleTickerProviderStateMixin {
  /// 0 to 1 over a change.
  late final AnimationController _progress;

  /// Names the screen showing now (a new one for each change of stage).
  var _id = 0;
  var _leaving = <_Leaving>[];

  /// The scene running, null for a crossfade or when nothing runs.
  SceneKind? _scene;

  Animation<double> _in = kAlwaysCompleteAnimation;
  Animation<Offset> _inSlide = const AlwaysStoppedAnimation(Offset.zero);
  Animation<Offset>? _edge;
  final _curved = <CurvedAnimation>[];

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(vsync: this)..addStatusListener(_finished);
    _warmUp();
  }

  @override
  void dispose() {
    _disposeCurves();
    _progress.dispose();
    super.dispose();
  }

  bool get _running => _progress.isAnimating;

  /// The arriving screens' own pictures, decoded before they are needed: a
  /// scene never rises on an empty header. (Not awaited; the app does not
  /// start slower for it.) Sized as the screens draw them, so the same
  /// decoded picture is found.
  void _warmUp() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final skin = context.skin;
      final size = MediaQuery.sizeOf(context);
      final top = MediaQuery.paddingOf(context).top;
      final ratio = MediaQuery.devicePixelRatioOf(context);
      final width = size.width.clamp(0, ScreenFrame.maxWidth).toDouble();
      final pictures = [
        // 04's village and moon.
        (
          skin.art.nightVillage,
          Size(width, TopArtLayout.backdrop.height + top),
        ),
        // 08's dawn rooftops.
        (
          skin.art.dawnGallows,
          Size(width, TimerBand.skyFor(size.height) + top),
        ),
      ];
      for (final (art, box) in pictures) {
        precacheImage(art.decodedFor(box, ratio), context, onError: (_, _) {});
      }
    });
  }

  void _disposeCurves() {
    for (final curve in _curved) {
      curve.dispose();
    }
    _curved.clear();
  }

  void _finished(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    setState(() {
      _leaving = [];
      _scene = null;
      _resting();
    });
  }

  void _resting() {
    _in = kAlwaysCompleteAnimation;
    _inSlide = const AlwaysStoppedAnimation(Offset.zero);
    _edge = null;
    _disposeCurves();
  }

  /// [from] to [to] of the change, [Motion.curve] over that stretch.
  Animation<double> _span(double from, double to) {
    final curved = CurvedAnimation(
      parent: _progress,
      curve: Interval(from, to, curve: Motion.curve),
    );
    _curved.add(curved);
    return curved;
  }

  @override
  void didUpdateWidget(SceneSwitcher<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stage == widget.stage) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _progress.stop();
      _leaving = [];
      _scene = null;
      _resting();
      _id++;
      return;
    }
    if (_running && _scene != null) {
      // The scene goes on; the screen it arrives on is another one now.
      _id++;
      return;
    }
    final scene = widget.sceneBetween(oldWidget.stage, widget.stage);
    // A crossfade cut across by this change: what was arriving at some
    // opacity leaves from that opacity.
    final from = _running ? _in.value : 1.0;
    final oldChild = oldWidget.child;
    final oldId = _id++;
    _progress.stop();
    _disposeCurves();
    _scene = scene;
    final (out, outSlide) = scene == null ? _crossfade(from) : _sink(scene);
    _leaving = [_Leaving(oldId, oldChild, out, outSlide)];
    _progress
      ..duration = scene == null ? Motion.settle : Motion.scene
      ..forward(from: 0);
  }

  (Animation<double>, Animation<Offset>) _crossfade(double from) {
    _in = _span(0, 1);
    _inSlide = const AlwaysStoppedAnimation(Offset.zero);
    _edge = null;
    return (
      _span(0, 1).drive(Tween(begin: from, end: 0)),
      const AlwaysStoppedAnimation(Offset.zero),
    );
  }

  /// The leaving screen, opaque, sinks down off the screen; the arriving one,
  /// opaque, rises [SceneKind.rise] into its place.
  (Animation<double>, Animation<Offset>) _sink(SceneKind scene) {
    _in = kAlwaysCompleteAnimation;
    _inSlide = _span(
      0,
      SceneSwitcher.move,
    ).drive(Tween(begin: Offset(0, scene.rise), end: Offset.zero));
    final sink = _span(
      0,
      SceneSwitcher.move,
    ).drive(Tween(begin: Offset.zero, end: const Offset(0, 1)));
    _edge = sink;
    return (kAlwaysCompleteAnimation, sink);
  }

  @override
  Widget build(BuildContext context) {
    final arriving = _Layer(
      key: ValueKey(_id),
      opacity: _in,
      slide: _inSlide,
      leaving: false,
      child: widget.child,
    );
    final leaving = [
      for (final gone in _leaving)
        _Layer(
          key: ValueKey(gone.id),
          opacity: gone.opacity,
          slide: gone.slide,
          leaving: true,
          child: gone.child,
        ),
    ];
    return Stack(
      fit: StackFit.expand,
      children: [
        // A scene: the arriving screen is whole under the leaving one, which
        // sinks off it. A crossfade: the arriving one fades in over it.
        if (_scene != null) ...[
          arriving,
          ...leaving,
          if (_edge case final edge?)
            _Edge(key: const ValueKey('scene'), slide: edge),
        ] else ...[
          ...leaving,
          arriving,
        ],
      ],
    );
  }
}

/// One screen in the switcher: always the same shape of widgets, so a screen
/// keeps its state from arriving to leaving. A [leaving] layer is for the
/// eyes only. The arriving one is never behind anything that stops a touch,
/// its semantics are in from the first frame, and what it slides does not
/// move where a touch lands.
class _Layer extends StatelessWidget {
  const _Layer({
    super.key,
    required this.opacity,
    required this.slide,
    required this.leaving,
    required this.child,
  });

  final Animation<double> opacity;
  final Animation<Offset> slide;
  final bool leaving;
  final Widget child;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: leaving,
    child: ExcludeSemantics(
      excluding: leaving,
      child: SlideTransition(
        position: slide,
        transformHitTests: leaving,
        child: FadeTransition(
          opacity: opacity,
          alwaysIncludeSemantics: true,
          child: RepaintBoundary(child: child),
        ),
      ),
    ),
  );
}

/// The paper edge of the sinking screen and the hard shadow it casts on the
/// one under it, riding the screen's top edge down.
class _Edge extends StatelessWidget {
  const _Edge({super.key, required this.slide});

  final Animation<Offset> slide;

  @override
  Widget build(BuildContext context) {
    final night = context.skin.night;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, box) => AnimatedBuilder(
            animation: slide,
            builder: (context, _) {
              final top = box.maxHeight * slide.value.dy;
              return Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: top - SceneSwitcher.shadow,
                    height: SceneSwitcher.shadow,
                    child: ColoredBox(color: night.shadow),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: top,
                    height: SceneSwitcher.lip,
                    child: ColoredBox(color: night.paperEdge),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
