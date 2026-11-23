import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/faces/held_face.dart';

/// One run of text as it was painted: its colour (with the opacity of
/// everything above it, laid over what is behind it), the colour actually
/// painted behind it (read from the screen's pixels), and whether WCAG asks
/// for 4.5:1 or, being large text or an icon, 3:1.
class PaintedText {
  PaintedText({
    required this.text,
    required this.foreground,
    required this.background,
    required this.large,
    required this.icon,
    required this.disabled,
    Color? worst,
  }) : worst = worst ?? background;

  final String text;
  final Color foreground;
  final Color background;

  /// The worst of what is painted round the text: the pixel (leaving out the
  /// most extreme 5%, the paper's grain) it has the least contrast to. The
  /// village and the lights of a dressed screen are read through this; the
  /// commonest colour ([background]) says what the text mostly sits on.
  final Color worst;
  final bool large;
  final bool icon;

  /// Inside a control that cannot be used now, which WCAG exempts.
  final bool disabled;

  double get ratio => contrast(foreground, background);

  /// WCAG 2.1 AA: 4.5:1, or 3:1 for large text (24 px, or 18.66 px bold) and
  /// for icons (1.4.11).
  double get minimum => large || icon ? 3 : 4.5;

  bool get passes => disabled || ratio >= minimum - 0.005;

  /// [ratio] against the [worst] pixel round it.
  double get worstRatio => contrast(foreground, worst);

  /// The same floor as [readable], against the worst pixel round the text.
  bool get readableEverywhere =>
      passes &&
      (large || icon || disabled || worstRatio >= readingContrast - 0.005);

  /// What a player reads by on a player screen: [readingContrast] for text
  /// below large size; large text and icons as [passes].
  bool get readable =>
      passes && (large || icon || disabled || ratio >= readingContrast - 0.005);

  @override
  String toString() =>
      '"$text" ${_hex(foreground)} on ${_hex(background)}: '
      '${ratio.toStringAsFixed(2)}:1 (needs $minimum)';
}

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// The contrast text below large size keeps on a player screen: WCAG AAA
/// (1.4.6).
const readingContrast = 7.0;

/// WCAG 2.1 relative luminance.
double luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double contrast(Color a, Color b) {
  final (la, lb) = (luminance(a), luminance(b));
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Reads every run of visible text on screen: renders the screen to pixels
/// (images loaded for real first), then for each paragraph takes its spans'
/// colours and the most common colour painted in its box that is not the
/// text itself.
Future<List<PaintedText>> readPaintedText(WidgetTester tester) async {
  await _loadImages(tester);
  final root = tester.binding.rootElement!;
  final (pixels, width, height) = (await tester.runAsync(() async {
    final image = await captureImage(root);
    final bytes = await image.toByteData();
    final result = (bytes!.buffer.asUint8List(), image.width, image.height);
    image.dispose();
    return result;
  }))!;

  // A held face is drawn over the screen: the text under it is not seen.
  final faces = [
    for (final face in find.byType(HeldFace).evaluate())
      MatrixUtils.transformRect(
        face.renderObject!.getTransformTo(null),
        Offset.zero & (face.renderObject! as RenderBox).size,
      ),
  ];
  final readings = <PaintedText>[];
  for (final element in find.byType(RichText).evaluate()) {
    final paragraph = element.renderObject;
    if (paragraph is! RenderParagraph || !paragraph.hasSize) continue;
    if (paragraph.size.isEmpty) continue;
    final opacity = _opacity(paragraph);
    if (opacity < 0.05) continue;
    final rect = MatrixUtils.transformRect(
      paragraph.getTransformTo(null),
      Offset.zero & paragraph.size,
    );
    if (_behindScrim(element)) continue;
    if (!_within<HeldFace>(element) && faces.any(rect.overlaps)) continue;
    final disabled = _disabled(element);
    final scale = paragraph.textScaler.scale(1);
    for (final run in _runs(paragraph.text, null)) {
      final style = run.style;
      final colour = style.color;
      if (colour == null) continue;
      final alpha = colour.a * opacity;
      final background = _background(
        pixels,
        width,
        height,
        rect: rect,
        ignore: colour.withValues(alpha: 1),
      );
      if (background == null) continue;
      final size = (style.fontSize ?? 14) * scale;
      final bold = (style.fontWeight?.value ?? 400) >= 700;
      readings.add(
        PaintedText(
          text: run.text,
          foreground: Color.lerp(
            background,
            colour.withValues(alpha: 1),
            alpha,
          )!,
          background: background,
          worst: _worstAround(
            pixels,
            width,
            height,
            rect: rect,
            ink: Color.lerp(background, colour.withValues(alpha: 1), alpha)!,
          ),
          large: size >= 24 || (bold && size >= 18.66),
          icon: style.fontFamily == 'MaterialIcons',
          disabled: disabled,
        ),
      );
    }
  }
  return readings;
}

/// Image providers load on real I/O, which the test clock never waits for.
Future<void> _loadImages(WidgetTester tester) async {
  await tester.runAsync(
    () => Future.wait([
      for (final element in find.byType(Image).evaluate())
        precacheImage((element.widget as Image).image, element),
    ]),
  );
  await tester.pump();
}

class _Run {
  _Run(this.text, this.style);

  final String text;
  final TextStyle style;
}

Iterable<_Run> _runs(InlineSpan span, TextStyle? parent) sync* {
  if (span is! TextSpan) return;
  final style = parent?.merge(span.style) ?? span.style ?? const TextStyle();
  final text = span.text?.trim() ?? '';
  if (text.isNotEmpty) yield _Run(text, style);
  for (final child in span.children ?? const <InlineSpan>[]) {
    yield* _runs(child, style);
  }
}

double _opacity(RenderObject object) {
  var opacity = 1.0;
  RenderObject? node = object;
  while (node != null) {
    if (node is RenderOpacity) opacity *= node.opacity;
    if (node is RenderAnimatedOpacity) opacity *= node.opacity.value;
    if (node is RenderOffstage && node.offstage) return 0;
    node = node.parent;
  }
  return opacity;
}

/// Marks a part of a test screen that is under a sheet's scrim, so not meant
/// to be read: [readPaintedText] leaves its text out.
class BehindScrim extends StatelessWidget {
  const BehindScrim({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

bool _behindScrim(Element element) => _within<BehindScrim>(element);

/// Whether [element] is inside a widget of type [T].
bool _within<T extends Widget>(Element element) {
  var inside = false;
  element.visitAncestorElements((ancestor) {
    inside = ancestor.widget is T;
    return !inside;
  });
  return inside;
}

bool _disabled(Element element) {
  var disabled = false;
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    // A busy control (it says what it is doing, "Working") is still read.
    if (widget is Semantics &&
        widget.properties.enabled == false &&
        widget.properties.value == null) {
      disabled = true;
      return false;
    }
    return true;
  });
  return disabled;
}

/// The pixel in the ring round [rect] that [ink] reads worst on, leaving out
/// the 5% most extreme (the grain of paper, a speck).
Color? _worstAround(
  Uint8List rgba,
  int width,
  int height, {
  required Rect rect,
  required Color ink,
}) {
  final outer = rect.inflate(4);
  final inner = rect.inflate(1);
  final found = <(double, int)>[];
  for (
    var y = outer.top.floor().clamp(0, height);
    y < outer.bottom.ceil().clamp(0, height);
    y++
  ) {
    for (
      var x = outer.left.floor().clamp(0, width);
      x < outer.right.ceil().clamp(0, width);
      x++
    ) {
      if (inner.contains(Offset(x + 0.5, y + 0.5))) continue;
      final i = (y * width + x) * 4;
      if (rgba[i + 3] == 0) continue;
      final c = Color.fromARGB(255, rgba[i], rgba[i + 1], rgba[i + 2]);
      // The glyphs' own overshoot (and a neighbour's) is not background.
      if ((rgba[i] - (ink.r * 255).round()).abs() +
              (rgba[i + 1] - (ink.g * 255).round()).abs() +
              (rgba[i + 2] - (ink.b * 255).round()).abs() <
          60) {
        continue;
      }
      found.add((contrast(ink, c), i));
    }
  }
  if (found.isEmpty) return null;
  found.sort((a, b) => a.$1.compareTo(b.$1));
  final i = found[(found.length * 0.05).floor()].$2;
  return Color.fromARGB(255, rgba[i], rgba[i + 1], rgba[i + 2]);
}

/// The colour painted around [rect]: the most common one in a thin ring just
/// outside the paragraph (inside, a glyph's own pixels can outnumber the
/// ground's), leaving out pixels close to the text's own colour.
Color? _background(
  Uint8List rgba,
  int width,
  int height, {
  required Rect rect,
  required Color ignore,
}) {
  final outer = rect.inflate(4);
  final inner = rect.inflate(1);
  final left = outer.left.floor().clamp(0, width);
  final right = outer.right.ceil().clamp(0, width);
  final top = outer.top.floor().clamp(0, height);
  final bottom = outer.bottom.ceil().clamp(0, height);
  if (right <= left || bottom <= top) return null;
  final ir = (ignore.r * 255).round();
  final ig = (ignore.g * 255).round();
  final ib = (ignore.b * 255).round();
  final counts = <int, int>{};
  final sums = <int, List<int>>{};
  for (var y = top; y < bottom; y++) {
    for (var x = left; x < right; x++) {
      if (inner.contains(Offset(x + 0.5, y + 0.5))) continue;
      final i = (y * width + x) * 4;
      final (r, g, b) = (rgba[i], rgba[i + 1], rgba[i + 2]);
      if ((r - ir).abs() + (g - ig).abs() + (b - ib).abs() < 60) continue;
      final key = (r >> 3) << 10 | (g >> 3) << 5 | (b >> 3);
      counts[key] = (counts[key] ?? 0) + 1;
      final sum = sums[key] ??= [0, 0, 0];
      sum[0] += r;
      sum[1] += g;
      sum[2] += b;
    }
  }
  if (counts.isEmpty) return null;
  final most = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
  final sum = sums[most.key]!;
  return Color.fromARGB(
    255,
    sum[0] ~/ most.value,
    sum[1] ~/ most.value,
    sum[2] ~/ most.value,
  );
}
