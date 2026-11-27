import 'dart:convert';
import 'dart:io';
import 'dart:ui' show FrameTiming;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/perf/field_beacon.dart';
import 'package:midnight_village/core/perf/field_recorder.dart';
import 'package:midnight_village/core/perf/field_summary.dart';
import 'package:midnight_village/core/perf/insights_route.dart';
import 'package:midnight_village/core/perf/perf.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/perf/control_kind.dart';
import 'package:midnight_village/design_system/perf/perf_strip.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';

import '../../helpers/finger.dart';
import '../../helpers/shell_setup.dart';

/// The test's clock, as the page's: ms on the fake clock.
double _now(WidgetTester tester) =>
    tester.binding.clock.now().microsecondsSinceEpoch / 1000;

Duration _stamp(WidgetTester tester) =>
    Duration(microseconds: tester.binding.clock.now().microsecondsSinceEpoch);

/// The quiet recorder for one test (as the live app has it), off after it.
FieldRecorder _quiet(WidgetTester tester) {
  final recorder = FieldRecorder(
    now: () => _now(tester),
    controlAt: controlAt,
    environment: const {
      'agent': 'Mozilla/5.0 (Linux; Android 10; K) Chrome/131.0.0.0 Mobile',
      'pixel_ratio': 2.625,
      'renderer': 'canvaskit',
    },
  )..install();
  Perf.recorder = recorder;
  addTearDown(() {
    recorder.uninstall();
    Perf.recorder = const PerfOff();
  });
  return recorder;
}

/// 08 at the talk, then "Ready to vote" pressed as a finger does.
Future<ShellSetup> _talkAndReady(WidgetTester tester) async {
  final s = await ShellSetup.pump(
    tester,
    recordedMe('me_discussion_choose_seer'),
    learned: {...Cue.values},
    appRoutes: true,
    before: (s) =>
        s.answerPost('/night-results/seen/', 'game/night_results_seen'),
  );
  await s.settle(tester);
  await pressAtLikeAFinger(tester, const Offset(4, 400));
  await tester.pumpAndSettle();
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
  return s;
}

/// What the server keeps (`backend/apps/observe/summary.py`), read from it:
/// the app and the server agree on the names, or a leg would be dropped.
Set<String> _serverNames(String tuple) {
  final source = File('../backend/apps/observe/summary.py').readAsStringSync();
  final found = RegExp('$tuple = \\(([^)]*)\\)').firstMatch(source)!;
  return {
    for (final m in RegExp(r'"([a-z_]+)"').allMatches(found.group(1)!))
      m.group(1)!,
  };
}

/// A recorder with requests made on a clock the test moves: each request's
/// round trip and the server's own `Server-Timing`.
Future<FieldRecorder> _requests(
  List<({double gap, double round, double total, double connect})> asked, {
  String Function(int i) path = _me,
}) async {
  var t = 0.0;
  final recorder = FieldRecorder(now: () => t, controlAt: (_, _) => null);
  for (final (i, q) in asked.indexed) {
    t += q.gap;
    final mark = recorder.httpQueued()!;
    mark.left(RequestOptions(path: path(i)));
    t += q.round;
    mark.arrived(200, {
      'server-timing': ['connect;dur=${q.connect}, total;dur=${q.total}'],
    });
    await mark.watch(Future.value(null));
  }
  return recorder;
}

String _me(int i) => 'https://api.example/api/onuw/games/7/me/';

void main() {
  testWidgets('a game\'s summary holds a tap\'s legs by kind, its frames and '
      'its request, and no player name, role or card', (tester) async {
    final recorder = _quiet(tester);
    final s = await _talkAndReady(tester);
    recorder.takeTimings([
      FrameTiming(
        vsyncStart: 0,
        buildStart: 1000,
        buildFinish: 4000,
        rasterStart: 4000,
        rasterFinish: 70000,
        rasterFinishWallTime: 70000,
      ),
    ]);

    final text = fieldSummaryJson(recorder, commit: 'faf62a1', end: 'hidden')!;
    final summary = jsonDecode(text) as Map<String, Object?>;

    expect(summary['v'], 1);
    final taps = summary['taps']! as Map<String, Object?>;
    final ready = taps.entries.singleWhere(
      (e) => e.key.startsWith('talk tap main_button POST'),
    );
    expect(ready.key, endsWith('/ready/'));
    final legs = ready.value! as Map<String, Object?>;
    expect(legs['n'], 1);
    expect(legs.keys.toSet().difference({'n'}), {
      'heard',
      'screen',
      'left',
      'answer',
      'applied',
      'shown',
      'total',
    });
    expect(
      legs.keys.toSet().difference({'n'}),
      _serverNames('TAP_LEGS'),
      reason: 'the server keeps exactly these legs',
    );
    final frames = summary['frames']! as Map<String, Object?>;
    expect(frames.values.whereType<Map<String, Object?>>().first['over_50'], 1);
    expect((summary['env']! as Map)['renderer'], 'canvaskit');

    final me = s.me;
    final secrets = [
      for (final p in (me['players'] as List).cast<Map<String, dynamic>>())
        p['display_name'] as String,
      for (final role in RoleId.values) role.displayName,
      for (final role in RoleId.values) role.name,
      if (me['game_id'] case final String id) id,
    ];
    expect(secrets, isNotEmpty);
    for (final secret in secrets) {
      final word = RegExp(
        '\\b${RegExp.escape(secret)}\\b',
        caseSensitive: false,
      );
      expect(text, isNot(matches(word)), reason: secret);
    }
    expect(text.length, lessThan(mostSummaryChars));

    await s.settle(tester);
    await s.close(tester);
  });

  test('the names of every part agree with what the server keeps', () {
    expect(_serverNames('CHANGE_LEGS'), {'first', 'content'});
    expect(_serverNames('REQUEST_LEGS'), {
      'round',
      'server',
      'connect',
      'outside',
    });
    expect(_serverNames('ENDS'), {FieldBeacon.endOfGame, 'hidden'});
    expect(_serverNames('COLD_KINDS'), {'boot', 'db_wake'});
  });

  test('a leg keeps at most 24 values, the smallest and the largest among '
      'them, so the server can merge games into percentiles', () {
    final values = [for (var i = 1; i <= 100; i++) i.toDouble()];
    final kept = spreadOf(values.reversed, mostValues);
    expect(kept, hasLength(mostValues));
    expect(kept.first, 1);
    expect(kept.last, 100);
    expect(spreadOf([3, null, 1], mostValues), [1, 3]);
  });

  test(
    'a request far slower outside the server than the game\'s others is a '
    'cold start (boot); one whose database connection is, a database '
    'waking (db_wake); each says how long the phone had asked nothing',
    () async {
      final recorder = await _requests([
        (gap: 0, round: 120, total: 50, connect: 12),
        (gap: 2000, round: 110, total: 50, connect: 10),
        (gap: 2000, round: 130, total: 50, connect: 14),
        (gap: 400000, round: 2100, total: 100, connect: 11),
        (gap: 3000, round: 900, total: 700, connect: 640),
        (gap: 2000, round: 125, total: 50, connect: 12),
      ]);

      final cold = coldStarts(recorder.requests);

      expect(cold, [
        {
          'kind': 'boot',
          'path': 'GET /api/onuw/games/·/me/',
          'round': 2100.0,
          'server': 100.0,
          'connect': 11.0,
          'outside': 2000.0,
          'gap_s': 400.0,
        },
        {
          'kind': 'db_wake',
          'path': 'GET /api/onuw/games/·/me/',
          'round': 900.0,
          'server': 700.0,
          'connect': 640.0,
          'outside': 200.0,
          'gap_s': 5.0,
        },
      ]);
    },
  );

  test('nothing tapped or asked for is no summary', () {
    final recorder = FieldRecorder(now: () => 0, controlAt: (_, _) => null)
      ..screen('table');
    expect(fieldSummaryJson(recorder, commit: 'x', end: 'hidden'), isNull);
  });

  test('a long evening still fits in one summary', () async {
    final word = [for (var c = 97; c < 123; c++) String.fromCharCode(c)];
    final recorder = await _requests([
      for (var i = 0; i < 1400; i++)
        (gap: 500, round: 100.0 + i % 50, total: 50, connect: 10),
    ], path: (i) => 'https://api.example/api/onuw/${word[i % 24]}/');
    for (var i = 0; i < 60; i++) {
      recorder.screen('screen_${String.fromCharCode(97 + i % 26)}');
    }
    expect(
      jsonEncode(fieldSummary(recorder, commit: 'x', end: 'hidden')).length,
      greaterThan(mostSummaryChars),
      reason: 'as much as this would not fit whole',
    );
    final text = fieldSummaryJson(recorder, commit: 'x', end: 'hidden')!;
    expect(text.length, lessThanOrEqualTo(mostSummaryChars));
  });

  group('the beacon', () {
    testWidgets('sends once when the end board is shown, in an idle task, '
        'then forgets what it sent', (tester) async {
      final sent = <String>[];
      final recorder = await tester.runAsync(
        () => _requests([(gap: 0, round: 100, total: 50, connect: 10)]),
      );
      final beacon = FieldBeacon(
        recorder: recorder!,
        commit: 'faf62a1',
        send: (s) {
          sent.add(s);
          return true;
        },
      );
      beacon.screenShown('vote');
      await tester.pump(const Duration(milliseconds: 1));
      expect(sent, isEmpty, reason: 'only the end board sends');

      beacon.screenShown(FieldBeacon.endBoard);
      expect(sent, isEmpty, reason: 'never in the frame that shows it');
      await tester.pump(const Duration(milliseconds: 1));
      expect(sent, hasLength(1));
      expect(jsonDecode(sent.single), containsPair('end', 'end_board'));
      expect(recorder.requests, isEmpty, reason: 'what was sent is forgotten');

      beacon.hidden();
      expect(sent, hasLength(1), reason: 'nothing new: nothing sent');
    });

    test('reads what the phone says about itself once, with the first '
        'summary, never before', () async {
      var reads = 0;
      final sent = <String>[];
      final recorder = await _requests([
        (gap: 0, round: 100, total: 50, connect: 10),
      ]);
      final beacon = FieldBeacon(
        recorder: recorder,
        commit: 'faf62a1',
        send: (s) {
          sent.add(s);
          return true;
        },
        environment: () {
          reads++;
          return {'renderer': 'canvaskit'};
        },
      );
      beacon.hidden();
      expect(reads, 1);
      expect(beacon.flush('hidden'), isFalse, reason: 'nothing new');
      expect(reads, 1, reason: 'nothing to send: nothing read');
      expect((jsonDecode(sent.single) as Map)['env'], {
        'renderer': 'canvaskit',
      });
    });

    test('the recorder tells it every new screen, once', () {
      final shown = <String>[];
      final recorder = FieldRecorder(now: () => 0, controlAt: (_, _) => null)
        ..screenChanged = shown.add;
      recorder.screen('vote');
      recorder.screen('vote');
      recorder.screen(FieldBeacon.endBoard);
      expect(shown, ['vote', FieldBeacon.endBoard]);
    });

    test('sends what was recorded when the tab is hidden', () async {
      final sent = <String>[];
      final recorder = await _requests([
        (gap: 0, round: 100, total: 50, connect: 10),
      ]);
      final beacon = FieldBeacon(
        recorder: recorder,
        commit: 'faf62a1',
        send: (s) {
          sent.add(s);
          return true;
        },
      );

      beacon.hidden();

      expect(jsonDecode(sent.single), containsPair('end', 'hidden'));
    });

    test('a test build (no commit) runs no quiet recorder at all', () {
      expect(quietField, isFalse);
    });
  });

  group('what Vercel is told of the address', () {
    test('a table\'s link is its route, never its code', () {
      expect(insightsRoute('/join/K7QX9P'), '/join/[code]');
      expect(insightsRoute('/game/3f2a9c1e-5b'), '/game/[id]');
      expect(insightsRoute('/'), '/');
      expect(insightsRoute(''), '/');
      expect(insightsRoute('/Ana/Bell'), '/[other]');
    });

    test('the query and the fragment go too', () {
      expect(
        insightsUrl('https://app.example/join/K7QX9P?perf=1#x'),
        'https://app.example/join/[code]',
      );
      expect(insightsUrl('not a url'), '/');
    });
  });
}
