@Skip(
  'The results phase shows the end board now (end_board_shell_test.dart); '
  'piece 5b deletes 10, 11 and this file.',
)
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/primitives/player_row.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/role_card.dart';
import 'package:midnight_village/design_system/primitives/secondary_button.dart';
import 'package:midnight_village/design_system/primitives/text_action.dart';
import 'package:midnight_village/design_system/primitives/you_tag.dart';
import 'package:midnight_village/features/game/domain/outcome_view.dart';
import 'package:midnight_village/features/game/domain/screen_table.dart';
import 'package:midnight_village/features/game/presentation/shell/count_screen.dart';
import 'package:midnight_village/features/game/presentation/shell/results_screen.dart';
import 'package:midnight_village/features/lobby/presentation/at_table_screen.dart';
import 'package:midnight_village/features/lobby/presentation/deck_screen.dart';
import 'package:midnight_village/features/lobby/presentation/join_screen.dart';

import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/contract/server_json.dart';
import '../../../helpers/mock_http_client.dart';
import '../../../helpers/outcome_samples.dart';
import '../../../helpers/shell_setup.dart';
import '../../../helpers/sheet/end_pages.dart';
import '../../../helpers/game_events.dart';
import '../../../helpers/truncated_text.dart';

// 10 The count and 11 Results through the real shell, on phones at the end
// of recorded games (test/helpers/outcome_samples.dart): every outcome the
// results can hold, the count's motion and its gate, "See who won" and a
// restart, the results failing to load and then arriving, play again, edit
// deck and leave.

/// The shell at the end of [results] on [viewer]'s phone.
Future<ShellSetup> _end(
  WidgetTester tester,
  Map<String, dynamic> results, {
  String viewer = 'Ben',
  String host = 'Ana',
  bool sameDevice = false,
  bool disableAnimations = false,
  void Function(ShellSetup s)? before,
}) async {
  final s = await ShellSetup.pump(
    tester,
    resultsMeFor(results, viewer: viewer, host: host),
    sameDevice: sameDevice,
    disableAnimations: disableAnimations,
    before: (s) {
      s.answerResults(results);
      before?.call(s);
    },
  );
  await s.settle(tester);
  return s;
}

/// Lets the count's rows land and its cards turn.
Future<void> _countDone(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

PrimaryButton _button(WidgetTester tester) =>
    tester.widget<PrimaryButton>(find.byType(PrimaryButton).last);

Future<void> _seeWhoWon(WidgetTester tester, ShellSetup s) async {
  await _countDone(tester);
  await tester.tap(find.text(CountCopy.seeWhoWon));
  await s.settle(tester);
}

/// The screen the table's shell decides ([tableScreenProvider]), checked
/// to be the real one on screen.
AppScreen? _screen(WidgetTester tester, ShellSetup s) {
  final screen = s.screenOn(tester);
  final widget = switch (screen) {
    AppScreen.join => JoinScreen,
    AppScreen.table => AtTableScreen,
    AppScreen.deck => DeckScreen,
    _ => null,
  };
  if (widget != null) expect(find.byType(widget), findsOneWidget);
  return screen;
}

void main() {
  group('10 The count: every outcome, from the results', () {
    testWidgets('one dies: the headline, the card as it ended, the votes '
        'by name, who did not vote', (tester) async {
      final s = await _end(tester, recordedResults('results_doppelganger'));
      await _countDone(tester);
      expect(find.byType(CountView), findsOneWidget);
      expect(find.text('Cleo dies.'), findsOneWidget);
      expect(find.text(CountCopy.now), findsOneWidget);
      expect(find.text(CountCopy.dealt), findsNothing, reason: 'not moved');
      expect(find.text('Werewolf'), findsWidgets);
      expect(find.text('Ana, Ben'), findsOneWidget);
      expect(
        find.text('No vote: Cleo, Dev, Esme, Fin, Gus, Hana'),
        findsOneWidget,
      );
      await s.close(tester);
    });

    testWidgets("the Hunter: two die; the Hunter's pick is named as his, and "
        'only the row the vote killed is outlined', (tester) async {
      final s = await _end(tester, recordedResults('results'));
      await _countDone(tester);
      expect(find.text('Fin dies.'), findsOneWidget);
      expect(find.text("Esme, Fin's pick, dies too."), findsOneWidget);
      // Two cards, each naming its player; "Now" said once.
      expect(find.text('Hunter'), findsOneWidget);
      expect(find.text(CountCopy.now), findsOneWidget);
      final outlined = {
        for (final row in tester.widgetList<PlayerRow>(find.byType(PlayerRow)))
          row.name: row.picked,
      };
      expect(outlined, {'Fin': true, 'Cleo': false, 'Esme': false});
      await s.close(tester);
    });

    testWidgets('a card that moved: Dealt, an arrow, and Now with its team '
        '(the card that counts)', (tester) async {
      final s = await _end(tester, recordedResults('results_moved_dead_card'));
      await _countDone(tester);
      expect(find.text('Ben dies.'), findsOneWidget);
      expect(find.text(CountCopy.dealt), findsOneWidget);
      expect(find.text(CountCopy.now), findsOneWidget);
      expect(find.text('Werewolf'), findsOneWidget);
      expect(find.text('Werewolf team'), findsOneWidget);
      await s.close(tester);
    });

    testWidgets('a Werewolf dies: "Werewolf team" on the tag beside the '
        'role', (tester) async {
      final s = await _end(tester, recordedResults('results_doppelganger'));
      await _countDone(tester);
      expect(find.text('Werewolf team'), findsOneWidget);
      await s.close(tester);
    });

    testWidgets('nobody dies: the fact, no card', (tester) async {
      final s = await _end(tester, recordedResults('results_nobody_dies'));
      await _countDone(tester);
      expect(find.text(CountCopy.nobodyDies), findsOneWidget);
      expect(find.text(CountCopy.nobodyGotTwo), findsOneWidget);
      expect(find.text(CountCopy.now), findsNothing);
      await s.close(tester);
    });

    testWidgets('before it turns, the card already says whose it is and '
        '"Now"; the role comes as it turns', (tester) async {
      final s = await _end(tester, recordedResults('results_doppelganger'));
      expect(find.text(CountCopy.now), findsOneWidget);
      expect(find.text('Cleo'), findsWidgets);
      expect(find.byType(RolePortrait), findsNothing, reason: 'face down');
      await _countDone(tester);
      expect(find.byType(RolePortrait), findsOneWidget);
      await s.close(tester);
    });

    testWidgets('"See who won" is live at once: one tap during the motion '
        'goes straight to 11', (tester) async {
      final s = await _end(tester, recordedResults('results_doppelganger'));
      expect(_button(tester).phase, ButtonPhase.ready);
      await tester.tap(find.text(CountCopy.seeWhoWon));
      await s.settle(tester);
      expect(find.byType(ResultsView), findsOneWidget);
      await s.close(tester);
    });

    testWidgets('any other tap finishes the motion; with reduce motion it '
        'opens finished', (tester) async {
      var s = await _end(tester, recordedResults('results_doppelganger'));
      await tester.tap(find.text('Cleo dies.'));
      await tester.pump();
      expect(find.byType(RolePortrait), findsOneWidget, reason: 'turned');
      await s.close(tester);
      s = await _end(
        tester,
        recordedResults('results_doppelganger'),
        disableAnimations: true,
      );
      expect(find.byType(RolePortrait), findsOneWidget);
      await s.close(tester);
    });

    testWidgets('names are never cut: ten long names at 320, text x2', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 692);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final results = widened(
        recordedResults('results_doppelganger'),
        add: 2,
        rename: longEndNames,
      );
      final s = await ShellSetup.pump(
        tester,
        resultsMeFor(results, viewer: 'Maximiliano', host: 'Christopher'),
        textScale: 2,
        before: (s) => s.answerResults(results),
      );
      await s.settle(tester);
      await _countDone(tester);
      expect(truncatedText(tester), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(CountCopy.seeWhoWon));
      await s.settle(tester);
      expect(find.byType(ResultsView), findsOneWidget);
      expect(truncatedText(tester), isEmpty);
      expect(tester.takeException(), isNull);
      await s.close(tester);
    });
  });

  group('the results load', () {
    testWidgets('failing: the ground and "One moment"; fetched again until '
        'it arrives, then the count', (tester) async {
      final results = recordedResults('results');
      final s = await _end(tester, results, before: (s) => s.failResults());
      expect(find.byType(EndWaiting), findsOneWidget);
      expect(find.text(BannerCopy.offline), findsOneWidget);
      expect(find.byType(CountView), findsNothing);
      s.answerResults(results);
      await s.settle(tester);
      expect(find.byType(CountView), findsOneWidget);
      expect(find.text(BannerCopy.offline), findsNothing);
      await s.close(tester);
    });
  });

  group('11 Results', () {
    testWidgets('"See who won" goes on to 11: who won, and this phone\'s '
        'own result', (tester) async {
      final s = await _end(tester, recordedResults('results'), viewer: 'Ana');
      await _seeWhoWon(tester, s);
      expect(find.byType(ResultsView), findsOneWidget);
      expect(find.text(ResultsCopy.villageWins), findsOneWidget);
      expect(find.text(ResultsCopy.youWon), findsOneWidget);
      // The host's buttons.
      expect(find.text(ResultsCopy.playAgain), findsOneWidget);
      expect(find.text(ResultsCopy.editDeck), findsOneWidget);
      await s.close(tester);
    });

    testWidgets('every winner the samples hold: the Werewolves (a Werewolf '
        'won), the Tanner (alone), nobody dies', (tester) async {
      for (final (results, viewer, headline, you) in [
        (
          recordedResults('results_werewolves_win'),
          'Cleo',
          ResultsCopy.werewolvesWin,
          ResultsCopy.youWon,
        ),
        (
          recordedResults('results_tanner'),
          'Dev',
          ResultsCopy.tannerWins,
          ResultsCopy.youWon,
        ),
        (
          recordedResults('results_tanner'),
          'Ben',
          ResultsCopy.tannerWins,
          ResultsCopy.youLost,
        ),
        (
          recordedResults('results_nobody_dies'),
          'Ben',
          ResultsCopy.werewolvesWin,
          ResultsCopy.youLost,
        ),
      ]) {
        final s = await _end(tester, results, viewer: viewer);
        await _seeWhoWon(tester, s);
        expect(find.text(headline), findsOneWidget, reason: viewer);
        expect(find.text(you), findsOneWidget, reason: viewer);
        // A guest: who deals next, and Leave.
        expect(find.text('Ana deals next.'), findsOneWidget);
        expect(find.text(CommonCopy.leave), findsOneWidget);
        await s.close(tester);
      }
    });

    testWidgets('a guest waits for the next game: "{host} deals next." is the '
        'message, and Leave is a quiet word beside it, never a button', (
      tester,
    ) async {
      final s = await _end(tester, recordedResults('results'), viewer: 'Ben');
      await _seeWhoWon(tester, s);
      final leave = find.widgetWithText(TextAction, CommonCopy.leave);
      expect(leave, findsOneWidget);
      expect(find.byType(SecondaryButton), findsNothing);
      expect(find.byType(PrimaryButton), findsNothing);
      final message = tester.getRect(find.text('Ana deals next.'));
      final word = tester.getRect(leave);
      expect(word.left, greaterThan(message.right), reason: 'beside it');
      expect(word.width, lessThan(message.width), reason: 'the smaller');
      await s.close(tester);
    });

    testWidgets('the night scrolls fully clear of the pinned line: its last '
        'step ends above "{host} deals next."', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = await _end(
        tester,
        recordedResults('results_doppelganger'),
        viewer: 'Ben',
      );
      await _seeWhoWon(tester, s);
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -4000),
      );
      await tester.pumpAndSettle();
      final message = tester.getRect(find.textContaining('deals next.'));
      final last = find.descendant(
        of: find.byType(SingleChildScrollView).first,
        matching: find.byType(RichText),
      );
      final bottom = last
          .evaluate()
          .map((e) => tester.getRect(find.byElementPredicate((x) => x == e)))
          .map((r) => r.bottom)
          .reduce((a, b) => a > b ? a : b);
      expect(bottom, lessThanOrEqualTo(message.top));
      await s.close(tester);
    });

    // The playtest: the night "cut off at the bottom". Scrolled to its
    // end, the whole story is there, the last step fully above the pinned
    // line, at the phone sizes the pack and the gallery use, five and ten
    // at the table, the host's buttons and a guest's line.
    for (final (width, height) in [(390.0, 844.0), (360.0, 640.0)]) {
      for (final game in [EndGame.five, EndGame.tenLong]) {
        final seats = outcomeOf(game.body).seats;
        final guest = seats.firstWhere((s) => s.name != game.host).name;
        for (final viewer in [game.host, guest]) {
          testWidgets('the whole night is reachable: scrolled to the end, its '
              'last step is fully above the pinned line (${width.toInt()} x '
              '${height.toInt()}, ${seats.length} players, '
              '${viewer == game.host ? 'host' : 'guest'})', (tester) async {
            tester.view.physicalSize = Size(width, height);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final s = await _end(
              tester,
              game.body,
              viewer: viewer,
              host: game.host,
            );
            await _seeWhoWon(tester, s);
            await tester.pumpAndSettle();
            final steps = find.byWidgetPredicate(
              (w) => w.runtimeType.toString() == '_Line',
            );
            expect(
              steps,
              findsNWidgets(nightLinesOf(outcomeOf(game.body)).length),
              reason: 'every step of the night is drawn',
            );
            final scroll = find.byType(SingleChildScrollView).first;
            await tester.drag(scroll, const Offset(0, -6000));
            await tester.pumpAndSettle();
            final last = tester.getRect(steps.last);
            final body = tester.getRect(scroll);
            final pinned = viewer == game.host
                ? tester.getRect(find.byType(PrimaryButton).first).top
                : tester.getRect(find.textContaining('deals next.')).top;
            expect(last.top, greaterThanOrEqualTo(body.top));
            expect(last.bottom, lessThanOrEqualTo(body.bottom));
            expect(last.bottom, lessThanOrEqualTo(pinned));
            await s.close(tester);
          });
        }
      }
    }

    testWidgets('"You" marks the viewer on 10 and 11', (tester) async {
      // Fin, voted out, is the viewer: his row on 10 and on 11 say "You".
      final s = await _end(tester, recordedResults('results'), viewer: 'Fin');
      expect(
        find.descendant(
          of: find.widgetWithText(PlayerRow, 'Fin'),
          matching: find.byType(YouTag),
        ),
        findsOneWidget,
      );
      expect(find.byType(YouTag), findsNWidgets(2), reason: 'dead card, row');
      await _seeWhoWon(tester, s);
      expect(find.byType(YouTag), findsOneWidget);
      await s.close(tester);
    });

    testWidgets("each player's card at the end; the dealt one where it moved; "
        'won or died', (tester) async {
      final s = await _end(tester, recordedResults('results'));
      await _seeWhoWon(tester, s);
      // Ana was dealt the Seer and ends with the Troublemaker.
      expect(find.text('Seer'), findsWidgets);
      expect(find.text('Troublemaker'), findsWidgets);
      expect(find.text(ResultsCopy.died), findsNWidgets(2));
      expect(find.text(ResultsCopy.won), findsNWidgets(4));
      expect(find.text('Center: Villager, Insomniac, Villager'), findsOne);
      await s.close(tester);
    });

    testWidgets('the night is open: the red line where the Werewolf card '
        'went, a line per step (at once with reduce motion); a tap on the '
        'red line folds the steps', (tester) async {
      final s = await _end(
        tester,
        recordedResults('results_doppelganger'),
        disableAnimations: true,
      );
      await tester.tap(find.text(CountCopy.seeWhoWon));
      await s.settle(tester);
      // The Werewolf card the Drunk took: from Left to Gus.
      expect(find.text('Left'), findsWidgets);
      expect(find.text('Gus'), findsWidgets);
      for (final line in [
        'Ana copies Ben.',
        'Ana sees Left, Right.',
        'Gus takes Left.',
        'Hana sees own card.',
      ]) {
        expect(find.textContaining(line, findRichText: true), findsOneWidget);
      }
      final night = find.bySemanticsLabel(ResultsCopy.nightSpoken);
      await tester.ensureVisible(night);
      await tester.pump();
      await tester.tap(night);
      await tester.pump();
      expect(
        find.textContaining('Gus takes Left.', findRichText: true),
        findsNothing,
      );
      await s.close(tester);
    });

    testWidgets('the host\'s buttons stack when "Play again" would not fit on '
        'one line (320, text x1.3); side by side at 320 and 390', (
      tester,
    ) async {
      Future<bool> stacked(double width, double scale) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        final s = await ShellSetup.pump(
          tester,
          resultsMeFor(recordedResults('results'), viewer: 'Ana', host: 'Ana'),
          textScale: scale,
          disableAnimations: true,
          before: (s) => s.answerResults(recordedResults('results')),
        );
        await s.settle(tester);
        await tester.tap(find.text(CountCopy.seeWhoWon));
        await s.settle(tester);
        final play = tester.getRect(find.byType(PrimaryButton));
        final edit = tester.getRect(find.byType(SecondaryButton));
        final label = tester.getRect(find.text(ResultsCopy.playAgain));
        // One line, never wrapped.
        expect(
          label.height,
          lessThan(
            2 *
                (tester
                        .widget<Text>(find.text(ResultsCopy.playAgain))
                        .style!
                        .fontSize! *
                    scale),
          ),
        );
        await s.close(tester);
        return edit.top >= play.bottom;
      }

      addTearDown(tester.view.reset);
      expect(await stacked(390, 1), isFalse);
      expect(await stacked(320, 1), isFalse);
      expect(await stacked(320, 1.3), isTrue);
      expect(await stacked(390, 1.6), isTrue);
    });

    testWidgets('a guest whose host is not at the table hears nothing about '
        'who deals', (tester) async {
      final results = recordedResults('results');
      final me = resultsMeFor(results, viewer: 'Ben', host: 'Ana');
      me['host_id'] = 999;
      final s = await ShellSetup.pump(
        tester,
        me,
        disableAnimations: true,
        before: (s) => s.answerResults(results),
      );
      await s.settle(tester);
      await tester.tap(find.text(CountCopy.seeWhoWon));
      await s.settle(tester);
      expect(find.textContaining('deals next'), findsNothing);
      expect(find.text(CommonCopy.leave), findsOneWidget);
      await s.close(tester);
    });

    testWidgets('the host role moves to this phone (host_changed): 11 gives '
        'it "Play again" at once', (tester) async {
      final results = recordedResults('results');
      final s = await _end(tester, results, disableAnimations: true);
      await _seeWhoWon(tester, s);
      expect(find.text(ResultsCopy.playAgain), findsNothing, reason: 'a guest');
      final me = s.me;
      s.ws.addServerEvent(
        GameEvents.hostChanged(
          hostId: me['player_id'] as int,
          hostName: 'Ben',
          originalHostId: me['host_id'] as int,
        ),
      );
      await s.settle(tester);
      expect(find.text(ResultsCopy.playAgain), findsOneWidget);
      await s.close(tester);
    });

    testWidgets('the count remembers it has knocked for this game, so a count '
        'opened again on it is quiet', (tester) async {
      final s = await _end(tester, recordedResults('results_doppelganger'));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CountView)),
      );
      expect(container.read(knockedCountsProvider), isEmpty);
      await _countDone(tester);
      expect(container.read(knockedCountsProvider), {s.gameId});
      await s.close(tester);
    });

    testWidgets('a restart after "See who won" lands on 11; one before it on '
        '10', (tester) async {
      final results = recordedResults('results');
      var s = await _end(tester, results);
      await _seeWhoWon(tester, s);
      expect(find.byType(ResultsView), findsOneWidget);
      await s.close(tester);

      s = await _end(tester, results, sameDevice: true);
      expect(find.byType(ResultsView), findsOneWidget);
      expect(find.byType(CountView), findsNothing);
      await s.close(tester);

      // Another device, which never went on: 10.
      s = await _end(tester, results);
      expect(find.byType(CountView), findsOneWidget);
      await s.close(tester);
    });
  });

  group('after the game', () {
    String code(ShellSetup s) => s.me['lobby_code'] as String;

    /// `/me/table/` after play again: the table waits for its next deal; 02
    /// reads the lobby (a recorded table, waiting).
    Map<String, dynamic> waiting(ShellSetup s, {required bool host}) {
      s.answerLobby(code(s));
      return serverMyTable(
        code: code(s),
        isHost: host,
        gameId: s.gameId,
        phase: 'results',
      );
    }

    testWidgets('the host plays again: the table waits, and the phone goes '
        'to 02', (tester) async {
      final s = await _end(tester, recordedResults('results'), viewer: 'Ana');
      await _seeWhoWon(tester, s);
      s.http.answer('POST', '/lobbies/${code(s)}/play-again/', s.playedAgain());
      s.answerTable(waiting(s, host: true));
      final from = s.http.requests.length;
      await tester.tap(find.text(ResultsCopy.playAgain));
      // Frames only, no time passing (the table's slow poll never comes due).
      for (
        var i = 0;
        i < 200 && find.byType(AtTableView).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(Duration.zero);
      }
      expect(_screen(tester, s), AppScreen.table);
      expect(find.byType(AtTableView), findsOneWidget);
      // The answer is the table and where the host sits: nothing is read
      // after it (no /me/table/, no lobby).
      expect(
        [for (final r in s.http.requests.skip(from)) '${r.method} ${r.path}'],
        ['POST /lobbies/${code(s)}/play-again/'],
      );
      await s.close(tester);
    });

    testWidgets('every other phone hears it and goes to 02 too', (
      tester,
    ) async {
      final s = await _end(tester, recordedResults('results'));
      await _seeWhoWon(tester, s);
      s.answerTable(waiting(s, host: false));
      s.ws.addServerEvent(ContractSamples.map('ws/game/play_again'));
      await s.settle(tester);
      expect(_screen(tester, s), AppScreen.table);
      await s.close(tester);
    });

    testWidgets('a guest still on the count goes to 02 as well (no step '
        'strands it)', (tester) async {
      final s = await _end(tester, recordedResults('results'));
      s.answerTable(waiting(s, host: false));
      s.ws.addServerEvent(ContractSamples.map('ws/game/play_again'));
      await s.settle(tester);
      expect(_screen(tester, s), AppScreen.table);
      await s.close(tester);
    });

    testWidgets('"Edit deck": play again, then 03 on the host\'s phone', (
      tester,
    ) async {
      final s = await _end(tester, recordedResults('results'), viewer: 'Ana');
      await _seeWhoWon(tester, s);
      s.http.answer('POST', '/lobbies/${code(s)}/play-again/', s.playedAgain());
      s.answerTable(waiting(s, host: true));
      await tester.tap(find.text(ResultsCopy.editDeck));
      await s.settle(tester);
      expect(_screen(tester, s), AppScreen.deck);
      await s.close(tester);
    });

    testWidgets('play again that gets no answer: "Not sent." and Try again; '
        'nothing moves until it lands', (tester) async {
      final s = await _end(tester, recordedResults('results'), viewer: 'Ana');
      await _seeWhoWon(tester, s);
      final path = '/lobbies/${code(s)}/play-again/';
      s.http.answer('POST', path, 'Server Error', status: 503);
      await tester.tap(find.text(ResultsCopy.playAgain));
      await s.settle(tester);
      expect(find.text(BannerCopy.notSent), findsOneWidget);
      expect(find.byType(ResultsView), findsOneWidget);
      s.http.answer('POST', path, s.playedAgain());
      s.answerTable(waiting(s, host: true));
      await tester.tap(find.text(BannerCopy.tryAgain));
      await s.settle(tester);
      expect(_screen(tester, s), AppScreen.table);
      await s.close(tester);
    });

    for (final (what, endpoint, sample, viewer, tap) in [
      (
        'play again',
        'play-again',
        'play_again_not_found',
        'Ana',
        ResultsCopy.playAgain,
      ),
      ('leave', 'leave', 'leave_not_found', 'Ben', CommonCopy.leave),
    ]) {
      testWidgets('the table closed while on 11: $what answered 404 is 01 '
          'with "This table has closed.", never "Not sent."', (tester) async {
        final s = await _end(
          tester,
          recordedResults('results'),
          viewer: viewer,
        );
        await _seeWhoWon(tester, s);
        s.http.answer(
          'POST',
          '/lobbies/${code(s)}/$endpoint/',
          ContractSamples.load('http/lobby/$sample'),
          status: 404,
        );
        s
          ..answerTable(ContractSamples.map('http/lobby/my_table_none'))
          ..answerHome();
        await tester.tap(find.text(tap));
        await s.settle(tester);
        expect(_screen(tester, s), AppScreen.join);
        expect(find.text(BannerCopy.tableClosed), findsOneWidget);
        expect(find.text(BannerCopy.notSent), findsNothing);
        await s.close(tester);
      });
    }

    testWidgets('a screen reader reaches "See who won" and Leave: the '
        'screen-wide tap that finishes the motion is no button of its own', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final s = await _end(tester, recordedResults('results'));
      await _countDone(tester);
      tester.semantics.tap(find.semantics.byLabel(CountCopy.seeWhoWon));
      await s.settle(tester);
      expect(_screen(tester, s), AppScreen.results);

      s.http.answer(
        'POST',
        '/lobbies/${code(s)}/leave/',
        ContractSamples.load('http/lobby/left'),
      );
      s
        ..answerTable(ContractSamples.map('http/lobby/my_table_none'))
        ..answerHome();
      tester.semantics.tap(find.semantics.byLabel(CommonCopy.leave));
      await s.settle(tester);
      expect(_screen(tester, s), AppScreen.join);
      await s.close(tester);
      semantics.dispose();
    });

    testWidgets('a guest leaves: back to 01', (tester) async {
      final s = await _end(tester, recordedResults('results'));
      await _seeWhoWon(tester, s);
      s.http.answer(
        'POST',
        '/lobbies/${code(s)}/leave/',
        ContractSamples.load('http/lobby/left'),
      );
      s
        ..answerTable(ContractSamples.map('http/lobby/my_table_none'))
        ..answerHome();
      await tester.tap(find.text(CommonCopy.leave));
      await s.settle(tester);
      expect(_screen(tester, s), AppScreen.join);
      await s.close(tester);
    });
  });
}
