// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scan_session.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The scanner's place, kept outside 01's widgets: a join that starts makes
/// the app swap one 01 for another (`HomeGate` shows 01 itself while a way
/// in is on its way), and the scanner, with the code it found, must stand
/// through that, then end with the join: it closes when the join ends or
/// is refused (01's banner says why), never before.

@ProviderFor(ScanSession)
const scanSessionProvider = ScanSessionProvider._();

/// The scanner's place, kept outside 01's widgets: a join that starts makes
/// the app swap one 01 for another (`HomeGate` shows 01 itself while a way
/// in is on its way), and the scanner, with the code it found, must stand
/// through that, then end with the join: it closes when the join ends or
/// is refused (01's banner says why), never before.
final class ScanSessionProvider
    extends $NotifierProvider<ScanSession, ScanState> {
  /// The scanner's place, kept outside 01's widgets: a join that starts makes
  /// the app swap one 01 for another (`HomeGate` shows 01 itself while a way
  /// in is on its way), and the scanner, with the code it found, must stand
  /// through that, then end with the join: it closes when the join ends or
  /// is refused (01's banner says why), never before.
  const ScanSessionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'scanSessionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$scanSessionHash();

  @$internal
  @override
  ScanSession create() => ScanSession();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ScanState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ScanState>(value),
    );
  }
}

String _$scanSessionHash() => r'10d81e4502b6aaf70e2d1c94576410b82b9cbca6';

/// The scanner's place, kept outside 01's widgets: a join that starts makes
/// the app swap one 01 for another (`HomeGate` shows 01 itself while a way
/// in is on its way), and the scanner, with the code it found, must stand
/// through that, then end with the join: it closes when the join ends or
/// is refused (01's banner says why), never before.

abstract class _$ScanSession extends $Notifier<ScanState> {
  ScanState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<ScanState, ScanState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ScanState, ScanState>,
              ScanState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
