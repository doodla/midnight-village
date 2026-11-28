import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/perf/perf.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';

import '../../helpers/finger.dart';
import '../../helpers/shell_setup.dart';

/// A recorder that throws from every hook and every mark: what a mistake in
/// the recorder would be. The app must not notice it.
final class _Throwing implements PerfRecorder {
  @override
  bool get on => throw StateError('on');
  @override
  HttpMark? httpQueued() => _ThrowingMark();
  @override
  RequestMark? playerRequestStarted() => _ThrowingRequest();
  @override
  void socketMessage(String url, Object? message) => throw StateError('m');
  @override
  void socketState(String url, Enum state) => throw StateError('s');
  @override
  void screen(Object place) => throw StateError('screen');
  @override
  void waitingShown() => throw StateError('w');
  @override
  void waitingGone() => throw StateError('w');
}

final class _ThrowingMark implements HttpMark {
  @override
  void left(RequestOptions? options) => throw StateError('left');
  @override
  void arrived(int status, Map<String, List<String>> headers) =>
      throw StateError('arrived');
  @override
  Future<T> watch<T>(Future<T> sent) =>
      sent.then((_) => throw StateError('watched'));
}

final class _ThrowingRequest implements RequestMark {
  @override
  void applied() => throw StateError('applied');
}

/// 08's "Ready to vote" pressed, its answer in: every word on screen after.
Future<List<String>> _readyTapped(WidgetTester tester) async {
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
  await pressLikeAFinger(tester, find.byType(PrimaryButton).last);
  await s.settle(tester);
  final words = [
    for (final text in tester.widgetList<RichText>(find.byType(RichText)))
      text.text.toPlainText(),
  ];
  expect(s.posts('/ready/'), 1, reason: 'the tap was sent, once');
  await s.close(tester);
  return words;
}

void main() {
  test('a recorder that throws is reached only through the guard: no hook '
      'and no mark lets it through, and a request\'s answer is passed on as '
      'it came', () async {
    Perf.recorder = _Throwing();
    addTearDown(() => Perf.recorder = const PerfOff());
    final r = Perf.recorder;
    expect(r, isA<GuardedRecorder>());
    expect(r.on, isFalse);
    r
      ..socketMessage('/ws/game/1/', '{}')
      ..socketState('/ws/game/1/', TestEnum.one)
      ..screen('talk')
      ..waitingShown()
      ..waitingGone();
    final mark = r.httpQueued()!
      ..left(null)
      ..arrived(200, const {});
    expect(await mark.watch(Future.value(42)), 42);
    await expectLater(
      mark.watch(Future<int>.error(ArgumentError('the server said no'))),
      throwsArgumentError,
      reason: 'a failure is the app\'s own failure, not the recorder\'s',
    );
    r.playerRequestStarted()!.applied();
  });

  test('off stays the constant, never wrapped', () {
    Perf.recorder = const PerfOff();
    expect(Perf.recorder, same(const PerfOff()));
  });

  testWidgets('with a recorder that throws everywhere, a tap does exactly '
      'what it does with the recorder off', (tester) async {
    final off = await _readyTapped(tester);

    Perf.recorder = _Throwing();
    addTearDown(() => Perf.recorder = const PerfOff());
    final throwing = await _readyTapped(tester);

    expect(throwing, off);
  });
}

enum TestEnum { one }
