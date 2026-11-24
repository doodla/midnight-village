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

  /// How far ahead a theme variant is scheduled, so it starts on an exact
  /// sample of the audio clock and lands in phase. The theme only: a cue
  /// starts at once.
  static const lead = Duration(milliseconds: 20);

  /// [d] in seconds, as the audio clock counts.
  static double seconds(Duration d) =>
      d.inMicroseconds / Duration.microsecondsPerSecond;
}

/// The state of the platform's audio output.
enum AudioState { running, suspended, closed }

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

  /// Creates the output and its master gain at [gain]. Called inside a
  /// user's gesture, where browsers allow sound.
  void open(double gain);

  AudioState get state;

  /// The audio clock, in seconds (frozen while suspended).
  double get now;

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

  /// Ramps [voice] to silence over [seconds] and then stops and releases it.
  void fadeOut(Voice voice, double seconds);

  /// Calls [gesture] on every user gesture (a cheap listener for the life of
  /// the page) and [visible] when the page or app is hidden or shown.
  void listen({
    required void Function() gesture,
    required void Function(bool shown) visible,
  });
}
