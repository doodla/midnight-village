import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/component_sheet.dart';
import '../../helpers/pump_skinned.dart';

// Nothing may rely on a fixed size to fit (design brief section 3, rule 6):
// every page of the component sheet, in every skin, at the narrow phones'
// widths and with the text made larger, lays out with no overflow.

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

          final overflows = <String>{};
          var where = '';
          final report = FlutterError.onError;
          FlutterError.onError = (details) => overflows.add(
            '$where: ${details.exceptionAsString().split('\n').first}'
            '${_culprit(details)}',
          );
          addTearDown(() => FlutterError.onError = report);
          for (final page in ComponentPage.values) {
            for (final ground in page.grounds) {
              where = '${page.name} on ${ground.name}';
              await pumpComponentPage(tester, page, ground, skin: skin);
            }
          }
          FlutterError.onError = report;
          expect(overflows, isEmpty);
        });
      }
    }
  }
}
