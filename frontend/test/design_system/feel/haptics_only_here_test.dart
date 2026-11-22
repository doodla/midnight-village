import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Every vibration goes through `Haptics` (lib/design_system/feel/haptics.dart,
// feel.md section 3): it is the one place that knows the night is silent and
// that only three light names exist. A direct call to Flutter's own
// `HapticFeedback`, or a long `vibrate`, anywhere else in lib/ fails here.
void main() {
  test('nothing in lib/ calls HapticFeedback except Haptics', () {
    final offenders = [
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File &&
            file.path.endsWith('.dart') &&
            !file.path.endsWith('design_system/feel/haptics.dart') &&
            file.readAsStringSync().contains('HapticFeedback'))
          file.path,
    ];
    expect(offenders, isEmpty);
  });

  test('Haptics has the three names and no heavy impact', () {
    final source = File(
      'lib/design_system/feel/haptics.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('heavyImpact')));
    expect(source, isNot(contains('.vibrate')));
    expect(source, contains('selectionClick'));
    expect(source, contains('lightImpact'));
    expect(source, contains('mediumImpact'));
  });
}
