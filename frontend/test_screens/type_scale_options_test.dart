// The type-size review's pictures (`docs/design/type-audit.md`): six screens
// at 360 wide, written to build/typescale/<screen>-<scale>.png for the scale
// this run is built with (`--dart-define=TYPE_SCALE=today|compact|tight`).
// Not part of `just test`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/skin/type_scale.dart';

import 'end_fixtures.dart';
import 'screen_gallery.dart';
import 'shell_fixtures.dart';
import 'table_fixtures.dart';

const _width = int.fromEnvironment('SCREENS_WIDTH', defaultValue: 360);

void main() {
  final screens = <String, Future<void> Function(WidgetTester)>{
    '1-first': pumpJoinFresh,
    '2-table': pumpTableHostSix,
    '3-your-card': pumpYourCardHeld,
    '4-night-board': pumpNightBoard,
    '5-vote': pumpVoteSixLong,
    '6-results': pumpResultsVillage,
  };
  final report = StringBuffer();
  tearDownAll(() {
    File('build/typescale/${TypeScale.current.name}-findings.txt')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('$report');
  });
  for (final MapEntry(key: id, value: build) in screens.entries) {
    testWidgets(id, (tester) async {
      final capture = await captureScreen(
        tester,
        build,
        width: _width,
        playerScreen: true,
      );
      if (capture.failure case final failure?) fail(failure);
      File('build/typescale/$id-${TypeScale.current.name}.png')
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(capture.png!);
      for (final finding in capture.findings) {
        report.writeln('$id: $finding');
      }
    });
  }
}
