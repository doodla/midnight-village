import 'package:flutter/foundation.dart';

import '../storage/device_preferences.dart';

/// Muted and the volume, as this device last left them.
@immutable
final class SoundLevel {
  const SoundLevel({this.muted = false, this.volume = 1});

  static const standard = SoundLevel();

  final bool muted;

  /// 0 (silent) to 1 (as mixed).
  final double volume;

  @override
  bool operator ==(Object other) =>
      other is SoundLevel && other.muted == muted && other.volume == volume;

  @override
  int get hashCode => Object.hash(muted, volume);
}

/// The sound settings, remembered on the device (`DevicePreferences`) and
/// listenable, so a control can be built on them later (none is today). A
/// failed read is the standard level; a failed write is logged and the
/// level holds for this visit.
class SoundSettings extends ValueNotifier<SoundLevel> {
  SoundSettings({DevicePreferences? preferences})
    : _preferences = preferences ?? DevicePreferences(),
      super(SoundLevel.standard);

  final DevicePreferences _preferences;

  static const mutedKey = 'sound.muted';
  static const volumeKey = 'sound.volume';

  /// Reads what this device remembered (fast; never throws).
  Future<void> restore() async {
    final muted = await _preferences.readString(mutedKey);
    final volume = double.tryParse(
      await _preferences.readString(volumeKey) ?? '',
    );
    value = SoundLevel(
      muted: muted == '1',
      volume: volume == null || volume.isNaN
          ? SoundLevel.standard.volume
          : volume.clamp(0, 1).toDouble(),
    );
  }

  Future<void> setMuted(bool muted) async {
    value = SoundLevel(muted: muted, volume: value.volume);
    await _preferences.writeString(mutedKey, muted ? '1' : '0');
  }

  Future<void> setVolume(double volume) async {
    final v = volume.isNaN ? value.volume : volume.clamp(0, 1).toDouble();
    value = SoundLevel(muted: value.muted, volume: v);
    await _preferences.writeString(volumeKey, '$v');
  }
}
