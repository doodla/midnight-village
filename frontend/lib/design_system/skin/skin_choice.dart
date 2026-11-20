import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/storage/device_preferences.dart';
import '../skin_loader.dart';
import 'skin_id.dart';
import 'skin_theme.dart';

part 'skin_choice.g.dart';

@Riverpod(keepAlive: true)
DevicePreferences devicePreferences(Ref ref) => DevicePreferences();

@Riverpod(keepAlive: true)
SkinLoader skinLoader(Ref ref) => SkinLoader();

SkinId? _restored;

/// Reads the skin saved on this device before the first frame (`main` awaits
/// it), so the app's first frame is already in it. Returns the skin;
/// [initialSkinProvider] gives it to the app.
Future<SkinId> restoreSkin({DevicePreferences? preferences}) async {
  final saved = await (preferences ?? DevicePreferences()).readSkin();
  return _restored = SkinId.byName(saved) ?? SkinId.fallback;
}

/// Forgets what [restoreSkin] read, so a test starts as a new device does.
@visibleForTesting
void forgetRestoredSkin() => _restored = null;

/// The skin the app starts in: the one [restoreSkin] read, else the default.
@Riverpod(keepAlive: true)
SkinId initialSkin(Ref ref) => _restored ?? SkinId.fallback;

/// The skin chosen on this device.
@Riverpod(keepAlive: true)
class SkinChoice extends _$SkinChoice {
  @override
  SkinId build() => ref.read(initialSkinProvider);

  /// Switches to [id] once its secrets' art is decoded
  /// (`SkinLoader.prepare`), so the first frame in it is whole, and saves the
  /// choice.
  Future<void> choose(SkinId id) async {
    await ref.read(skinLoaderProvider).prepare(id.skin);
    if (!ref.mounted) return;
    state = id;
    await ref.read(devicePreferencesProvider).saveSkin(id.name);
  }
}

/// The app's Material theme, from the chosen skin.
@Riverpod(keepAlive: true)
ThemeData appTheme(Ref ref) => skinTheme(ref.watch(skinChoiceProvider).skin);
