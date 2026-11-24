import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/game/presentation/end/end_reveal.dart'
    show RenderRevealPaint;

// No text a player sees is drawn cut short: a name, a heading or a button's
// words are set smaller or wrap between words, never end in "...", fade out,
// stop at a line limit or lose glyphs to a box round them. Checked on what is
// actually drawn: by the fit sweep (test/design_system/skin/fit_sweep_test.dart)
// on every component sheet page at every width and text scale, and by the
// screen gallery (`just screens ... strict`) on every screen.

/// Every run of visible text on screen that is drawn cut, one line each:
/// - more lines than its `maxLines` allows (what is past the limit is not
///   drawn, with or without an ellipsis);
/// - one unwrapped line wider than its box, or lines taller than it,
///   ending in an ellipsis, a fade or a clip;
/// - glyphs outside a clip of a box round it (a scrolling list's edge aside:
///   scrolled text is not cut, it is further down).
List<String> truncatedText(WidgetTester tester) {
  final cut = <String>[];
  for (final element in find.byType(RichText).evaluate()) {
    final paragraph = element.renderObject;
    if (paragraph is! RenderParagraph || !paragraph.hasSize) continue;
    if (paragraph.size.isEmpty || isUnseen(element, paragraph)) continue;
    final text = paragraph.text.toPlainText();
    if (text.trim().isEmpty) continue;
    if (_cutByItself(paragraph) case final why?) {
      cut.add('"${_short(text)}" $why');
    } else if (_cutByClip(paragraph) case final why?) {
      cut.add('"${_short(text)}" $why');
    }
  }
  return cut;
}

/// Not seen: transparent, offstage, or under a sheet's scrim (a widget named
/// `BehindScrim` above it).
bool isUnseen(Element element, RenderObject paragraph) {
  var behind = false;
  element.visitAncestorElements((ancestor) {
    behind = ancestor.widget.runtimeType.toString() == 'BehindScrim';
    return !behind;
  });
  if (behind) return true;
  RenderObject? node = paragraph;
  var opacity = 1.0;
  while (node != null) {
    if (node is RenderOpacity) opacity *= node.opacity;
    if (node is RenderAnimatedOpacity) opacity *= node.opacity.value;
    // The end board's own fade (the settled board hidden while the night
    // plays, a reveal's piece before its beat): painted at this opacity.
    if (node is RenderRevealPaint) opacity *= node.opacity?.call() ?? 1;
    if (node is RenderOffstage && node.offstage) return true;
    node = node.parent;
  }
  return opacity < 0.05;
}

String _short(String text) {
  final line = text.replaceAll('\n', ' ');
  return line.length > 60 ? '${line.substring(0, 57)}...' : line;
}

/// Why [paragraph] cuts its own text, or null: laid out again with no line
/// limit and no ellipsis, it needs more lines, or more width, than it drew.
String? _cutByItself(RenderParagraph paragraph) {
  final width = paragraph.constraints.maxWidth;
  final painter = TextPainter(
    text: paragraph.text,
    textDirection: paragraph.textDirection,
    textScaler: paragraph.textScaler,
    textAlign: paragraph.textAlign,
    locale: paragraph.locale,
    strutStyle: paragraph.strutStyle,
    textWidthBasis: paragraph.textWidthBasis,
    textHeightBehavior: paragraph.textHeightBehavior,
  )..layout(maxWidth: paragraph.softWrap ? width : double.infinity);
  try {
    final lines = painter.computeLineMetrics().length;
    if (paragraph.maxLines case final most? when lines > most) {
      return 'needs $lines lines and is cut at $most';
    }
    final over = painter.width - paragraph.size.width;
    if (over > 0.5 && paragraph.overflow != TextOverflow.visible) {
      return 'is ${over.toStringAsFixed(1)} px wider than its box and is cut '
          '(${paragraph.overflow.name})';
    }
    final below = painter.height - paragraph.size.height;
    if (below > 0.5 && paragraph.overflow != TextOverflow.visible) {
      return 'is ${below.toStringAsFixed(1)} px taller than its box and is '
          'cut (${paragraph.overflow.name})';
    }
    return null;
  } finally {
    painter.dispose();
  }
}

/// Why a clip above [paragraph] cuts its glyphs, or null.
String? _cutByClip(RenderParagraph paragraph) {
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(
      baseOffset: 0,
      extentOffset: paragraph.text.toPlainText().length,
    ),
  );
  if (boxes.isEmpty) return null;
  var glyphs = boxes.first.toRect();
  for (final box in boxes.skip(1)) {
    glyphs = glyphs.expandToInclude(box.toRect());
  }
  RenderObject child = paragraph;
  var parent = paragraph.parent;
  while (parent != null) {
    if (parent is RenderAbstractViewport) return null;
    final clip = parent.describeApproximatePaintClip(child);
    if (clip != null) {
      final drawn = MatrixUtils.transformRect(
        paragraph.getTransformTo(parent),
        glyphs,
      );
      final inside = clip.inflate(0.5);
      if (!_contains(inside, drawn)) {
        final lost = math.max(
          math.max(inside.left - drawn.left, drawn.right - inside.right),
          math.max(inside.top - drawn.top, drawn.bottom - inside.bottom),
        );
        return 'loses ${lost.toStringAsFixed(1)} px of its glyphs to the clip '
            'of ${parent.runtimeType}';
      }
    }
    child = parent;
    parent = parent.parent;
  }
  return null;
}

bool _contains(Rect outer, Rect inner) =>
    inner.left >= outer.left &&
    inner.top >= outer.top &&
    inner.right <= outer.right &&
    inner.bottom <= outer.bottom;
