// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'join_flow.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The ways in from 01, outside any widget so a screen that is swapped
/// mid-way (the sign-in that comes first puts the app in the table's shell)
/// loses nothing:
/// - the name: this device's own guest account when it has that name, else
///   a new guest account with it (the server has no rename);
/// - then a new table (`defaults: "v2"`, always) or a join by code, whose
///   answer is the table's lobby ([LobbySeed]: 02 draws it, no second read);
/// - then the screen `/me/table/` names (02) follows, the answer being where
///   the player sits ([SeatSeed]: nothing is asked after it). Joining a
///   table this player already sits at is no refusal: it is there, and
///   `/me/table/` is read to say so.
/// The account step never makes a second account over a saved one the
/// server has not refused (`AuthNotifier.createGuest`).

@ProviderFor(JoinFlow)
const joinFlowProvider = JoinFlowProvider._();

/// The ways in from 01, outside any widget so a screen that is swapped
/// mid-way (the sign-in that comes first puts the app in the table's shell)
/// loses nothing:
/// - the name: this device's own guest account when it has that name, else
///   a new guest account with it (the server has no rename);
/// - then a new table (`defaults: "v2"`, always) or a join by code, whose
///   answer is the table's lobby ([LobbySeed]: 02 draws it, no second read);
/// - then the screen `/me/table/` names (02) follows, the answer being where
///   the player sits ([SeatSeed]: nothing is asked after it). Joining a
///   table this player already sits at is no refusal: it is there, and
///   `/me/table/` is read to say so.
/// The account step never makes a second account over a saved one the
/// server has not refused (`AuthNotifier.createGuest`).
final class JoinFlowProvider
    extends $NotifierProvider<JoinFlow, JoinFlowState> {
  /// The ways in from 01, outside any widget so a screen that is swapped
  /// mid-way (the sign-in that comes first puts the app in the table's shell)
  /// loses nothing:
  /// - the name: this device's own guest account when it has that name, else
  ///   a new guest account with it (the server has no rename);
  /// - then a new table (`defaults: "v2"`, always) or a join by code, whose
  ///   answer is the table's lobby ([LobbySeed]: 02 draws it, no second read);
  /// - then the screen `/me/table/` names (02) follows, the answer being where
  ///   the player sits ([SeatSeed]: nothing is asked after it). Joining a
  ///   table this player already sits at is no refusal: it is there, and
  ///   `/me/table/` is read to say so.
  /// The account step never makes a second account over a saved one the
  /// server has not refused (`AuthNotifier.createGuest`).
  const JoinFlowProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'joinFlowProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$joinFlowHash();

  @$internal
  @override
  JoinFlow create() => JoinFlow();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(JoinFlowState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<JoinFlowState>(value),
    );
  }
}

String _$joinFlowHash() => r'5196a24caf62d3e5f8a008d8c7e687c118caa4df';

/// The ways in from 01, outside any widget so a screen that is swapped
/// mid-way (the sign-in that comes first puts the app in the table's shell)
/// loses nothing:
/// - the name: this device's own guest account when it has that name, else
///   a new guest account with it (the server has no rename);
/// - then a new table (`defaults: "v2"`, always) or a join by code, whose
///   answer is the table's lobby ([LobbySeed]: 02 draws it, no second read);
/// - then the screen `/me/table/` names (02) follows, the answer being where
///   the player sits ([SeatSeed]: nothing is asked after it). Joining a
///   table this player already sits at is no refusal: it is there, and
///   `/me/table/` is read to say so.
/// The account step never makes a second account over a saved one the
/// server has not refused (`AuthNotifier.createGuest`).

abstract class _$JoinFlow extends $Notifier<JoinFlowState> {
  JoinFlowState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<JoinFlowState, JoinFlowState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<JoinFlowState, JoinFlowState>,
              JoinFlowState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
