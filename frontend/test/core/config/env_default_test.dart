import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/config/env.dart';

void main() {
  test('a build that sets no ENV is prod, so it ships without /debug', () {
    final source = File('lib/core/config/env.dart').readAsStringSync();
    expect(
      source,
      contains(
        RegExp(
          r"String\.fromEnvironment\(\s*'ENV',\s*defaultValue: 'prod',?\s*\)",
        ),
      ),
      reason: 'the default must stay prod; dev is an explicit --dart-define',
    );
  });

  test('the suite runs as dev on purpose (just test passes ENV=dev)', () {
    expect(Env.isDev, isTrue);
    expect(Env.isProd, isFalse);
  });
}
