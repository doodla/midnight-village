import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/audio/audio_backend.dart';
import 'package:midnight_village/core/audio/sound_set.dart';

import 'engine_fixture.dart';
import 'fake_audio_backend.dart';

// The battery: an output left running renders silence, so it sleeps when
// nothing can sound and wakes on the next gesture or theme.

void main() {
  test('the idle length covers the theme fading out and the longest cue', () {
    expect(
      SoundTiming.idle,
      greaterThanOrEqualTo(SoundTiming.themeOut + SoundTiming.longestCue),
    );
  });

  test('no theme wanted: the output sleeps after the idle length; the next '
      'touch wakes it and its own cue plays', () {
    fakeAsync((async) {
      final backend = FakeAudioBackend();
      final (engine, _) = started(backend);
      backend.touch();
      async.flushMicrotasks();
      engine.play(knock);
      async.elapse(SoundTiming.idle - SoundTiming.mute);
      expect(backend.suspends, 0, reason: 'the cue may still sound');
      async.elapse(SoundTiming.mute);
      expect(backend.suspends, 1);
      expect(backend.state, AudioState.suspended);

      backend.touch();
      engine.play(knock);
      async.flushMicrotasks();
      expect(backend.state, AudioState.running);
      expect(backend.fired, [knockFile, knockFile]);
      expect(backend.lateCues, isEmpty);
    });
  });

  test('a theme wanted keeps it awake; once none is, it sleeps after the '
      'fade out, and the next theme wakes it', () {
    fakeAsync((async) {
      final backend = FakeAudioBackend()..resumeNeedsGesture = false;
      final (engine, _) = started(backend);
      backend.tap();
      engine.theme(ThemeVariant.table);
      async.elapse(SoundTiming.idle * 3);
      expect(backend.suspends, 0);

      engine.theme(null);
      async.elapse(SoundTiming.idle);
      expect(backend.state, AudioState.suspended);

      engine.theme(ThemeVariant.night);
      async.flushMicrotasks();
      expect(backend.state, AudioState.running);
      expect(engine.playing, ThemeVariant.night);
    });
  });

  test('muted, the output sleeps once the mute ramp is over', () {
    fakeAsync((async) {
      final backend = FakeAudioBackend();
      final (engine, _) = started(backend);
      backend.tap();
      engine
        ..theme(ThemeVariant.table)
        ..setMuted(true);
      async.elapse(SoundTiming.mute);
      expect(backend.state, AudioState.suspended);
      backend.touch();
      async.flushMicrotasks();
      expect(backend.state, AudioState.suspended, reason: 'muted: not woken');
    });
  });

  test('each touch puts the sleep off again', () {
    fakeAsync((async) {
      final backend = FakeAudioBackend();
      started(backend);
      for (var i = 0; i < 5; i++) {
        backend.touch();
        async.elapse(SoundTiming.idle - SoundTiming.mute);
      }
      expect(backend.suspends, 0);
    });
  });
}
