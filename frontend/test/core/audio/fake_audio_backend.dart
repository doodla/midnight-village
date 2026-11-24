import 'dart:async';

import 'package:midnight_village/core/audio/audio_backend.dart';
import 'package:midnight_village/core/audio/sound_set.dart';

/// A looping voice as the fake saw it start.
class FakeLoop {
  FakeLoop(
    this.path,
    this.variant,
    this.at,
    this.offset,
    this.fadeIn,
    this.points,
  );

  final String path;
  final ThemeVariant variant;
  final double at;
  final double offset;
  final double fadeIn;
  final LoopPoints? points;

  /// When its fade out was asked for, and how long it is.
  double? fadedAt;
  double? fadeLength;

  /// Sounding at [now]: started and not yet faded out to silence.
  bool soundingAt(double now) =>
      fadedAt == null || now < fadedAt! + fadeLength!;
}

/// An [AudioBackend] with a clock the test moves and a record of every
/// call, so the engine's logic is checked without a browser. A decode is
/// held until the test completes it ([finishDecode]) unless [decodeAtOnce].
class FakeAudioBackend implements AudioBackend {
  FakeAudioBackend({this.lengths = const {}, this.decodeAtOnce = true});

  /// The seconds each path decodes to (4 s when not named).
  final Map<String, double> lengths;
  bool decodeAtOnce;

  double clock = 0;
  bool opened = false;
  AudioState current = AudioState.suspended;
  int opens = 0;
  double? masterGain;
  final masterRamps = <(double, double)>[];
  final fired = <String>[];
  final loops = <FakeLoop>[];
  final decodes = <String>[];
  final fetches = <String>[];
  final released = <String>[];
  int resumes = 0;
  int suspends = 0;
  void Function()? gesture;
  void Function(bool)? visible;

  /// Paths this platform cannot decode.
  final undecodable = <String>{};

  /// What a resume does: null resolves it (and the state runs).
  Object? resumeError;
  bool resumeThrowsAtOnce = false;

  /// Throws from every call when set (a broken platform).
  Object? everything;

  final _pending = <String, Completer<Clip>>{};

  void _maybeThrow() {
    if (everything case final e?) throw e;
  }

  /// Completes the held decode of [path].
  void finishDecode(String path) =>
      _pending.remove(path)!.complete(Clip(path, lengths[path] ?? 4));

  void failDecode(String path) =>
      _pending.remove(path)!.completeError(StateError('bad file'));

  List<FakeLoop> soundingLoops() => [
    for (final l in loops)
      if (l.soundingAt(clock)) l,
  ];

  @override
  bool get isOpen => opened;

  @override
  void open(double gain) {
    _maybeThrow();
    opens++;
    opened = true;
    masterGain = gain;
  }

  @override
  AudioState get state => current;

  @override
  double get now => clock;

  @override
  Future<void> resume() {
    _maybeThrow();
    resumes++;
    if (resumeThrowsAtOnce) throw StateError('resume blew up');
    if (resumeError case final e?) return Future.error(e);
    current = AudioState.running;
    return Future.value();
  }

  @override
  Future<void> suspend() {
    _maybeThrow();
    suspends++;
    current = AudioState.suspended;
    return Future.value();
  }

  @override
  bool canDecode(String path) {
    _maybeThrow();
    return !undecodable.contains(path);
  }

  @override
  Future<void> fetch(String path) {
    _maybeThrow();
    fetches.add(path);
    return Future.value();
  }

  @override
  Future<Clip> decode(String path) {
    _maybeThrow();
    decodes.add(path);
    if (decodeAtOnce) return Future.value(Clip(path, lengths[path] ?? 4));
    return (_pending[path] = Completer<Clip>()).future;
  }

  @override
  void release(Clip clip) => released.add(clip.native as String);

  @override
  void master(double to, double seconds) {
    _maybeThrow();
    masterGain = to;
    masterRamps.add((to, seconds));
  }

  @override
  void fire(Clip clip) {
    _maybeThrow();
    fired.add(clip.native as String);
  }

  @override
  Voice loop(
    Clip clip,
    ThemeVariant variant, {
    required double at,
    required double offset,
    required double fadeIn,
    LoopPoints? points,
  }) {
    _maybeThrow();
    final l = FakeLoop(
      clip.native as String,
      variant,
      at,
      offset,
      fadeIn,
      points,
    );
    loops.add(l);
    return Voice(l, variant);
  }

  @override
  void fadeOut(Voice voice, double seconds) {
    _maybeThrow();
    final l = voice.native as FakeLoop;
    // A second fade (a cut mid-crossfade) wins only if it ends sooner.
    if (l.fadedAt case final at? when at + l.fadeLength! <= clock + seconds) {
      return;
    }
    l
      ..fadedAt = clock
      ..fadeLength = seconds;
  }

  @override
  void listen({
    required void Function() gesture,
    required void Function(bool shown) visible,
  }) {
    _maybeThrow();
    this.gesture = gesture;
    this.visible = visible;
  }
}
