// PROTOTYPE (branch `atmosphere-proto`): the moving parts behind the switch in
// `atmo.dart`. Each is a no-op unless its effect is on.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../layout/space.dart';
import 'atmo.dart';

double frac(double x) => x - x.floorToDouble();

double smoothStep(double a, double b, double x) {
  final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// A seeded 0-to-1 from a string (djb2), the same on every phone.
double seeded(String s, [int salt = 0]) {
  var h = 5381 + salt;
  for (final c in s.codeUnits) {
    h = ((h << 5) + h + c) & 0x7fffffff;
  }
  return (h % 10007) / 10007;
}

// ---------------------------------------------------------------- the flame

/// The candle's flame, alive: it leans and flutters about its foot, and with
/// [AtmoEffect.gutter] it gutters in the last seconds ([share] under 0.15).
class AtmoFlame extends StatelessWidget {
  const AtmoFlame({super.key, required this.share, required this.child});

  final double? share;
  final Widget child;

  static bool get any =>
      Atmo.has(AtmoEffect.flame) || Atmo.has(AtmoEffect.gutter);

  /// The flame's (scale x, scale y, lean) at [t].
  static (double, double, double) at(double t, double? share) {
    var sy = 1.0;
    var lean = 0.0;
    if (Atmo.has(AtmoEffect.flame)) {
      sy +=
          wander(t, 2.3, seed: 1) * 0.05 +
          math.sin(2 * math.pi * t * 5.7) * .012;
      lean = wander(t, 6.1, seed: 2) * 0.05;
    }
    final low = share != null && share < 0.15;
    if (low && Atmo.has(AtmoEffect.gutter)) {
      // A gutter now and then: the flame ducks and leans, and comes back.
      final duck = math.pow(math.max(0, math.sin(2 * math.pi * t / 1.7)), 12);
      sy *= 1 - 0.35 * duck;
      lean += 0.14 * duck * (wander(t, 3.1, seed: 5) >= 0 ? 1 : -1);
    }
    return (1 - (sy - 1) * 0.5, sy, lean);
  }

  @override
  Widget build(BuildContext context) {
    if (!any) return child;
    return Ambient(
      effect: Atmo.has(AtmoEffect.flame) ? AtmoEffect.flame : AtmoEffect.gutter,
      child: RepaintBoundary(child: child),
      builder: (context, t, child) {
        final (sx, sy, lean) = at(t, share);
        return Transform(
          alignment: Alignment.bottomCenter,
          transform: Matrix4.rotationZ(lean)..scaleByDouble(sx, sy, 1, 1),
          child: child,
        );
      },
    );
  }
}

/// How strong the candle's light is at [t] (1 at rest).
double flameLight(double t) =>
    Atmo.has(AtmoEffect.flame) ? 1 + wander(t, 2.9, seed: 3) * 0.18 : 1;

// --------------------------------------------------------- dust and the moth

/// Dust turning slowly in the candle's light, and now and then a moth: drawn
/// over a box round the flame; the light is at [flame] in it.
class AtmoCandleAir extends StatelessWidget {
  const AtmoCandleAir({
    super.key,
    required this.flame,
    required this.light,
    required this.flameHeight,
  });

  final Offset flame;
  final Color light;
  final double flameHeight;

  static bool get any => Atmo.has(AtmoEffect.dust) || Atmo.has(AtmoEffect.moth);

  @override
  Widget build(BuildContext context) {
    if (!any) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: Ambient(
          effect: Atmo.has(AtmoEffect.dust) ? AtmoEffect.dust : AtmoEffect.moth,
          builder: (context, t, _) => Stack(
            clipBehavior: Clip.none,
            children: [
              if (Atmo.has(AtmoEffect.dust))
                Positioned.fill(
                  child: CustomPaint(
                    painter: _DustPainter(t, flame, light, flameHeight),
                  ),
                ),
              if (Atmo.has(AtmoEffect.moth)) ..._moth(t),
            ],
          ),
        ),
      ),
    );
  }

  /// The moth: a visit of 6 s, first at 2 s, then every 41 to 67 s.
  List<Widget> _moth(double t) {
    const visit = 6.0;
    var start = 2.0;
    var n = 0;
    while (start + visit < t) {
      start += 41 + 26 * frac(n * 0.618 + 0.3);
      n++;
    }
    final u = (t - start) / visit;
    if (u < 0 || u > 1) return const [];
    final size = flameHeight * 0.9;
    // In from the upper right, two loose loops round the flame, out left.
    final arrive = smoothStep(0, 0.2, u);
    final leave = smoothStep(0.8, 1, u);
    final a = 2 * math.pi * (u * 2.2);
    final r = flameHeight * (1.1 + 0.3 * math.sin(a * 1.7));
    final loop = flame + Offset(math.cos(a) * r * 1.3, math.sin(a) * r * 0.6);
    final from = flame + Offset(flameHeight * 6, -flameHeight * 5);
    final to = flame + Offset(-flameHeight * 7, -flameHeight * 4);
    final p = Offset.lerp(Offset.lerp(from, loop, arrive), to, leave)!;
    final wing = 0.55 + 0.45 * math.sin(2 * math.pi * t * 7).abs();
    return [
      Positioned(
        left: p.dx - size / 2,
        top: p.dy - size / 2,
        width: size,
        height: size,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.diagonal3Values(wing, 1, 1),
          child: const Image(
            image: AssetImage('assets/skins/shadow_paper/tokens/moth.webp'),
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    ];
  }
}

class _DustPainter extends CustomPainter {
  _DustPainter(this.t, this.flame, this.light, this.unit);

  final double t;
  final Offset flame;
  final Color light;
  final double unit;

  static const count = 11;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final reach = unit * 3.2;
    for (var i = 0; i < count; i++) {
      final s1 = frac(i * 0.618 + 0.11);
      final s2 = frac(i * 0.414 + 0.37);
      final speed = 0.035 + 0.05 * s2; // of the column a second
      final y = 1 - frac(s1 + t * speed);
      final x = (s2 - 0.5) * 1.6 + wander(t, 9 + 7 * s1, seed: i) * 0.35;
      final p = flame + Offset(x * reach, (y - 0.55) * reach * 2.2);
      final d = (p - flame).distance / (reach * 1.4);
      final a =
          (1 - d).clamp(0.0, 1.0) *
          (0.25 + 0.6 * s1) *
          math.sin(math.pi * y).clamp(0.0, 1.0);
      if (a <= 0.02) continue;
      paint.color = light.withValues(alpha: a);
      canvas.drawCircle(p, 0.6 + 0.8 * s2, paint);
    }
  }

  @override
  bool shouldRepaint(_DustPainter old) => old.t != t;
}

// --------------------------------------------------------------- the deal

/// Your card dealt onto 04: it slides in from the deck at the upper right,
/// turning, and lands on its place with a little weight. Painted only: it is
/// held where it rests from the first frame.
class AtmoDeal extends StatefulWidget {
  const AtmoDeal({super.key, required this.child});

  final Widget child;

  @override
  State<AtmoDeal> createState() => _AtmoDealState();
}

class _AtmoDealState extends State<AtmoDeal>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 820),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_c.isAnimating && _c.value == 0) {
      if (Atmo.moves(context, AtmoEffect.deal)) {
        _c.forward();
      } else {
        _c.value = 1;
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Atmo.has(AtmoEffect.deal)) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        // A short pause while the dusk lowers the screen, then the throw.
        final v = const Interval(
          0.25,
          0.85,
          curve: Curves.easeOutCubic,
        ).transform(_c.value);
        final settle = _c.value > 0.8
            ? math.sin(math.pi * (_c.value - 0.8) / 0.2) * 0.022
            : 0.0;
        final size = MediaQuery.sizeOf(context);
        return PaintShift(
          offset: Offset(size.width * 0.55, -size.height * 0.55) * (1 - v),
          scale: (0.45 + 0.55 * v) * (1 + settle),
          turn: -0.42 * (1 - v),
          child: child,
        );
      },
    );
  }
}

// -------------------------------------------------------------- carrying

/// A part that is carried from one screen to the next: a new [Carried] of the
/// same [tag] that mounts while another is on screen (the screen it replaces,
/// fading) starts where that one stands and travels to its own place; the
/// old one hides. Painted only, so the new one takes touches where it rests.
class Carried extends StatefulWidget {
  const Carried({super.key, required this.tag, required this.child});

  final String tag;
  final Widget child;

  /// Where the latest of [tag] stands on the screen, if one is up.
  static Rect? rectOf(String tag) => _CarriedState._live[tag]?._rect();

  @override
  State<Carried> createState() => _CarriedState();
}

class _CarriedState extends State<Carried> with SingleTickerProviderStateMixin {
  static final _live = <String, _CarriedState>{};

  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
    value: 1,
  );
  Rect? _from;
  Rect? _to;
  var _handedOver = false;

  Rect? _rect() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  void initState() {
    super.initState();
    if (!Atmo.has(AtmoEffect.carry)) return;
    final before = _live[widget.tag];
    _live[widget.tag] = this;
    if (before == null || !before.mounted) return;
    final from = before._rect();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      before._handOver();
      if (from == null || MediaQuery.disableAnimationsOf(context)) return;
      setState(() {
        _from = from;
        _to = _rect();
      });
      _c.forward(from: 0);
    });
  }

  void _handOver() {
    if (mounted) setState(() => _handedOver = true);
  }

  @override
  void dispose() {
    if (_live[widget.tag] == this) _live.remove(widget.tag);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Atmo.has(AtmoEffect.carry)) return widget.child;
    if (_handedOver) return Opacity(opacity: 0, child: widget.child);
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final from = _from;
        final to = _to;
        if (from == null || to == null || _c.value >= 1) return child!;
        final v = Motion.curve.transform(_c.value);
        final lift = math.sin(math.pi * v) * -to.height * 0.25;
        return PaintShift(
          offset: (from.center - to.center) * (1 - v) + Offset(0, lift),
          scale: ui.lerpDouble(from.height / to.height, 1, v)!,
          child: child,
        );
      },
    );
  }
}
