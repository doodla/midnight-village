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

  /// When its (last) fade out starts, and how long it is: the last `stop()`
  /// wins, as in Web Audio.
  double? fadedAt;
  double? fadeLength;
  void Function()? ended;
  bool hasEnded = false;

  double? get stopAt => fadedAt == null ? null : fadedAt! + fadeLength!;

  /// Sounding at [now]: started, and not yet faded out to silence.
  bool soundingAt(double now) =>
      !hasEnded && now >= at - 1e-12 && (stopAt == null || now < stopAt!);
}

/// An [AudioBackend] that follows Web Audio's rules, with a clock the test
/// moves and a record of every call, so the engine's logic is checked
/// without a browser:
///
/// - a context made outside a user activation starts suspended;
/// - `resume()` outside one stays pending until a `resume()` inside one
///   (unless [resumeNeedsGesture] is false: Chrome once the page has had a
///   gesture), and the state changes a microtask later, not in the call;
/// - suspend and resume apply in order: the last one asked wins;
/// - the states are suspended, running, interrupted and closed;
/// - the audio clock stands still unless running;
/// - a voice's last `stop()` wins.
///
/// A decode is held until the test completes it ([finishDecode]) unless
/// [decodeAtOnce].
class FakeAudioBackend implements AudioBackend {
  FakeAudioBackend({this.lengths = const {}, this.decodeAtOnce = true});

  /// The seconds each path decodes to (4 s when not named).
  final Map<String, double> lengths;
  bool decodeAtOnce;

  /// Whether a resume needs a user activation (Safari, and Chrome before
  /// the page's first gesture).
  bool resumeNeedsGesture = true;

  /// True only inside a gesture the test sends as a user activation.
  bool activation = false;

  @override
  double baseLatency = 0;

  double clock = 0;
  bool opened = false;
  AudioState current = AudioState.suspended;
  int opens = 0;
  double? masterGain;
  final masterRamps = <(double, double)>[];
  final fired = <String>[];

  /// Cues started while the output was not running and no resume asked
  /// inside an activation was on its way (they would sound late, together).
  final lateCues = <String>[];
  final loops = <FakeLoop>[];
  final decodes = <String>[];
  final fetches = <String>[];
  final released = <String>[];

  /// Decoded clips not released yet, by path (a path may be there twice).
  final held = <String>[];
  int resumes = 0;
  int suspends = 0;
  void Function(bool activates)? gesture;
  void Function(bool)? visible;

  /// Paths this platform cannot decode, and paths whose fetch fails.
  final undecodable = <String>{};
  final unfetchable = <String>{};

  /// What a resume does: an error rejects it.
  Object? resumeError;
  bool resumeThrowsAtOnce = false;

  /// Throws from every call when set (a broken platform).
  Object? everything;

  final _pending = <String, Completer<Clip>>{};
  final _waitingResumes = <Completer<void>>[];
  bool _granted = false;
  int _op = 0;

  void _maybeThrow() {
    if (everything case final e?) throw e;
  }

  /// Decodes not finished yet.
  Iterable<String> get decoding => _pending.keys;

  /// Completes the held decode of [path].
  void finishDecode(String path) {
    held.add(path);
    _pending.remove(path)!.complete(Clip(path, lengths[path] ?? 4));
  }

  void failDecode(String path) =>
      _pending.remove(path)!.completeError(StateError('bad file'));

  /// One gesture, sent as the page would (an activation or not).
  void send({required bool activates}) {
    activation = activates;
    try {
      gesture!(activates);
    } finally {
      activation = false;
    }
  }

  /// A mouse click or a key: every event an activation.
  void tap() => send(activates: true);

  /// A finger on Android: pointerdown is no activation; pointerup, touchend
  /// and click are.
  void touch() {
    send(activates: false);
    for (var i = 0; i < 3; i++) {
      send(activates: true);
    }
  }

  /// The audio clock moves [seconds] (only while running), and every voice
  /// whose stop time has passed ends.
  void advance(double seconds) {
    if (current == AudioState.running) clock += seconds;
    for (final l in [...loops]) {
      if (!l.hasEnded && l.stopAt != null && l.stopAt! <= clock) {
        l.hasEnded = true;
        l.ended?.call();
      }
    }
  }

  /// The platform takes the output away (Safari: a call).
  void interrupt() {
    if (current != AudioState.closed) current = AudioState.interrupted;
  }

  /// The platform closes the context (a lost device, a crashed renderer).
  void close() {
    current = AudioState.closed;
    for (final l in loops) {
      l.hasEnded = true;
    }
    for (final c in _waitingResumes) {
      c.completeError(StateError('closed'));
    }
    _waitingResumes.clear();
  }

  List<FakeLoop> soundingLoops() => [
    for (final l in loops)
      if (l.soundingAt(clock)) l,
  ];

  @override
  bool get isOpen => opened;

  @override
  void open(double gain) {
    _maybeThrow();
    if (opened) throw StateError('opened twice');
    opens++;
    opened = true;
    masterGain = gain;
    current = activation ? AudioState.running : AudioState.suspended;
  }

  @override
  void discard() {
    opened = false;
    held.clear();
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
    if (current == AudioState.closed) return Future.error(StateError('closed'));
    final mine = Completer<void>();
    if (resumeNeedsGesture && !activation) {
      _waitingResumes.add(mine);
      return mine.future;
    }
    final op = ++_op;
    _granted = true;
    scheduleMicrotask(() {
      _granted = false;
      if (current == AudioState.closed) return;
      if (op == _op) current = AudioState.running;
      for (final c in _waitingResumes) {
        c.complete();
      }
      _waitingResumes.clear();
      mine.complete();
    });
    return mine.future;
  }

  @override
  Future<void> suspend() {
    _maybeThrow();
    suspends++;
    if (current == AudioState.closed) return Future.error(StateError('closed'));
    final op = ++_op;
    scheduleMicrotask(() {
      if (current != AudioState.closed && op == _op) {
        current = AudioState.suspended;
      }
    });
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
    if (unfetchable.contains(path)) return Future.error(StateError('404'));
    return Future.value();
  }

  @override
  Future<Clip> decode(String path) {
    _maybeThrow();
    if (!opened) throw StateError('decode before open');
    decodes.add(path);
    if (unfetchable.contains(path)) return Future.error(StateError('404'));
    if (decodeAtOnce) {
      held.add(path);
      return Future.value(Clip(path, lengths[path] ?? 4));
    }
    return (_pending[path] = Completer<Clip>()).future;
  }

  @override
  void release(Clip clip) {
    final path = clip.native as String;
    released.add(path);
    held.remove(path);
  }

  @override
  void master(double to, double seconds) {
    _maybeThrow();
    masterGain = to;
    masterRamps.add((to, seconds));
  }

  @override
  void fire(Clip clip) {
    _maybeThrow();
    final path = clip.native as String;
    fired.add(path);
    if (current != AudioState.running && !_granted) lateCues.add(path);
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
  void fadeOut(
    Voice voice,
    double seconds, {
    double? at,
    void Function()? ended,
  }) {
    _maybeThrow();
    final l = voice.native as FakeLoop;
    final from = at == null || at < clock ? clock : at;
    l
      ..fadedAt = from
      ..fadeLength = seconds
      ..ended = ended;
  }

  @override
  void listen({
    required void Function(bool activates) gesture,
    required void Function(bool shown) visible,
  }) {
    _maybeThrow();
    this.gesture = gesture;
    this.visible = visible;
  }
}
