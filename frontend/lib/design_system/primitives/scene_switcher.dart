import 'package:flutter/widgets.dart';

import '../layout/space.dart';
import '../skin/ground.dart';
import '../skin/skin.dart';
import 'art_picture.dart';
import 'screen_frame.dart';

/// The two scene changes of the game, the moments every phone at a table
/// shares: the village sinks into night, and the rooftops rise on the day.
enum SceneKind {
  /// The deal to the night: the table's screen sinks away and the night
  /// village settles into place.
  dusk,

  /// The night to the talk: the night sinks away and the dawn rooftops rise,
  /// the sun with them.
  dawn,
}

/// Shows [child] and, when [stage] changes, takes the change over: a crossfade
/// ([Motion.settle]) unless [sceneBetween] names a [SceneKind] for it, then
/// that scene ([Motion.scene]). Reduce motion: an instant cut.
///
/// Nothing in here waits or blocks. The screen arriving is in the tree and
/// takes touches from the first frame, even while it is not yet seen (it is
/// never wrapped in anything that stops a touch); the screen leaving and the
/// scene's art are for the eyes only (no touch, no semantics), and everything
/// that moves is an opacity or a slide of a layer already painted.
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
  Widget? _plate;

  /// The scene's art is over the arriving screen (the dawn) or under it.
  var _plateAbove = false;

  Animation<double> _in = kAlwaysCompleteAnimation;
  Animation<Offset> _inSlide = const AlwaysStoppedAnimation(Offset.zero);
  Animation<double> _plateOpacity = kAlwaysCompleteAnimation;
  Animation<Offset> _plateSlide = const AlwaysStoppedAnimation(Offset.zero);
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

  /// The scenes' art, decoded before it is needed: a scene never starts on
  /// an empty picture. (Not awaited; the app does not start slower for it.)
  void _warmUp() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final skin = context.skin;
      final size = MediaQuery.sizeOf(context);
      final box = Size(
        size.width.clamp(0, ScreenFrame.maxWidth).toDouble(),
        size.height,
      );
      final ratio = MediaQuery.devicePixelRatioOf(context);
      for (final art in [skin.art.nightVillage, skin.art.dawnRooftops]) {
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
      _plate = null;
      _plateAbove = false;
      _resting();
    });
  }

  void _resting() {
    _in = kAlwaysCompleteAnimation;
    _inSlide = const AlwaysStoppedAnimation(Offset.zero);
    _plateOpacity = kAlwaysCompleteAnimation;
    _plateSlide = const AlwaysStoppedAnimation(Offset.zero);
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
      _plate = null;
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
    _plateAbove = false;
    final (out, outSlide) = switch (scene) {
      null => _crossfade(from),
      SceneKind.dusk => _dusk(),
      SceneKind.dawn => _dawn(),
    };
    _leaving = [_Leaving(oldId, oldChild, out, outSlide)];
    _plate = scene == null ? null : _Plate(scene);
    _progress
      ..duration = scene == null ? Motion.settle : Motion.scene
      ..forward(from: 0);
  }

  (Animation<double>, Animation<Offset>) _crossfade(double from) {
    _in = _span(0, 1);
    _inSlide = const AlwaysStoppedAnimation(Offset.zero);
    _plateOpacity = kAlwaysCompleteAnimation;
    _plateSlide = const AlwaysStoppedAnimation(Offset.zero);
    return (
      _span(0, 1).drive(Tween(begin: from, end: 0)),
      const AlwaysStoppedAnimation(Offset.zero),
    );
  }

  /// The table's screen sinks and darkens away; the night village sinks down
  /// from above into the place it has on the card, and the card, there from
  /// the first frame, is seen once the village has settled.
  (Animation<double>, Animation<Offset>) _dusk() {
    _in = _span(0.4, 0.9);
    _inSlide = const AlwaysStoppedAnimation(Offset.zero);
    _plateOpacity = _span(0, 0.3);
    _plateSlide = _span(
      0,
      0.6,
    ).drive(Tween(begin: const Offset(0, -0.5), end: Offset.zero));
    return (
      _span(0, 0.6).drive(Tween(begin: 1, end: 0)),
      _span(0, 0.9).drive(Tween(begin: Offset.zero, end: const Offset(0, 0.1))),
    );
  }

  /// The dawn rooftops rise over the night, the sun with them, and go on up
  /// and out, taking the sun off the top of the screen: under the night and
  /// the rooftops the day's screen is whole and live all along.
  (Animation<double>, Animation<Offset>) _dawn() {
    _plateAbove = true;
    _in = kAlwaysCompleteAnimation;
    _inSlide = const AlwaysStoppedAnimation(Offset.zero);
    _plateOpacity = _span(0.55, 0.95).drive(Tween(begin: 1, end: 0));
    _plateSlide = _progress.drive(
      TweenSequence<Offset>([
        TweenSequenceItem(
          tween: Tween(
            begin: const Offset(0, 0.5),
            end: Offset.zero,
          ).chain(CurveTween(curve: Motion.curve)),
          weight: 50,
        ),
        TweenSequenceItem(tween: ConstantTween(Offset.zero), weight: 5),
        TweenSequenceItem(
          tween: Tween(
            begin: Offset.zero,
            end: const Offset(0, -0.3),
          ).chain(CurveTween(curve: Motion.curve)),
          weight: 45,
        ),
      ]),
    );
    // The night stays as it is, under the rooftops, until they cover it; it
    // is gone before they lift.
    return (
      _span(0.42, 0.55).drive(Tween(begin: 1, end: 0)),
      const AlwaysStoppedAnimation(Offset.zero),
    );
  }

  Widget _sceneLayer(Widget plate) => _Layer(
    key: const ValueKey('scene'),
    opacity: _plateOpacity,
    slide: _plateSlide,
    leaving: true,
    child: plate,
  );

  @override
  Widget build(BuildContext context) {
    final arriving = _Layer(
      key: ValueKey(_id),
      opacity: _in,
      slide: _inSlide,
      leaving: false,
      child: widget.child,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        // The dawn's arriving screen is whole under everything (it is only
        // covered); the others fade in over what is leaving.
        if (_plateAbove) arriving,
        for (final gone in _leaving)
          _Layer(
            key: ValueKey(gone.id),
            opacity: gone.opacity,
            slide: gone.slide,
            leaving: true,
            child: gone.child,
          ),
        if (_plate case final plate? when !_plateAbove) _sceneLayer(plate),
        if (!_plateAbove) arriving,
        if (_plate case final plate? when _plateAbove) _sceneLayer(plate),
      ],
    );
  }
}

/// One screen, or the scene's art, in the switcher: always the same shape of
/// widgets, so a screen keeps its state from arriving to leaving. A [leaving]
/// layer is for the eyes only. The arriving one is never behind anything that
/// stops a touch, and its semantics are in from the first frame.
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
        child: FadeTransition(
          opacity: opacity,
          alwaysIncludeSemantics: true,
          child: RepaintBoundary(child: child),
        ),
      ),
    ),
  );
}

/// What a scene is made of, in the skin's art: the dusk's night village laid
/// exactly as the card has it (a ground under it, the picture across the
/// top, fading into the ground), the dawn's rooftops across the whole
/// screen.
class _Plate extends StatelessWidget {
  const _Plate(this.scene);

  final SceneKind scene;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return switch (scene) {
      SceneKind.dusk => ScreenFrame(
        ground: GroundKind.night,
        topArt: skin.art.nightVillage,
        topArtLayout: TopArtLayout.backdrop,
        fitsHeight: true,
        body: const SizedBox.shrink(),
      ),
      SceneKind.dawn => ColoredBox(
        color: skin.day.ground,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: ScreenFrame.maxWidth),
            child: SizedBox.expand(child: ArtPicture(skin.art.dawnRooftops)),
          ),
        ),
      ),
    };
  }
}
