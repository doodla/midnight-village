import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/audio/audio_backend.dart';
import 'package:midnight_village/core/audio/sound_engine.dart';
import 'package:midnight_village/core/audio/sound_set.dart';

import 'engine_fixture.dart';
import 'fake_audio_backend.dart';

// The engine's logic over a fake backend that follows Web Audio's rules
// (`docs/design/feel.md`, section 6): the unlock, cues, the page hidden,
// mute. The theme is `theme_test.dart`. Time is the fake's audio clock,
// moved by hand; fake_async flushes the decodes and resumes, so nothing
// here sleeps.

void main() {
  test('an empty catalogue does nothing at all: no listener, no output', () {
    final backend = FakeAudioBackend();
    final engine = SoundEngine(backend, SoundSet.empty)
      ..start()
      ..gesture(activates: true)
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

      backend.tap();
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
      backend.tap();
      async.flushMicrotasks();
      engine.play(knock);
      // No microtask flushed: it fired synchronously.
      expect(backend.fired, [knockFile]);
      // One made at run time is the same cue.
      engine.play(Sfx(['kn', 'ock'].join()));
      expect(backend.fired, [knockFile, knockFile]);
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
      backend.tap();
      async.flushMicrotasks();
      engine.play(knock);
      expect(backend.fired, [m4a]);
    });
  });

  group('cues never pile up and burst late', () {
    test('a cue while the output is stopped and no activation asked it to '
        'run is dropped, not started into it', () {
      fakeAsync((async) {
        final backend = FakeAudioBackend();
        final (engine, _) = started(backend);
        backend.tap();
        async.flushMicrotasks();
        backend.current = AudioState.suspended;
        // A pointerdown asks for a resume that stays pending.
        backend.send(activates: false);
        for (var i = 0; i < 5; i++) {
          engine.play(knock);
        }
        async.elapse(Duration.zero);
        expect(backend.fired, isEmpty);
        // The pointerup runs it: nothing stored bursts out.
        backend.send(activates: true);
        async.flushMicrotasks();
        expect(backend.state, AudioState.running);
        expect(backend.fired, isEmpty);
        expect(backend.lateCues, isEmpty);
      });
    });

    test('the cue of the very gesture that asked for the resume plays, '
        'from a later listener of the same event too', () {
      fakeAsync((async) {
        final backend = FakeAudioBackend();
        final (engine, _) = started(backend);
        backend.tap();
        async.flushMicrotasks();
        backend.current = AudioState.suspended;
        backend.send(activates: true);
        // The browser runs the microtasks between the engine's listener and
        // the app's: the cue still belongs to this gesture.
        async.flushMicrotasks();
        engine.play(knock);
        expect(backend.fired, [knockFile]);
        expect(backend.lateCues, isEmpty);
      });
    });

    test('the allowance ends with the gesture: a cue on the next task while '
        'still stopped is dropped', () {
      fakeAsync((async) {
        final backend = FakeAudioBackend();
        final (engine, _) = started(backend);
        backend.tap();
        async.flushMicrotasks();
        backend
          ..current = AudioState.suspended
          ..resumeError = StateError('not allowed');
        backend.send(activates: true);
        async.elapse(Duration.zero);
        engine.play(knock);
        expect(backend.fired, isEmpty);
      });
    });
  });

  group('the page hidden and shown', () {
    test('hidden suspends and drops cues; shown resumes the same loop', () {
      fakeAsync((async) {
        final backend = FakeAudioBackend()..resumeNeedsGesture = false;
        final (engine, _) = started(backend);
        backend.tap();
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

    test('quick hidden, shown, hidden, shown: the last one wins, and a '
        'resume left pending is no gate on the next touch', () {
      fakeAsync((async) {
        final backend = FakeAudioBackend();
        final (engine, _) = started(backend);
        backend.tap();
        engine.theme(ThemeVariant.table);
        async.flushMicrotasks();
        for (final shown in [false, true, false, true]) {
          backend.visible!(shown);
        }
        async.flushMicrotasks();
        // Shown outside a gesture: the resume waits for an activation.
        expect(backend.state, AudioState.suspended);
        backend.touch();
        async.flushMicrotasks();
        expect(backend.state, AudioState.running);
        engine.play(knock);
        expect(backend.fired, [knockFile]);
      });
    });

    test('a gesture while hidden opens nothing', () {
      final backend = FakeAudioBackend();
      started(backend);
      backend.visible!(false);
      backend.tap();
      expect(backend.opens, 0);
    });
  });

  group('the first touch on Android', () {
    test('pointerdown is no activation: nothing is opened on it; the '
        'pointerup that follows opens a running output', () {
      fakeAsync((async) {
        final backend = FakeAudioBackend();
        final (engine, _) = started(backend);
        backend.send(activates: false);
        expect(backend.opens, 0, reason: 'not on pointerdown');
        backend.send(activates: true);
        async.flushMicrotasks();
        expect(backend.opens, 1);
        expect(backend.state, AudioState.running);
        engine.play(knock);
        expect(backend.fired, [knockFile]);
      });
    });

    test('a resume left pending by a pointerdown does not lock the later '
        'gestures out: each asks again, and the activating one runs it', () {
      fakeAsync((async) {
        final backend = FakeAudioBackend();
        final (engine, _) = started(backend);
        backend.tap();
        async.flushMicrotasks();
        // Chrome on Android suspends it on its own.
        backend.current = AudioState.suspended;
        backend.send(activates: false);
        async.flushMicrotasks();
        expect(backend.state, AudioState.suspended, reason: 'still pending');
        backend.send(activates: false);
        expect(backend.resumes, 2, reason: 'asked again, no gate');
        backend.send(activates: true);
        async.flushMicrotasks();
        expect(backend.state, AudioState.running);
        engine.play(knock);
        expect(backend.fired, [knockFile]);
        backend.tap();
        expect(backend.resumes, 3, reason: 'running: nothing to do');
      });
    });

    test('a refused or failing resume never reaches the tap', () {
      fakeAsync((async) {
        final backend = FakeAudioBackend();
        final (engine, log) = started(backend);
        backend.tap();
        async.flushMicrotasks();
        backend
          ..current = AudioState.suspended
          ..resumeError = StateError('not allowed');
        expect(backend.tap, returnsNormally);
        async.elapse(Duration.zero);
        expect(log.single, contains('refused'));
        engine.play(knock);
        expect(backend.fired, isEmpty, reason: 'not running: dropped');

        backend.resumeThrowsAtOnce = true;
        expect(backend.tap, returnsNormally);
        expect(() => backend.visible!(true), returnsNormally);
        async.flushMicrotasks();
        expect(log.last, contains('resume failed'));

        backend
          ..resumeThrowsAtOnce = false
          ..resumeError = null;
        backend.tap();
        async.flushMicrotasks();
        engine.play(knock);
        expect(backend.fired, [knockFile], reason: 'a later tap unlocks');
      });
    });
  });

  group('mute and volume', () {
    test('muted from the start opens and decodes nothing; unmuted, the next '
        'touch opens it and the wanted theme and the cues come', () {
      fakeAsync((async) {
        final backend = FakeAudioBackend();
        final (engine, _) = started(backend, muted: true);
        engine.theme(ThemeVariant.night);
        backend.touch();
        async.flushMicrotasks();
        expect(backend.opens, 0, reason: 'never opened while muted');
        expect(backend.decodes, isEmpty);
        expect(backend.fetches, isEmpty);
        engine.play(knock);
        expect(backend.fired, isEmpty);

        engine.setMuted(false);
        async.flushMicrotasks();
        expect(backend.opens, 0, reason: 'outside a gesture');
        backend.touch();
        async.flushMicrotasks();
        expect(backend.masterGain, 1);
        expect(engine.playing, ThemeVariant.night);
        engine.play(knock);
        expect(backend.fired, [knockFile]);
      });
    });

    test('unmuting an open output ramps the master back', () {
      fakeAsync((async) {
        final backend = FakeAudioBackend();
        final (engine, _) = started(backend);
        backend.tap();
        engine
          ..setMuted(true)
          ..setMuted(false);
        expect(backend.masterRamps.last, (
          1.0,
          SoundTiming.seconds(SoundTiming.mute),
        ));
      });
    });

    test('muting ramps the master to 0 and stops the theme', () {
      fakeAsync((async) {
        final backend = FakeAudioBackend();
        final (engine, _) = started(backend);
        backend.tap();
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
      backend.tap();
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
          ..gesture(activates: true)
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
