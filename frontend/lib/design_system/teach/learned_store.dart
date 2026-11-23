import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/storage/device_preferences.dart';
import '../skin/skin_choice.dart';

part 'learned_store.g.dart';

/// The things the app teaches once per device (first-time play spec, section
/// 2): an animation, and for [hold] the word "Hold", shown until the player
/// has done the thing once on this device.
enum Cue {
  /// The breathing hold ring on whatever hides a secret (the card on 04,
  /// "You" on the night board, My night on 08); taught once: learned by the
  /// first 0.8 s reveal on any face, and then gone from all of them.
  hold('hold'),

  /// The wave across the night board as it opens; learned by the first
  /// successful choose.
  nightChoose('night_choose'),

  /// The nudge across the vote rows; learned by the first successful lock.
  voteLock('vote_lock'),

  /// 08's sealed "My night": until it has been held once (a reveal that
  /// counts), its seal lifts and settles as the talk opens and after a tap
  /// too short to open it. Taught by doing it, never in words.
  myNight('my_night'),

  /// "Go on" on the end board's lower edge as What happened begins; learned
  /// by the first step played (`EndBoardView.stepTaught`, `onStepTaught`).
  endStep('end_step');

  const Cue(this.id);

  /// The cue's name in storage.
  final String id;

  /// Where it is stored, value "1" (`shared_preferences`; localStorage on
  /// the web).
  String get key => '$learnedPrefix$id';

  /// Every learned cue's key starts with this.
  static const learnedPrefix = 'mv.learned.v1.';

  static Cue? byKey(String key) =>
      values.where((cue) => cue.key == key).firstOrNull;
}

Set<Cue>? _restored;

/// Reads the cues this device has learned, before the first frame (`main`
/// awaits it, as it does the skin), so a cue never flashes on for one frame
/// on a device that knows it.
Future<Set<Cue>> restoreLearned({DevicePreferences? preferences}) async {
  final keys = await (preferences ?? DevicePreferences()).readFlags(
    Cue.learnedPrefix,
  );
  return _restored = {for (final key in keys) ?Cue.byKey(key)};
}

/// Forgets what [restoreLearned] read, so a test starts as a new device does.
@visibleForTesting
void forgetRestoredLearned() => _restored = null;

/// The cues learned on this device. Whether a cue shows depends on the
/// device's history only, never on the role (hidden information: every phone
/// that has not learned a cue shows it at the same moment).
@Riverpod(keepAlive: true)
class LearnedCues extends _$LearnedCues {
  @override
  Set<Cue> build() => _restored ?? const {};

  /// Marks [cue] learned here and saves it; learning it again does nothing.
  Future<void> learn(Cue cue) async {
    if (state.contains(cue)) return;
    state = {...state, cue};
    await ref.read(devicePreferencesProvider).setFlag(cue.key);
  }

  /// Forgets every cue on this device, so the next game teaches them again.
  /// For the debug toolbar (`lib/features/debug/`):
  /// `ref.read(learnedCuesProvider.notifier).reset()`.
  Future<void> reset() async {
    state = const {};
    await ref.read(devicePreferencesProvider).clearFlags(Cue.learnedPrefix);
  }
}
