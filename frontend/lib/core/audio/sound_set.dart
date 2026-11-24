/// The game's sounds as data (`docs/design/feel.md`, section 6): which cue
/// and which piece of the theme is which file. Nothing here plays; the
/// engine (`sound_engine.dart`) reads it. Pure Dart, so the engine and its
/// tests need no Flutter.
library;

/// A short sound fired by a touch or a moment (a knock, a seal). Screens name
/// one as `Sfx.knock` once it exists; none is chosen yet. Const, so it can
/// key a const [SoundSet]; the engine finds one made at run time by its
/// [name].
final class Sfx {
  const Sfx(this.name);

  final String name;

  @override
  String toString() => 'Sfx($name)';
}

/// One stage's version of the theme. The variants are the same piece in
/// the same length (stems of one mix), so switching keeps the music in
/// phase. These are the stages a screen may ask for; which ones have a file
/// is the [SoundSet]'s business (data, not code).
enum ThemeVariant {
  /// The lobby and the table (01 to 03, and between games).
  table,

  /// The deal to the last night window (04 to 06).
  night,

  /// The talk and the vote (08, 09).
  vote,

  /// The count and the results (10, 11).
  reveal,
}

/// One sound in the bundle, as one or more encodings of the same audio, in
/// order of preference (`.ogg` before `.m4a`, say): the engine takes the
/// first the platform can decode.
final class SoundFile {
  const SoundFile(this.paths, {this.loop});

  /// Asset paths as listed in `pubspec.yaml` (`assets/sounds/...`).
  final List<String> paths;

  /// Where a theme variant loops, when it is not the whole file (an
  /// encoder's padding, an intro played once).
  final LoopPoints? loop;
}

/// The stretch of a file that repeats. From the WAV master's loop points in
/// samples (with the master's rate, since a decoded file is resampled to the
/// device's rate) or in seconds.
final class LoopPoints {
  const LoopPoints.seconds(this.start, this.end);

  LoopPoints.samples(int startSample, int endSample, {required int rate})
    : start = startSample / rate,
      end = endSample / rate;

  /// Seconds from the file's start.
  final double start;
  final double end;
}

/// Every cue and theme variant of a look, by name. Empty today: the owner is
/// choosing them by ear (24 November 2026).
final class SoundSet {
  const SoundSet({this.cues = const {}, this.theme = const {}});

  static const empty = SoundSet();

  final Map<Sfx, SoundFile> cues;
  final Map<ThemeVariant, SoundFile> theme;

  bool get isEmpty => cues.isEmpty && theme.isEmpty;

  /// Every asset path named, for the bundle check.
  Iterable<String> get paths => [
    for (final file in [...cues.values, ...theme.values]) ...file.paths,
  ];
}

/// Where a variant's playhead is after [elapsed] seconds of the theme, for a
/// file of [duration] seconds looping over [loop] (the whole file when null):
/// the intro before the loop plays once, then the loop repeats.
double loopPosition(double elapsed, double duration, LoopPoints? loop) {
  final end = switch (loop?.end) {
    final e? when e > 0 && e <= duration => e,
    _ => duration,
  };
  final start = switch (loop?.start) {
    final s? when s >= 0 && s < end => s,
    _ => 0.0,
  };
  if (elapsed < 0) return 0;
  if (elapsed < end) return elapsed;
  final span = end - start;
  if (span <= 0) return start;
  return start + (elapsed - start) % span;
}
