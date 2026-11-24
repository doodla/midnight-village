import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/audio/audio_backend.dart';
import '../../core/audio/backend_stub.dart'
    if (dart.library.js_interop) '../../core/audio/backend_web.dart';
import '../../core/audio/sound_engine.dart';
import '../../core/audio/sound_set.dart';
import '../../core/audio/sound_settings.dart';
import '../../core/logging/app_logger.dart';

export '../../core/audio/sound_set.dart' show Sfx, ThemeVariant;
export '../../core/audio/sound_settings.dart' show SoundLevel, SoundSettings;

/// The game's sound (`docs/design/feel.md`, section 6): the one place a
/// screen asks for one, as `Haptics` is for a vibration
/// (`sounds_only_here_test.dart` fails anything else in lib/ that reaches
/// the engine or the browser's audio). Never throws, never waits: a cue
/// fires in the frame of its tap or not at all.
///
/// Nothing is chosen yet (the owner is picking by ear): [catalogue] is
/// empty, no screen calls [play] or [theme], and with an empty catalogue
/// [start] does nothing at all.
abstract final class Sounds {
  /// Every cue and theme variant, by name, to its files in the bundle.
  /// Each path must be in `pubspec.yaml`'s assets (`sound_set_test.dart`).
  static const catalogue = SoundSet.empty;

  /// Muted and the volume, remembered on this device; listenable for the
  /// control a later piece builds.
  static final settings = SoundSettings();

  static SoundEngine? _engine;
  static ThemeVariant? _wanted;
  static AppLifecycleListener? _lifecycle;

  /// Called once from `main.dart`, after the skin's art is in (after the
  /// first frame): reads the settings and listens for the first gesture.
  static void start() => unawaited(startWith(catalogue, platformBackend));

  /// [start] with a given set and backend (the tests).
  @visibleForTesting
  static Future<void> startWith(
    SoundSet set,
    AudioBackend Function() backend, {
    bool watchLifecycle = !backendWatchesVisibility,
  }) async {
    if (set.isEmpty || _engine != null) return;
    try {
      await settings.restore();
      final level = settings.value;
      final engine = SoundEngine(
        backend(),
        set,
        log: logger.w,
        muted: level.muted,
        volume: level.volume,
      );
      _engine = engine;
      engine
        ..theme(_wanted)
        ..start();
      settings.addListener(_follow);
      if (watchLifecycle) {
        _lifecycle = AppLifecycleListener(
          onHide: () => engine.visible(false),
          onShow: () => engine.visible(true),
        );
      }
    } on Object catch (e) {
      logger.w('Sounds: could not start: $e');
    }
  }

  /// Fires [cue] now, or drops it when it cannot sound now (before the first
  /// touch, muted, hidden, not decoded yet).
  static void play(Sfx cue) {
    try {
      _engine?.play(cue);
    } on Object catch (e) {
      logger.w('Sounds: $cue: $e');
    }
  }

  /// The stage's piece of the theme; null lets it fade out. Asked before the
  /// first touch, it starts on that touch; the same one again does nothing.
  static void theme(ThemeVariant? variant) {
    _wanted = variant;
    try {
      _engine?.theme(variant);
    } on Object catch (e) {
      logger.w('Sounds: theme $variant: $e');
    }
  }

  static void setMuted(bool muted) => unawaited(settings.setMuted(muted));

  static void setVolume(double volume) => unawaited(settings.setVolume(volume));

  static void _follow() {
    final level = settings.value;
    _engine
      ?..setMuted(level.muted)
      ..setVolume(level.volume);
  }

  /// Forgets the engine (the tests).
  @visibleForTesting
  static void reset() {
    settings.removeListener(_follow);
    _lifecycle?.dispose();
    _lifecycle = null;
    _engine = null;
    _wanted = null;
  }
}
