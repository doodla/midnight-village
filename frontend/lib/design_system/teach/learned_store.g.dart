// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'learned_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The cues learned on this device. Whether a cue shows depends on the
/// device's history only, never on the role (hidden information: every phone
/// that has not learned a cue shows it at the same moment).

@ProviderFor(LearnedCues)
const learnedCuesProvider = LearnedCuesProvider._();

/// The cues learned on this device. Whether a cue shows depends on the
/// device's history only, never on the role (hidden information: every phone
/// that has not learned a cue shows it at the same moment).
final class LearnedCuesProvider
    extends $NotifierProvider<LearnedCues, Set<Cue>> {
  /// The cues learned on this device. Whether a cue shows depends on the
  /// device's history only, never on the role (hidden information: every phone
  /// that has not learned a cue shows it at the same moment).
  const LearnedCuesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'learnedCuesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$learnedCuesHash();

  @$internal
  @override
  LearnedCues create() => LearnedCues();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<Cue> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<Cue>>(value),
    );
  }
}

String _$learnedCuesHash() => r'd6226ae6c2bc21fd37525daebff231de3beab29b';

/// The cues learned on this device. Whether a cue shows depends on the
/// device's history only, never on the role (hidden information: every phone
/// that has not learned a cue shows it at the same moment).

abstract class _$LearnedCues extends $Notifier<Set<Cue>> {
  Set<Cue> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<Set<Cue>, Set<Cue>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Set<Cue>, Set<Cue>>,
              Set<Cue>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
