import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../join_flow.dart';

part 'scan_session.g.dart';

/// Whether the scanner (01b) is open, and the table's code once it has read
/// one.
@immutable
class ScanState {
  const ScanState({this.open = false, this.code});

  final bool open;

  /// The code the scanner read, while the join it started is on its way.
  final String? code;
}

/// The scanner's place, kept outside 01's widgets: a join that starts makes
/// the app swap one 01 for another (`HomeGate` shows 01 itself while a way
/// in is on its way), and the scanner, with the code it found, must stand
/// through that, then end with the join: it closes when the join ends or
/// is refused (01's banner says why), never before.
@Riverpod(keepAlive: true)
class ScanSession extends _$ScanSession {
  @override
  ScanState build() {
    ref.listen(joinFlowProvider, (before, after) {
      if (!state.open || state.code == null) return;
      final ended = before?.busy != null && after.busy == null;
      final refused = after.banner != null && after.banner != before?.banner;
      if (ended || refused) close();
    });
    return const ScanState();
  }

  /// The player tapped scan.
  void open() => state = const ScanState(open: true);

  /// The camera read [code] and its join starts.
  void found(String code) => state = ScanState(open: true, code: code);

  /// The 01 that showed the scanner is gone: it ends with it, unless a join it
  /// started is on its way (the app swaps one 01 for another then, and this
  /// reads the state as it is now, not as the old screen last drew it).
  void left() {
    if (ref.mounted && state.code == null) state = const ScanState();
  }

  void close() {
    // A screen's last word can come after the app is gone.
    if (ref.mounted) state = const ScanState();
  }
}
