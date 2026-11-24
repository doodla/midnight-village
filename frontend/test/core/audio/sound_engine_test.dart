import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/audio/audio_backend.dart';
import 'package:midnight_village/core/audio/sound_engine.dart';
import 'package:midnight_village/core/audio/sound_set.dart';

import 'fake_audio_backend.dart';

// The engine's logic over a fake backend (`docs/design/feel.md`, section 6).
// Time is the fake's audio clock, moved by hand; fake_async flushes the
// decodes and resumes, so nothing here sleeps.

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

void main() {
  test('an empty catalogue does nothing at all: no listener, no output', () {
    final backend = FakeAudioBackend();
    final engine = SoundEngine(backend, SoundSet.empty)
      ..start()
      ..gesture()
      ..theme(ThemeVariant.night)
      ..play(knock);
    expect(engine.playing, isNull);
    expect(backend.gesture, isNull);
    expect(backend.opens, 0);
    expect(backend.fetches, isEmpty);
  });

  test('nothing is opened before the first gesture; the cues are fetched '
      'ahead, not decoded', () {
    final backend = FakeAudioBackend();
    started(backend).$1.theme(ThemeVariant.table);
    expect(backend.opens, 0);
    expect(backend.fetches, [knockFile]);
    expect(backend.decodes, isEmpty);
  });

  test('a cue before the unlock is dropped; the theme asked for before it '
      'starts on it', () {
    fakeAsync((async) {
      final backend = FakeAudioBackend();
      final (engine, _) = started(backend);
      engine
        ..play(knock)
        ..theme(ThemeVariant.table);
      async.flushMicrotasks();
      expect(backend.fired, isEmpty);
      expect(backend.loops, isEmpty);

      backend.gesture!();
      async.flushMicrotasks();
      expect(backend.opens, 1);
      expect(engine.playing, ThemeVariant.table);
      expect(backend.loops.single.offset, 0);
      expect(backend.fired, isEmpty, reason: 'the early cue is gone');

      engine.play(knock);
      expect(backend.fired, [knockFile]);
    });
  });

  test('a cue fires in the same call as the tap, with nothing awaited', () {
    fakeAsync((async) {
      final backend = FakeAudioBackend();
      final (engine, _) = started(backend);
      backend.gesture!();
      async.flushMicrotasks();
      engine.play(knock);
      // No microtask flushed: it fired synchronously.
      expect(backend.fired, [knockFile]);
    });
  });

  test('a switch starts the new variant where the music is and crossfades', () {
    fakeAsync((async) {
      final backend = FakeAudioBackend(lengths: {tableFile: 4, nightFile: 4});
      final (engine, _) = started(backend);
      backend.gesture!();
      engine.theme(ThemeVariant.table);
      async.flushMicrotasks();
      final table = backend.loops.single;
      expect(table.at, lead);

      // 7.3 s later the table variant is 3.3 s into its second round.
      backend.clock = 7.3;
      engine.theme(ThemeVariant.night);
      async.flushMicrotasks();
      final night = backend.loops.last;
      expect(night.variant, ThemeVariant.night);
      expect(night.at, closeTo(7.3 + lead, 1e-9));
      expect(night.offset, closeTo((7.3 + lead - table.at) % 4, 1e-9));
      expect(night.fadeIn, crossfade);
      expect(table.fadedAt, 7.3);
      expect(table.fadeLength, crossfade);
      expect(engine.voices, 2);

      backend.clock = 7.3 + lead + crossfade + 0.01;
      expect(engine.voices, 1, reason: 'the old variant is stopped');
      expect(backend.soundingLoops(), [night]);
    });
  });

  test('asking for the variant already playing does nothing', () {
    fakeAsync((async) {
      final backend = FakeAudioBackend();
      final (engine, _) = started(backend);
      backend.gesture!();
      engine.theme(ThemeVariant.table);
      async.flushMicrotasks();
      backend.clock = 3;
      engine.theme(ThemeVariant.table);
      async.flushMicrotasks();
      expect(backend.loops, hasLength(1));
      expect(backend.loops.single.fadedAt, isNull);
      expect(backend.decodes.where((p) => p == tableFile), hasLength(1));
    });
  });

  test('a variant not decoded yet keeps the music going and switches, in '
      'phase, when it is ready', () {
    fakeAsync((async) {
      final backend = FakeAudioBackend(decodeAtOnce: false);
      final (engine, _) = started(backend);
      backend.gesture!();
      engine.theme(ThemeVariant.table);
      backend.finishDecode(tableFile);
      async.flushMicrotasks();
      final table = backend.loops.single;

      backend.clock = 2;
      engine.theme(ThemeVariant.night);
      async.flushMicrotasks();
      expect(engine.playing, ThemeVariant.table, reason: 'not ready: no gap');
      expect(table.fadedAt, isNull);

      backend.clock = 9.5;
      backend.finishDecode(nightFile);
      async.flushMicrotasks();
      final night = backend.loops.last;
      expect(engine.playing, ThemeVariant.night);
      expect(night.offset, closeTo((9.5 + lead - table.at) % 4, 1e-9));
      expect(table.fadedAt, 9.5);
    });
  });

  test('a variant that fails to decode is logged and the music goes on', () {
    fakeAsync((async) {
      final backend = FakeAudioBackend(decodeAtOnce: false);
      final (engine, log) = started(backend);
      backend.gesture!();
      engine.theme(ThemeVariant.table);
      backend.finishDecode(tableFile);
      async.flushMicrotasks();
      engine.theme(ThemeVariant.night);
      backend.failDecode(nightFile);
      async.flushMicrotasks();
      expect(engine.playing, ThemeVariant.table);
      expect(log.single, contains(nightFile));
    });
  });

  test('at most two variants sound: a third cuts the one fading out', () {
    fakeAsync((async) {
      final backend = FakeAudioBackend();
      final (engine, _) = started(backend);
      backend.gesture!();
      engine.theme(ThemeVariant.table);
      async.flushMicrotasks();
      backend.clock = 5;
      engine.theme(ThemeVariant.night);
      async.flushMicrotasks();
      backend.clock = 5.5;
      engine.theme(ThemeVariant.vote);
      async.flushMicrotasks();
      final [table, night, vote] = backend.loops;
      expect(table.fadeLength, SoundTiming.seconds(SoundTiming.declick));
      expect(night.fadeLength, crossfade);
      expect(vote.variant, ThemeVariant.vote);
      backend.clock = 5.5 + SoundTiming.seconds(SoundTiming.declick) + 0.001;
      expect(backend.soundingLoops(), [night, vote]);
      expect(engine.voices, 2);
    });
  });

  test('only the two most recent variants stay decoded', () {
    fakeAsync((async) {
      final backend = FakeAudioBackend();
      final (engine, _) = started(backend);
      backend.gesture!();
      for (final (t, v) in [
        (0.0, ThemeVariant.table),
        (5.0, ThemeVariant.night),
        (10.0, ThemeVariant.vote),
      ]) {
        backend.clock = t;
        engine.theme(v);
        async.flushMicrotasks();
      }
      expect(backend.released, [tableFile]);
    });
  });

  test('no theme fades the music out and the next one starts afresh', () {
    fakeAsync((async) {
      final backend = FakeAudioBackend();
      final (engine, _) = started(backend);
      backend.gesture!();
      engine.theme(ThemeVariant.table);
      async.flushMicrotasks();
      backend.clock = 6;
      engine.theme(null);
      expect(
        backend.loops.single.fadeLength,
        SoundTiming.seconds(SoundTiming.themeOut),
      );
      expect(engine.playing, isNull);
      backend.clock = 20;
      engine.theme(ThemeVariant.night);
      async.flushMicrotasks();
      expect(backend.loops.last.offset, 0);
    });
  });

  test('loop points carry to the source and set the phase', () {
    fakeAsync((async) {
      final points = LoopPoints.samples(48000, 240000, rate: 48000);
      final backend = FakeAudioBackend(lengths: {tableFile: 6, nightFile: 6});
      final sounds = SoundSet(
        theme: {
          ThemeVariant.table: SoundFile([tableFile], loop: points),
          ThemeVariant.night: SoundFile([nightFile], loop: points),
        },
      );
      final (engine, _) = started(backend, sounds: sounds);
      backend.gesture!();
      engine.theme(ThemeVariant.table);
      async.flushMicrotasks();
      expect(backend.loops.single.points, points);
      backend.clock = 9;
      engine.theme(ThemeVariant.night);
      async.flushMicrotasks();
      // 9 s in: the intro (1 s) once, then a 4 s loop from 1 s: 1 + 8 % 4.
      expect(backend.loops.last.offset, closeTo(1, 1e-9));
    });
  });

  test('the first encoding this platform decodes is the one used', () {
    fakeAsync((async) {
      const ogg = 'assets/sounds/knock.ogg';
      const m4a = 'assets/sounds/knock.m4a';
      final backend = FakeAudioBackend()..undecodable.add(ogg);
      final (engine, _) = started(
        backend,
        sounds: const SoundSet(
          cues: {
            knock: SoundFile([ogg, m4a]),
          },
        ),
      );
      backend.gesture!();
      async.flushMicrotasks();
      engine.play(knock);
      expect(backend.fired, [m4a]);
    });
  });

  group('the page hidden and shown', () {
    test('hidden suspends and drops cues; shown resumes the loop', () {
      fakeAsync((async) {
        final backend = FakeAudioBackend();
        final (engine, _) = started(backend);
        backend.gesture!();
        engine.theme(ThemeVariant.table);
        async.flushMicrotasks();
        backend.visible!(false);
        async.flushMicrotasks();
        expect(backend.suspends, 1);
        engine.play(knock);
        expect(backend.fired, isEmpty);

        backend.visible!(true);
        async.flushMicrotasks();
        expect(backend.state, AudioState.running);
        expect(backend.loops.single.fadedAt, isNull, reason: 'same loop');
        engine.play(knock);
        expect(backend.fired, [knockFile]);
      });
    });

    test('a gesture while hidden opens nothing', () {
      final backend = FakeAudioBackend();
      started(backend);
      backend.visible!(false);
      backend.gesture!();
      expect(backend.opens, 0);
    });
  });

  group('Chrome on Android suspending on its own', () {
    test('the next gesture resumes a context that stopped running', () {
      fakeAsync((async) {
        final backend = FakeAudioBackend();
        final (engine, _) = started(backend);
        backend.gesture!();
        async.flushMicrotasks();
        expect(backend.resumes, 1);
        backend.current = AudioState.suspended;
        backend.gesture!();
        async.flushMicrotasks();
        expect(backend.resumes, 2);
        expect(backend.state, AudioState.running);
        engine.play(knock);
        expect(backend.fired, [knockFile]);
        backend.gesture!();
        expect(backend.resumes, 2, reason: 'running: nothing to do');
      });
    });

    test('a refused or failing resume never reaches the tap', () {
      fakeAsync((async) {
        final backend = FakeAudioBackend()
          ..resumeError = StateError('not allowed');
        final (engine, log) = started(backend);
        expect(() => backend.gesture!(), returnsNormally);
        async.flushMicrotasks();
        expect(log.single, contains('refused'));
        engine.play(knock);
        expect(backend.fired, isEmpty, reason: 'not running: dropped');

        backend.resumeThrowsAtOnce = true;
        expect(() => backend.gesture!(), returnsNormally);
        expect(() => backend.visible!(true), returnsNormally);
        async.flushMicrotasks();
        expect(log.last, contains('resume failed'));

        backend
          ..resumeThrowsAtOnce = false
          ..resumeError = null;
        backend.gesture!();
        async.flushMicrotasks();
        engine.play(knock);
        expect(backend.fired, [knockFile], reason: 'a later tap unlocks');
      });
    });
  });

  group('mute and volume', () {
    test('muted from the start decodes nothing; unmuted, the wanted theme '
        'and the cues come', () {
      fakeAsync((async) {
        final backend = FakeAudioBackend();
        final (engine, _) = started(backend, muted: true);
        engine.theme(ThemeVariant.night);
        backend.gesture!();
        async.flushMicrotasks();
        expect(backend.masterGain, 0);
        expect(backend.decodes, isEmpty);
        expect(backend.fetches, isEmpty);
        engine.play(knock);
        expect(backend.fired, isEmpty);

        engine.setMuted(false);
        async.flushMicrotasks();
        expect(backend.masterRamps.last, (
          1.0,
          SoundTiming.seconds(SoundTiming.mute),
        ));
        expect(engine.playing, ThemeVariant.night);
        engine.play(knock);
        expect(backend.fired, [knockFile]);
      });
    });

    test('muting ramps the master to 0 and stops the theme', () {
      fakeAsync((async) {
        final backend = FakeAudioBackend();
        final (engine, _) = started(backend);
        backend.gesture!();
        engine.theme(ThemeVariant.table);
        async.flushMicrotasks();
        engine.setMuted(true);
        final ramp = SoundTiming.seconds(SoundTiming.mute);
        expect(backend.masterRamps.last, (0.0, ramp));
        expect(backend.loops.single.fadeLength, ramp);
        expect(engine.wanted, ThemeVariant.table, reason: 'still wanted');
      });
    });

    test('the volume ramps the master, clamped to 0..1', () {
      final backend = FakeAudioBackend();
      final (engine, _) = started(backend);
      backend.gesture!();
      engine.setVolume(0.4);
      expect(backend.masterGain, 0.4);
      engine.setVolume(3);
      expect(engine.volume, 1);
    });
  });

  test('a backend that throws everywhere is swallowed and logged', () {
    fakeAsync((async) {
      final backend = FakeAudioBackend()..everything = StateError('broken');
      final (engine, log) = started(backend);
      expect(() {
        engine
          ..gesture()
          ..theme(ThemeVariant.table)
          ..play(knock)
          ..visible(false)
          ..visible(true)
          ..setMuted(true)
          ..setMuted(false)
          ..setVolume(0.5);
      }, returnsNormally);
      async.flushMicrotasks();
      expect(log, isNotEmpty);
      expect(log, everyElement(contains('broken')));
    });
  });

  test('loopPosition: an intro once, then the loop; whole file by default', () {
    expect(loopPosition(5, 4, null), 1);
    expect(loopPosition(3, 4, null), 3);
    const points = LoopPoints.seconds(1, 3);
    expect(loopPosition(0.5, 4, points), 0.5);
    expect(loopPosition(3.5, 4, points), 1.5);
    expect(loopPosition(-1, 4, points), 0);
    // Points outside the file fall back to the whole file.
    expect(loopPosition(5, 4, const LoopPoints.seconds(0, 9)), 1);
  });
}
