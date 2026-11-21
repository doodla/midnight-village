import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/night/night_board.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';

// What the fit sweep (test/design_system/skin/fit_sweep_test.dart) and the
// night board's tests check on what is drawn; truncated_text.dart has the
// third, text cut short.

/// Every word on screen that is laid out across two lines.
List<String> brokenWords(WidgetTester tester) {
  final broken = <String>[];
  for (final element in find.byType(RichText).evaluate()) {
    final paragraph = element.renderObject;
    if (paragraph is! RenderParagraph || !paragraph.hasSize) continue;
    if (!paragraph.softWrap || paragraph.maxLines == 1) continue;
    final width = paragraph.constraints.maxWidth;
    if (!width.isFinite) continue;
    final text = paragraph.text.toPlainText();
    final painter = TextPainter(
      text: paragraph.text,
      textDirection: paragraph.textDirection,
      textScaler: paragraph.textScaler,
      textAlign: paragraph.textAlign,
      maxLines: paragraph.maxLines,
    )..layout(maxWidth: width);
    // A word is broken where two letters of it sit on different lines.
    double top(int i) {
      final boxes = painter.getBoxesForSelection(
        TextSelection(baseOffset: i, extentOffset: i + 1),
      );
      return boxes.isEmpty ? double.nan : boxes.first.top;
    }

    bool inWord(String c) => c.trim().isNotEmpty;
    for (var i = 1; i < text.length; i++) {
      final (before, after) = (text[i - 1], text[i]);
      if (!inWord(before) || !inWord(after)) continue;
      if (before == '-' || before == '\u00AD') continue;
      if (top(i) > top(i - 1) + 0.5) {
        broken.add('"$text" breaks after "${text.substring(0, i)}"');
      }
    }
    painter.dispose();
  }
  return broken;
}

/// On a night board, every card is on the screen, above the button, with
/// no scrolling: a Drunk can only pick a center card.
List<String> offBoard(WidgetTester tester) {
  if (find.byType(NightBoard).evaluate().isEmpty) return const [];
  final screen = Offset.zero & tester.view.physicalSize;
  final button = tester.getRect(find.byType(PrimaryButton).last);
  return [
    for (final element in find.byType(FaceDownCard).evaluate())
      if (tester.getRect(find.byWidget(element.widget)) case final card
          when !screen.contains(card.bottomRight - const Offset(1, 1)) ||
              card.bottom > button.top)
        '"${(element.widget as FaceDownCard).semanticLabel}" is off the board',
  ];
}
