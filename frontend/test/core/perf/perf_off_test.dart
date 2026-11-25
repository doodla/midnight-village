import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/perf/field_recorder.dart';
import 'package:midnight_village/core/perf/perf.dart';
import 'package:midnight_village/core/perf/perf_switch.dart';
import 'package:midnight_village/core/storage/tab_storage.dart';
import 'package:midnight_village/design_system/perf/perf_strip.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('off (the default)', () {
    test('the recorder is the constant null object: no state, and every '
        'hook returns nothing, so a tap, a request or a socket message '
        'makes no object, starts no timer and adds no listener', () {
      expect(Perf.recorder, same(const PerfOff()));
      const off = PerfOff();
      expect(off.on, isFalse);
      expect(off.httpQueued(), isNull);
      expect(off.playerRequestStarted(), isNull);
    });

    test('starting the app with no switch leaves it off: no pointer route '
        'and nothing else changed', () {
      final routes =
          GestureBinding.instance.pointerRouter.debugGlobalRouteCount;
      startPerfField();
      expect(Perf.recorder, same(const PerfOff()));
      expect(
        GestureBinding.instance.pointerRouter.debugGlobalRouteCount,
        routes,
      );
    });

    test('the app is drawn as it is: no strip, no wrapper', () {
      const app = SizedBox();
      expect(perfStripAround(app), same(app));
    });
  });

  test('on, the recorder listens to the pointer, and stops when taken off', () {
    final router = GestureBinding.instance.pointerRouter;
    final before = router.debugGlobalRouteCount;
    final recorder = FieldRecorder(now: () => 0, controlAt: (_, _) => null)
      ..install();
    expect(router.debugGlobalRouteCount, before + 1);
    recorder.uninstall();
    expect(router.debugGlobalRouteCount, before);
  });

  group('the switch (`?perf=` on the web address, kept for the tab)', () {
    test('?perf=1 switches it on and the tab remembers it', () {
      final tab = MemoryTabStorage();
      expect(perfSwitchedOn({'perf': '1'}, tab), isTrue);
      // The app's own navigation dropped the query; a reload keeps it.
      expect(perfSwitchedOn({}, tab), isTrue);
    });

    test('?perf=0 switches it off and the tab forgets it', () {
      final tab = MemoryTabStorage()..write(perfSwitchKey, '1');
      expect(perfSwitchedOn({'perf': '0'}, tab), isFalse);
      expect(perfSwitchedOn({}, tab), isFalse);
    });

    test('with nothing asked, it is off', () {
      expect(perfSwitchedOn({}, MemoryTabStorage()), isFalse);
      expect(perfSwitchedOn({'perf': 'yes'}, MemoryTabStorage()), isFalse);
    });
  });
}
