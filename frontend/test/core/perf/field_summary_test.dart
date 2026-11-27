import 'dart:convert';
import 'dart:io';
import 'dart:ui' show FrameTiming;

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/perf/field_recorder.dart';
import 'package:midnight_village/core/perf/field_summary.dart';
import 'package:midnight_village/core/perf/insights_route.dart';
import 'package:midnight_village/core/perf/perf.dart';
import 'package:midnight_village/core/perf/perf_records.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/perf/control_kind.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';

import '../../helpers/finger.dart';
import '../../helpers/shell_setup.dart';
import 'perf_kit.dart';

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
Future<ShellSetup> _talkAndReady(
  WidgetTester tester, {
  FieldRecorder? recorder,
}) async {
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
  // The setting-up touch carries no time stamp of its own; only the
  // measured tap below does.
  recorder?.clear();
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

/// The app's own summary, recorded for the server's test
/// (`backend/tests/observe/test_summary_clean.py` cleans it and asserts
/// nothing is dropped): `UPDATE_CONTRACT_SAMPLES=1` writes it; otherwise
/// its shape (every key and label, not the times) must match.
final _sample = File('../contract_samples/app/field_summary.json');

Object? _shape(Object? value) => switch (value) {
  final Map<String, Object?> m => {
    for (final e in m.entries) e.key: _shape(e.value),
  },
  List() => 'list',
  num() => 'number',
  String() => 'text',
  _ => value,
};

void main() {
  testWidgets('a summary holds a tap\'s legs by kind, its frames and its '
      'request, and no player name, role, card or id; the server keeps all '
      'of it', (tester) async {
    final recorder = _quiet(tester);
    final s = await _talkAndReady(tester, recorder: recorder);
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
    // The tests' client has no base address; the live app's is `<origin>/api`.
    expect(ready.key, 'talk tap main_button POST /onuw/games/·/ready/');
    final legs = ready.value! as Map<String, Object?>;
    expect(legs['n'], 1);
    expect(
      legs.keys.toSet().difference({'n'}),
      quotedWords(serverFile('apps/observe/summary.py'), 'TAP_LEGS'),
      reason: 'the server keeps exactly these legs',
    );
    final frames = summary['frames']! as Map<String, Object?>;
    expect(frames.values.whereType<Map<String, Object?>>().first['over_50'], 1);
    expect(summary['env'], {
      'agent': 'Mozilla/5.0 (Linux; Android 10; K) Chrome/131.0.0.0 Mobile',
      'pixel_ratio': 2.625,
      'renderer': 'canvaskit',
    });

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

    // As the live app sends it: its requests go to `<origin>/api/...`.
    final live = jsonDecode(
      text.replaceAllMapped(
        RegExp(r'(GET|POST|PUT|PATCH|DELETE) /(?!api/)'),
        (m) => '${m[1]} /api/',
      ),
    );
    final pretty = '${const JsonEncoder.withIndent('  ').convert(live)}\n';
    if (Platform.environment['UPDATE_CONTRACT_SAMPLES'] != null) {
      _sample
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(pretty);
    }
    expect(
      _shape(jsonDecode(_sample.readAsStringSync())),
      _shape(live),
      reason:
          'contract_samples/app/field_summary.json is the app\'s summary: '
          're-record it with UPDATE_CONTRACT_SAMPLES=1 and run the server\'s '
          'tests/observe',
    );

    await s.settle(tester);
    await s.close(tester);
  });

  test('a leg keeps at most 16 values, the smallest and the largest among '
      'them, so the server can merge summaries into percentiles', () {
    final values = [for (var i = 1; i <= 100; i++) i.toDouble()];
    final kept = spreadOf(values.reversed, mostValues);
    expect(kept, hasLength(mostValues));
    expect(kept.first, 1);
    expect(kept.last, 100);
    expect(spreadOf([3, null, 1], mostValues), [1, 3]);
  });

  test('a request far slower outside the server than the others is a cold '
      'start (boot); one whose database connection is, a database waking '
      '(db_wake); each says how long the phone had asked nothing', () async {
    final recorder = await recorderWithRequests([
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
  });

  test('nothing tapped or asked for is no summary', () {
    final recorder = FieldRecorder(now: () => 0, controlAt: (_, _) => null)
      ..screen('table');
    expect(fieldSummaryJson(recorder, commit: 'x', end: 'hidden'), isNull);
  });

  test('a long evening still fits in one summary', () async {
    final words = apiWords.toList();
    final recorder = await recorderWithRequests([
      for (var i = 0; i < 1400; i++)
        (gap: 500, round: 100.0 + i % 50, total: 50, connect: 10),
    ], path: (i) => 'https://api.example/api/${words[i % words.length]}/');
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

  group('a path keeps only the server\'s own route words', () {
    test('ids, codes and the query go, whatever they look like', () {
      expect(
        cleanPath('https://x.example/api/onuw/games/123/vote/?t=abc'),
        '/api/onuw/games/·/vote/',
      );
      expect(cleanPath('/api/lobbies/QWERTY/join/'), '/api/lobbies/·/join/');
      expect(
        cleanPath('/api/lobbies/qwerty/join/'),
        '/api/lobbies/·/join/',
        reason: 'a lowercase code is no route word either',
      );
      expect(cleanPath('/api/ana-bell/'), '/api/·/');
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
