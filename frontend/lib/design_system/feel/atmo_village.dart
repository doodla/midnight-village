// PROTOTYPE (branch `atmosphere-proto`): the night village's ambient life
// behind the switch in `atmo.dart`: the clouds' drift, the windows, the moon's
// light, the mist. Each is a no-op unless its effect is on.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'atmo.dart';
import 'atmo_parts.dart';

// ------------------------------------------------------------- the village

/// The village's ambient parts, in canvas pixels of the night village
/// (768 x 1024) and given the [toBox] mapping.
abstract final class AtmoVillage {
  /// How far a cloud layer drifts at [t], in canvas pixels (its bleed is 16).
  /// The sky moves in bursts (5 s, 12 to 26 s apart), resting between.
  static const skyBursts = Bursts(
    length: 5,
    gapLeast: 12,
    gapSpread: 14,
    first: 1,
    seed: 7,
  );

  /// The sky's own time: seconds spent in its bursts (so it glides, then
  /// rests where it stopped).
  static double skyTime(double t) {
    final (k, u) = skyBursts.at(t);
    if (k < 0) return 0;
    return (k + u.clamp(0.0, 1.0)) * skyBursts.length;
  }

  static Offset cloudDrift(String file, double t) {
    if (!file.contains('cloud') && !file.contains('moon_shadow')) {
      return Offset.zero;
    }
    final cream = file.contains('cream');
    return Offset(wander(t, cream ? 53 : 71, seed: cream ? 7 : 3) * 13, 0);
  }

  /// The lit windows: their rect on the canvas and their left in the atlas.
  static const windows = <(Rect, double)>[
    (Rect.fromLTRB(59, 420, 83, 477), 0),
    (Rect.fromLTRB(47, 520, 99, 585), 26),
    (Rect.fromLTRB(63, 659, 110, 725), 80),
    (Rect.fromLTRB(199, 593, 222, 645), 129),
    (Rect.fromLTRB(272, 680, 304, 713), 154),
    (Rect.fromLTRB(345, 625, 363, 670), 188),
    (Rect.fromLTRB(392, 623, 418, 680), 208),
    (Rect.fromLTRB(449, 577, 470, 617), 236),
    (Rect.fromLTRB(451, 647, 476, 691), 259),
    (Rect.fromLTRB(518, 647, 535, 698), 286),
    (Rect.fromLTRB(613, 622, 633, 665), 305),
    (Rect.fromLTRB(620, 688, 643, 733), 327),
    (Rect.fromLTRB(705, 487, 732, 543), 352),
    (Rect.fromLTRB(697, 587, 733, 677), 381),
    (Rect.fromLTRB(337, 550, 355, 573), 419),
  ];

  /// How lit window [i] is at [t]: each keeps its own slow hours (lit for
  /// about a fifth of a cycle of 26 to 63 s), fading over about 2 s.
  ///
  /// Bursts with rest between: in burst k (9 to 22 s apart, 1.6 s long) one
  /// window lights and the one lit three bursts before goes out, so at most
  /// three are lit and between bursts nothing changes (no frame is asked).
  static const windowBursts = Bursts(
    length: 1.6,
    gapLeast: 9,
    gapSpread: 13,
    first: 1.5,
    seed: 3,
  );

  static int _windowOf(int k) =>
      (frac(k * 0.414 + 0.27) * windows.length).floor() % windows.length;

  static double windowLight(int i, double t) {
    final (now, _) = windowBursts.at(t);
    var a = 0.0;
    for (var k = now - 3; k <= now; k++) {
      if (k < 0 || _windowOf(k) != i) continue;
      double rise(int b) =>
          smoothStep(0, 1, (t - windowBursts.startOf(b)) / windowBursts.length);
      a = math.max(a, rise(k) * (1 - rise(k + 3)));
    }
    return a;
  }
}

/// The windows lighting, over the plate: [toBox] maps the canvas to the box.
class AtmoWindows extends StatefulWidget {
  const AtmoWindows({super.key, required this.toBox});

  final Rect Function(Rect canvas) toBox;

  @override
  State<AtmoWindows> createState() => _AtmoWindowsState();
}

class _AtmoWindowsState extends State<AtmoWindows> {
  ui.Image? _atlas;
  ImageStream? _stream;
  late final _listener = ImageStreamListener(
    (info, _) => setState(() => _atlas = info.image),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream?.removeListener(_listener);
    _stream = const AssetImage(
      'assets/skins/shadow_paper/atmo/windows_lit.webp',
    ).resolve(createLocalImageConfiguration(context))..addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final atlas = _atlas;
    if (atlas == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: Ambient(
          effect: AtmoEffect.windows,
          restFor: AtmoVillage.windowBursts.restAt,
          still: 30,
          builder: (context, t, _) =>
              CustomPaint(painter: _WindowsPainter(atlas, t, widget.toBox)),
        ),
      ),
    );
  }
}

class _WindowsPainter extends CustomPainter {
  _WindowsPainter(this.atlas, this.t, this.toBox);

  final ui.Image atlas;
  final double t;
  final Rect Function(Rect) toBox;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..filterQuality = FilterQuality.medium;
    final glow = Paint();
    for (final (i, (rect, left)) in AtmoVillage.windows.indexed) {
      final a = AtmoVillage.windowLight(i, t);
      if (a <= 0.01) continue;
      final dst = toBox(rect);
      final src = Rect.fromLTWH(left, 0, rect.width, rect.height);
      // A little warm light on the paper round it, then the panes.
      glow.shader = ui.Gradient.radial(dst.center, dst.longestSide * 1.1, [
        const Color(0xFFFFC46E).withValues(alpha: 0.16 * a),
        const Color(0x00FFC46E),
      ]);
      canvas.drawCircle(dst.center, dst.longestSide * 1.1, glow);
      paint.color = Color.fromRGBO(255, 255, 255, a);
      canvas.drawImageRect(atlas, src, dst, paint);
    }
  }

  @override
  bool shouldRepaint(_WindowsPainter old) => old.t != t || old.atlas != atlas;
}

/// The moon's light breathing, round [moon] (a centre and radius in the box).
class AtmoMoonLight extends StatelessWidget {
  const AtmoMoonLight({super.key, required this.centre, required this.radius});

  final Offset centre;
  final double radius;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: Ambient(
        effect: AtmoEffect.clouds,
        restFor: AtmoVillage.skyBursts.restAt,
        builder: (context, t, _) => CustomPaint(
          painter: _MoonPainter(
            centre,
            radius,
            0.5 + 0.5 * wander(AtmoVillage.skyTime(t) * 2, 13),
          ),
        ),
      ),
    ),
  );
}

class _MoonPainter extends CustomPainter {
  _MoonPainter(this.centre, this.radius, this.breath);

  final Offset centre;
  final double radius;
  final double breath;

  @override
  void paint(Canvas canvas, Size size) {
    final r = radius * (1 + 0.06 * breath);
    canvas.drawCircle(
      centre,
      r,
      Paint()
        ..shader = ui.Gradient.radial(centre, r, [
          Color.fromRGBO(220, 226, 255, 0.06 + 0.09 * breath),
          const Color.fromRGBO(220, 226, 255, 0),
        ]),
    );
  }

  @override
  bool shouldRepaint(_MoonPainter old) => old.breath != breath;
}

/// Torn strips of thin paper drifting along the village's foot, between
/// [top] and [bottom] of the box.
class AtmoMist extends StatelessWidget {
  const AtmoMist({super.key, required this.top, required this.bottom});

  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final band = bottom - top;
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            for (var i = 0; i < 3; i++)
              Positioned(
                left: -w * 0.3,
                width: w * 1.6,
                top: top + band * (0.15 + 0.32 * i),
                height: band * 0.42,
                child: Ambient(
                  effect: AtmoEffect.mist,
                  still: 20,
                  child: RepaintBoundary(
                    child: CustomPaint(painter: _MistStrip(i)),
                  ),
                  builder: (context, t, child) => Transform.translate(
                    offset: Offset(
                      wander(t, 47 + 19.0 * i, seed: 11 + i) * w * 0.14 +
                          (i.isEven ? 1 : -1) * w * 0.02,
                      0,
                    ),
                    child: child,
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _MistStrip extends CustomPainter {
  _MistStrip(this.i);

  final int i;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(41 + i);
    final path = Path();
    const steps = 46;
    final mid = size.height / 2;
    final top = <Offset>[];
    final bot = <Offset>[];
    for (var s = 0; s <= steps; s++) {
      final x = size.width * s / steps;
      final taper = math.sin(math.pi * s / steps);
      final h = size.height * 0.5 * taper * (0.55 + 0.45 * rnd.nextDouble());
      top.add(Offset(x, mid - h * (0.7 + 0.3 * rnd.nextDouble())));
      bot.add(Offset(x, mid + h * (0.35 + 0.25 * rnd.nextDouble())));
    }
    path.moveTo(top.first.dx, top.first.dy);
    for (final p in top.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    for (final p in bot.reversed) {
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()..color = Color.fromRGBO(196, 202, 228, 0.14 + 0.05 * i),
    );
  }

  @override
  bool shouldRepaint(_MistStrip old) => old.i != i;
}
