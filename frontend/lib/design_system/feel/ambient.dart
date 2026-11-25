import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../layout/space.dart';

/// Draws one loop's frame: hand [loop] to a paint-only layer (a
/// `CustomPainter`'s `repaint:`, a `FadeTransition`), never to a rebuild of
/// [child]. The builder runs when the part is built, not on every tick.
typedef AmbientBuilder =
    Widget Function(
      BuildContext context,
      Animation<double> loop,
      Widget? child,
    );

/// Asks a resting [Ambient] for one more burst (the hold cue's breath after
/// a tap that was not a hold). An [Ambient] given one rests for good after
/// its burst, until [again].
class AmbientCue extends ChangeNotifier {
  int _cycles = 1;

  /// How many cycles the burst [again] asked for plays.
  int get cycles => _cycles;

  void again({int cycles = 1}) {
    _cycles = cycles;
    notifyListeners();
  }
}

/// The one place anything idles (a candle's flicker, a lantern's breath,
/// light drifting, the village living). An effect is a small layer over a
/// still picture, never a reason to draw the screen again, and a screen at
/// rest draws nothing most of the time. So by default it plays in bursts:
/// [cycles] rounds, then a true rest at [still] (no ticker, no frame asked
/// for; one timer wakes the next burst) for a gap between [Motion.restLeast]
/// and [Motion.restMost], taken from its [id], so every phone is the same.
/// Given a [cue] it rests for good after its burst, until [AmbientCue.again]
/// (teaching: a few breaths, then still). [Ambient.continuous] loops without
/// rest, only for something whose job is to show a wait.
///
/// It asks for frames only while all of these hold:
///
/// - the app is in front ([AppForeground]: on screen; a hidden browser tab,
///   a phone locked or another app in front is not);
/// - its ticker is allowed ([TickerMode]: a route covered by an opaque one,
///   a screen kept offstage, a screen leaving that switches it off);
/// - its owner says it runs ([running]: a sign hidden, a field typed in);
/// - no finger is down anywhere ([FingerDown]: the frame that answers a
///   press never waits behind decoration). A touch ENDS a burst under way: it
///   goes to [still] at once, without animating, and counts as played (a
///   burst with a [cue] stays still until [AmbientCue.again]). Its rest does
///   not run while a finger is down; it starts after the last lift and
///   [Motion.settle], so after a tap it schedules no frame at all. A burst
///   asked for under a finger waits for the settle. [Ambient.continuous]
///   only holds where it is and goes on after the settle;
/// - motion is allowed (`MediaQuery.disableAnimations` off). With reduce
///   motion it rests at [still].
///
/// Stopped by anything else but a touch (and reduce motion) it holds where it
/// was and goes on from there (a burst it was in plays to its end; a rest it
/// was in starts again whole). Nothing finer is checked: a part scrolled out of a
/// lazy list is not built at all, and a screen under a sheet still shows
/// through its scrim, so it keeps living there rather than freezing in view.
///
/// The loop drives paint only, inside its own [RepaintBoundary]: a tick
/// repaints the looping part and nothing else, and rebuilds nothing.
class Ambient extends StatefulWidget {
  /// Bursts and rests. [still] is where it rests: 0 or 1 (a breath goes
  /// from it to the other end and back; a turn goes 0 to 1).
  const Ambient({
    super.key,
    required this.id,
    required this.still,
    required this.builder,
    this.period = Motion.ambient,
    this.curve = Motion.breathe,
    this.reverse = true,
    this.cycles = 1,
    this.cue,
    this.running = true,
    this.child,
  }) : continuous = false,
       assert(still == 0 || still == 1, 'a burst rests at an end'),
       assert(cycles > 0);

  /// Loops while it may, with no rest: only for something whose job is to
  /// show that the app is waiting (the waiting sign).
  const Ambient.continuous({
    super.key,
    required this.still,
    required this.builder,
    this.period = Motion.ambient,
    this.curve = Motion.breathe,
    this.reverse = true,
    this.running = true,
    this.child,
  }) : continuous = true,
       id = '',
       cycles = 1,
       cue = null;

  /// Its own name: the seed of its rests (the same on every phone).
  final String id;

  /// Where it rests between bursts and with reduce motion (the builder sees
  /// this value).
  final double still;

  final AmbientBuilder builder;
  final Widget? child;

  /// One way of a cycle (0 to 1; with [reverse], and back takes as long).
  final Duration period;
  final Curve curve;

  /// There and back (a breath); off, it starts again at 0 (a turn).
  final bool reverse;

  /// Rounds in one burst.
  final int cycles;

  /// Given: one burst, then rest for good until [AmbientCue.again].
  final AmbientCue? cue;

  /// No rest at all ([Ambient.continuous]).
  final bool continuous;

  /// The owner's own say: false stops it where it is.
  final bool running;

  /// The rest after burst [k] for [id]: a share of the range from a small
  /// hash, in whole numbers that stay exact on the web.
  static Duration restFor(String id, int k) {
    const m = 2147483647;
    var h = 7;
    for (final c in id.codeUnits) {
      h = (h * 31 + c) % m;
    }
    final x = ((h + k * 7919) % m) * 48271 % m;
    final range = Motion.restMost - Motion.restLeast;
    return Motion.restLeast + range * (x / m);
  }

  /// Whether [b] is the same loop as [a]: an [Ambient] keeps its mode, id,
  /// cycles and still for its life (asserted when it is built again).
  static bool sameLoop(Ambient a, Ambient b) =>
      a.continuous == b.continuous &&
      a.id == b.id &&
      a.cycles == b.cycles &&
      a.still == b.still;

  @override
  State<Ambient> createState() => _AmbientState();
}

class _AmbientState extends State<Ambient> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.period,
    value: widget.continuous ? 0 : widget.still,
  );
  late CurvedAnimation _curved = CurvedAnimation(
    parent: _c,
    curve: widget.curve,
  );

  var _ticking = true;
  var _still = false;

  /// Legs (one way each) left in the burst under way; 0 at rest.
  var _left = 0;

  /// Where the leg under way goes.
  var _to = 1.0;

  /// Bursts played: which rest comes next.
  var _bursts = 0;
  var _started = false;
  Timer? _rest;

  /// A leg is under way (or held halfway): its end, and only its end, moves
  /// the burst on.
  var _inLeg = false;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener(_ended);
    AppForeground.instance.addListener(_sync);
    FingerDown.instance.addListener(_sync);
    widget.cue?.addListener(_again);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ticking = TickerMode.of(context);
    _still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _sync();
  }

  @override
  void didUpdateWidget(Ambient old) {
    super.didUpdateWidget(old);
    assert(
      Ambient.sameLoop(old, widget),
      'an Ambient keeps its mode, id, cycles and still: give a new one a new '
      'key',
    );
    if (old.cue != widget.cue) {
      old.cue?.removeListener(_again);
      widget.cue?.addListener(_again);
    }
    if (old.curve != widget.curve) {
      _curved.dispose();
      _curved = CurvedAnimation(parent: _c, curve: widget.curve);
    }
    if (old.period != widget.period || old.reverse != widget.reverse) {
      _c
        ..duration = widget.period
        ..stop();
    }
    _sync();
  }

  bool get _allowed =>
      widget.running && !_still && _ticking && AppForeground.instance.value;

  void _sync() {
    if (!mounted) return;
    final allowed = _allowed;
    final down = FingerDown.instance.value;
    final moving = allowed && !down;
    if (widget.continuous) {
      if (_still) {
        // Reduce motion: the same sign, at rest at [still], not wherever
        // the loop began.
        _c.stop();
        _c.value = widget.still;
        return;
      }
      if (moving && !_c.isAnimating) {
        unawaited(_c.repeat(reverse: widget.reverse));
      } else if (!moving && _c.isAnimating) {
        _c.stop();
      }
      return;
    }
    if (!allowed) {
      // Hidden, covered, stopped or still: no frame and no timer. A rest
      // starts again whole when it may run again.
      _rest?.cancel();
      _rest = null;
      _c.stop();
      return;
    }
    if (down) {
      // A touch ends the burst under way and stops the rest's clock: both
      // start again after the last lift and the settle.
      _rest?.cancel();
      _rest = null;
      if (_inLeg) _endBurst();
    }
    if (!_started) {
      _started = true;
      _burst(widget.cycles);
      return;
    }
    if (_left > 0) {
      moving ? _go() : _c.stop();
    } else if (_rest == null && widget.cue == null && !down) {
      _restNow();
    }
  }

  /// The burst is over, played or not: at [still] at once, no frame asked for.
  void _endBurst() {
    _inLeg = false;
    _c.stop();
    _c.value = widget.still;
    _left = 0;
    _bursts += 1;
  }

  void _again() {
    _rest?.cancel();
    _rest = null;
    _started = true;
    _burst(widget.cue?.cycles ?? 1);
  }

  void _burst(int cycles) {
    _rest = null;
    // A burst asked for in the middle of one starts over from where it is.
    _inLeg = false;
    _c.stop();
    _left = widget.reverse ? cycles * 2 : cycles;
    _to = widget.reverse ? 1 - widget.still : 1;
    if (!widget.reverse) _c.value = 0;
    if (_allowed && !FingerDown.instance.value) _go();
  }

  /// The leg under way, from where the controller is.
  void _go() {
    if (_c.isAnimating) return;
    if (_c.value == _to) return _legDone();
    _inLeg = true;
    unawaited(_c.animateTo(_to));
  }

  /// Told in the tick that ends a leg, so the next leg starts on that same
  /// frame's clock: a burst of breaths takes exactly its cycles' time.
  void _ended(AnimationStatus status) {
    if (!_inLeg || _c.isAnimating || _c.value != _to) return;
    _legDone();
  }

  void _legDone() {
    _inLeg = false;
    _left -= 1;
    if (_left > 0) {
      if (widget.reverse) {
        _to = 1 - _to;
      } else {
        _c.value = 0;
      }
      if (_allowed && !FingerDown.instance.value) _go();
      return;
    }
    if (!widget.reverse && _c.value != widget.still) _c.value = widget.still;
    if (widget.cue == null) _restNow();
    _bursts += 1;
  }

  /// A true rest: nothing ticks; one timer wakes the next burst.
  void _restNow() {
    _rest?.cancel();
    if (!_allowed || FingerDown.instance.value) {
      _rest = null;
      return;
    }
    _rest = Timer(Ambient.restFor(widget.id, _bursts), () {
      if (mounted) _burst(widget.cycles);
    });
  }

  @override
  void dispose() {
    _rest?.cancel();
    widget.cue?.removeListener(_again);
    FingerDown.instance.removeListener(_sync);
    AppForeground.instance.removeListener(_sync);
    _curved.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: widget.builder(
      context,
      _still ? AlwaysStoppedAnimation(widget.still) : _curved,
      widget.child,
    ),
  );
}

/// Whether the app is in front: on screen, so `resumed`, and `inactive` too
/// (still in view: a browser tab whose window lost focus, the notification
/// shade pulled over it); not `hidden`, `paused` or `detached`. Before the
/// first word from the platform, it is. One lifecycle observer for every
/// [Ambient], there only while something listens.
class AppForeground extends ChangeNotifier
    with WidgetsBindingObserver
    implements ValueListenable<bool> {
  AppForeground._();

  static final instance = AppForeground._();

  @override
  bool get value => switch (WidgetsBinding.instance.lifecycleState) {
    null || AppLifecycleState.resumed || AppLifecycleState.inactive => true,
    _ => false,
  };

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => notifyListeners();

  @override
  void addListener(VoidCallback listener) {
    final first = !hasListeners;
    super.addListener(listener);
    if (first) WidgetsBinding.instance.addObserver(this);
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) WidgetsBinding.instance.removeObserver(this);
  }
}

/// Whether any finger (or mouse button, or stylus) is down anywhere in the
/// app: one global route on the gesture binding's pointer router for every
/// [Ambient], there only while something listens. While it is, everything
/// that idles holds where it is, so the frame that answers the press has
/// nothing else to draw; after the last lift it stays true for
/// [Motion.settle] more, so the frames where the tap commits and its answer
/// comes in are not shared with decoration either.
///
/// A finger is let go on its up or cancel, and also when its device is
/// removed or hovers (a lift the app never heard), and all at once when the
/// app leaves the front ([AppForeground]: a tab hidden under a finger gets
/// no up), so a lost lift never holds every loop for good.
class FingerDown extends ChangeNotifier implements ValueListenable<bool> {
  FingerDown._();

  static final instance = FingerDown._();

  /// Each finger down, and the device it is on.
  final _down = <int, int>{};

  /// Still held after the last lift, until [Motion.settle] has passed.
  Timer? _settling;

  @override
  bool get value => _down.isNotEmpty || _settling != null;

  void _route(PointerEvent event) {
    switch (event) {
      case PointerDownEvent():
        final was = value;
        _settling?.cancel();
        _settling = null;
        _down[event.pointer] = event.device;
        if (!was) notifyListeners();
      case PointerUpEvent() || PointerCancelEvent():
        _lift(() => _down.remove(event.pointer));
      case PointerRemovedEvent() || PointerHoverEvent():
        _lift(() => _down.removeWhere((_, device) => device == event.device));
      default:
        return;
    }
  }

  /// Lets go of what [drop] drops; the last one gone starts the settle.
  void _lift(void Function() drop) {
    if (_down.isEmpty) return;
    drop();
    if (_down.isNotEmpty || _settling != null) return;
    _settling = Timer(Motion.settle, () {
      _settling = null;
      notifyListeners();
    });
  }

  /// The app left the front: every finger is let go at once, with no settle
  /// (nothing on screen to share a frame with).
  void _away() {
    if (AppForeground.instance.value || !value) return;
    _clear();
    notifyListeners();
  }

  void _clear() {
    _down.clear();
    _settling?.cancel();
    _settling = null;
  }

  @override
  void addListener(VoidCallback listener) {
    final first = !hasListeners;
    super.addListener(listener);
    if (first) {
      GestureBinding.instance.pointerRouter.addGlobalRoute(_route);
      AppForeground.instance.addListener(_away);
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      GestureBinding.instance.pointerRouter.removeGlobalRoute(_route);
      AppForeground.instance.removeListener(_away);
      _clear();
    }
  }
}
