// PROTOTYPE (branch `atmosphere-proto`): the moments behind the switch in
// `atmo.dart`: night falling over the board, and the breeze through the name
// tags. Each is a no-op unless its effect is on.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'atmo.dart';
import 'atmo_parts.dart';

/// Night falls when the screen goes from your card to the night board
/// ([falls] turns true): over whatever is shown, taking no touch, the dark
/// sweeps down from the top and lifts ([AtmoEffect.veil]), or the room goes
/// dark and the candle's light opens it again ([AtmoEffect.kindle]).
class AtmoNightFall extends StatefulWidget {
  const AtmoNightFall({super.key, required this.screen, required this.child});

  /// The screen's name; night falls on `yourCard` to `nightBoard`.
  final String? screen;
  final Widget child;

  @override
  State<AtmoNightFall> createState() => _AtmoNightFallState();
}

class _AtmoNightFallState extends State<AtmoNightFall>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
    value: 1,
  );

  @override
  void didUpdateWidget(AtmoNightFall old) {
    super.didUpdateWidget(old);
    final on = Atmo.has(AtmoEffect.veil) || Atmo.has(AtmoEffect.kindle);
    if (on &&
        old.screen == 'yourCard' &&
        widget.screen == 'nightBoard' &&
        !MediaQuery.disableAnimationsOf(context)) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      widget.child,
      IgnorePointer(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => _c.value >= 1
                ? const SizedBox.shrink()
                : CustomPaint(
                    painter: Atmo.has(AtmoEffect.kindle)
                        ? _Kindle(
                            _c.value,
                            Carried.rectOf('clock-candle')?.center,
                          )
                        : _Veil(_c.value),
                  ),
          ),
        ),
      ),
    ],
  );
}

const _night = Color(0xFF05070F);

double _ease(double x) => 1 - math.pow(1 - x.clamp(0.0, 1.0), 3).toDouble();

/// The dark sweeps down from the top edge over the first 40%, then lifts.
class _Veil extends CustomPainter {
  _Veil(this.v);

  final double v;

  @override
  void paint(Canvas canvas, Size size) {
    final reach =
        Curves.easeInOut.transform((v / 0.4).clamp(0.0, 1.0)) *
        (size.height + 160);
    final strength =
        0.62 *
        (1 - Curves.easeIn.transform(((v - 0.45) / 0.55).clamp(0.0, 1.0)));
    if (strength <= 0) return;
    final edge = reach - 160;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, reach),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, math.max(0, edge)),
          Offset(0, reach),
          [_night.withValues(alpha: strength), _night.withValues(alpha: 0)],
        ),
    );
  }

  @override
  bool shouldRepaint(_Veil old) => old.v != v;
}

/// The room dark at once, then the candle's warm light opens it from the
/// candle outwards.
class _Kindle extends CustomPainter {
  _Kindle(this.v, this.candle);

  final double v;
  final Offset? candle;

  @override
  void paint(Canvas canvas, Size size) {
    final at = candle ?? Offset(size.width * 0.25, size.height * 0.08);
    final far = math.sqrt(size.width * size.width + size.height * size.height);
    final open = _ease(v) * far * 1.25;
    final dark = 0.7 * (1 - _ease((v - 0.35) / 0.65));
    final warm = 0.22 * math.sin(math.pi * v.clamp(0.0, 1.0));
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          at,
          math.max(open, 1),
          [
            const Color(0xFFFFB45A).withValues(alpha: warm),
            const Color(0xFFFFB45A).withValues(alpha: 0),
            _night.withValues(alpha: dark),
          ],
          [0, 0.7, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(_Kindle old) => old.v != v;
}

/// How many are ready on the square: a rise sends a breeze through the name
/// tags under it ([AtmoEffect.sway]), never saying whose.
class Breeze extends InheritedWidget {
  const Breeze({super.key, required this.ready, required super.child});

  final int ready;

  static int? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<Breeze>()?.ready;

  @override
  bool updateShouldNotify(Breeze old) => old.ready != ready;
}

/// A name tag that swings about its pin: in the breeze ([AtmoEffect.sway],
/// left to right across the screen) and, with [AtmoEffect.tagsettle], once
/// as it first hangs, each tag its own swing from its [name].
class SwayingTag extends StatefulWidget {
  const SwayingTag({super.key, required this.name, required this.child});

  final String name;
  final Widget child;

  @override
  State<SwayingTag> createState() => _SwayingTagState();
}

class _SwayingTagState extends State<SwayingTag>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
    value: 1,
  );
  int? _ready;
  var _amp = 0.0;

  bool get _own => Atmo.has(AtmoEffect.tagsettle);

  /// The tag's own swing: (amplitude, swings a second, how fast it stills).
  (double, double, double) get _swing => _own
      ? (
          0.6 + 0.8 * seeded(widget.name, 1),
          1.1 + 1.0 * seeded(widget.name, 2),
          1.6 + 1.8 * seeded(widget.name, 3),
        )
      : (1.0, 1.5, 2.4);

  @override
  void initState() {
    super.initState();
    if (_own) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !MediaQuery.disableAnimationsOf(context)) {
          _swingNow(0.09, Duration(milliseconds: (300 * _x()).round()));
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ready = Breeze.of(context);
    final before = _ready;
    _ready = ready;
    if (before == null || ready == null || ready <= before) return;
    if (!Atmo.moves(context, AtmoEffect.sway)) return;
    _swingNow(0.11, Duration(milliseconds: (380 * _x()).round()));
  }

  /// Where the tag stands across the screen, 0 to 1.
  double _x() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return 0.5;
    final w = MediaQuery.sizeOf(context).width;
    return (box.localToGlobal(box.size.center(Offset.zero)).dx / w).clamp(
      0.0,
      1.0,
    );
  }

  void _swingNow(double amp, Duration after) {
    Future<void>.delayed(after, () {
      if (!mounted) return;
      _amp = amp;
      _c.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Atmo.has(AtmoEffect.sway) && !_own) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        if (_c.value >= 1) return child!;
        final (a, f, k) = _swing;
        final t = _c.value * 2.6;
        final turn =
            _amp * a * math.exp(-k * t) * math.sin(2 * math.pi * f * t);
        return PaintShift(
          turn: turn,
          alignment: Alignment.topCenter,
          child: child,
        );
      },
    );
  }
}
