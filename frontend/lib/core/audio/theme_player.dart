import 'dart:async';

import 'audio_backend.dart';
import 'sound_set.dart';

/// The theme's part of [SoundEngine]: its voices and its decoded variants.
///
/// The music has a clock of its own: the audio time [_t0] its first variant
/// started. Every variant is the same length, so a switch starts the new one
/// at the place the old one has reached and the two crossfade in phase.
///
/// Memory is bounded: at most [keptVariants] variants are decoded at once
/// (a 60 s stereo variant is about 20 MB decoded), counting the one being
/// decoded, and one is decoded at a time, only the one wanted. A decode that
/// finishes when it is no longer wanted is released at once. A third variant
/// asked for mid-crossfade waits for the outgoing voice to end (the music
/// playing goes on meanwhile), unless it is already decoded.
class ThemePlayer {
  ThemePlayer(
    this._backend,
    this._set,
    this._pathOf,
    this._log, {
    required void Function() changed,
  }) : _changed = changed;

  final AudioBackend _backend;
  final SoundSet _set;
  final String? Function(SoundFile) _pathOf;
  final void Function(String) _log;

  /// Something ended or arrived: the engine brings things in line again.
  final void Function() _changed;

  /// The theme variants kept decoded at once: the one playing and the one
  /// it came from.
  static const keptVariants = 2;

  /// The variant a stage asked for.
  ThemeVariant? wanted;

  Voice? _current;
  final _outgoing = <(Voice, double)>[];
  double? _t0;

  /// Decoded variants by path, least recently used first.
  final _held = <String, Clip>{};
  String? _decoding;

  /// Bumped when the output is dropped: a decode from before is stale.
  int _generation = 0;

  ThemeVariant? get playing => _current?.variant;

  /// Voices sounding now, the fading ones included (at most two).
  int get voices {
    final now = _backend.now;
    return (_current == null ? 0 : 1) +
        _outgoing.where((v) => v.$2 > now).length;
  }

  /// Whether any voice is sounding or about to.
  bool get sounding => _current != null || voices > 0;

  /// Brings what plays in line with what is wanted, as far as it can now.
  void reconcile() {
    _prune();
    final wanted = this.wanted;
    if (wanted == null) {
      stop(SoundTiming.seconds(SoundTiming.themeOut));
      return;
    }
    if (_current?.variant == wanted) return;
    final file = _set.theme[wanted];
    final path = file == null ? null : _pathOf(file);
    if (file == null || path == null) return;
    final clip = _held.remove(path);
    if (clip == null) {
      _decode(path);
      return;
    }
    _held[path] = clip;
    _switchTo(clip, wanted, file);
    _evict();
  }

  void _switchTo(Clip clip, ThemeVariant variant, SoundFile file) {
    final old = _current;
    final fade = SoundTiming.seconds(
      old == null ? SoundTiming.themeIn : SoundTiming.crossfade,
    );
    if (old != null) _cutOutgoing();
    final at = _backend.now + SoundTiming.seconds(SoundTiming.lead);
    final t0 = _t0 ??= at;
    _current = _backend.loop(
      clip,
      variant,
      at: at,
      offset: loopPosition(at - t0, clip.seconds, file.loop),
      fadeIn: fade,
      points: file.loop,
    );
    if (old != null) _fadeOut(old, fade, at: at);
  }

  /// The theme out over [fade] seconds; the next variant starts afresh.
  void stop(double fade) {
    _cutOutgoing();
    final old = _current;
    _current = null;
    _t0 = null;
    if (old != null) _fadeOut(old, fade);
  }

  /// The output is gone: every voice and decoded variant with it.
  void drop() {
    _generation++;
    _decoding = null;
    _current = null;
    _outgoing.clear();
    _t0 = null;
    for (final clip in _held.values) {
      _release(clip);
    }
    _held.clear();
  }

  void _fadeOut(Voice voice, double fade, {double? at}) {
    final from = at ?? _backend.now;
    _outgoing.add((voice, from + fade));
    _backend.fadeOut(voice, fade, at: at, ended: () => _ended(voice));
  }

  /// Keeps at most two voices: a variant still fading out when a third is
  /// asked for is cut (with a ramp too short to click, and shorter than the
  /// lead, so it is silent before the new one starts). A cut voice no longer
  /// holds its variant decoded: the platform keeps its buffer until it stops.
  void _cutOutgoing() {
    for (final (voice, _) in _outgoing) {
      _backend.fadeOut(voice, SoundTiming.seconds(SoundTiming.declick));
    }
    _outgoing.clear();
  }

  void _ended(Voice voice) {
    final before = _outgoing.length;
    _outgoing.removeWhere((v) => identical(v.$1, voice));
    if (_outgoing.length == before) return;
    _evict();
    _changed();
  }

  /// Forgets voices whose fade is over (when the platform's end is late).
  void _prune() {
    final now = _backend.now;
    _outgoing.removeWhere((v) => v.$2 <= now);
  }

  Set<String> get _soundingPaths => {
    for (final v in [?_current, for (final (v, _) in _outgoing) v])
      if (_set.theme[v.variant] case final file?) ?_pathOf(file),
  };

  String? get _wantedPath => switch (wanted) {
    final w? => switch (_set.theme[w]) {
      final file? => _pathOf(file),
      null => null,
    },
    null => null,
  };

  /// Releases the least recent decoded variants that are not sounding and
  /// not wanted while more than [keep] are held.
  void _evict({int keep = keptVariants}) {
    final sounding = _soundingPaths;
    final wantedPath = _wantedPath;
    for (final path in [..._held.keys]) {
      if (_held.length <= keep) return;
      if (sounding.contains(path) || path == wantedPath) continue;
      _release(_held.remove(path)!);
    }
  }

  void _decode(String path) {
    if (_decoding != null) return;
    _evict(keep: keptVariants - 1);
    if (_held.length >= keptVariants) return;
    final generation = _generation;
    final Future<Clip> decoded;
    try {
      decoded = _backend.decode(path);
    } on Object catch (e) {
      _log('SoundEngine: could not decode $path: $e');
      return;
    }
    _decoding = path;
    unawaited(
      decoded.then(
        (clip) {
          if (generation != _generation) {
            _release(clip);
            return;
          }
          _decoding = null;
          if (path == _wantedPath) {
            _held[path] = clip;
          } else {
            _release(clip);
          }
          _changed();
        },
        onError: (Object e) {
          if (generation == _generation) _decoding = null;
          _log('SoundEngine: could not decode $path: $e');
        },
      ),
    );
  }

  void _release(Clip clip) {
    try {
      _backend.release(clip);
    } on Object catch (e) {
      _log('SoundEngine: release failed: $e');
    }
  }
}
