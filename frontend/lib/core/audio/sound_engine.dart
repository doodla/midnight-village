import 'dart:async';

import 'audio_backend.dart';
import 'sound_set.dart';

/// All the logic of the game's sound, over a thin [AudioBackend], so it is
/// tested without a browser (`docs/design/feel.md`, section 6).
///
/// Performance first (the owner, 24 November 2026: "Every tap was delayed"):
/// nothing here awaits on a tap's path. A cue fires in the same call as the
/// tap or not at all; a theme variant that is not decoded yet is decoded on
/// its first need and switched to when it is ready, while the music already
/// playing goes on. Nothing throws: a failing backend is logged and skipped.
///
/// The music has a clock of its own: the audio time [_t0] its first variant
/// started. Every variant is the same length, so a switch starts the new one
/// at the place the old one has reached and the two crossfade in phase.
class SoundEngine {
  SoundEngine(
    this._backend,
    this._set, {
    void Function(String message)? log,
    bool muted = false,
    double volume = 1,
  }) : _log = log ?? _silent,
       _muted = muted,
       _volume = _clamp(volume);

  final AudioBackend _backend;
  final SoundSet _set;
  final void Function(String) _log;

  /// The theme variants kept decoded at once: the one playing and the one
  /// it came from (a 60 s stereo variant is about 20 MB decoded).
  static const keptVariants = 2;

  bool _started = false;
  bool _muted;
  double _volume;
  bool _hidden = false;

  ThemeVariant? _wanted;
  Voice? _current;
  final _outgoing = <(Voice, double)>[];
  double? _t0;

  final _clips = <String, Clip>{};
  final _decoding = <String>{};
  final _keptThemes = <String>[];
  final _chosen = <SoundFile, String?>{};

  bool get muted => _muted;
  double get volume => _volume;

  /// The variant a stage asked for (played once the output is unlocked and
  /// its file decoded).
  ThemeVariant? get wanted => _wanted;

  /// The variant playing now, if any.
  ThemeVariant? get playing => _current?.variant;

  /// Voices sounding now, the fading ones included (at most two).
  int get voices {
    final now = _backend.now;
    return (_current == null ? 0 : 1) +
        _outgoing.where((v) => v.$2 > now).length;
  }

  /// Begins listening for the first gesture and fetches the cues' bytes
  /// ahead. With nothing in the set it does nothing at all: no listener and
  /// no output.
  void start() {
    if (_started || _set.isEmpty) return;
    _started = true;
    _guard('listen', () {
      _backend.listen(
        gesture: (activates) => gesture(activates: activates),
        visible: visible,
      );
    });
    if (_muted) return;
    _guard('fetch', () {
      for (final file in _set.cues.values) {
        final path = _pathOf(file);
        if (path != null) _quiet('fetch $path', _backend.fetch(path));
      }
    });
  }

  /// A user gesture, [activates] when it is a user activation (a touch's
  /// pointerup, touchend or click, a key, a mouse's press; not a touch's
  /// pointerdown). Only an activating one opens the output (a context made
  /// outside one starts suspended and may stay so). Every gesture asks a
  /// stopped output to run again (Chrome on Android suspends it on its own):
  /// `resume()` is cheap and idempotent, and one asked on a pointerdown may
  /// stay pending, so nothing waits on an earlier one. Never throws.
  void gesture({required bool activates}) {
    if (!_started) return;
    _guard('gesture', () {
      if (_hidden) return;
      if (!_backend.isOpen) {
        if (!activates) return;
        _backend.open(_muted ? 0 : _volume);
        _opened();
      }
      if (_backend.state != AudioState.running) _resume();
    });
  }

  /// The page or app was hidden ([shown] false) or came back. Hidden is
  /// silent; shown continues the loop where it was. Each call asks at once
  /// (no gate on one still on its way): the last one asked wins.
  void visible(bool shown) {
    if (!_started) return;
    _hidden = !shown;
    _guard('visibility', () {
      if (!_backend.isOpen) return;
      if (shown) {
        _resume();
      } else {
        _quiet('suspend', _backend.suspend());
      }
    });
  }

  /// Fires [cue] now if it can sound now; otherwise drops it (a cue late is
  /// worse than none).
  void play(Sfx cue) {
    _guard('play ${cue.name}', () {
      if (!_canSound) return;
      final file = _set.cues[cue] ?? _cueNamed(cue.name);
      if (file == null) return;
      final path = _pathOf(file);
      final clip = path == null ? null : _clips[path];
      if (clip == null) {
        if (path != null) _decode(path);
        return;
      }
      _backend.fire(clip);
    });
  }

  /// Asks for [variant] of the theme (none: the theme fades out). The same
  /// variant again does nothing.
  void theme(ThemeVariant? variant) {
    if (variant == _wanted) return;
    _wanted = variant;
    _guard('theme ${variant?.name}', _reconcile);
  }

  void setMuted(bool muted) {
    if (muted == _muted) return;
    _muted = muted;
    _guard('mute', () {
      if (!_backend.isOpen) return;
      final ramp = SoundTiming.seconds(SoundTiming.mute);
      _backend.master(muted ? 0 : _volume, ramp);
      if (muted) {
        _stopTheme(ramp);
      } else {
        for (final file in _set.cues.values) {
          final path = _pathOf(file);
          if (path != null) _decode(path);
        }
        _reconcile();
      }
    });
  }

  void setVolume(double volume) {
    final v = _clamp(volume);
    if (v == _volume) return;
    _volume = v;
    _guard('volume', () {
      if (!_backend.isOpen || _muted) return;
      _backend.master(v, SoundTiming.seconds(SoundTiming.volume));
    });
  }

  bool get _canSound =>
      _started &&
      !_muted &&
      !_hidden &&
      _backend.isOpen &&
      _backend.state == AudioState.running;

  void _opened() {
    if (_muted) return;
    for (final file in _set.cues.values) {
      final path = _pathOf(file);
      if (path != null) _decode(path);
    }
    _reconcile();
  }

  void _resume() {
    if (_hidden) return;
    final Future<void> resumed;
    try {
      resumed = _backend.resume();
    } on Object catch (e) {
      _log('SoundEngine: resume failed: $e');
      return;
    }
    unawaited(
      resumed.then(
        (_) => _guard('after resume', _reconcile),
        onError: (Object e) => _log('SoundEngine: resume refused: $e'),
      ),
    );
  }

  /// Brings what plays in line with what is wanted, as far as it can now.
  void _reconcile() {
    if (!_backend.isOpen || _muted) return;
    final wanted = _wanted;
    if (wanted == null) {
      _stopTheme(SoundTiming.seconds(SoundTiming.themeOut));
      return;
    }
    if (_current?.variant == wanted) return;
    final file = _set.theme[wanted];
    final path = file == null ? null : _pathOf(file);
    if (file == null || path == null) return;
    final clip = _clips[path];
    if (clip == null) {
      _decode(path, theme: true);
      return;
    }
    _touch(path);
    final now = _backend.now;
    final at = now + SoundTiming.seconds(SoundTiming.lead);
    final t0 = _t0 ??= at;
    final offset = loopPosition(at - t0, clip.seconds, file.loop);
    final old = _current;
    final fade = SoundTiming.seconds(
      old == null ? SoundTiming.themeIn : SoundTiming.crossfade,
    );
    if (old != null) {
      _dropOutgoing(now);
      _backend.fadeOut(old, fade, at: at);
      _outgoing.add((old, at + fade));
    }
    _current = _backend.loop(
      clip,
      wanted,
      at: at,
      offset: offset,
      fadeIn: fade,
      points: file.loop,
    );
  }

  /// Keeps at most two voices: a variant still fading out when a third is
  /// asked for is cut (with a ramp too short to click).
  void _dropOutgoing(double now) {
    _outgoing.removeWhere((v) => v.$2 <= now);
    for (final (voice, _) in _outgoing) {
      _backend.fadeOut(voice, SoundTiming.seconds(SoundTiming.declick));
    }
    _outgoing.clear();
  }

  void _stopTheme(double fade) {
    final now = _backend.now;
    _dropOutgoing(now);
    final old = _current;
    if (old != null) {
      _backend.fadeOut(old, fade);
      _outgoing.add((old, now + fade));
    }
    _current = null;
    _t0 = null;
  }

  void _decode(String path, {bool theme = false}) {
    if (_clips.containsKey(path) || !_decoding.add(path)) return;
    final Future<Clip> decoded;
    try {
      decoded = _backend.decode(path);
    } on Object catch (e) {
      _decoding.remove(path);
      _log('SoundEngine: could not decode $path: $e');
      return;
    }
    unawaited(
      decoded.then(
        (clip) {
          _decoding.remove(path);
          _clips[path] = clip;
          if (theme) {
            _touch(path);
            _guard('decoded $path', _reconcile);
          }
        },
        onError: (Object e) {
          _decoding.remove(path);
          _log('SoundEngine: could not decode $path: $e');
        },
      ),
    );
  }

  /// Marks a theme file as just used and forgets the least recent beyond
  /// [keptVariants] (never one that is sounding).
  void _touch(String path) {
    _keptThemes
      ..remove(path)
      ..add(path);
    final sounding = {
      for (final v in [
        ?_current,
        for (final (v, ends) in _outgoing)
          if (ends > _backend.now) v,
      ])
        if (_set.theme[v.variant] case final file?) _pathOf(file),
    };
    while (_keptThemes.length > keptVariants) {
      final oldest = _keptThemes.firstWhere(
        (p) => p != path && !sounding.contains(p),
        orElse: () => path,
      );
      if (oldest == path) break;
      _keptThemes.remove(oldest);
      final clip = _clips.remove(oldest);
      if (clip != null) _guard('release', () => _backend.release(clip));
    }
  }

  SoundFile? _cueNamed(String name) {
    for (final MapEntry(:key, :value) in _set.cues.entries) {
      if (key.name == name) return value;
    }
    return null;
  }

  /// The first encoding of [file] this platform decodes.
  String? _pathOf(SoundFile file) => _chosen.putIfAbsent(file, () {
    for (final path in file.paths) {
      if (_backend.canDecode(path)) return path;
    }
    _log('SoundEngine: no encoding of ${file.paths} decodes here');
    return null;
  });

  void _guard(String what, void Function() body) {
    try {
      body();
    } on Object catch (e) {
      _log('SoundEngine: $what failed: $e');
    }
  }

  void _quiet(String what, Future<void> future) {
    unawaited(
      future.then<void>(
        (_) {},
        onError: (Object e) => _log('SoundEngine: $what failed: $e'),
      ),
    );
  }

  static double _clamp(double v) => v.isNaN ? 1 : v.clamp(0, 1).toDouble();

  static void _silent(String _) {}
}
