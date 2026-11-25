import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'audio_backend.dart';
import 'sound_set.dart';

/// Web Audio under the [SoundEngine]: one context, made in the first
/// gesture; a file is fetched and decoded by the browser (`decodeAudioData`),
/// so its bytes and samples stay on the browser's side and never pass
/// through Dart. A cue is a new `AudioBufferSourceNode` on a decoded buffer,
/// started in the same call as the tap. A theme variant is a looping source
/// (`loop`, with the file's loop points when it has them: a sample-exact
/// loop with no gap) through its own gain, crossfaded with gain ramps.
///
/// Pure `package:web`, no Flutter, so `tool/audio_proof/` compiles the same
/// code for a real browser. [open] may make an `OfflineAudioContext` there.
class WebAudioBackend implements AudioBackend {
  WebAudioBackend({
    required String Function(String path) urlOf,
    web.BaseAudioContext Function()? create,
  }) : _urlOf = urlOf,
       _create = create;

  final String Function(String) _urlOf;
  final web.BaseAudioContext Function()? _create;

  web.BaseAudioContext? _context;
  web.GainNode? _master;
  final _fetched = <String, Future<JSArrayBuffer>>{};
  web.HTMLAudioElement? _probe;

  /// The context, once open (for the proof's measurements).
  web.BaseAudioContext? get context => _context;

  web.AudioContext? get _live {
    final c = _context;
    return c != null && c.isA<web.AudioContext>()
        ? c as web.AudioContext
        : null;
  }

  @override
  bool get isOpen => _context != null;

  @override
  void open(double gain) {
    if (_context != null) return;
    final context = _create?.call() ?? web.AudioContext();
    final master = context.createGain();
    master.gain.value = gain;
    master.connect(context.destination);
    _context = context;
    _master = master;
  }

  @override
  void discard() {
    _context = null;
    _master = null;
  }

  @override
  AudioState get state => switch (_context?.state) {
    'running' => AudioState.running,
    'closed' => AudioState.closed,
    'interrupted' => AudioState.interrupted,
    _ => AudioState.suspended,
  };

  @override
  double get now => _context?.currentTime ?? 0;

  @override
  double get baseLatency {
    final live = _live;
    // Not every browser has it (older Safari): 0 then.
    if (live == null || !(live as JSObject).has('baseLatency')) return 0;
    final v = live.baseLatency;
    return v.isFinite && v > 0 ? v : 0;
  }

  @override
  Future<void> resume() async {
    final live = _live;
    if (live != null) await live.resume().toDart;
  }

  @override
  Future<void> suspend() async {
    final live = _live;
    if (live != null) await live.suspend().toDart;
  }

  static const _types = {
    'ogg': 'audio/ogg',
    'oga': 'audio/ogg',
    'opus': 'audio/ogg; codecs="opus"',
    'm4a': 'audio/mp4',
    'mp4': 'audio/mp4',
    'aac': 'audio/aac',
    'mp3': 'audio/mpeg',
    'wav': 'audio/wav',
  };

  @override
  bool canDecode(String path) {
    final type = _types[path.split('.').last.toLowerCase()];
    if (type == null) return false;
    final probe = _probe ??= web.HTMLAudioElement();
    return probe.canPlayType(type).isNotEmpty;
  }

  @override
  Future<void> fetch(String path) => _bytes(path);

  Future<JSArrayBuffer> _bytes(String path) =>
      _fetched.putIfAbsent(path, () async {
        final response = await web.window.fetch(_urlOf(path).toJS).toDart;
        if (!response.ok) throw StateError('$path: HTTP ${response.status}');
        return response.arrayBuffer().toDart;
      });

  @override
  Future<Clip> decode(String path) async {
    final context = _context;
    if (context == null) throw StateError('decode before open');
    final Future<JSArrayBuffer> bytes = _bytes(path);
    // decodeAudioData takes the buffer over: a later decode fetches again
    // (from the browser's cache).
    _fetched.remove(path);
    final buffer = await context.decodeAudioData(await bytes).toDart;
    return Clip(buffer, buffer.duration);
  }

  @override
  void release(Clip clip) {}

  @override
  void master(double to, double seconds) {
    final context = _context;
    final master = _master;
    if (context == null || master == null) return;
    _ramp(master.gain, context.currentTime, to, seconds);
  }

  @override
  void fire(Clip clip) {
    final context = _context!;
    final source = context.createBufferSource()
      ..buffer = clip.native as web.AudioBuffer;
    source.connect(_master!);
    source.onended = ((web.Event _) => source.disconnect()).toJS;
    source.start();
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
    final context = _context!;
    final gain = context.createGain();
    gain.gain
      ..setValueAtTime(0, at)
      ..linearRampToValueAtTime(1, at + fadeIn);
    gain.connect(_master!);
    final source = loopSource(
      context,
      clip.native as web.AudioBuffer,
      points: points,
    );
    source.connect(gain);
    source.start(at, offset);
    return Voice((source, gain), variant);
  }

  /// A looping source on [buffer], over [points] when given (the proof
  /// renders the same node offline).
  static web.AudioBufferSourceNode loopSource(
    web.BaseAudioContext context,
    web.AudioBuffer buffer, {
    LoopPoints? points,
  }) {
    final source = context.createBufferSource()
      ..buffer = buffer
      ..loop = true;
    if (points != null) {
      source
        ..loopStart = points.start
        ..loopEnd = points.end;
    }
    return source;
  }

  @override
  void fadeOut(
    Voice voice,
    double seconds, {
    double? at,
    void Function()? ended,
  }) {
    final context = _context;
    if (context == null) return;
    final (source, gain) =
        voice.native as (web.AudioBufferSourceNode, web.GainNode);
    final now = context.currentTime;
    final from = at == null || at < now ? now : at;
    _ramp(gain.gain, now, 0, seconds, from: from);
    source.onended = ((web.Event _) {
      source.disconnect();
      gain.disconnect();
      ended?.call();
    }).toJS;
    source.stop(from + seconds);
  }

  /// Ramps [param] from where it is to [to] over [s] seconds starting at
  /// [from] (now by default), holding it until then.
  static void _ramp(
    web.AudioParam param,
    double now,
    double to,
    double s, {
    double? from,
  }) {
    final start = from ?? now;
    final value = param.value;
    param
      ..cancelScheduledValues(now)
      ..setValueAtTime(value, now);
    if (start > now) param.setValueAtTime(value, start);
    param.linearRampToValueAtTime(to, start + s);
  }

  /// The events that are a user activation whatever the pointer (HTML's
  /// activation-triggering events). A touch's pointerdown is not one on
  /// Android, so a context made or resumed there may stay suspended; a
  /// mouse's pointerdown is, and [_activeNow] says so.
  static const _activating = {'pointerup', 'touchend', 'click', 'keydown'};

  static const _gestures = [
    'pointerdown',
    'pointerup',
    'touchend',
    'mousedown',
    'keydown',
    'click',
  ];

  @override
  void listen({
    required void Function(bool activates) gesture,
    required void Function(bool shown) visible,
  }) {
    // On the window, in the capture phase: it runs before the app sees the
    // event, so the tap that unlocks is already inside a gesture. Passive:
    // it never holds a scroll or a touch.
    final options = web.AddEventListenerOptions(capture: true, passive: true);
    final onGesture = ((web.Event e) => gesture(
      _activating.contains(e.type) || _activeNow(),
    )).toJS;
    for (final type in _gestures) {
      web.window.addEventListener(type, onGesture, options);
    }
    web.document.addEventListener(
      'visibilitychange',
      ((web.Event _) => visible(
        web.document.visibilityState == 'visible',
      )).toJS,
    );
  }

  /// Whether the page holds a transient user activation now
  /// (`navigator.userActivation.isActive`; false where it is missing).
  static bool _activeNow() {
    final navigator = web.window.navigator as JSObject;
    if (!navigator.has('userActivation')) return false;
    return web.window.navigator.userActivation.isActive;
  }
}
