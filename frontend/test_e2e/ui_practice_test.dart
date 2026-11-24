@Tags(['e2e'])
library;

import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/debug/debug_models.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/value_stepper.dart';
import 'package:midnight_village/design_system/primitives/you_tag.dart';
import 'package:midnight_village/features/auth/domain/auth_state.dart';
import 'package:midnight_village/features/auth/presentation/auth_notifier.dart';
import 'package:midnight_village/features/lobby/presentation/at_table_screen.dart';
import 'package:midnight_village/features/lobby/presentation/deck_screen.dart';
import 'package:midnight_village/features/lobby/presentation/join_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/test_fonts.dart';
import 'harness/end_of_game.dart' as end_of_game;
import 'harness/failure_report.dart';
import 'harness/harness_config.dart';
import 'harness/live_table.dart';
import 'harness/time_budget.dart';
import 'harness/ui_harness.dart';

/// UI runner, one person alone against a real server: the owner's case. The
/// phone opens a table (01), finds nothing of practice players on 02 or 03,
/// holds "Players" on 03 (the hidden switch), seats three with the Practice
/// stepper, sees them tagged on 02 and deals to four. Then the person plays
/// their part through the API while the phone follows, and NOTHING acts for
/// the practice players but the server: they look, choose, are ready to vote
/// and lock a vote by themselves, and the game reaches 10 and 11 as the
/// oracle says. Filmstrip: `integration_test/screenshots/practice-alone/`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await HarnessConfig.setUp();
    HarnessConfig.stubSecureStorage();
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    await loadAppFonts();
  });

  testWidgets('alone: hold "Players", seat three practice players, deal, '
      'play the whole game while the server plays them', (tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    const name = 'practice-alone';
    final ui = UiHarness(tester);
    final clients = harnessClients();
    var frame = 0;
    Future<void> shoot(String state) =>
        ui.captureFrame(name, '${(++frame).toString().padLeft(2, '0')}-$state');
    Future<T> api<T>(Future<T> Function() call) async =>
        (await tester.runAsync(() => call().timeout(eventTimeout))) as T;
    bool shows<T extends Widget>() => find.byType(T).evaluate().isNotEmpty;
    bool text(String t) => find.text(t).evaluate().isNotEmpty;
    Future<void> tap(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pump();
      await ui.tapAndSubmit(finder);
    }

    try {
      await ui.pumpApp();
      await ui.pumpUntil(
        () =>
            shows<JoinScreen>() &&
            ui.container.read(authProvider) is AuthUnauthenticated,
        reason: '01 Join, signed out',
      );
      // 01's one amber plaque while no code is typed: it acts once the name
      // is in the field (with none, a tap only leads to the name).
      final start = find.widgetWithText(PrimaryButton, JoinCopy.startTable);
      bool startOpen() =>
          start.evaluate().isNotEmpty &&
          tester
                  .widget<EditableText>(find.byType(EditableText).first)
                  .controller
                  .text
                  .trim() ==
              'Owner';
      for (var i = 0; i < 3 && !startOpen(); i++) {
        await tester.enterText(find.byType(EditableText).first, 'Owner');
        await tester.pump();
        await ui.settle();
      }
      await ui.tapAndSubmit(start);
      await ui.pumpUntil(
        () => ui.container.read(authProvider) is AuthAuthenticated,
        reason: 'signed in',
        rounds: 200,
      );
      final seat = await ui.followTable(until: (t) => t != null);
      final code = seat!.lobbyCode;
      await ui.pumpUntil(shows<AtTableScreen>, reason: '02');
      await ui.readLobby(code);
      await ui.pumpUntil(
        () => text(TableCopy.needPlayers),
        reason: '02 alone: "Need 3 players", the owner stuck',
      );
      expect(text(TableCopy.practice), isFalse, reason: 'nothing on 02');
      await shoot('alone');

      final owner = await api(() async {
        final auth = ui.container.read(authProvider) as AuthAuthenticated;
        final tokens = ui.container.read(tokenStorageProvider);
        return DebugPlayer(
          userId: auth.user.id,
          displayName: auth.user.displayName,
          accessToken: (await tokens.accessToken)!,
          refreshToken: (await tokens.refreshToken)!,
          role: 'Unknown',
          isHost: true,
        );
      });
      Future<Map<String, dynamic>> lobby() => api(
        () => clients.client.get('/lobbies/$code/', token: owner.accessToken),
      );
      Future<void> until(
        bool Function(Map<String, dynamic>) holds,
        String why,
      ) => tester.runAsync(
        () => pollUntil(
          () async => holds(
            await clients.client.get(
              '/lobbies/$code/',
              token: owner.accessToken,
            ),
          ),
          reason: why,
          timeout: eventTimeout,
        ),
      );

      // Every stage ends because everyone did their part, never by a clock.
      await api(
        () => clients.client.patch(
          '/lobbies/$code/',
          token: owner.accessToken,
          data: {
            'settings': {
              'card_look_seconds': 120,
              'night_wave_seconds': 600,
              'night_min_window_seconds': 0,
              'night_doppelganger_window_seconds': 0,
              'discussion_seconds': 600,
              'voting_seconds': 600,
            },
          },
        ),
      );

      // 03: nothing of practice players until "Players" is held.
      await tap(find.text(TableCopy.editDeck));
      await ui.pumpUntil(shows<DeckView>, reason: '03');
      expect(text(DeckCopy.practice), isFalse, reason: 'hidden on 03');
      final players = find.text(DeckCopy.players);
      await tester.ensureVisible(players);
      // In the real zone, as every tap that talks to the server here: a
      // request started under the test's fake clock never completes.
      await tester.runAsync(() async {
        // The recognizer's timer is armed in the real zone, so the hold fires
        // (and its request goes) on the real clock: held past the platform's
        // long-press time, with a frame's margin.
        final hold = await tester.startGesture(tester.getCenter(players));
        await Future<void>.delayed(
          kLongPressTimeout + const Duration(milliseconds: 100),
        );
        await hold.up();
      });
      await tester.pump();
      expect(
        text(DeckCopy.practice),
        isTrue,
        reason: 'the hold answers at once',
      );
      await until(
        (l) => (l['settings'] as Map)['practice'] == true,
        'practice players switched on at the server',
      );
      final plus = find.descendant(
        of: find.widgetWithText(LabelledStepper, DeckCopy.practice),
        matching: find.byIcon(Icons.add),
      );
      for (var i = 0; i < 3; i++) {
        await tap(plus);
      }
      await until(
        (l) =>
            (l['players'] as List)
                .where((p) => (p as Map)['practice'] == true)
                .length ==
            3,
        'three practice players seated',
      );
      await shoot('three-practice');
      await tap(find.text(DeckCopy.done));
      await ui.pumpUntil(
        () =>
            shows<AtTableScreen>() &&
            find.byType(PracticeTag).evaluate().length == 3 &&
            text(TableCopy.start),
        reason: '02: three tagged "Practice", "Start the game"',
      );
      await shoot('table-four');

      final seated = [
        for (final p in (await lobby())['players'] as List)
          if ((p as Map)['practice'] == true)
            DebugPlayer(
              userId: ((p['user'] as Map)['id'] as num).toInt(),
              displayName: (p['user'] as Map)['display_name'] as String,
              // The server plays them: no token, no request, ever.
              accessToken: '',
              refreshToken: '',
              role: 'Unknown',
              isHost: false,
            ),
      ];

      await tap(find.text(TableCopy.start));
      final dealt = await ui.followTable(until: (t) => t?.gameId != null);
      final gameId = dealt!.gameId!;
      await ui.openShell(gameId);
      await shoot('dealt');

      final live = LiveTable.adopt(
        DebugTable(
          gameId: gameId,
          lobbyCode: code,
          players: [owner, ...seated],
        ),
      );
      // The person's part only: the practice players are the server's.
      await tester.runAsync(() => _playAlone(live, owner, seated));
      await end_of_game.endAsTheOracleSays(
        tester: tester,
        ui: ui,
        table: live,
        name: owner.displayName,
        shoot: shoot,
      );
      final oracle = (await tester.runAsync(() => live.oracleJson()))!;
      final votes = (oracle['votes'] as Map).cast<String, Object?>();
      for (final bot in seated) {
        expect(
          votes['${bot.userId}'],
          isNotNull,
          reason: '${bot.displayName} voted',
        );
      }
    } catch (e) {
      FailureReport.record(
        scenario: name,
        checkpoint: 'ui-practice',
        message: e.toString(),
        pngPath: 'integration_test/screenshots/$name/',
      );
      rethrow;
    } finally {
      await ui.tearDownHarness();
    }
  });
}

/// The person's part, through the API: look, choose nothing where the prompt
/// asks, ready to vote, vote for the first practice player. Every count it
/// waits on is the whole table's: the practice players do theirs at once.
Future<void> _playAlone(
  LiveTable t,
  DebugPlayer person,
  List<DebugPlayer> practice,
) async {
  Future<Map<String, dynamic>> me() => t.me(person);
  Future<void> staged(String tail, Map<String, dynamic> data) async {
    final now = await me();
    await t.client.post(
      '/onuw/games/${t.gameId}/$tail/',
      token: person.accessToken,
      idempotent409: true,
      data: {...data, 'stage': now['stage'] as String},
    );
  }

  Future<void> phase(String phase) => pollUntil(
    () async => (await me())['phase'] == phase,
    reason: 'the table to reach $phase',
    timeout: eventTimeout,
  );

  // The look: the practice players looked the moment it opened.
  await pollUntil(
    () async {
      final progress = (await me())['progress'] as Map<String, dynamic>?;
      return progress != null && progress['done'] == practice.length;
    },
    reason: 'the practice players looked by themselves',
    timeout: eventTimeout,
  );
  await staged('ready', {'ready': true});
  await pollUntil(
    () async {
      final now = await me();
      if (now['phase'] != 'night') return true;
      final prompt = now['action_prompt'] as Map<String, dynamic>?;
      if (prompt != null && (prompt['chooses_left'] as int) > 0) {
        await staged('action', {
          'action_type': 'choose',
          'picks': const <Object>[],
          'chosen': prompt['chosen'] as int,
        });
      }
      return false;
    },
    reason: 'the night to end with only the person choosing',
    timeout: const Duration(seconds: 60),
  );
  await phase('discussion');
  final talk = (await me())['progress'] as Map<String, dynamic>;
  if (talk['done'] != practice.length) {
    throw StateError('the practice players were not ready to vote: $talk');
  }
  await staged('ready', {'ready': true});
  await phase('voting');
  final vote = (await me())['progress'] as Map<String, dynamic>;
  if (vote['done'] != practice.length) {
    throw StateError('the practice players had not locked a vote: $vote');
  }
  await staged('vote', {
    'target_player_id': practice.first.userId,
    'lock': true,
  });
  await phase('results');
}
