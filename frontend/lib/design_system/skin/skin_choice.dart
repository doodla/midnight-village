import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/storage/device_preferences.dart';
import 'skin_id.dart';
import 'skin_theme.dart';

part 'skin_choice.g.dart';

@Riverpod(keepAlive: true)
DevicePreferences devicePreferences(Ref ref) => DevicePreferences();

/// The skin chosen on this device: Shadow paper until the saved choice has
/// been read, then the saved one. A choice made before the saved one is read
/// wins over it.
@Riverpod(keepAlive: true)
class SkinChoice extends _$SkinChoice {
  var _chosen = false;

  @override
  SkinId build() {
    _restore();
    return SkinId.shadowPaper;
  }

  Future<void> _restore() async {
    final saved = await ref.read(devicePreferencesProvider).skin;
    final id = SkinId.values.asNameMap()[saved];
    if (id != null && ref.mounted && !_chosen) state = id;
  }

  Future<void> choose(SkinId id) async {
    _chosen = true;
    state = id;
    await ref.read(devicePreferencesProvider).saveSkin(id.name);
  }
}

/// The app's Material theme, from the chosen skin.
@Riverpod(keepAlive: true)
ThemeData appTheme(Ref ref) => skinTheme(ref.watch(skinChoiceProvider).skin);
