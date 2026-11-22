import 'dart:async';

import 'package:midnight_village/design_system/skin/card_back.dart';

import '../test/flutter_test_config.dart' as base;
import '../test/helpers/shell_setup.dart';

/// The card back the gallery draws every game with, so its pictures are the
/// same on every run: the calm one (`CardBack.fallback`). Another, to look at
/// it, with `--dart-define=SCREENS_CARD_BACK=eye` (a `CardBack` name).
const _back = String.fromEnvironment('SCREENS_CARD_BACK');

/// The gallery runs with the same fonts and setup as the widget tests.
Future<void> testExecutable(FutureOr<void> Function() testMain) {
  ShellSetup.pinnedCardBack =
      CardBack.values.asNameMap()[_back] ?? CardBack.fallback;
  return base.testExecutable(testMain);
}
