import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';
import 'package:midnight_village/features/game/domain/screen_table.dart';
import 'package:midnight_village/features/game/presentation/end/end_board_view.dart';
import 'package:midnight_village/features/game/presentation/end/end_reveal.dart';
import 'package:midnight_village/features/game/presentation/shell/end_screen.dart';
import 'package:midnight_village/features/game/presentation/shell/vote_screen.dart';
import 'package:midnight_village/features/game/presentation/shell/waits.dart'
    show EndWaiting;

import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/contract/server_json.dart';
import '../../../helpers/game_events.dart';
import '../../../helpers/mock_http_client.dart';
import '../../../helpers/outcome_samples.dart';
import '../../../helpers/shell_setup.dart';

// The results phase through the real shell: the end board in place of 10 and
// 11. A phone that opens at the results gets the settled board; one that was
// at the vote watches the reveal, once (the latch: a refetch, a turned phone,
// What happened, a failed request or a second board of the same result never
// replays it). Every action of 11 is here, with a real press, and the table
// moving on (play again, the host leaving, a new game) never strands a board.

const _ms = Duration(milliseconds: 16);

/// The shell opened at the end of [results] on [viewer]'s phone: a late
/// arrival, so the board is settled.
Future<ShellSetup> _late(
  WidgetTester tester,
  Map<String, dynamic> results, {
  String viewer = 'Ben',
  Set<Cue> learned = const {...Cue.values},
  void Function(ShellSetup s)? before,
}) async {
  final s = await ShellSetup.pump(
    tester,
    resultsMeFor(results, viewer: viewer, host: 'Ana'),
    learned: learned,
    before: (s) {
      s.answerResults(results);
      before?.call(s);
    },
  );
  await s.settle(tester);
  return s;
}

/// The shell at the vote; then voting ends and [viewer]'s phone goes on to
/// the end board, its reveal just begun.
Future<ShellSetup> _fromVote(
  WidgetTester tester,
  Map<String, dynamic> results, {
  String viewer = 'Ben',
}) async {
  final s = await ShellSetup.pump(
    tester,
    recordedMe('me_voting_locked'),
    learned: Cue.values.toSet(),
    before: (s) => s.answerResults(results),
  );
  await s.settle(tester);
  expect(find.byType(VoteScreen), findsOneWidget);
  s.answerMe(resultsMeFor(results, viewer: viewer, host: 'Ana'));
  s.resume();
  for (var i = 0; i < 60 && _driver(tester) == null; i++) {
    await tester.pump(_ms);
  }
  return s;
}

/// The reveal's clock while it plays; null once the board is settled.
EndRevealDriver? _driver(WidgetTester tester) {
  final scope = find.byType(EndRevealScope);
  if (scope.evaluate().isEmpty) return null;
  return tester.widget<EndRevealScope>(scope.first).driver;
}

/// A finger's press: down, a frame, up.
Future<void> _press(WidgetTester tester, Finder target) async {
  final gesture = await tester.startGesture(tester.getCenter(target.first));
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(EndScreen)));

String _code(ShellSetup s) => s.me['lobby_code'] as String;

/// `/me/table/` after play again: the table waits for its next deal; 02 reads
/// the lobby (a recorded table, waiting).
Map<String, dynamic> _waiting(ShellSetup s, {required bool host}) {
  s.answerLobby(_code(s));
  return serverMyTable(
    code: _code(s),
    isHost: host,
    gameId: s.gameId,
    phase: 'results',
  );
}

/// Frames only, no time passing (the table's slow poll never comes due),
/// until the phone is at [screen].
Future<void> _until(WidgetTester tester, ShellSetup s, AppScreen screen) async {
  for (var i = 0; i < 200 && s.screenOn(tester) != screen; i++) {
    await tester.pump(Duration.zero);
  }
}

void main() {
  group('the results phase is the end board', () {
    testWidgets('a phone that opens at the results: the settled board, no '
        'count and no "See who won"', (tester) async {
      final s = await _late(tester, recordedResults('results'));
      expect(s.screenOn(tester), AppScreen.end);
      expect(find.byType(EndBoardView), findsOneWidget);
      expect(
        tester.widget<EndBoardView>(find.byType(EndBoardView)).reveal,
        false,
      );
      expect(_driver(tester), isNull);
      await s.close(tester);
    });

    testWidgets('the results failing to load: the wait and "One moment"; '
        'fetched again until they come, then the board', (tester) async {
      final results = recordedResults('results');
      final s = await _late(tester, results, before: (s) => s.failResults());
      expect(find.byType(EndWaiting), findsOneWidget);
      expect(find.text(BannerCopy.offline), findsOneWidget);
      s.answerResults(results);
      await s.settle(tester);
      expect(find.byType(EndBoardView), findsOneWidget);
      expect(find.text(BannerCopy.offline), findsNothing);
      await s.close(tester);
    });

    testWidgets('from the vote: the reveal plays, then the board settles by '
        'itself and the latch will not play it again', (tester) async {
      final s = await _fromVote(tester, recordedResults('results'));
      expect(s.screenOn(tester), AppScreen.end);
      final driver = _driver(tester);
      expect(driver, isNotNull, reason: 'the reveal plays');
      await tester.pump(driver!.reveal!.total + Motion.settle);
      await tester.pump();
      expect(_driver(tester), isNull);
      // A board of this result built again (a remount) asks the latch.
      expect(
        _container(tester).read(endRevealLatchProvider).take(s.gameId),
        isFalse,
      );
      await s.close(tester);
    });
  });

  group('the reveal plays once per result on this phone', () {
    test('the latch: once per game, and only for a phone in the game', () {
      final latch = EndRevealLatch()..inPlay('a');
      expect(latch.take('b'), isFalse, reason: 'opened late');
      expect(latch.take('b'), isFalse);
      expect(latch.take('a'), isTrue);
      expect(latch.take('a'), isFalse, reason: 'a remount');
      latch.inPlay('c');
      expect(latch.take('c'), isTrue, reason: 'the next game at the table');
    });

    testWidgets('the same results fetched again mid-reveal (a reconnect): '
        'the same board, its clock going on, never back to the start', (
      tester,
    ) async {
      final s = await _fromVote(tester, recordedResults('results'));
      await tester.pump(const Duration(milliseconds: 300));
      final state = tester.state(find.byType(EndBoardView));
      final at = _driver(tester)!.now;
      s.socket(connected: false);
      s.socket(connected: true);
      s.resume();
      for (var i = 0; i < 6; i++) {
        await tester.pump(_ms);
      }
      expect(tester.state(find.byType(EndBoardView)), same(state));
      final driver = _driver(tester);
      if (driver != null) expect(driver.now, greaterThan(at));
      await s.close(tester);
    });

    testWidgets('a turned phone mid-reveal settles it; turned back, nothing '
        'replays', (tester) async {
      final s = await _fromVote(tester, recordedResults('results'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(_driver(tester), isNotNull);
      final size = tester.view.physicalSize;
      tester.view.physicalSize = Size(size.height, size.width);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pump();
      await tester.pump();
      expect(_driver(tester), isNull);
      tester.view.physicalSize = size;
      await s.settle(tester);
      expect(_driver(tester), isNull);
      await s.close(tester);
    });

    testWidgets('What happened mid-reveal, and back to the result: the '
        'settled board, no replay; a failed Edit deck stays settled too', (
      tester,
    ) async {
      final s = await _fromVote(
        tester,
        recordedResults('results'),
        viewer: 'Ana',
      );
      await _press(tester, find.bySemanticsLabel(EndCopy.whatHappened));
      await s.settle(tester);
      expect(_driver(tester), isNull);
      await _press(tester, find.bySemanticsLabel(EndCopy.backToResult));
      await s.settle(tester);
      expect(_driver(tester), isNull);
      s.http.answer(
        'POST',
        '/lobbies/${_code(s)}/play-again/',
        'Server Error',
        status: 503,
      );
      await _press(tester, find.text(EndCopy.editDeck));
      await s.settle(tester);
      expect(find.text(BannerCopy.notSent), findsOneWidget);
      expect(s.screenOn(tester), AppScreen.end);
      expect(_driver(tester), isNull);
      await s.close(tester);
    });
  });

  group('the table moves on: no stuck board, no stale board', () {
    testWidgets('play again from the host while the reveal plays: this '
        'phone goes to 02', (tester) async {
      final s = await _fromVote(tester, recordedResults('results'));
      await tester.pump(const Duration(milliseconds: 300));
      s.answerTable(_waiting(s, host: false));
      s.ws.addServerEvent(ContractSamples.map('ws/game/play_again'));
      await s.settle(tester);
      expect(s.screenOn(tester), AppScreen.table);
      expect(find.byType(EndBoardView), findsNothing);
      await s.close(tester);
    });

    testWidgets('play again while What happened plays: 02', (tester) async {
      final s = await _late(tester, recordedResults('results'));
      await _press(tester, find.bySemanticsLabel(EndCopy.whatHappened));
      await tester.pump(const Duration(milliseconds: 100));
      s.answerTable(_waiting(s, host: false));
      s.ws.addServerEvent(ContractSamples.map('ws/game/play_again'));
      await s.settle(tester);
      expect(s.screenOn(tester), AppScreen.table);
      await s.close(tester);
    });

    testWidgets('the host leaves mid-reveal and the role moves to this '
        'phone: "Play again" at once, the same board, settled in its time', (
      tester,
    ) async {
      final s = await _fromVote(tester, recordedResults('results'));
      await tester.pump(const Duration(milliseconds: 300));
      final state = tester.state(find.byType(EndBoardView));
      expect(find.text(EndCopy.playAgain), findsNothing, reason: 'a guest');
      final me = resultsMeFor(
        recordedResults('results'),
        viewer: 'Ben',
        host: 'Ana',
      );
      s.ws.addServerEvent(
        GameEvents.hostChanged(
          hostId: me['player_id'] as int,
          hostName: 'Ben',
          originalHostId: me['host_id'] as int,
        ),
      );
      await s.settle(tester);
      expect(find.text(EndCopy.playAgain), findsOneWidget);
      expect(tester.state(find.byType(EndBoardView)), same(state));
      await tester.pump(const Duration(seconds: 4));
      expect(_driver(tester), isNull, reason: 'never stuck mid-reveal');
      await s.close(tester);
    });

    testWidgets('the next game is dealt at the table: the old board is gone, '
        'and the new game will have its own reveal', (tester) async {
      final s = await _late(tester, recordedResults('results'));
      final next = recordedMe('me_choose_prompt_drunk');
      final nextId = next['game_id'] as String;
      expect(nextId, isNot(s.gameId));
      final latch = _container(tester).read(endRevealLatchProvider);
      s.http.answer('GET', '/onuw/games/$nextId/me/', next);
      s.answerTable(
        serverMyTable(
          code: next['lobby_code'] as String,
          status: 'in_game',
          isHost: false,
          gameId: nextId,
          phase: 'night',
        ),
      );
      s.resume();
      await s.settle(tester);
      expect(find.byType(EndBoardView), findsNothing);
      expect(s.screenOn(tester), AppScreen.nightBoard);
      expect(latch.take(nextId), isTrue);
      await s.close(tester);
    });
  });

  group('every action of 11, on the board, with a real press', () {
    testWidgets('the host plays again: one request, and 02', (tester) async {
      final s = await _late(tester, recordedResults('results'), viewer: 'Ana');
      s.http.answer(
        'POST',
        '/lobbies/${_code(s)}/play-again/',
        s.playedAgain(),
      );
      s.answerTable(_waiting(s, host: true));
      final from = s.http.requests.length;
      await _press(tester, find.text(EndCopy.playAgain));
      await _until(tester, s, AppScreen.table);
      expect(s.screenOn(tester), AppScreen.table);
      expect(
        [for (final r in s.http.requests.skip(from)) '${r.method} ${r.path}'],
        ['POST /lobbies/${_code(s)}/play-again/'],
      );
      await s.close(tester);
    });

    testWidgets('"Edit deck": play again, then 03 on the host\'s phone', (
      tester,
    ) async {
      final s = await _late(tester, recordedResults('results'), viewer: 'Ana');
      s.http.answer(
        'POST',
        '/lobbies/${_code(s)}/play-again/',
        s.playedAgain(),
      );
      s.answerTable(_waiting(s, host: true));
      await _press(tester, find.text(EndCopy.editDeck));
      await s.settle(tester);
      expect(s.screenOn(tester), AppScreen.deck);
      await s.close(tester);
    });

    testWidgets('play again with no answer: "Not sent." and Try again on '
        'the foot; the board stays until it lands', (tester) async {
      final s = await _late(tester, recordedResults('results'), viewer: 'Ana');
      final path = '/lobbies/${_code(s)}/play-again/';
      s.http.answer('POST', path, 'Server Error', status: 503);
      await _press(tester, find.text(EndCopy.playAgain));
      await s.settle(tester);
      expect(find.text(BannerCopy.notSent), findsOneWidget);
      expect(find.byType(EndBoardView), findsOneWidget);
      expect(
        tester.widget<PrimaryButton>(find.byType(PrimaryButton).last).busy,
        isFalse,
      );
      s.http.answer('POST', path, s.playedAgain());
      s.answerTable(_waiting(s, host: true));
      await _press(tester, find.text(BannerCopy.tryAgain));
      await s.settle(tester);
      expect(s.screenOn(tester), AppScreen.table);
      await s.close(tester);
    });

    for (final (what, endpoint, sample, viewer, tap) in [
      (
        'play again',
        'play-again',
        'play_again_not_found',
        'Ana',
        EndCopy.playAgain,
      ),
      ('leave', 'leave', 'leave_not_found', 'Ben', EndCopy.leave),
    ]) {
      testWidgets('the table closed: $what answered 404 is 01 with "This '
          'table has closed.", never "Not sent."', (tester) async {
        final s = await _late(
          tester,
          recordedResults('results'),
          viewer: viewer,
        );
        s.http.answer(
          'POST',
          '/lobbies/${_code(s)}/$endpoint/',
          ContractSamples.load('http/lobby/$sample'),
          status: 404,
        );
        s
          ..answerTable(ContractSamples.map('http/lobby/my_table_none'))
          ..answerHome();
        await _press(tester, find.text(tap));
        await s.settle(tester);
        expect(s.screenOn(tester), AppScreen.join);
        expect(find.text(BannerCopy.tableClosed), findsOneWidget);
        expect(find.text(BannerCopy.notSent), findsNothing);
        await s.close(tester);
      });
    }

    testWidgets('a guest: who deals next and "Leave", no "Play again"; '
        'Leave goes to 01', (tester) async {
      final s = await _late(tester, recordedResults('results'));
      expect(find.text('Ana deals next.'), findsOneWidget);
      expect(find.text(EndCopy.playAgain), findsNothing);
      expect(find.text(EndCopy.editDeck), findsNothing);
      s.http.answer(
        'POST',
        '/lobbies/${_code(s)}/leave/',
        ContractSamples.load('http/lobby/left'),
      );
      s
        ..answerTable(ContractSamples.map('http/lobby/my_table_none'))
        ..answerHome();
      await _press(tester, find.text(EndCopy.leave));
      await s.settle(tester);
      expect(s.screenOn(tester), AppScreen.join);
      await s.close(tester);
    });

    testWidgets('What happened: the night on the board, "Go on" the first '
        'time, learned on this device by the first step', (tester) async {
      final s = await _late(
        tester,
        recordedResults('results'),
        learned: const {},
      );
      await _press(tester, find.bySemanticsLabel(EndCopy.whatHappened));
      await s.settle(tester);
      expect(find.text(StoryCopy.dealt), findsOneWidget);
      expect(find.text(StoryCopy.goOn), findsOneWidget);
      final learned = _container(tester).read(learnedCuesProvider.notifier);
      await tester.tapAt(const Offset(180, 300));
      await s.settle(tester);
      expect(find.text(StoryCopy.goOn), findsNothing);
      expect(learned.state, contains(Cue.endStep));
      await _press(tester, find.bySemanticsLabel(EndCopy.backToResult));
      await s.settle(tester);
      expect(find.bySemanticsLabel(EndCopy.whatHappened), findsOneWidget);
      await s.close(tester);
    });

    testWidgets('a screen reader reaches What happened and Leave', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final s = await _late(tester, recordedResults('results'));
      tester.semantics.tap(find.semantics.byLabel(EndCopy.whatHappened));
      await s.settle(tester);
      expect(find.bySemanticsLabel(EndCopy.backToResult), findsOneWidget);
      s.http.answer(
        'POST',
        '/lobbies/${_code(s)}/leave/',
        ContractSamples.load('http/lobby/left'),
      );
      s
        ..answerTable(ContractSamples.map('http/lobby/my_table_none'))
        ..answerHome();
      tester.semantics.tap(find.semantics.byLabel(EndCopy.leave));
      await s.settle(tester);
      expect(s.screenOn(tester), AppScreen.join);
      await s.close(tester);
      semantics.dispose();
    });
  });

  testWidgets('nothing on the board vibrates for a late arrival', (
    tester,
  ) async {
    final buzzes = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          buzzes.add(call.arguments as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final s = await _late(tester, recordedResults('results'));
    await tester.pump(const Duration(seconds: 3));
    expect(buzzes, isEmpty);
    await s.close(tester);
  });
}
