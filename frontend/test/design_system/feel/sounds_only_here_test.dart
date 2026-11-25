import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Every sound goes through `Sounds` (lib/design_system/feel/sounds.dart,
// feel.md section 6), as every vibration goes through `Haptics`: it is the
// one place that never throws, never waits and knows what is muted. Nothing
// else in lib/ reaches the engine, its backends or the browser's audio.
void main() {
  bool allowed(String path) =>
      path.contains('lib/core/audio/') ||
      path.endsWith('lib/design_system/feel/sounds.dart');

  const reaches = [
    'core/audio/',
    'SoundEngine',
    'AudioBackend',
    'AudioContext',
    'AudioBufferSourceNode',
    'HTMLAudioElement',
  ];

  test('nothing in lib/ outside core/audio and Sounds touches the audio', () {
    final offenders = [
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File && file.path.endsWith('.dart') && !allowed(file.path))
          for (final word in reaches)
            if (file.readAsStringSync().contains(word)) '${file.path}: $word',
    ];
    expect(offenders, isEmpty);
  });

  test('the engine is pure Dart: no Flutter in core/audio but the '
      'settings', () {
    final flutter = [
      for (final file in Directory('lib/core/audio').listSync())
        if (file is File &&
            !file.path.endsWith('sound_settings.dart') &&
            file.readAsStringSync().contains('package:flutter'))
          file.path,
    ];
    expect(flutter, isEmpty);
  });
}
