import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/storage/device_preferences.dart';
import 'skin_id.dart';
import 'skin_theme.dart';

part 'skin_choice.g.dart';

@Riverpod(keepAlive: true)
DevicePreferences devicePreferences(Ref ref) => DevicePreferences();

/// The app's Material theme, from the skin. There is one look
/// ([SkinId.fallback]); a future look is a separate design, not a switch.
@Riverpod(keepAlive: true)
ThemeData appTheme(Ref ref) => skinTheme(SkinId.fallback.skin);
