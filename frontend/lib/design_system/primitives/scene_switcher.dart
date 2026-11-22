import 'dart:async';

import 'package:flutter/widgets.dart';

import '../layout/space.dart';
import '../skin/skin.dart';
import 'scene_arrival.dart';

/// The two scene changes of the game, the moments every phone at a table
/// shares. A scene is made of nothing but the two screens and a paper edge.
enum SceneKind {
  /// The deal to the night: the night comes down. The card's screen, a sheet
  /// of paper, is lowered over the table's from above on a lip and its
  /// shadow while the table dims; its own header picture comes down further
  /// than the sheet, so the moon arrives last.
  dusk,

  /// The night to the talk: the day breaks. The night sheet sinks away down
  /// the screen on its lip; the talk, whole and live underneath, has its own
  /// header rise from below into its window, the sun with it, while the text
  /// under it does not move.
  dawn,
}

/// Shows [child] and, when [stage] changes, takes the change over: a crossfade
/// ([Motion.settle]) unless [sceneBetween] names a [SceneKind] for it, then
/// that scene ([Motion.scene]). Reduce motion ([Motion.within]): an instant
/// cut.
///
/// A scene is made of nothing but the two screens, no picture of its own and
/// no dissolve: one of them is a sheet of paper that moves on a hard edge,
/// the other stays in place under (dawn) or over (dusk) it. No screen is ever
/// seen through another. A crossfade fades the new screen in over the old,
/// which stays whole.
///
/// Nothing in here waits or blocks. The arriving screen is in the tree and
/// takes touches from the first frame, where it will rest (its slide does not
/// move what a touch lands on), even while the other still covers it; the
/// leaving screen and the edge are for the eyes only (no touch, no
/// semantics), and everything that moves is a slide or one fade of a layer
/// already painted.
///
/// A change that comes while a scene runs (the night's "village sleeps" wait
/// giving way to the card) swaps the arriving screen in place and lets the
/// scene finish; it never restarts it. A change that cuts a crossfade short
/// by starting a scene takes the screens of that crossfade into the scene's
/// sheet, which finish fading inside it.
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

  /// The share of a scene the sheet takes to land (the rest it holds still):
  /// the arriving screen's primary button is on show by 60% of
  /// [Motion.scene].
  static const move = 0.85;

  /// How dark the table gets under the night coming down (the dusk).
  static const dusk = 0.5;

  @override
  State<SceneSwitcher<T>> createState() => _SceneSwitcherState<T>();
}

/// One change in motion: its own controller, so a change that comes while
/// another runs never moves the other's animations.
class _Run {
  _Run(TickerProvider vsync, Duration duration)
    : controller = AnimationController(vsync: vsync, duration: duration);

  final AnimationController controller;
  final _curves = <CurvedAnimation>[];

  /// [from] to [to] of the change, [Motion.curve] over that stretch.
  Animation<double> span(double from, double to) {
    final curved = CurvedAnimation(
      parent: controller,
      curve: Interval(from, to, curve: Motion.curve),
    );
    _curves.add(curved);
    return curved;
  }

  void dispose() {
    for (final curve in _curves) {
      curve.dispose();
    }
    controller.dispose();
  }
}

/// A screen on its way out.
class _Old {
  const _Old(this.key, this.child, this.opacity);

  final GlobalKey key;
  final Widget child;

  /// 1 unless the screen was itself still fading in when it was left.
  final Animation<double> opacity;
}

class _SceneSwitcherState<T> extends State<SceneSwitcher<T>>
    with TickerProviderStateMixin {
  final _runs = <_Run>[];
  _Run? _latest;

  /// The arriving screen's own key: it keeps its state from arriving to
  /// leaving, in whatever layer it is then in.
  var _key = GlobalKey();
  var _old = <_Old>[];

  /// The scene running, null for a crossfade or when nothing runs.
  SceneKind? _scene;

  Animation<double> _in = kAlwaysCompleteAnimation;
  Animation<Offset> _inSlide = const AlwaysStoppedAnimation(Offset.zero);
  Animation<double>? _arrival;
  Animation<Offset> _oldSlide = const AlwaysStoppedAnimation(Offset.zero);
  Animation<double> _dim = kAlwaysDismissedAnimation;

  @override
  void dispose() {
    for (final run in _runs) {
      run.dispose();
    }
    super.dispose();
  }

  void _resting() {
    for (final run in _runs) {
      run.dispose();
    }
    _runs.clear();
    _latest = null;
    _old = [];
    _scene = null;
    _in = kAlwaysCompleteAnimation;
    _inSlide = const AlwaysStoppedAnimation(Offset.zero);
    _arrival = null;
    _oldSlide = const AlwaysStoppedAnimation(Offset.zero);
    _dim = kAlwaysDismissedAnimation;
  }

  void _finished(_Run run, AnimationStatus status) {
    // Only the last change finishing clears the stage: an earlier one has
    // finished before it (a crossfade is shorter than a scene).
    if (status != AnimationStatus.completed || run != _latest) return;
    final done = [..._runs];
    setState(() {
      _runs.clear();
      _latest = null;
      _old = [];
      _scene = null;
      _in = kAlwaysCompleteAnimation;
      _inSlide = const AlwaysStoppedAnimation(Offset.zero);
      _arrival = null;
      _oldSlide = const AlwaysStoppedAnimation(Offset.zero);
      _dim = kAlwaysDismissedAnimation;
    });
    // Not from inside the controller's own notification.
    scheduleMicrotask(() {
      for (final run in done) {
        run.dispose();
      }
    });
  }

  @override
  void didUpdateWidget(SceneSwitcher<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stage == widget.stage) return;
    final scene = Motion.within(context, Motion.scene);
    final settle = Motion.within(context, Motion.settle);
    if (settle == Duration.zero) {
      _resting();
      _key = GlobalKey();
      return;
    }
    if (_scene != null) {
      // The scene goes on; the screen it arrives on is another one now.
      _key = GlobalKey();
      return;
    }
    final kind = widget.sceneBetween(oldWidget.stage, widget.stage);
    // The screen that was arriving leaves from where its fade had got to.
    _old = [..._old, _Old(_key, oldWidget.child, _in)];
    _key = GlobalKey();
    final run = _Run(this, kind == null ? settle : scene);
    run.controller.addStatusListener((status) => _finished(run, status));
    _runs.add(run);
    _latest = run;
    _scene = kind;
    switch (kind) {
      case null:
        _in = run.span(0, 1);
        _inSlide = const AlwaysStoppedAnimation(Offset.zero);
        _arrival = null;
        _oldSlide = const AlwaysStoppedAnimation(Offset.zero);
        _dim = kAlwaysDismissedAnimation;
      case SceneKind.dusk:
        final landing = run.span(0, SceneSwitcher.move);
        _in = kAlwaysCompleteAnimation;
        _inSlide = landing.drive(
          Tween(begin: const Offset(0, -1), end: Offset.zero),
        );
        _arrival = landing;
        _oldSlide = landing.drive(
          Tween(begin: Offset.zero, end: const Offset(0, 0.03)),
        );
        _dim = landing.drive(Tween<double>(begin: 0, end: SceneSwitcher.dusk));
      case SceneKind.dawn:
        final landing = run.span(0, SceneSwitcher.move);
        _in = kAlwaysCompleteAnimation;
        _inSlide = const AlwaysStoppedAnimation(Offset.zero);
        _arrival = landing;
        _oldSlide = landing.drive(
          Tween(begin: Offset.zero, end: const Offset(0, 1)),
        );
        _dim = kAlwaysDismissedAnimation;
    }
    run.controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final arriving = _Layer(
      key: _key,
      opacity: _in,
      slide: _inSlide,
      arrival: _arrival,
      leaving: false,
      child: widget.child,
    );
    final old = _Group(
      key: const ValueKey('old'),
      slide: _oldSlide,
      dim: _dim,
      children: [
        for (final gone in _old)
          _Layer(
            key: gone.key,
            opacity: gone.opacity,
            slide: const AlwaysStoppedAnimation(Offset.zero),
            arrival: null,
            leaving: true,
            child: gone.child,
          ),
      ],
    );
    return Stack(
      fit: StackFit.expand,
      children: switch (_scene) {
        // The day breaks under the night sheet sinking off it.
        SceneKind.dawn => [
          arriving,
          old,
          _Edge(
            key: const ValueKey('scene'),
            kind: SceneKind.dawn,
            slide: _oldSlide,
          ),
        ],
        // The night sheet is lowered over the table.
        SceneKind.dusk => [
          old,
          arriving,
          _Edge(
            key: const ValueKey('scene'),
            kind: SceneKind.dusk,
            slide: _inSlide,
          ),
        ],
        // The new screen fades in over the old, which stays whole.
        null => [old, arriving],
      },
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
    required this.arrival,
    required this.leaving,
    required this.child,
  });

  final Animation<double> opacity;
  final Animation<Offset> slide;
  final Animation<double>? arrival;
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
          child: RepaintBoundary(
            child: SceneArrival(progress: arrival, child: child),
          ),
        ),
      ),
    ),
  );
}

/// The screens that are leaving, as one sheet: they slide together, and the
/// dusk darkens them together.
class _Group extends StatelessWidget {
  const _Group({
    super.key,
    required this.slide,
    required this.dim,
    required this.children,
  });

  final Animation<Offset> slide;
  final Animation<double> dim;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: SlideTransition(
        position: slide,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ...children,
            FadeTransition(
              opacity: dim,
              child: ColoredBox(color: context.skin.night.shadow),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The paper edge of the sheet that moves, and the hard shadow it casts, which
/// grows with the sheet's height above what it is over: the dawn's night
/// sheet, its top edge sinking, shadows the day; the dusk's, its foot coming
/// down, shadows the table.
class _Edge extends StatelessWidget {
  const _Edge({super.key, required this.kind, required this.slide});

  final SceneKind kind;
  final Animation<Offset> slide;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final night = skin.night;
    final lip = skin.shape.paperLip;
    final widest = skin.shape.paperShadow;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, box) => AnimatedBuilder(
            animation: slide,
            builder: (context, _) {
              final dy = slide.value.dy;
              final children = switch (kind) {
                // Above the top edge of the sinking night: its shadow thins
                // as the night goes.
                SceneKind.dawn => () {
                  final top = box.maxHeight * dy;
                  final shadow = widest * (1 - 0.75 * dy);
                  return [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: top - shadow,
                      height: shadow,
                      child: ColoredBox(color: night.shadow),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: top,
                      height: lip,
                      child: ColoredBox(color: night.paperEdge),
                    ),
                  ];
                }(),
                // Below the foot of the sheet coming down: the shadow
                // shortens as it lands.
                SceneKind.dusk => () {
                  final foot = box.maxHeight * (1 + dy);
                  final shadow = widest * (0.25 - 0.75 * dy);
                  return [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: foot,
                      height: lip,
                      child: ColoredBox(color: night.paperEdge),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: foot + lip,
                      height: shadow,
                      child: ColoredBox(color: night.shadow),
                    ),
                  ];
                }(),
              };
              return Stack(children: children);
            },
          ),
        ),
      ),
    );
  }
}
