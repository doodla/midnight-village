import 'dart:convert';
import 'dart:ui' show FrameTiming;

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/perf/field_recorder.dart';
import 'package:midnight_village/core/perf/perf.dart';
import 'package:midnight_village/core/perf/perf_records.dart';
import 'package:midnight_village/core/perf/perf_report.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/perf/control_kind.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';

import '../../helpers/finger.dart';
import '../../helpers/shell_setup.dart';

/// The test's clock, as the page's: ms on the fake clock.
double _now(WidgetTester tester) =>
    tester.binding.clock.now().microsecondsSinceEpoch / 1000;

Duration _stamp(WidgetTester tester) =>
    Duration(microseconds: tester.binding.clock.now().microsecondsSinceEpoch);

/// Switches the recorder on for one test, and off again after it.
FieldRecorder _on(WidgetTester tester) {
  final recorder = FieldRecorder(now: () => _now(tester), controlAt: controlAt)
    ..install();
  Perf.recorder = recorder;
  addTearDown(() {
    recorder.uninstall();
    Perf.recorder = const PerfOff();
  });
  return recorder;
}

/// 08 at the talk, signed in through the app's own home (`HomeGate`).
Future<ShellSetup> _talk(WidgetTester tester) async {
  final s = await ShellSetup.pump(
    tester,
    recordedMe('me_discussion_choose_seer'),
    learned: {...Cue.values},
    appRoutes: true,
    before: (s) =>
        s.answerPost('/night-results/seen/', 'game/night_results_seen'),
  );
  await s.settle(tester);
  // My night is up by itself as the talk opens: the first touch puts it
  // away.
  await pressAtLikeAFinger(tester, const Offset(4, 400));
  await tester.pumpAndSettle();
  return s;
}

/// "Ready to vote", pressed as a finger does, each event with its own time
/// stamp; then frames until the tap has finished.
Future<void> _pressReady(WidgetTester tester, ShellSetup s) async {
  s.answerPost('/ready/', 'game/ready_talk');
  final at = tester.getCenter(find.byType(PrimaryButton).last);
  final finger = await tester.createGesture();
  await finger.down(at, timeStamp: _stamp(tester));
  for (var i = 0; i < fingerFrames; i++) {
    tester.binding.scheduleFrame();
    await tester.pump(fingerFrame);
  }
  await finger.up(timeStamp: _stamp(tester));
  for (var i = 0; i < 6; i++) {
    await tester.pump(fingerFrame);
  }
}

void main() {
  testWidgets('a tap is recorded with every leg, in order: the finger, the '
      'app handling it, its frame, its request leaving and answered, the '
      'answer applied and the frame after', (tester) async {
    final recorder = _on(tester);
    final s = await _talk(tester);

    await _pressReady(tester, s);

    final tap = recorder.taps.singleWhere((t) => t.control == 'main_button');
    expect(tap.done, isTrue);
    expect(recorder.finished.value, same(tap));
    expect(tap.screen, 'talk');
    final request = tap.request!;
    expect(request.method, 'POST');
    expect(request.path, endsWith('/ready/'));
    expect(request.path, isNot(matches(RegExp(r'\d'))));
    expect(request.cause, 'tap');
    final legs = [
      tap.downAt,
      tap.upAt!,
      tap.heardUpAt!,
      request.queuedAt,
      request.leftAt!,
      request.doneAt!,
      tap.appliedAt!,
      tap.shownAt!,
    ];
    for (var i = 1; i < legs.length; i++) {
      expect(legs[i], greaterThanOrEqualTo(legs[i - 1]), reason: 'leg $i');
    }
    expect(tap.upFrameAt!, greaterThanOrEqualTo(tap.heardUpAt!));
    expect(tap.upFrameAt! - tap.downAt, greaterThan(0));
    expect(tap.shownAt! - tap.appliedAt!, greaterThan(0));
    expect(stripLine(tap), startsWith('finger → screen '));
    expect(stripLine(tap), contains('request left'));

    await s.settle(tester);
    await s.close(tester);
  });

  testWidgets('the report holds no player name, no role and no card: only '
      'screens, kinds of control, paths without ids and times', (tester) async {
    final recorder = _on(tester);
    final s = await _talk(tester);
    await _pressReady(tester, s);
    recorder.takeTimings([
      FrameTiming(
        vsyncStart: 0,
        buildStart: 1000,
        buildFinish: 4000,
        rasterStart: 4000,
        rasterFinish: 30000,
        rasterFinishWallTime: 30000,
      ),
    ]);

    final short = shortReport(recorder);
    final everything = fullReport(recorder);
    expect(jsonDecode(everything), isA<Map<String, Object?>>());
    final me = s.me;
    final names = [
      for (final p in (me['players'] as List).cast<Map<String, dynamic>>())
        p['display_name'] as String,
    ];
    expect(names, isNotEmpty);
    final secrets = [
      ...names,
      for (final role in RoleId.values) role.displayName,
      ...[for (final role in RoleId.values) role.name],
    ];
    for (final secret in secrets) {
      final word = RegExp(
        '\\b${RegExp.escape(secret)}\\b',
        caseSensitive: false,
      );
      expect(short, isNot(matches(word)), reason: secret);
      expect(everything, isNot(matches(word)), reason: secret);
    }
    expect(short.length, lessThan(4000));
    expect(short, contains('talk tap main_button POST'));

    await s.settle(tester);
    await s.close(tester);
  });

  testWidgets('where the engine reports frame timings, a tap\'s frames are '
      'the engine\'s own raster finish, and the tap finishes only on them', (
    tester,
  ) async {
    final recorder = _on(tester);
    final s = await _talk(tester);
    FrameTiming drawn(double endMs) {
      final end = (endMs * 1000).round();
      return FrameTiming(
        vsyncStart: end - 3000,
        buildStart: end - 3000,
        buildFinish: end - 2000,
        rasterStart: end - 2000,
        rasterFinish: end,
        rasterFinishWallTime: end,
      );
    }

    // The engine reports here: from now a tap waits for its frames' timings.
    recorder.takeTimings([drawn(_now(tester) - 500)]);
    await _pressReady(tester, s);
    final tap = recorder.taps.singleWhere((t) => t.control == 'main_button');
    expect(tap.done, isFalse, reason: 'its frames\' timings are not in yet');

    // The frames were finished 7 ms after each stand-in's mark.
    final later = _now(tester) + 7;
    recorder.takeTimings([drawn(later)]);
    expect(tap.done, isTrue);
    expect(tap.shownAt, later);
    expect(tap.upFrameAt, later);
    expect(recorder.finished.value, same(tap));

    await s.settle(tester);
    await s.close(tester);
  });

  test('a long report stays short enough to paste in a chat', () {
    var t = 0.0;
    final recorder = FieldRecorder(
      now: () => t += 7,
      controlAt: (_, _) => null,
    );
    for (var i = 0; i < 300; i++) {
      recorder.screen('screen_${String.fromCharCode(97 + i % 20)}');
      final mark = recorder.httpQueued()!;
      mark.left(null);
      mark.arrived(200, const {});
      recorder.socketMessage('/ws/game/1/', '{"type":"phase_change"}');
    }
    final short = shortReport(recorder);
    expect(short.length, lessThanOrEqualTo(4000));
    expect(fullReport(recorder).length, greaterThan(short.length));
  });

  test('frames are counted per screen, by length, and at rest', () {
    var t = 0.0;
    final recorder = FieldRecorder(now: () => t, controlAt: (_, _) => null);
    recorder.screen('vote');
    FrameTiming frame(double startMs, double totalMs) => FrameTiming(
      vsyncStart: (startMs * 1000).round(),
      buildStart: (startMs * 1000).round(),
      buildFinish: (startMs * 1000 + 2000).round(),
      rasterStart: (startMs * 1000 + 2000).round(),
      rasterFinish: ((startMs + totalMs) * 1000).round(),
      rasterFinishWallTime: ((startMs + totalMs) * 1000).round(),
    );
    recorder.takeTimings([frame(100, 10), frame(200, 40), frame(5000, 120)]);
    t = 65000;
    recorder.settleRest();
    final f = recorder.frames['vote']!;
    expect(f.frames, 3);
    expect([f.over16, f.over32, f.over50, f.over100], [2, 2, 1, 1]);
    expect(f.worst, 120);
    expect(f.restFrames, 1, reason: 'the frame at 5 s came with nothing new');
    // At rest from 1 s (a second after the screen came) to 65 s.
    expect(f.restPerMinute, closeTo(60 / 64, 0.001));
  });

  test('a path loses its ids, codes and query', () {
    expect(
      cleanPath('https://x.example/api/v2/games/123/vote/?t=abc'),
      '/api/v2/games/·/vote/',
    );
    expect(
      cleanPath('/api/v2/lobbies/QWERTY/join/'),
      '/api/v2/lobbies/·/join/',
    );
    expect(serverTiming('connect;dur=12.5, total;dur=50'), (
      connect: 12.5,
      total: 50.0,
    ));
  });

  test('a touch on nothing that takes a tap, or on the strip, is no tap', () {
    final recorder = FieldRecorder(
      now: () => 0,
      controlAt: (position, _) => position.dx < 10 ? null : 'perf',
    )..install();
    addTearDown(recorder.uninstall);
    for (final x in [1.0, 20.0]) {
      GestureBinding.instance.pointerRouter.route(
        PointerDownEvent(position: Offset(x, 1)),
      );
    }
    expect(recorder.taps, isEmpty);
  });
}
