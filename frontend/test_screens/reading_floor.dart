import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/skin/skin.dart';

import '../test/helpers/painted_text.dart';

// The reading floor (docs/specs/frontend/first-time-play.md, copy rule 7),
// checked on what a player screen actually draws: `just screens ... strict`
// fails a player screen with a breach.

/// Anything a player reads to act, at text scale 1.0.
const readingFloor = 16.0;

/// Captions under cards and tokens.
const captionFloor = 14.0;

/// Tracked capitals smaller than this are a micro-label.
const _labelSize = 20.0;

/// Every run of visible text on screen drawn below the floor, or set as an
/// uppercase, letter-spaced micro-label, one line each. A run is measured as
/// drawn: its size times the text scale's at 1.0 and any shrinking on the
/// way (a `FitLine` set smaller). A role of 16 or more must stay at 16; a
/// caption role (14, 15) at 14; nothing goes below 14. The table code,
/// tracked capitals read letter by letter, is not a label.
List<String> readingFloorBreaches(WidgetTester tester) {
  final breaches = <String>[];
  for (final element in find.byType(RichText).evaluate()) {
    final paragraph = element.renderObject;
    if (paragraph is! RenderParagraph || !paragraph.hasSize) continue;
    if (paragraph.size.isEmpty || _hidden(element, paragraph)) continue;
    final code = Theme.of(element).extension<Skin>()?.typography.code;
    // In logical pixels: the view's own pixel ratio is divided back out.
    final shrink = _widthScale(paragraph) / _viewScale(tester);
    final scale = paragraph.textScaler.scale(1);
    for (final (text, style) in _runs(paragraph.text, null)) {
      if (style.fontFamily == 'MaterialIcons') continue;
      final size = style.fontSize ?? 14;
      final drawn = size * scale * shrink;
      String at(double floor) =>
          '"$text" is drawn at ${drawn.toStringAsFixed(1)} px, below the '
          '$floor px reading floor';
      if (drawn < captionFloor - 0.05) {
        breaches.add(at(captionFloor));
      } else if (size >= readingFloor && drawn < readingFloor - 0.05) {
        breaches.add(at(readingFloor));
      }
      final tracked = (style.letterSpacing ?? 0) > 0.05 * size;
      final capitals =
          RegExp('[A-Z]{2}').hasMatch(text) && text == text.toUpperCase();
      final isCode =
          style.fontSize == code?.fontSize &&
          style.letterSpacing == code?.letterSpacing;
      if (tracked && capitals && size < _labelSize && !isCode) {
        breaches.add('"$text" is an uppercase, letter-spaced micro-label');
      }
    }
  }
  return breaches;
}

/// How much a unit of width under [node] is scaled on its way to the screen
/// (a 2D scale leaves depth at 1, so the largest axis would hide a shrink).
double _widthScale(RenderObject node) {
  final m = node.getTransformTo(null).storage;
  return Offset(m[0], m[1]).distance;
}

double _viewScale(WidgetTester tester) {
  final child = tester.binding.renderViews.first.child;
  return child == null ? 1 : _widthScale(child);
}

/// Not seen: transparent, offstage, or under a sheet's scrim.
bool _hidden(Element element, RenderParagraph paragraph) {
  var behind = false;
  element.visitAncestorElements((ancestor) {
    behind = ancestor.widget is BehindScrim;
    return !behind;
  });
  if (behind) return true;
  RenderObject? node = paragraph;
  var opacity = 1.0;
  while (node != null) {
    if (node is RenderOpacity) opacity *= node.opacity;
    if (node is RenderAnimatedOpacity) opacity *= node.opacity.value;
    if (node is RenderOffstage && node.offstage) return true;
    node = node.parent;
  }
  return opacity < 0.05;
}

Iterable<(String, TextStyle)> _runs(InlineSpan span, TextStyle? parent) sync* {
  if (span is! TextSpan) return;
  final style = parent?.merge(span.style) ?? span.style ?? const TextStyle();
  final text = span.text?.trim() ?? '';
  if (text.isNotEmpty) yield (text, style);
  for (final child in span.children ?? const <InlineSpan>[]) {
    yield* _runs(child, style);
  }
}
