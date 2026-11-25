import 'dart:async';

import 'audio_backend.dart';
import 'sound_set.dart';
import 'theme_player.dart';

/// All the logic of the game's sound, over a thin [AudioBackend], so it is
/// tested without a browser (`docs/design/feel.md`, section 6).
///
/// Performance first (the owner, 24 November 2026: "Every tap was delayed"):
/// nothing here awaits on a tap's path. A cue fires in the same call as the
/// tap or not at all; a theme variant that is not decoded yet is decoded on
/// its first need and switched to when it is ready, while the music already
/// playing goes on. Nothing throws: a failing backend is logged and skipped.
/// The theme's voices and memory are [ThemePlayer]'s.
class SoundEngine {
  SoundEngine(
    this._backend,
    this._set, {
    void Function(String message)? log,
    bool muted = false,
    double volume = 1,
  }) : _log = log ?? _silent,
       _muted = muted,
       _volume = _clamp(volume) {
    _theme = ThemePlayer(
      _backend,
      _set,
      _pathOf,
      _log,
      failed: _failed,
      changed: () => _guard('theme', _reconcile),
    );
  }

  final AudioBackend _backend;
  final SoundSet _set;
  final void Function(String) _log;

  late final ThemePlayer _theme;

  bool _started = false;
  bool _muted;
  double _volume;
  bool _hidden = false;

  /// Bumped when a closed output is dropped: a cue decoded on it is stale.
  int _generation = 0;
  bool _closedLogged = false;

  /// Puts the output to sleep when nothing can sound (see [_settle]).
  Timer? _idle;

  /// Set while the gesture being handled asked a stopped output to run from
  /// inside a user activation: a cue of that same gesture may start (the
  /// output runs a moment later). Cleared on the next task, not the next
  /// microtask: a browser runs the microtasks between the engine's capture
  /// listener and the app's own handler of the same event (Flutter's tap
  /// runs on that pointerup), so a microtask would clear it before the cue
  /// (`tool/audio_proof/result.json`, `e`).
  bool _resumeAsked = false;
  int _asks = 0;

  /// Files whose fetch or decode failed: given up on for this visit, so a
  /// broken file costs one log line, not a fetch, a decode and a line per tap.
  final _failed = <String>{};

  /// The cues' decoded clips (small; all kept).
  final _clips = <String, Clip>{};
  final _decoding = <String>{};
  final _chosen = <SoundFile, String?>{};

  bool get muted => _muted;
  double get volume => _volume;

  /// The variant a stage asked for (played once the output is unlocked and
  /// its file decoded).
  ThemeVariant? get wanted => _theme.wanted;

  /// The variant playing now, if any.
  ThemeVariant? get playing => _theme.playing;

  /// Voices sounding now, the fading ones included (at most two).
  int get voices => _theme.voices;

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
        if (path != null) _fetch(path);
      }
    });
  }

  /// A user gesture, [activates] when it is a user activation (a touch's
  /// pointerup, touchend or click, a key, a mouse's press; not a touch's
  /// pointerdown). Only an activating one opens the output (a context made
  /// outside one starts suspended and may stay so). Every gesture asks a
  /// stopped output to run again (Chrome on Android suspends it on its own):
  /// `resume()` is cheap and idempotent, and one asked on a pointerdown may
  /// stay pending, so nothing waits on an earlier one. Muted, nothing is
  /// opened or woken. Never throws.
  void gesture({required bool activates}) {
    if (!_started) return;
    _guard('gesture', () {
      _dropIfClosed();
      if (_hidden || _muted) return;
      if (!_backend.isOpen) {
        if (!activates) return;
        _backend.open(_volume);
        _opened();
      }
      if (_backend.state != AudioState.running) _resume(activated: activates);
      _settle();
    });
  }

  /// The page or app was hidden ([shown] false) or came back. Hidden is
  /// silent; shown continues the loop where it was. Each call asks at once
  /// (no gate on one still on its way): the last one asked wins.
  void visible(bool shown) {
    if (!_started) return;
    _hidden = !shown;
    _guard('visibility', () {
      _dropIfClosed();
      if (!_backend.isOpen) return;
      if (!shown) {
        _idle?.cancel();
        _quiet('suspend', _backend.suspend());
        return;
      }
      if (!_muted && _theme.wanted != null) _resume();
      _settle();
    });
  }

  /// Fires [cue] now if it can sound now: the output is running, or this
  /// very gesture asked it to run from inside a user activation. Otherwise
  /// it is dropped, never started into a stopped output to burst out late
  /// with the others when it runs again (a cue late is worse than none).
  void play(Sfx cue) {
    _guard('play ${cue.name}', () {
      _dropIfClosed();
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
      _settle();
    });
  }

  /// Asks for [variant] of the theme (none: the theme fades out). The same
  /// variant again does nothing.
  void theme(ThemeVariant? variant) {
    if (variant == _theme.wanted) return;
    _theme.wanted = variant;
    _guard('theme ${variant?.name}', () {
      _dropIfClosed();
      _reconcile();
      _wake();
      _settle();
    });
  }

  void setMuted(bool muted) {
    if (muted == _muted) return;
    _muted = muted;
    _guard('mute', () {
      _dropIfClosed();
      if (!_backend.isOpen) return;
      final ramp = SoundTiming.seconds(SoundTiming.mute);
      _backend.master(muted ? 0 : _volume, ramp);
      if (muted) {
        _theme.stop(ramp);
      } else {
        for (final file in _set.cues.values) {
          final path = _pathOf(file);
          if (path != null) _decode(path);
        }
        _reconcile();
        _wake();
      }
      _settle();
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
      switch (_backend.state) {
        AudioState.running => true,
        AudioState.closed => false,
        _ => _resumeAsked,
      };

  /// A closed output (a lost device, a crashed renderer) is dropped with
  /// everything decoded on it, so the next activating gesture opens a new
  /// one; said once a visit, not on every tap.
  void _dropIfClosed() {
    if (!_backend.isOpen || _backend.state != AudioState.closed) return;
    _idle?.cancel();
    _idle = null;
    _generation++;
    _theme.drop();
    for (final clip in _clips.values) {
      _guard('release', () => _backend.release(clip));
    }
    _clips.clear();
    _decoding.clear();
    _backend.discard();
    if (_closedLogged) return;
    _closedLogged = true;
    _log('SoundEngine: the output closed; a new one opens on the next touch');
  }

  /// A stopped output asked to run again outside a gesture, when a theme is
  /// wanted (a browser may hold it until the next touch, which asks again).
  void _wake() {
    if (!_backend.isOpen || _muted || _hidden || _theme.wanted == null) return;
    final state = _backend.state;
    if (state != AudioState.running && state != AudioState.closed) _resume();
  }

  /// Battery: an output left running renders silence. When nothing can
  /// sound (muted, or no theme wanted) it is suspended once the mute ramp,
  /// or the theme's fade out and the longest cue, are over
  /// ([SoundTiming.idle]); the next gesture or [theme] wakes it.
  void _settle() {
    _idle?.cancel();
    _idle = null;
    if (!_backend.isOpen || _hidden) return;
    if (!_muted && _theme.wanted != null) return;
    _idle = Timer(_muted ? SoundTiming.mute : SoundTiming.idle, () {
      _idle = null;
      _guard('idle', () {
        final quiet = _muted || _theme.wanted == null;
        if (!_backend.isOpen || _hidden || !quiet) return;
        if (_backend.state != AudioState.running) return;
        _quiet('suspend', _backend.suspend());
      });
    });
  }

  void _opened() {
    if (_muted) return;
    for (final file in _set.cues.values) {
      final path = _pathOf(file);
      if (path != null) _decode(path);
    }
    _reconcile();
  }

  void _resume({bool activated = false}) {
    if (_hidden) return;
    final Future<void> resumed;
    try {
      resumed = _backend.resume();
    } on Object catch (e) {
      _log('SoundEngine: resume failed: $e');
      return;
    }
    if (activated) {
      _resumeAsked = true;
      final ask = ++_asks;
      Timer.run(() {
        if (ask == _asks) _resumeAsked = false;
      });
    }
    unawaited(
      resumed.then(
        (_) => _guard('after resume', _reconcile),
        onError: (Object e) => _log('SoundEngine: resume refused: $e'),
      ),
    );
  }

  void _reconcile() {
    if (!_backend.isOpen || _muted) return;
    _theme.reconcile();
  }

  /// Decodes a cue (all of them are small and kept).
  void _decode(String path) {
    if (_clips.containsKey(path) || _failed.contains(path)) return;
    if (!_decoding.add(path)) return;
    final generation = _generation;
    final Future<Clip> decoded;
    try {
      decoded = _backend.decode(path);
    } on Object catch (e) {
      _decoding.remove(path);
      _gaveUp(path, e);
      return;
    }
    unawaited(
      decoded.then(
        (clip) {
          if (generation != _generation) {
            _guard('release', () => _backend.release(clip));
            return;
          }
          _decoding.remove(path);
          _clips[path] = clip;
        },
        onError: (Object e) {
          if (generation != _generation) return;
          _decoding.remove(path);
          _gaveUp(path, e);
        },
      ),
    );
  }

  void _fetch(String path) {
    unawaited(
      _backend
          .fetch(path)
          .then<void>((_) {}, onError: (Object e) => _gaveUp(path, e)),
    );
  }

  void _gaveUp(String path, Object e) {
    if (!_failed.add(path)) return;
    _log('SoundEngine: could not load $path (not tried again): $e');
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
