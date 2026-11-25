import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/audio/sound_set.dart';
import 'package:midnight_village/core/storage/device_preferences.dart';
import 'package:midnight_village/design_system/feel/sounds.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/audio/fake_audio_backend.dart';

/// The bundled assets `pubspec.yaml` lists: files, and folders (whose
/// direct files are bundled).
List<String> pubspecAssets(String pubspec) {
  final lines = pubspec.split('\n');
  final start = lines.indexWhere((l) => l.trim() == 'assets:');
  return [
    for (final line in lines.skip(start + 1))
      if (RegExp(r'^\s+- (\S+)').firstMatch(line) case final m?)
        m.group(1)!
      else if (line.trim().isNotEmpty && !line.trim().startsWith('#'))
        null,
  ].takeWhile((a) => a != null).cast<String>().toList();
}

/// The paths of [sounds] that are not a bundled file.
List<String> missingAssets(SoundSet sounds, String pubspec) {
  final listed = pubspecAssets(pubspec);
  bool bundled(String path) => listed.any(
    (a) =>
        a == path ||
        (a.endsWith('/') &&
            File(path).parent.path == a.substring(0, a.length - 1)),
  );
  return [
    for (final path in sounds.paths)
      if (!File(path).existsSync() || !bundled(path)) path,
  ];
}

void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();

  test('every file in the catalogue is a bundled asset', () {
    expect(pubspecAssets(pubspec), contains('assets/fonts/gloock/OFL.txt'));
    expect(missingAssets(Sounds.catalogue, pubspec), isEmpty);
  });

  test('the bundle check catches a file that is not bundled', () {
    const sounds = SoundSet(
      cues: {
        Sfx('knock'): SoundFile(['assets/sounds/knock.ogg']),
      },
      theme: {
        ThemeVariant.table: SoundFile(['assets/fonts/gloock/OFL.txt']),
      },
    );
    expect(missingAssets(sounds, pubspec), ['assets/sounds/knock.ogg']);
  });

  test('nothing is chosen yet: the catalogue is empty', () {
    expect(Sounds.catalogue.isEmpty, isTrue);
  });

  group('Sounds', () {
    setUp(() {
      Sounds.reset();
      SharedPreferences.setMockInitialValues({});
    });
    tearDown(Sounds.reset);

    const knock = Sfx('knock');
    const sounds = SoundSet(
      cues: {
        knock: SoundFile(['assets/sounds/knock.ogg']),
      },
      theme: {
        ThemeVariant.night: SoundFile(['assets/sounds/night.ogg']),
      },
    );

    test('with an empty catalogue nothing is made', () async {
      var made = 0;
      await Sounds.startWith(SoundSet.empty, () {
        made++;
        return FakeAudioBackend();
      });
      expect(made, 0);
      expect(() => Sounds.play(knock), returnsNormally);
    });

    test('a theme asked for before the start plays on the first touch', () {
      fakeAsync((async) {
        final backend = FakeAudioBackend();
        Sounds.claimTheme().set(ThemeVariant.night);
        Sounds.startWith(sounds, () => backend, watchLifecycle: false);
        async.flushMicrotasks();
        expect(backend.opens, 0);
        backend.tap();
        async.flushMicrotasks();
        expect(backend.loops.single.variant, ThemeVariant.night);
      });
    });

    test('the theme has one owner: a second claim fails, a released one '
        'drives nothing and frees the claim', () {
      fakeAsync((async) {
        final backend = FakeAudioBackend();
        Sounds.startWith(sounds, () => backend, watchLifecycle: false);
        async.flushMicrotasks();
        backend.tap();
        final shell = Sounds.claimTheme()..set(ThemeVariant.night);
        expect(Sounds.claimTheme, throwsStateError);
        shell.release();
        async.flushMicrotasks();
        shell.set(null);
        expect(backend.loops.single.fadedAt, isNull, reason: 'still plays');
        expect(Sounds.claimTheme, returnsNormally);
      });
    });

    test('mute and volume are remembered and restored on this device', () {
      fakeAsync((async) {
        final backend = FakeAudioBackend();
        Sounds.startWith(sounds, () => backend, watchLifecycle: false);
        async.flushMicrotasks();
        backend.tap();
        Sounds.setVolume(0.25);
        async.flushMicrotasks();
        expect(backend.masterGain, 0.25);
        Sounds.setMuted(true);
        async.flushMicrotasks();
        expect(backend.masterGain, 0);

        final again = SoundSettings();
        again.restore();
        async.flushMicrotasks();
        expect(again.value, const SoundLevel(muted: true, volume: 0.25));
      });
    });

    test(
      'a device that cannot read its preferences gets the standard level',
      () async {
        final settings = SoundSettings(
          preferences: DevicePreferences(open: () => throw StateError('no')),
        );
        await settings.restore();
        expect(settings.value, SoundLevel.standard);
        await settings.setMuted(true);
        expect(settings.value.muted, isTrue, reason: 'holds for this visit');
      },
    );

    test('a nonsense volume on the device is the standard one', () async {
      SharedPreferences.setMockInitialValues({SoundSettings.volumeKey: 'loud'});
      final settings = SoundSettings();
      await settings.restore();
      expect(settings.value.volume, SoundLevel.standard.volume);
    });

    test('muted on this device: started muted, nothing opened', () {
      fakeAsync((async) {
        SharedPreferences.setMockInitialValues({SoundSettings.mutedKey: '1'});
        final backend = FakeAudioBackend();
        Sounds.claimTheme().set(ThemeVariant.night);
        Sounds.startWith(sounds, () => backend, watchLifecycle: false);
        async.flushMicrotasks();
        backend.tap();
        async.flushMicrotasks();
        expect(backend.opens, 0);
        expect(backend.decodes, isEmpty);
      });
    });
  });
}
