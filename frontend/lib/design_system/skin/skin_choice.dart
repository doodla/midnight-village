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

/// Reads the skin saved on this device and loads its fonts, before the first
/// frame (`main` awaits it), so the app's first frame is already in it: no
/// flash of the default skin. Returns the skin; [initialSkinProvider] gives
/// it to the app.
Future<SkinId> restoreSkin({
  DevicePreferences? preferences,
  SkinLoader? loader,
}) async {
  final saved = await (preferences ?? DevicePreferences()).readSkin();
  final id = SkinId.byName(saved) ?? SkinId.fallback;
  await (loader ?? SkinLoader()).loadFonts(id.skin);
  return _restored = id;
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
  var _latest = 0;

  @override
  SkinId build() => ref.read(initialSkinProvider);

  /// Switches to [id] once its fonts and its secrets' art are loaded
  /// (`SkinLoader.prepare`), so the first frame in it is whole, and saves the
  /// choice. When choices overlap, the last one made wins.
  Future<void> choose(SkinId id) async {
    final ticket = ++_latest;
    await ref.read(skinLoaderProvider).prepare(id.skin);
    if (ticket != _latest || !ref.mounted) return;
    state = id;
    await ref.read(devicePreferencesProvider).saveSkin(id.name);
  }
}

/// The app's Material theme, from the chosen skin.
@Riverpod(keepAlive: true)
ThemeData appTheme(Ref ref) => skinTheme(ref.watch(skinChoiceProvider).skin);
