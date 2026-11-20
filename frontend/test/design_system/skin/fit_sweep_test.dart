import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/night/night_board.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';

import '../../helpers/component_sheet.dart';
import '../../helpers/pump_skinned.dart';

// Nothing may rely on a fixed size to fit (design brief section 3, rule 6):
// every page of the component sheet, in every skin, at the narrow phones'
// widths and with the text made larger, lays out with no overflow, and no
// word is broken across two lines (a name or a heading is set smaller, or
// wraps between words, never inside one).

const _widths = [320.0, 360.0, 390.0];
const _textScales = [1.0, 1.3, 2.0];

/// A phone's height at [width] (the mocks' 390 x 844).
double _height(double width) => width * 844 / 390;

/// Where in lib/ the overflow is, from the report's creator chain.
String _culprit(FlutterErrorDetails details) {
  final match = RegExp(
    r'(?:package:midnight_village/|lib/)(design_system/[\w/]+\.dart:\d+)',
  ).firstMatch(details.toString());
  return match == null ? '' : ' (${match.group(1)})';
}

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

void main() {
  for (final MapEntry(key: name, value: skin) in skinsUnderTest.entries) {
    for (final width in _widths) {
      for (final scale in _textScales) {
        testWidgets('$name at $width wide, text x$scale', (tester) async {
          tester.view.physicalSize = Size(width, _height(width));
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          final findings = <String>{};
          var where = '';
          final report = FlutterError.onError;
          FlutterError.onError = (details) => findings.add(
            '$where: ${details.exceptionAsString().split('\n').first}'
            '${_culprit(details)}',
          );
          addTearDown(() => FlutterError.onError = report);
          for (final page in ComponentPage.values) {
            for (final ground in page.grounds) {
              where = '${page.name} on ${ground.name}';
              await pumpComponentPage(tester, page, ground, skin: skin);
              for (final word in brokenWords(tester)) {
                findings.add('$where: $word');
              }
              findings.addAll([
                for (final card in offBoard(tester)) '$where: $card',
              ]);
            }
          }
          FlutterError.onError = report;
          expect(findings, isEmpty);
        });
      }
    }
  }
}
