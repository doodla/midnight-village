import 'package:midnight_village/core/audio/audio_backend.dart';
import 'package:midnight_village/core/audio/sound_engine.dart';
import 'package:midnight_village/core/audio/sound_set.dart';

import 'fake_audio_backend.dart';

// What the engine's tests share: a set of one cue and three theme variants,
// and an engine started over a fake backend with a log the test reads.

const knock = Sfx('knock');
const tableFile = 'assets/sounds/theme_table.ogg';
const nightFile = 'assets/sounds/theme_night.ogg';
const voteFile = 'assets/sounds/theme_vote.ogg';
const knockFile = 'assets/sounds/knock.ogg';

const set = SoundSet(
  cues: {
    knock: SoundFile([knockFile]),
  },
  theme: {
    ThemeVariant.table: SoundFile([tableFile]),
    ThemeVariant.night: SoundFile([nightFile]),
    ThemeVariant.vote: SoundFile([voteFile]),
  },
);

final lead = SoundTiming.seconds(SoundTiming.lead);
final crossfade = SoundTiming.seconds(SoundTiming.crossfade);

/// An engine started over [backend], with a log the test reads.
(SoundEngine, List<String>) started(
  FakeAudioBackend backend, {
  SoundSet sounds = set,
  bool muted = false,
}) {
  final log = <String>[];
  final engine = SoundEngine(backend, sounds, log: log.add, muted: muted)
    ..start();
  return (engine, log);
}
