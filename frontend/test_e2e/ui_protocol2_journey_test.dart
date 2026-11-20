@Tags(['e2e'])
library;

import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/debug/debug_models.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/role_card.dart';
import 'package:midnight_village/design_system/primitives/secondary_button.dart';
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

/// UI runner, night protocol 2, the whole way on the host's phone: the REAL
/// widget tree from 01 Join ("Start a table") through 02 (the others join
/// through the API; the phone follows the lobby's socket), 03 (a chip, its
/// cards face up from the server), "Deal to 4" on 02, the game played by
/// every player through the API while the phone follows, 10 and 11 as the
/// oracle says, and "Play again" back to 02. Nothing here is forced: the
/// deal is the server's own. Filmstrip: `integration_test/screenshots/
/// p2-journey/`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await HarnessConfig.setUp();
    HarnessConfig.stubSecureStorage();
    // Test code; the analyzer only counts test/ and *_test.dart as tests.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    await loadAppFonts();
  });

  testWidgets('01 Start a table, 02 as the others join, 03 Classic, Deal, '
      'the game, 10 and 11 as the oracle says, Play again back to 02', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    const name = 'p2-journey';
    final ui = UiHarness(tester);
    final clients = harnessClients();
    LiveTable? table;
    var frame = 0;
    Future<void> shoot(String state) =>
        ui.captureFrame(name, '${(++frame).toString().padLeft(2, '0')}-$state');
    Future<T> api<T>(Future<T> Function() call) async =>
        (await tester.runAsync(() => call().timeout(eventTimeout))) as T;
    bool shows<T extends Widget>() => find.byType(T).evaluate().isNotEmpty;
    bool text(String t) => find.text(t).evaluate().isNotEmpty;

    try {
      await ui.pumpApp();

      // 01: a new phone, signed out.
      // Signed out for certain first: a session restore that lands after
      // the name is typed rebuilds 01 and drops it.
      await ui.pumpUntil(
        () =>
            shows<JoinScreen>() &&
            ui.container.read(authProvider) is AuthUnauthenticated,
        reason: '01 Join, signed out',
      );
      await shoot('join');
      final start = find.widgetWithText(SecondaryButton, JoinCopy.startTable);
      bool startOpen() =>
          start.evaluate().isNotEmpty &&
          tester.widget<SecondaryButton>(start).onPressed != null;
      for (var i = 0; i < 3 && !startOpen(); i++) {
        await tester.enterText(find.byType(EditableText).first, 'Alice');
        await tester.pump();
        await ui.settle();
      }
      expect(startOpen(), isTrue, reason: 'a name opens "Start a table"');
      await ui.tapAndSubmit(start);
      // Signed in first (the guest account the tap makes): a read of
      // `/me/table/` before the token is stored is a 401, which signs the
      // phone out mid-way.
      await ui.pumpUntil(
        () => ui.container.read(authProvider) is AuthAuthenticated,
        reason: 'the guest account Start a table makes',
        rounds: 200,
      );
      final seat = await ui.followTable(until: (t) => t != null);
      expect(seat, isNotNull, reason: 'the server seats Alice at her table');
      final code = seat!.lobbyCode;
      await ui.pumpUntil(shows<AtTableScreen>, reason: '02 Table');
      await ui.readLobby(code);
      await ui.pumpUntil(
        () => text(TableCopy.needPlayers),
        reason: '02 alone: "Need 3 players"',
      );
      await shoot('table-alone');

      // Alice's own account, as the server made it from her phone.
      final alice = await api(() async {
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

      // The others scan the code: guests made and seated through the API.
      final players = [alice];
      for (final other in ['Bob', 'Cara', 'Dan']) {
        final guest = await api(
          () => clients.client.post(
            '/auth/guest/',
            token: '',
            data: {'display_name': other},
          ),
        );
        final user = guest['user'] as Map<String, dynamic>;
        final p = DebugPlayer(
          userId: (user['id'] as num).toInt(),
          displayName: other,
          accessToken: guest['access'] as String,
          refreshToken: guest['refresh'] as String,
          role: 'Unknown',
          isHost: false,
        );
        await api(
          () =>
              clients.client.post('/lobbies/$code/join/', token: p.accessToken),
        );
        players.add(p);
      }
      await ui.pumpUntil(
        () => text('Dan') && text(TableCopy.deal.fill({'n': 4})),
        reason: '02 follows the lobby: four at the table, "Deal to 4"',
      );
      await shoot('table-four');

      // What the phone does not set: every stage ends because everyone
      // acted, never by a clock (the host's settings, through the API).
      await api(
        () => clients.client.patch(
          '/lobbies/$code/',
          token: alice.accessToken,
          data: {
            'settings': {
              'card_look_seconds': 120,
              'night_wave_seconds': 600,
              'night_min_window_seconds': 0,
              'night_doppelganger_window_seconds': 600,
              'discussion_seconds': 600,
              'voting_seconds': 600,
            },
          },
        ),
      );

      // 03: Edit, the Classic chip; its cards face up from the server.
      final edit = find.text(TableCopy.editDeck);
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await ui.settle();
      await ui.pumpUntil(shows<DeckView>, reason: '03 Deck');
      await ui.tapAndSubmit(find.text('Classic'));
      var lobby = <String, dynamic>{};
      await tester.runAsync(
        () => pollUntil(
          () async {
            lobby = await clients.client.get(
              '/lobbies/$code/',
              token: alice.accessToken,
            );
            return (lobby['settings'] as Map)['deck_chip'] == 'classic';
          },
          reason: 'the Classic chip at the server',
          timeout: eventTimeout,
        ),
      );
      final preview = {
        for (final MapEntry(:key, :value)
            in (lobby['deck_preview'] as Map<String, dynamic>).entries)
          RoleId.fromServer(key)!: value as int,
      };
      Map<RoleId, int> faceUp() => {
        for (final card in tester.widgetList<RoleCard>(find.byType(RoleCard)))
          if (card.count > 0) card.role: card.count,
      };
      await ui.pumpUntil(
        () => mapEquals(faceUp(), preview),
        reason: "03 shows the server's Classic deck for four, face up",
      );
      await shoot('deck-classic');
      final use = find.text(DeckCopy.useDeck);
      await tester.ensureVisible(use);
      await tester.tap(use);
      await ui.settle();
      await ui.pumpUntil(shows<AtTableScreen>, reason: 'back at 02');

      // Deal, from the phone.
      final deal = find.text(TableCopy.deal.fill({'n': 4}));
      await tester.ensureVisible(deal);
      await ui.tapAndSubmit(deal);
      final dealt = await ui.followTable(until: (t) => t?.gameId != null);
      final gameId = dealt?.gameId;
      expect(gameId, isNotNull, reason: 'the deal opened a game');
      await ui.openShell(gameId!);
      await shoot('dealt');

      // The game, every player through the API; the phone follows.
      final live = table = LiveTable.adopt(
        DebugTable(gameId: gameId, lobbyCode: code, players: players),
      );
      await tester.runAsync(() => _playThrough(live));
      await end_of_game.endAsTheOracleSays(
        tester: tester,
        ui: ui,
        table: live,
        name: 'Alice',
        shoot: shoot,
      );

      // Play again, from the phone: back to 02, the table waiting.
      await ui.tapAndSubmit(
        find.text(ResultsCopy.playAgain),
        until: shows<AtTableScreen>,
      );
      await ui.readLobby(code);
      await ui.pumpUntil(
        () => text(TableCopy.deal.fill({'n': 4})),
        reason: '02 again: "Deal to 4"',
      );
      await shoot('table-again');
      final again = await api(() => live.lobby(alice));
      expect(again['status'], 'waiting');
    } catch (e) {
      FailureReport.record(
        scenario: name,
        checkpoint: 'ui-protocol2-journey',
        message: e.toString(),
        pngPath: 'integration_test/screenshots/$name/',
      );
      rethrow;
    } finally {
      try {
        await tester.runAsync(() async => table?.closeAll());
      } catch (_) {}
      await ui.tearDownHarness();
    }
  });
}

/// Plays the dealt game to its results through the API: everyone looks,
/// chooses nothing in every window (the server decides what that means), is
/// ready to vote and votes for the next player.
Future<void> _playThrough(LiveTable t) async {
  final players = t.table.players;
  Future<Map<String, dynamic>> me(DebugPlayer p) => t.me(p);
  Future<void> staged(
    DebugPlayer p,
    String tail,
    Map<String, dynamic> data,
    Map<String, dynamic> me,
  ) => t.client.post(
    '/onuw/games/${t.gameId}/$tail/',
    token: p.accessToken,
    idempotent409: true,
    data: {...data, 'stage': me['stage'] as String},
  );
  Future<void> phase(String phase) => pollUntil(
    () async => (await me(players.first))['phase'] == phase,
    reason: 'the table to reach $phase',
    timeout: eventTimeout,
  );

  for (final p in players) {
    await staged(p, 'ready', {'ready': true}, await me(p));
  }
  // Every window: each phone chooses once, picking nothing.
  await pollUntil(
    () async {
      for (final p in players) {
        final now = await me(p);
        if (const {'discussion', 'voting', 'results'}.contains(now['phase'])) {
          return true;
        }
        final prompt = now['action_prompt'] as Map<String, dynamic>?;
        if (prompt != null && (prompt['chooses_left'] as int) > 0) {
          await staged(p, 'action', {
            'action_type': 'choose',
            'picks': const <Object>[],
            'chosen': prompt['chosen'] as int,
          }, now);
        }
      }
      return false;
    },
    reason: 'the night to end',
    timeout: const Duration(seconds: 60),
  );
  await phase('discussion');
  for (final p in players) {
    await staged(p, 'ready', {'ready': true}, await me(p));
  }
  await phase('voting');
  for (final (i, p) in players.indexed) {
    final target = players[(i + 1) % players.length];
    await staged(p, 'vote', {'target_player_id': target.userId}, await me(p));
  }
  await phase('results');
}
