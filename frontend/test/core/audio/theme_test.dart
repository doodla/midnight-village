import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/audio/audio_backend.dart';
import 'package:midnight_village/core/audio/sound_set.dart';

import 'engine_fixture.dart';
import 'fake_audio_backend.dart';

// The theme over the fake backend: in phase, crossfaded, at most two voices
// and two decoded variants, one decode at a time.

void main() {
  test('a switch starts the new variant where the music is and crossfades', () {
    fakeAsync((async) {
      final backend = FakeAudioBackend(lengths: {tableFile: 4, nightFile: 4});
      final (engine, _) = started(backend);
      backend.tap();
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
      expect(table.fadedAt, closeTo(7.3 + lead, 1e-9), reason: 'with the new');
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
      backend.tap();
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
      backend.tap();
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
      expect(table.fadedAt, closeTo(9.5 + lead, 1e-9));
    });
  });

  test('a variant that fails to decode is logged and the music goes on', () {
    fakeAsync((async) {
      final backend = FakeAudioBackend(decodeAtOnce: false);
      final (engine, log) = started(backend);
      backend.tap();
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

  test('a variant whose decode failed is not tried again this visit', () {
    fakeAsync((async) {
      final backend = FakeAudioBackend(decodeAtOnce: false);
      final (engine, log) = started(backend);
      backend.tap();
      engine.theme(ThemeVariant.table);
      backend.failDecode(tableFile);
      async.flushMicrotasks();
      for (final v in [null, ThemeVariant.table, null, ThemeVariant.table]) {
        engine.theme(v);
        async.flushMicrotasks();
      }
      expect(backend.decodes.where((p) => p == tableFile), hasLength(1));
      expect(log.where((l) => l.contains(tableFile)), hasLength(1));
      expect(engine.playing, isNull);
    });
  });

  test('the theme fading out is never cut short by a later ask: a touch '
      'or an unmute while it fades leaves it to end', () {
    fakeAsync((async) {
      final backend = FakeAudioBackend();
      final (engine, _) = started(backend);
      backend.tap();
      engine.theme(ThemeVariant.table);
      async.flushMicrotasks();
      backend.advance(3);
      engine.theme(null);
      backend.current = AudioState.suspended;
      backend.tap();
      engine
        ..setMuted(true)
        ..setMuted(false);
      async.flushMicrotasks();
      expect(
        backend.loops.single.fadeLength,
        SoundTiming.seconds(SoundTiming.themeOut),
      );
    });
  });

  test('a cut voice is silent before the new one starts', () {
    expect(SoundTiming.declick, lessThan(SoundTiming.lead));
  });

  test('the start is scheduled from the clock at the start call, with a '
      'lead of at least the output\'s base latency, and stays in phase', () {
    fakeAsync((async) {
      final backend = FakeAudioBackend()..baseLatency = 0.08;
      final (engine, _) = started(backend);
      backend.tap();
      engine.theme(ThemeVariant.table);
      async.flushMicrotasks();
      backend.advance(5);
      engine.theme(ThemeVariant.night);
      async.flushMicrotasks();
      backend.advance(0.4);
      // Time passes while the switch cuts the voice fading out.
      backend.slowCalls = 0.05;
      engine.theme(ThemeVariant.table);
      async.flushMicrotasks();
      final table = backend.loops.first;
      for (final l in backend.loops) {
        expect(l.at - l.calledAt, closeTo(0.08, 1e-9));
        expect(l.offset, closeTo((l.at - table.at) % 4, 1e-9));
      }
    });
  });

  int themesHeld(FakeAudioBackend b) =>
      b.held.where((p) => p != knockFile).length;

  test('table, night, vote in quick succession: never three variants '
      'decoded, never three voices; the vote comes once the outgoing ends', () {
    fakeAsync((async) {
      final backend = FakeAudioBackend();
      final (engine, _) = started(backend);
      backend.tap();
      void check() {
        async.flushMicrotasks();
        expect(themesHeld(backend), lessThanOrEqualTo(2));
        expect(backend.soundingLoops().length, lessThanOrEqualTo(2));
        expect(engine.voices, lessThanOrEqualTo(2));
      }

      engine.theme(ThemeVariant.table);
      check();
      backend.advance(5);
      engine.theme(ThemeVariant.night);
      check();
      backend.advance(0.3);
      engine.theme(ThemeVariant.vote);
      check();
      expect(engine.playing, ThemeVariant.night, reason: 'the music goes on');
      expect(backend.decodes, isNot(contains(voteFile)));
      // The table voice ends when the crossfade is over: then the vote.
      for (var i = 0; i < 20; i++) {
        backend.advance(0.1);
        check();
      }
      expect(engine.playing, ThemeVariant.vote);
      expect(backend.released, [tableFile]);
      final [table, night, vote] = backend.loops;
      expect(table.hasEnded, isTrue);
      expect(night.fadeLength, crossfade);
      expect(vote.offset, closeTo((vote.at - table.at) % 4, 1e-9));
    });
  });

  test('a third variant already decoded, asked mid-crossfade, cuts the one '
      'fading out and starts at once', () {
    fakeAsync((async) {
      final backend = FakeAudioBackend();
      final (engine, _) = started(backend);
      backend.tap();
      engine.theme(ThemeVariant.table);
      async.flushMicrotasks();
      backend.advance(5);
      engine.theme(ThemeVariant.night);
      async.flushMicrotasks();
      backend.advance(0.5);
      engine.theme(ThemeVariant.table);
      async.flushMicrotasks();
      final [oldTable, night, table] = backend.loops;
      expect(oldTable.fadeLength, SoundTiming.seconds(SoundTiming.declick));
      expect(night.fadeLength, crossfade);
      expect(table.variant, ThemeVariant.table);
      expect(backend.decodes.where((p) => p == tableFile), hasLength(1));
      backend.advance(lead + 0.001);
      expect(backend.soundingLoops(), [night, table]);
      expect(engine.voices, 2);
    });
  });

  test('fast stage changes: one theme decode at a time, only of what is '
      'wanted; one finished and no longer wanted is released at once', () {
    fakeAsync((async) {
      final backend = FakeAudioBackend(decodeAtOnce: false);
      final (engine, _) = started(backend);
      backend.tap();
      async.flushMicrotasks();
      for (final v in [
        ThemeVariant.table,
        ThemeVariant.night,
        ThemeVariant.vote,
        ThemeVariant.night,
      ]) {
        engine.theme(v);
        async.flushMicrotasks();
        expect(backend.decoding.where((p) => p != knockFile), hasLength(1));
      }
      expect(backend.decodes.where((p) => p != knockFile), [tableFile]);
      backend.finishDecode(tableFile);
      async.flushMicrotasks();
      expect(backend.released, [tableFile], reason: 'not wanted any more');
      expect(backend.decoding.where((p) => p != knockFile), [
        nightFile,
      ], reason: 'only the one wanted');
      backend.finishDecode(nightFile);
      async.flushMicrotasks();
      expect(engine.playing, ThemeVariant.night);
      expect(backend.decodes, isNot(contains(voteFile)));
      expect(themesHeld(backend), 1);
    });
  });

  test(
    'the two most recent variants stay decoded, so going back is at once',
    () {
      fakeAsync((async) {
        final backend = FakeAudioBackend();
        final (engine, _) = started(backend);
        backend.tap();
        for (final v in [
          ThemeVariant.table,
          ThemeVariant.night,
          ThemeVariant.vote,
          ThemeVariant.night,
        ]) {
          engine.theme(v);
          async.flushMicrotasks();
          backend.advance(5);
        }
        expect(backend.released, [tableFile]);
        expect(backend.decodes.where((p) => p == nightFile), hasLength(1));
        expect(themesHeld(backend), 2);
      });
    },
  );

  test('no theme fades the music out and the next one starts afresh', () {
    fakeAsync((async) {
      final backend = FakeAudioBackend();
      final (engine, _) = started(backend);
      backend.tap();
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
      backend.tap();
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
}
