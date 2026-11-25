// The audio layer in a real browser (`run.cjs` compiles this with
// `dart compile js` and drives it with Playwright). It runs the app's own
// SoundEngine and WebAudioBackend, not a copy: live, on the page's one
// AudioContext, and offline, over an OfflineAudioContext, to read every
// sample the theme makes across a loop end and a variant switch.
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;

import 'package:midnight_village/core/audio/audio_backend.dart';
import 'package:midnight_village/core/audio/sound_engine.dart';
import 'package:midnight_village/core/audio/sound_set.dart';
import 'package:midnight_village/core/audio/web_audio_backend.dart';
import 'package:web/web.dart' as web;

const knock = Sfx('knock');

/// Two stand-ins from the owner's candidates, served at test time only.
/// Both variants are the SAME file: a switch in phase is then invisible in
/// the output, and any phase error shows as a difference.
const stand = SoundSet(
  cues: {
    knock: SoundFile(['knock.mp3']),
  },
  theme: {
    ThemeVariant.table: SoundFile(['loop.mp3']),
    ThemeVariant.night: SoundFile(['loop.mp3']),
  },
);

void main() {
  final live = WebAudioBackend(urlOf: (p) => p);
  final engine = SoundEngine(live, stand, log: (m) => web.console.log(m.toJS))
    ..start();

  // The app's tap, as Flutter's onTap fires it: on the finger's lift
  // (pointerup), in a handler on the page, after the engine's own listener
  // (which runs first, in the capture phase, with a microtask checkpoint
  // between the two).
  web.document.addEventListener(
    'pointerup',
    ((web.Event _) => engine.play(knock)).toJS,
  );

  final proof = JSObject();
  proof['state'] = (() => (live.context?.state ?? 'none').toJS).toJS;
  proof['latency'] = (() {
    final c = live.context;
    if (c == null || !c.isA<web.AudioContext>()) return null;
    final a = c as web.AudioContext;
    return [a.baseLatency.toJS, a.outputLatency.toJS, a.sampleRate.toJS].toJS;
  }).toJS;
  proof['theme'] = ((JSString name) => engine.theme(
    ThemeVariant.values.byName(name.toDart),
  )).toJS;
  proof['playing'] = (() => engine.playing?.name.toJS).toJS;
  proof['offline'] = ((JSBoolean trim) => _offline(trim.toDart).toJS).toJS;
  globalContext['mvProof'] = proof;
}

/// Renders the theme offline through the engine: the table variant from
/// the start, a switch to the night variant at 1.5 loops, on until the
/// crossfade is over and two loop ends have passed. With [trim], the
/// variants carry loop points cut to the file's sound (its encoder padding
/// left out). Returns what it measured, as JSON.
Future<JSString> _offline(bool trim) async {
  const rate = 48000;
  final probe = web.OfflineAudioContext(
    web.OfflineAudioContextOptions(length: 1, sampleRate: rate),
  );
  final bytes = await (await web.window.fetch('loop.mp3'.toJS).toDart)
      .arrayBuffer()
      .toDart;
  final file = await probe.decodeAudioData(bytes).toDart;
  final wanted = file.getChannelData(0).toDart;
  final n = wanted.length;
  var lead = 0;
  while (lead < n && wanted[lead].abs() < _quiet) {
    lead++;
  }
  var tail = 0;
  while (tail < n && wanted[n - 1 - tail].abs() < _quiet) {
    tail++;
  }
  final points = trim ? LoopPoints.samples(lead, n - tail, rate: rate) : null;
  final sounds = SoundSet(
    theme: {
      ThemeVariant.table: SoundFile(const ['loop.mp3'], loop: points),
      ThemeVariant.night: SoundFile(const ['loop.mp3'], loop: points),
    },
  );
  final length = file.duration;
  final t0 = SoundTiming.seconds(SoundTiming.lead);
  final switchAt = (length * 1.5 * rate / 128).floor() * 128 / rate;
  final crossfade = SoundTiming.seconds(SoundTiming.crossfade);
  final seconds = math.max(length * 3, switchAt + t0 + crossfade + 0.3);
  final frames = (seconds * rate).ceil();
  final offline = web.OfflineAudioContext(
    web.OfflineAudioContextOptions(
      numberOfChannels: file.numberOfChannels,
      length: frames,
      sampleRate: rate,
    ),
  );
  final backend = WebAudioBackend(urlOf: (p) => p, create: () => offline);
  final engine = SoundEngine(backend, sounds)
    ..start()
    ..gesture(activates: true)
    ..theme(ThemeVariant.table);
  while (engine.playing == null) {
    await Future<void>.delayed(Duration.zero);
  }
  var voicesInCrossfade = 0;
  unawaited(
    offline.suspend(switchAt).toDart.then((_) {
      engine.theme(ThemeVariant.night);
      voicesInCrossfade = engine.voices;
      offline.resume();
    }),
  );
  final out = await offline.startRendering().toDart;
  final played = out.getChannelData(0).toDart;

  // What the output should be: the file at the theme's own position, the
  // intro once and then the loop (the engine's loopPosition).
  double ideal(int i) {
    final at = loopPosition(i / rate - t0, length, points);
    return wanted[(at * rate).round().clamp(0, n - 1)];
  }

  final from = ((t0 + SoundTiming.seconds(SoundTiming.themeIn)) * rate).ceil();
  var worst = 0.0;
  var worstAt = 0;
  var sumDiff = 0.0;
  var sumSignal = 0.0;
  for (var i = from; i < played.length; i++) {
    final w = ideal(i);
    final d = (played[i] - w).abs();
    sumDiff += d * d;
    sumSignal += w * w;
    if (d > worst) {
      worst = d;
      worstAt = i;
    }
  }
  int longestQuiet(List<double> s, int start, int end) {
    var best = 0;
    var run = 0;
    for (var i = start; i < end; i++) {
      run = s[i].abs() < _quiet ? run + 1 : 0;
      best = math.max(best, run);
    }
    return best;
  }

  final report = <String, Object>{
    'trimmedLoopPoints': trim,
    'rate': rate,
    'fileSeconds': length,
    'fileLeadingSilenceSamples': lead,
    'fileTrailingSilenceSamples': tail,
    'renderedSeconds': frames / rate,
    'switchAtSeconds': switchAt,
    'crossfadeEndsAtSeconds': switchAt + t0 + crossfade,
    'voicesDuringCrossfade': voicesInCrossfade,
    'voicesAtEnd': engine.voices,
    'comparedFromSeconds': from / rate,
    'maxAbsDifference': worst,
    'maxAbsDifferenceAtSeconds': worstAt / rate,
    'differenceToSignalDb': 10 * math.log(sumDiff / sumSignal) / math.ln10,
    'longestSilentRunInOutputSamples': longestQuiet(played, from, frames),
    'longestSilentRunInLoopedPartOfFileSamples': longestQuiet(
      wanted,
      trim ? lead : 0,
      trim ? n - tail : n,
    ),
  };
  return _json(report).toJS;
}

/// Below this a sample counts as silence.
const _quiet = 1e-5;

String _json(Map<String, Object> m) =>
    '{${m.entries.map((e) => '"${e.key}":${e.value}').join(',')}}';
