import 'sound_set.dart';

/// The lengths the sound engine uses (`docs/design/feel.md`, section 6), in
/// the audio clock's seconds: one place, as `Motion` is for what moves. They
/// shape a sound; none of them delays a tap or a screen.
abstract final class SoundTiming {
  /// One theme variant handing over to the next.
  static const crossfade = Duration(milliseconds: 1500);

  /// The theme coming in from silence (its first start, an unmute).
  static const themeIn = Duration(milliseconds: 800);

  /// The theme going out when no stage asks for it.
  static const themeOut = Duration(milliseconds: 1200);

  /// Mute and unmute: a ramp short enough to feel at once, long enough not
  /// to click.
  static const mute = Duration(milliseconds: 60);

  /// A volume change.
  static const volume = Duration(milliseconds: 40);

  /// A voice cut short (a third variant asked for mid-crossfade): just long
  /// enough not to click.
  static const declick = Duration(milliseconds: 15);

  /// The longest cue a look may have: the output stays awake this long
  /// after one (a longer cue would be cut by [idle]).
  static const longestCue = Duration(seconds: 3);

  /// How long the output runs with nothing that can sound (no theme wanted)
  /// before it is suspended, to spare the battery: the theme's fade out and
  /// the longest cue ([themeOut] + [longestCue]).
  static const idle = Duration(milliseconds: 4200);

  /// How far ahead a theme variant is scheduled, so it starts on an exact
  /// sample of the audio clock and lands in phase. The theme only: a cue
  /// starts at once.
  static const lead = Duration(milliseconds: 20);

  /// [d] in seconds, as the audio clock counts.
  static double seconds(Duration d) =>
      d.inMicroseconds / Duration.microsecondsPerSecond;
}

/// The state of the platform's audio output, as Web Audio names it:
/// `interrupted` is Safari's (a call, another app took the output).
enum AudioState { running, suspended, interrupted, closed }

/// A decoded sound the backend holds (on the web an `AudioBuffer`, kept in
/// the browser: its samples never pass through Dart).
final class Clip {
  Clip(this.native, this.seconds);

  final Object native;

  /// Its length in seconds.
  final double seconds;
}

/// A looping theme variant playing through its own gain.
final class Voice {
  Voice(this.native, this.variant);

  final Object native;
  final ThemeVariant variant;
}

/// The thin layer between [SoundEngine]'s logic and a platform's audio: on
/// the web, Web Audio (`web_audio_backend.dart`); elsewhere silence
/// (`silent_backend.dart`). Every call is quick and synchronous except the
/// futures, which the engine never awaits on a tap's path.
abstract interface class AudioBackend {
  /// Whether the output exists. Nothing creates it before [open].
  bool get isOpen;

  /// Creates the output and its master gain at [gain]. Called only from a
  /// gesture that is a user activation (browsers start sound only there; a
  /// context made outside one starts suspended).
  void open(double gain);

  /// Forgets a closed output and its master gain, so the next [open] makes
  /// a new one.
  void discard();

  AudioState get state;

  /// The audio clock, in seconds (frozen while suspended).
  double get now;

  /// What the output adds between the clock and the speaker's buffer, in
  /// seconds (0 when the platform does not say).
  double get baseLatency;

  /// Asks the output to run. Cheap and idempotent; outside a user
  /// activation a browser may leave it pending until one.
  Future<void> resume();

  Future<void> suspend();

  /// Whether this platform decodes [path]'s encoding (by its extension).
  bool canDecode(String path);

  /// Fetches [path]'s bytes ahead, with no output needed (kept on the
  /// platform side for [decode]).
  Future<void> fetch(String path);

  /// Decodes [path] (after [open]).
  Future<Clip> decode(String path);

  /// Forgets a decoded clip.
  void release(Clip clip);

  /// Ramps the master gain to [to] over [seconds].
  void master(double to, double seconds);

  /// Starts [clip] now, once, through the master gain.
  void fire(Clip clip);

  /// Starts [clip] looping at audio time [at], [offset] seconds into it,
  /// through a new gain at zero, ramped to one over [fadeIn] seconds.
  Voice loop(
    Clip clip,
    ThemeVariant variant, {
    required double at,
    required double offset,
    required double fadeIn,
    LoopPoints? points,
  });

  /// Ramps [voice] to silence over [seconds] from audio time [at] (now when
  /// null), then stops and releases it, and calls [ended] once it has
  /// stopped. A crossfade gives both ramps the same [at], so the two gains
  /// always sum to one. A later call on the same voice replaces an earlier
  /// one (the last `stop()` wins, as in Web Audio).
  void fadeOut(
    Voice voice,
    double seconds, {
    double? at,
    void Function()? ended,
  });

  /// Calls [gesture] on every user gesture (a cheap listener for the life of
  /// the page), with whether it is a user activation (a touch's pointerdown
  /// is not; its pointerup, touchend and click are, as are a key and a
  /// mouse's press), and [visible] when the page or app is hidden or shown.
  void listen({
    required void Function(bool activates) gesture,
    required void Function(bool shown) visible,
  });
}
