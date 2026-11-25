import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/audio/audio_backend.dart';
import 'package:midnight_village/core/audio/sound_set.dart';

import 'engine_fixture.dart';
import 'fake_audio_backend.dart';

// Seeded random runs of everything a page, a player and a browser can do to
// the engine, over the fake that follows Web Audio's rules. After every step:
// at most two theme variants decoded and one decoding, at most two voices
// sounding, no cue started into an output that is not running, nothing
// Web Audio would refuse, and never a throw. A failure names its seed and
// its steps, so it replays.

const seeds = 300;
const steps = 250;

void main() {
  test('random taps, stages, pages, mutes and browser moods keep every '
      'bound', () {
    var fired = 0;
    var switches = 0;
    var reopened = 0;
    for (var seed = 0; seed < seeds; seed++) {
      final backend = _run(seed);
      fired += backend.fired.length;
      switches += backend.loops.length;
      if (backend.opens > 1) reopened++;
    }
    // The runs reach the cases that matter, not only a locked page.
    expect(fired, greaterThan(seeds));
    expect(switches, greaterThan(seeds));
    expect(reopened, greaterThan(seeds ~/ 10));
  });
}

FakeAudioBackend _run(int seed) {
  late FakeAudioBackend result;
  fakeAsync((async) {
    final rng = Random(seed);
    final backend = FakeAudioBackend(decodeAtOnce: rng.nextBool())
      ..resumeNeedsGesture = rng.nextBool()
      ..baseLatency = rng.nextDouble() * 0.05;
    final (engine, _) = started(backend, muted: rng.nextInt(4) == 0);
    result = backend;
    final done = <String>[];
    final variants = [...ThemeVariant.values, null];

    T pick<T>(List<T> from) => from[rng.nextInt(from.length)];

    void step() {
      switch (rng.nextInt(16)) {
        case 0 || 1:
          done.add('touch');
          backend.touch();
        case 2:
          done.add('click');
          backend.tap();
        case 3:
          done.add('pointerdown');
          backend.send(activates: false);
        case 4 || 5:
          final v = pick(variants);
          done.add('theme $v');
          engine.theme(v);
        case 6:
          done.add('play');
          engine.play(knock);
        case 7:
          final shown = rng.nextBool();
          done.add('visible $shown');
          backend.visible?.call(shown);
        case 8:
          final muted = rng.nextInt(3) == 0;
          done.add('muted $muted');
          engine.setMuted(muted);
        case 9:
          done.add('volume');
          engine.setVolume(rng.nextDouble());
        case 10:
          final s = rng.nextDouble() * 2;
          done.add('advance $s');
          backend.advance(s);
        case 11:
          final f = rng.nextDouble();
          done.add('elapse $f idle');
          async.elapse(SoundTiming.idle * f);
        case 12:
          final pending = [...backend.decoding];
          if (pending.isEmpty) return;
          final path = pick(pending);
          if (rng.nextInt(8) == 0) {
            done.add('fail $path');
            backend.failDecode(path);
          } else {
            done.add('finish $path');
            backend.finishDecode(path);
          }
        case 13:
          if (!backend.opened || backend.current == AudioState.closed) return;
          done.add('the browser suspends it');
          backend.current = AudioState.suspended;
        case 14:
          done.add('interrupt');
          backend.interrupt();
        case _:
          if (rng.nextInt(10) != 0) return;
          done.add('close');
          backend.close();
      }
    }

    for (var i = 0; i < steps; i++) {
      String why() => 'seed $seed after ${done.join(', ')}';
      expect(step, returnsNormally, reason: why());
      // Each step is its own task: what is due now runs before the next.
      async.elapse(Duration.zero);
      final themes = backend.held.where((p) => p != knockFile);
      expect(themes.length, lessThanOrEqualTo(2), reason: why());
      expect(
        backend.decoding.where((p) => p != knockFile).length,
        lessThanOrEqualTo(1),
        reason: why(),
      );
      expect(
        backend.soundingLoops().length,
        lessThanOrEqualTo(2),
        reason: why(),
      );
      expect(engine.voices, lessThanOrEqualTo(2), reason: why());
      expect(backend.lateCues, isEmpty, reason: why());
      expect(backend.misuse, isEmpty, reason: why());
    }
  });
  return result;
}
