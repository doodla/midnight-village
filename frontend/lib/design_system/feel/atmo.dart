// PROTOTYPE (branch `atmosphere-proto`, not for main): the switch for the
// atmosphere effects the owner watches and chooses from. Each effect is off
// unless named, so the app is exactly today's with no switch at all.
//
//   web:   ?atmo=flame,clouds        (read once from the page's address)
//   build: --dart-define=ATMO=flame,clouds
//   all:   ?atmo=all
//
// Every effect honours reduce motion (still), stops under a covering route
// (TickerMode) and while the app is in the background (lifecycle), and never
// takes a touch: the screen under it works from its first frame.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// One effect of the prototype.
enum AtmoEffect {
  /// The candle's flame lives: it leans and flutters, its light breathes.
  flame,

  /// The night sky drifts: the clouds slide a few pixels, the moon's light
  /// breathes.
  clouds,

  /// Far windows in the village light up and go out, one at a time.
  windows,

  /// Dust turns slowly in the candle's light.
  dust,

  /// Torn-paper mist drifts along the village's foot.
  mist,

  /// Every tappable thing presses down in the frame the finger lands.
  press,

  /// Your card is dealt onto 04: it slides in from the deck and lands.
  deal,

  /// Night falls (04 to the board), A: the dark sweeps down from the top.
  veil,

  /// Night falls (04 to the board), B: the room goes dark and the candle's
  /// light opens it again.
  kindle,

  /// The clock candle and your card are carried from 04 onto the board.
  carry,

  /// A breeze through the name tags on the square when someone readies.
  sway,

  // Joy: small hand-made surprises, rare and quiet, found rather than shown.

  /// The candle gutters in the last seconds of its window.
  gutter,

  /// Now and then a moth visits the candle, circles it and goes.
  moth,

  /// Each name tag hangs and settles in its own way (its own swing, from
  /// its name), so no two players' tags move alike.
  tagsettle,
}

abstract final class Atmo {
  static const _defined = String.fromEnvironment('ATMO');

  /// The effects switched on, read once.
  static final Set<AtmoEffect> on = _read();

  /// How often the ambient clock ticks (frames a second it asks for).
  static final int fps = _fps();

  static Set<AtmoEffect> _read() {
    final names = <String>{
      ..._defined.split(','),
      ...?Uri.base.queryParameters['atmo']?.split(','),
    }.map((n) => n.trim()).where((n) => n.isNotEmpty).toSet();
    if (names.contains('all')) return AtmoEffect.values.toSet();
    return {
      for (final e in AtmoEffect.values)
        if (names.contains(e.name)) e,
    };
  }

  /// A time-lapse for the clips (`?atmo_speed=4`): the ambient clock runs
  /// this many times faster. 1 in the app.
  static final double speed =
      double.tryParse(Uri.base.queryParameters['atmo_speed'] ?? '') ?? 1;

  static int _fps() =>
      int.tryParse(Uri.base.queryParameters['atmo_fps'] ?? '')?.clamp(5, 60) ??
      30;

  /// Whether [effect] is switched on (motion or not).
  static bool has(AtmoEffect effect) => on.contains(effect);

  /// Whether [effect] moves here: switched on and motion not reduced.
  static bool moves(BuildContext context, AtmoEffect effect) =>
      on.contains(effect) && !MediaQuery.disableAnimationsOf(context);
}

/// The one slow clock every ambient effect reads: seconds of the app in the
/// foreground with no finger down. It ticks (asks for a frame, at
/// [Atmo.fps]) only while an effect in a burst listens; between bursts, and
/// while a finger is down, nothing ticks, so the screen rests.
class AmbientClock extends ChangeNotifier implements ValueListenable<double> {
  AmbientClock._() {
    _lifecycle = AppLifecycleListener(onStateChange: _onState);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
    _watch.start();
  }

  static final AmbientClock instance = AmbientClock._();

  // ignore: unused_field
  late final AppLifecycleListener _lifecycle;
  final _watch = Stopwatch();
  Timer? _timer;
  var _users = 0;
  var _foreground = true;
  var _fingers = 0;

  /// Seconds the clock has run (it holds in the background and under a
  /// finger, so an effect stands still while someone touches the screen).
  @override
  double get value => _watch.elapsedMicroseconds / 1e6 * Atmo.speed;

  void _onState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _run();
  }

  void _onPointer(PointerEvent event) {
    if (event is PointerDownEvent) {
      _fingers++;
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _fingers = _fingers > 0 ? _fingers - 1 : 0;
    } else {
      return;
    }
    _run();
  }

  void join() {
    _users++;
    _run();
  }

  void leave() {
    _users--;
    _run();
  }

  void _run() {
    final live = _foreground && _fingers == 0;
    if (live) {
      _watch.start();
    } else {
      _watch.stop();
    }
    final go = _users > 0 && live;
    if (go && _timer == null) {
      _timer = Timer.periodic(
        Duration(microseconds: 1000000 ~/ Atmo.fps),
        (_) => notifyListeners(),
      );
    } else if (!go && _timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }
}

/// Builds [builder] with the ambient clock's seconds, again on each tick,
/// while it is on screen, moving and in a burst; else once, still. With
/// [restFor], an effect says how long it rests at a moment (0: it is in a
/// burst): it leaves the clock for that long, so the screen asks for no
/// frame at all between its bursts.
class Ambient extends StatefulWidget {
  const Ambient({
    super.key,
    required this.effect,
    required this.builder,
    this.child,
    this.still = 0,
    this.restFor,
  });

  final AtmoEffect effect;
  final Widget Function(BuildContext context, double t, Widget? child) builder;
  final Widget? child;

  /// The moment shown when nothing moves (reduce motion, covered, off).
  final double still;

  /// Seconds of rest from clock time t (0 in a burst); null: always moving.
  final double Function(double t)? restFor;

  @override
  State<Ambient> createState() => _AmbientState();
}

class _AmbientState extends State<Ambient> {
  ValueListenable<bool>? _mode;
  var _joined = false;
  late var _shown = widget.still;
  Timer? _wake;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _mode?.removeListener(_update);
    _mode = TickerMode.getNotifier(context)..addListener(_update);
    _update();
  }

  bool get _wanted =>
      mounted && (_mode?.value ?? false) && Atmo.moves(context, widget.effect);

  void _update() {
    _wake?.cancel();
    // Off, covered or still: the clock is not even made.
    if (!_wanted && !_joined) {
      if (mounted && _shown != widget.still) {
        setState(() => _shown = widget.still);
      }
      return;
    }
    final clock = AmbientClock.instance;
    var want = _wanted;
    if (want && widget.restFor != null) {
      final rest = widget.restFor!(clock.value + widget.still);
      if (rest > 0) {
        want = false;
        // Back for the next burst (clock seconds are real seconds over the
        // time-lapse; a held finger only makes it look again later).
        _wake = Timer(
          Duration(milliseconds: (rest / Atmo.speed * 1000).ceil() + 16),
          _update,
        );
      }
    }
    if (want != _joined) {
      _joined = want;
      if (want) {
        clock
          ..addListener(_tick)
          ..join();
      } else {
        clock
          ..removeListener(_tick)
          ..leave();
      }
    }
    final t = _wanted ? clock.value + widget.still : widget.still;
    if (mounted && t != _shown) setState(() => _shown = t);
  }

  void _tick() {
    if (widget.restFor != null) {
      _update();
    } else {
      setState(() => _shown = AmbientClock.instance.value + widget.still);
    }
  }

  @override
  void dispose() {
    _wake?.cancel();
    _mode?.removeListener(_update);
    if (_joined) {
      AmbientClock.instance
        ..removeListener(_tick)
        ..leave();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _shown, widget.child);
}

/// Seeded bursts with real rest between: burst k starts at [startOf] k
/// ([first], then gaps of [gapLeast] to [gapLeast] + [gapSpread] seconds,
/// seeded) and lasts [length].
class Bursts {
  const Bursts({
    required this.length,
    required this.gapLeast,
    required this.gapSpread,
    this.first = 2,
    this.seed = 0,
  });

  final double length;
  final double gapLeast;
  final double gapSpread;
  final double first;
  final int seed;

  double _gap(int k) {
    final x = (k + 1) * 0.618034 + seed * 0.414;
    return gapLeast + gapSpread * (x - x.floorToDouble());
  }

  /// When burst [k] starts.
  double startOf(int k) {
    var t = first;
    for (var i = 0; i < k; i++) {
      t += length + _gap(i);
    }
    return t;
  }

  /// The burst at or before [t]: (its index, how far into it, 0 to 1 or
  /// more past its end); index -1 before the first.
  (int, double) at(double t) {
    if (t < first) return (-1, 0);
    var k = 0;
    var start = first;
    while (true) {
      final next = start + length + _gap(k);
      if (next > t) return (k, (t - start) / length);
      start = next;
      k++;
    }
  }

  /// Seconds of rest at [t] before the next burst (0 inside one).
  double restAt(double t) {
    final (k, u) = at(t);
    if (k >= 0 && u < 1) return 0;
    return startOf(k + 1) - t;
  }
}

/// A slow wander, -1 to 1, that never repeats in a way the eye can count: the
/// sum of three sines with periods that share no beat ([period] the longest).
double wander(double t, double period, {int seed = 0}) {
  final p = seed * 1.618;
  return (math.sin(2 * math.pi * t / period + p) * 0.55 +
          math.sin(2 * math.pi * t / (period * 0.618) + p * 2.3) * 0.3 +
          math.sin(2 * math.pi * t / (period * 0.377) + p * 0.7) * 0.15)
      .clamp(-1.0, 1.0);
}

/// Paints [child] moved, scaled and turned about its centre, while its
/// layout, hit testing and semantics stay where it rests: a touch lands on the
/// card where it will be, from the first frame of any motion.
class PaintShift extends SingleChildRenderObjectWidget {
  const PaintShift({
    super.key,
    this.offset = Offset.zero,
    this.scale = 1,
    this.turn = 0,
    this.alignment = Alignment.center,
    super.child,
  });

  final Offset offset;
  final double scale;

  /// Radians.
  final double turn;
  final Alignment alignment;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderPaintShift(offset, scale, turn, alignment);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderPaintShift renderObject,
  ) => renderObject
    ..offset = offset
    ..scale = scale
    ..turn = turn
    ..alignment = alignment;
}

class RenderPaintShift extends RenderProxyBox {
  RenderPaintShift(this._offset, this._scale, this._turn, this._alignment);

  Offset _offset;
  double _scale;
  double _turn;
  Alignment _alignment;

  set offset(Offset v) => _set(() => _offset = v, _offset != v);
  set scale(double v) => _set(() => _scale = v, _scale != v);
  set turn(double v) => _set(() => _turn = v, _turn != v);
  set alignment(Alignment v) => _set(() => _alignment = v, _alignment != v);

  void _set(VoidCallback change, bool changed) {
    if (!changed) return;
    change();
    markNeedsPaint();
  }

  bool get _still => _offset == Offset.zero && _scale == 1 && _turn == 0;

  @override
  bool get alwaysNeedsCompositing => child != null && !_still;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    if (_still) {
      layer = null;
      context.paintChild(child!, offset);
      return;
    }
    final pivot = _alignment.alongSize(size);
    final m = Matrix4.identity()
      ..translateByDouble(pivot.dx + _offset.dx, pivot.dy + _offset.dy, 0, 1)
      ..rotateZ(_turn)
      ..scaleByDouble(_scale, _scale, 1, 1)
      ..translateByDouble(-pivot.dx, -pivot.dy, 0, 1);
    layer = context.pushTransform(
      needsCompositing,
      offset,
      m,
      super.paint,
      oldLayer: layer is TransformLayer ? layer! as TransformLayer : null,
    );
  }
}

/// With [AtmoEffect.press]: tells [onPressed] true in the frame the finger
/// lands (a raw pointer, not the tap's 100 ms wait) and false when it lifts
/// or is taken away. Off: [child] as it is.
class PressAtOnce extends StatelessWidget {
  const PressAtOnce({
    super.key,
    required this.onPressed,
    required this.child,
    this.enabled = true,
  });

  final ValueChanged<bool> onPressed;
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!Atmo.has(AtmoEffect.press) || !enabled) return child;
    return Listener(
      onPointerDown: (_) => onPressed(true),
      onPointerUp: (_) => onPressed(false),
      onPointerCancel: (_) => onPressed(false),
      child: child,
    );
  }
}
