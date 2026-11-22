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

  test('the toolbar still carries the marker the release check looks for', () {
    final source = File(
      'lib/features/debug/presentation/debug_toolbar_screen.dart',
    ).readAsStringSync();
    final declared = RegExp(
      r"^const String debugToolbarShipMarker = '([^']+)';",
      multiLine: true,
    ).firstMatch(source);
    expect(declared, isNotNull, reason: 'debugToolbarShipMarker was removed');
    expect(
      source,
      contains('ValueKey<String>(debugToolbarShipMarker)'),
      reason: 'the marker must be used, or it does not ship with the toolbar',
    );
    expect(
      'debugToolbarShipMarker'.allMatches(
        File('lib/core/router/app_router.dart').readAsStringSync(),
      ),
      isEmpty,
      reason: 'the marker must not leak outside the toolbar',
    );
  });
}
