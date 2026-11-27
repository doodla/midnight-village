import 'dart:async';

import '../test/helpers/quiet_field.dart';

/// The harness's suites (`tool/run_harness.sh`): as they are, unless
/// `HARNESS_DEFINES="FIELD_QUIET=true"` asked for the live app's quiet field
/// recorder on in every test (`quietFieldInTests`).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  quietFieldInTests();
  await testMain();
}
