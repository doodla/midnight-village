import 'package:flutter/foundation.dart';
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

/// The one place anything idles (a candle's flicker, a lantern's breath,
/// light drifting, the village living): it owns the repeating clock and asks
/// for frames only while all of these hold:
///
/// - the app is in front ([AppForeground]: on screen; a hidden browser tab,
///   a phone locked or another app in front is not);
/// - its ticker is allowed ([TickerMode]: a route covered by an opaque one,
///   a screen kept offstage, a screen leaving that switches it off);
/// - its owner says it runs ([running]: a sign hidden, a field typed in);
/// - motion is allowed (`MediaQuery.disableAnimations` off). With reduce
///   motion it rests at [still], the value its owner declares.
///
/// Stopped for any reason but reduce motion it holds where it was and goes
/// on from there. Nothing finer is checked: a part scrolled out of a lazy
/// list is not built at all, and a screen under a sheet still shows through
/// its scrim, so it keeps living there rather than freezing in view.
///
/// The loop drives paint only, inside its own [RepaintBoundary]: a tick
/// repaints the looping part and nothing else, and rebuilds nothing.
class Ambient extends StatefulWidget {
  const Ambient({
    super.key,
    required this.still,
    required this.builder,
    this.period = Motion.ambient,
    this.curve = Motion.breathe,
    this.reverse = true,
    this.running = true,
    this.child,
  });

  /// Where the loop rests with reduce motion (the builder sees this value).
  final double still;

  final AmbientBuilder builder;
  final Widget? child;

  /// One way of the loop (0 to 1; with [reverse], and back takes as long).
  final Duration period;
  final Curve curve;

  /// There and back (a breath); off, it starts again at 0 (a turn).
  final bool reverse;

  /// The owner's own say: false stops it where it is.
  final bool running;

  @override
  State<Ambient> createState() => _AmbientState();
}

class _AmbientState extends State<Ambient> with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: widget.period,
  );
  late CurvedAnimation _curved = CurvedAnimation(
    parent: _loop,
    curve: widget.curve,
  );

  var _ticking = true;
  var _still = false;

  @override
  void initState() {
    super.initState();
    AppForeground.instance.addListener(_sync);
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
    if (old.curve != widget.curve) {
      _curved.dispose();
      _curved = CurvedAnimation(parent: _loop, curve: widget.curve);
    }
    if (old.period != widget.period || old.reverse != widget.reverse) {
      _loop
        ..duration = widget.period
        ..stop();
    }
    _sync();
  }

  void _sync() {
    final run =
        widget.running && !_still && _ticking && AppForeground.instance.value;
    if (run && !_loop.isAnimating) {
      _loop.repeat(reverse: widget.reverse);
    } else if (!run && _loop.isAnimating) {
      _loop.stop();
    }
  }

  @override
  void dispose() {
    AppForeground.instance.removeListener(_sync);
    _curved.dispose();
    _loop.dispose();
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
