import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/perf/field_beacon.dart';
import 'package:midnight_village/core/perf/field_recorder.dart';
import 'package:midnight_village/design_system/perf/perf_strip.dart';

import 'perf_kit.dart';

double _now(WidgetTester tester) =>
    tester.binding.clock.now().microsecondsSinceEpoch / 1000;

/// A recorder on the test's clock, with one request answered just now.
Future<FieldRecorder> _asked(WidgetTester tester) async {
  final recorder = FieldRecorder(
    now: () => _now(tester),
    controlAt: (_, _) => null,
  );
  final mark = recorder.httpQueued()!;
  mark.left(RequestOptions(path: gameMe(0)));
  mark.arrived(200, const {});
  await mark.watch(Future.value(null));
  return recorder;
}

FieldBeacon _beacon(FieldRecorder recorder, List<String> sent) => FieldBeacon(
  recorder: recorder,
  commit: 'faf62a1',
  send: (s) {
    sent.add(s);
    return true;
  },
);

const _second = Duration(seconds: 1);

void main() {
  testWidgets('at the end board it sends once the phone has been at rest a '
      'second, not in the frame that shows it, then forgets what it sent', (
    tester,
  ) async {
    final sent = <String>[];
    final recorder = await _asked(tester);
    final beacon = _beacon(recorder, sent);

    beacon.screenShown('vote');
    await tester.pump(_second * 3);
    expect(sent, isEmpty, reason: 'only the end board sends');

    beacon.screenShown(FieldBeacon.endBoard);
    expect(sent, isEmpty, reason: 'never as it is shown');
    await tester.pump(_second);
    expect(sent, hasLength(1));
    expect(jsonDecode(sent.single), containsPair('end', 'end_board'));
    expect(recorder.requests, isEmpty, reason: 'what was sent is forgotten');

    beacon.hidden();
    expect(sent, hasLength(1), reason: 'nothing new: nothing sent');
  });

  testWidgets('while someone touches the end board (Play again, a socket '
      'message) it waits, a second at a time, and sends once all is quiet', (
    tester,
  ) async {
    final sent = <String>[];
    final recorder = await _asked(tester);
    final beacon = _beacon(recorder, sent);

    beacon.screenShown(FieldBeacon.endBoard);
    await tester.pump(const Duration(milliseconds: 900));
    recorder.socketMessage('/ws/game/1/', '{"type":"progress"}');
    await tester.pump(_second);
    expect(sent, isEmpty, reason: 'busy a moment ago');
    await tester.pump(_second);
    expect(sent, hasLength(1));
  });

  testWidgets('leaving the end board first leaves the summary for the next '
      'send', (tester) async {
    final sent = <String>[];
    final recorder = await _asked(tester);
    final beacon = _beacon(recorder, sent);

    beacon.screenShown(FieldBeacon.endBoard);
    await tester.pump(const Duration(milliseconds: 500));
    beacon.screenShown('table');
    await tester.pump(_second * 3);

    expect(sent, isEmpty);
    expect(recorder.requests, hasLength(1), reason: 'kept for the next');
  });

  test('reads what the phone says about itself once, with the first '
      'summary, never before', () async {
    var reads = 0;
    final sent = <String>[];
    final recorder = await recorderWithRequests(pollThenEvent);
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
    expect((jsonDecode(sent.single) as Map)['env'], {'renderer': 'canvaskit'});
  });

  test(
    'after each summary the browser forgets its records of requests',
    () async {
      var cleared = 0;
      final recorder = await recorderWithRequests(pollThenEvent);
      FieldBeacon(
        recorder: recorder,
        commit: 'faf62a1',
        send: (_) => true,
        sent: () => cleared++,
      ).hidden();
      expect(cleared, 1);
    },
  );

  test('the recorder tells it every new screen, once', () {
    final shown = <String>[];
    final recorder = FieldRecorder(now: () => 0, controlAt: (_, _) => null)
      ..screenChanged = shown.add;
    recorder.screen('vote');
    recorder.screen('vote');
    recorder.screen(FieldBeacon.endBoard);
    expect(shown, ['vote', FieldBeacon.endBoard]);
  });

  test('a tab hidden while nothing but polls went out sends nothing: they '
      'go with the next summary', () async {
    final sent = <String>[];
    final recorder = await recorderWithRequests([
      (gap: 0, round: 100, total: 50, connect: 10),
      (gap: 5000, round: 100, total: 50, connect: 10),
    ]);
    expect(recorder.requests.every((q) => q.isPoll), isTrue);
    _beacon(recorder, sent).hidden();
    expect(sent, isEmpty);
    expect(recorder.requests, hasLength(2), reason: 'kept for the next');
  });

  test('sends what was recorded when the tab is hidden', () async {
    final sent = <String>[];
    final recorder = await recorderWithRequests(pollThenEvent);
    _beacon(recorder, sent).hidden();
    expect(jsonDecode(sent.single), containsPair('end', 'hidden'));
  });

  test(
    'a send that throws changes nothing: the beacon says it sent none',
    () async {
      final recorder = await recorderWithRequests(pollThenEvent);
      final beacon = FieldBeacon(
        recorder: recorder,
        commit: 'faf62a1',
        send: (_) => throw StateError('no beacon here'),
      );
      expect(beacon.flush('hidden'), isFalse);
      expect(beacon.hidden, returnsNormally);
    },
  );

  test('a test build (no commit) runs no quiet recorder at all', () {
    expect(
      quietField,
      const bool.fromEnvironment('FIELD_QUIET'),
      reason: 'only a run that asks for it (FIELD_QUIET)',
    );
  });
}
