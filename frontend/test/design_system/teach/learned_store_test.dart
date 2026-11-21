import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/storage/device_preferences.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

ProviderContainer _app() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container;
}

/// main(): reads what this device has learned before the first frame.
Future<Set<Cue>> _launch() => restoreLearned(preferences: DevicePreferences());

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    forgetRestoredLearned();
  });

  test('a new device has learned nothing', () async {
    expect(await _launch(), isEmpty);
    expect(_app().read(learnedCuesProvider), isEmpty);
  });

  test('a learned cue is stored as mv.learned.v1.<id> = "1"', () async {
    await _app().read(learnedCuesProvider.notifier).learn(Cue.nightChoose);
    final stored = await SharedPreferences.getInstance();
    expect(stored.getString('mv.learned.v1.night_choose'), '1');
  });

  test('what was learned is read before the first frame, after a '
      'restart', () async {
    await _app().read(learnedCuesProvider.notifier).learn(Cue.hold);
    forgetRestoredLearned();
    expect(await _launch(), {Cue.hold});
    expect(_app().read(learnedCuesProvider), {Cue.hold});
  });

  test('keys it does not know, and unset values, are ignored', () async {
    SharedPreferences.setMockInitialValues({
      'mv.learned.v1.hold': '1',
      'mv.learned.v1.retired_cue': '1',
      'mv.learned.v1.vote_lock': '0',
      'skin': 'shadowPaper',
    });
    expect(await _launch(), {Cue.hold});
  });

  test('reset forgets every cue on this device, and nothing else', () async {
    SharedPreferences.setMockInitialValues({
      'mv.learned.v1.hold': '1',
      'mv.learned.v1.vote_lock': '1',
      'skin': 'shadowPaper',
    });
    await _launch();
    final app = _app();
    expect(app.read(learnedCuesProvider), {Cue.hold, Cue.voteLock});

    await app.read(learnedCuesProvider.notifier).reset();
    expect(app.read(learnedCuesProvider), isEmpty);
    forgetRestoredLearned();
    expect(await _launch(), isEmpty);
    final stored = await SharedPreferences.getInstance();
    expect(stored.getString('skin'), 'shadowPaper');
  });

  test('a device whose storage cannot be read starts as a new one', () async {
    final broken = DevicePreferences(open: () => throw StateError('locked'));
    expect(await restoreLearned(preferences: broken), isEmpty);
  });
}
