@Tags(['e2e'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/debug/debug_api_client.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/role_card.dart';
import 'package:midnight_village/design_system/primitives/secondary_button.dart';
import 'package:midnight_village/design_system/primitives/value_stepper.dart';
import 'package:midnight_village/features/auth/domain/auth_state.dart';
import 'package:midnight_village/features/auth/presentation/auth_notifier.dart';
import 'package:midnight_village/features/lobby/presentation/at_table_screen.dart';
import 'package:midnight_village/features/lobby/presentation/deck_screen.dart';
import 'package:midnight_village/features/lobby/presentation/join_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/test_fonts.dart';
import 'harness/failure_report.dart';
import 'harness/harness_config.dart';
import 'harness/live_table.dart';
import 'harness/time_budget.dart';
import 'harness/ui_harness.dart';

/// UI runner, the host's phone against a real server: the owner's set-up.
/// The host sets the table for eight before anyone joins (and, in one run,
/// builds a deck of their own for eight), the others arrive one by one
/// through the API while 02 counts them ("3 of 8", "Start the game" locked, the
/// cards needed never moving), only seven come, the host taps "Play with 7"
/// (the automatic deck follows; the own deck, one over, opens 03 with its
/// count and the host takes one card out), and deals. And the owner's leave: the host alone
/// leaves and is at 01, never "Not sent.". Filmstrips:
/// `integration_test/screenshots/setup-*/`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await HarnessConfig.setUp();
    HarnessConfig.stubSecureStorage();
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    await loadAppFonts();
  });

  for (final own in [false, true]) {
    final name = own ? 'setup-own-deck' : 'setup-auto-deck';
    testWidgets('the host sets a table for 8 before anyone joins'
        '${own ? ', builds a deck of their own for 8' : ''}; people arrive '
        'one by one; seven come; "Play with 7"; deal', (tester) async {
      final run = await _Run.start(tester, name);
      try {
        final ui = run.ui;
        // 03 before anyone else is here: eight players.
        await run.tap(find.text(TableCopy.editDeck));
        await ui.pumpUntil(run.shows<DeckView>, reason: '03');
        for (var i = 0; i < 6; i++) {
          // Any, then 3 to 8.
          await run.tap(run.playersGlyph(Icons.add));
        }
        await run.until(
          (lobby) => (lobby['settings'] as Map)['seats'] == 8,
          'the table set for eight at the server',
        );
        await ui.pumpUntil(
          () =>
              run.text(DeckCopy.count.fill({'picked': 11, 'need': 11})) &&
              run.text('1 of 8'),
          reason: '03: eleven cards for eight, one of eight here',
        );
        if (own) {
          // One card out and another in: the deck is the host's own.
          final out = run.lit().first;
          await run.tap(
            find.descendant(
              of: run.card(out),
              matching: find.byIcon(Icons.remove),
            ),
          );
          final into = run.unlit().first;
          await run.tap(run.card(into));
          await run.until(
            (lobby) =>
                (lobby['settings'] as Map)['deck'] == 'custom' &&
                (lobby['deal'] as Map)['have'] == 11,
            'a deck of eleven of the host\'s own at the server',
          );
          await ui.pumpUntil(
            () => run.text(DeckCopy.count.fill({'picked': 11, 'need': 11})),
            reason: 'it fits',
          );
        }
        await run.shoot('set-for-8');
        await run.tap(find.text(DeckCopy.done));
        await ui.pumpUntil(run.shows<AtTableScreen>, reason: 'back at 02');
        await run.expectDealLocked(7);

        // They arrive one by one; only six of the seven others come.
        for (final (i, guest) in [
          'Ivo',
          'Jun',
          'Kim',
          'Lea',
          'Max',
          'Nia',
        ].indexed) {
          await run.join(guest);
          await ui.pumpUntil(
            () => run.text(guest) && run.text('${i + 2} of 8'),
            reason: '02 counts ${i + 2} of 8',
          );
          final lobby = await run.lobby();
          expect((lobby['deal'] as Map)['need'], 11, reason: 'never moves');
          await run.expectDealLocked(8 - (i + 2));
        }
        await run.shoot('seven-of-8');

        // Only seven came: one tap.
        await run.tap(find.text(TableCopy.playWith.fill({'n': 7})));
        await run.until(
          (lobby) => (lobby['settings'] as Map)['seats'] == 7,
          'the table set for seven',
        );
        if (own) {
          // The own deck was built for eight: "Play with 7" opens 03 with
          // its count showing ("11 of 10 · Remove 1 card"), never throwing the deck away.
          await ui.pumpUntil(
            () =>
                run.shows<DeckView>() &&
                run.text(
                  DeckCopy.countFix.fill({
                    'picked': 11,
                    'need': 10,
                    'fix': DeckCopy.removeCard,
                  }),
                ),
            reason: '03, the own deck one over',
          );
          await run.shoot('lowered-own-deck');
          expect(
            (((await run.lobby())['settings'] as Map)['deck']),
            'custom',
            reason: 'the own deck kept',
          );
          await run.tap(
            find.descendant(
              of: run.card(run.lit().last),
              matching: find.byIcon(Icons.remove),
            ),
          );
          await run.until(
            (lobby) => (lobby['deal'] as Map)['ok'] == true,
            'ten cards for seven',
          );
          await ui.pumpUntil(
            () => run.text(DeckCopy.count.fill({'picked': 10, 'need': 10})),
            reason: '03: fits',
          );
          await run.tap(find.text(DeckCopy.done));
          await ui.pumpUntil(run.shows<AtTableScreen>, reason: '02');
        }
        final deal = find.widgetWithText(PrimaryButton, TableCopy.start);
        await ui.pumpUntil(
          () =>
              deal.evaluate().isNotEmpty &&
              tester.widget<PrimaryButton>(deal).onPressed != null,
          reason: '"Start the game" live',
        );
        await run.shoot('ready');
        await tester.ensureVisible(deal);
        await ui.tapAndSubmit(deal);
        final dealt = await ui.followTable(until: (t) => t?.gameId != null);
        expect(dealt?.gameId, isNotNull, reason: 'dealt to seven');
      } catch (e) {
        FailureReport.record(
          scenario: name,
          checkpoint: 'ui-setup',
          message: e.toString(),
          pngPath: 'integration_test/screenshots/$name/',
        );
        rethrow;
      } finally {
        await run.ui.tearDownHarness();
      }
    });
  }

  testWidgets('the host alone leaves: at 01, never "Not sent."', (
    tester,
  ) async {
    const name = 'setup-leave-alone';
    final run = await _Run.start(tester, name);
    try {
      final ui = run.ui;
      final leave = find.widgetWithText(SecondaryButton, CommonCopy.leave);
      await tester.ensureVisible(leave);
      await tester.pump();
      await tester.tap(leave);
      await ui.settle();
      await ui.tapAndSubmit(
        find.text(CommonCopy.leave).last,
        until: () => run.shows<JoinScreen>() || run.text(BannerCopy.notSent),
      );
      expect(run.text(BannerCopy.notSent), isFalse);
      expect(run.shows<JoinScreen>(), isTrue);
      await run.shoot('left');
    } catch (e) {
      FailureReport.record(
        scenario: name,
        checkpoint: 'ui-setup-leave',
        message: e.toString(),
        pngPath: 'integration_test/screenshots/$name/',
      );
      rethrow;
    } finally {
      await run.ui.tearDownHarness();
    }
  });
}

/// One run: the host's phone, signed in and at a new table of their own.
class _Run {
  _Run._(this.tester, this.ui, this.name, this.code, this.hostToken);

  final WidgetTester tester;
  final UiHarness ui;
  final String name;
  final String code;
  final String hostToken;
  final DebugApiClient client = harnessClients().client;
  var _frame = 0;

  static Future<_Run> start(WidgetTester tester, String name) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final ui = UiHarness(tester);
    await ui.pumpApp();
    bool shows<T extends Widget>() => find.byType(T).evaluate().isNotEmpty;
    await ui.pumpUntil(
      () =>
          shows<JoinScreen>() &&
          ui.container.read(authProvider) is AuthUnauthenticated,
      reason: '01 Join, signed out',
    );
    final start = find.widgetWithText(SecondaryButton, JoinCopy.startTable);
    bool startOpen() =>
        start.evaluate().isNotEmpty &&
        tester.widget<SecondaryButton>(start).onPressed != null;
    for (var i = 0; i < 3 && !startOpen(); i++) {
      await tester.enterText(find.byType(EditableText).first, 'Hana');
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
    final token = (await tester.runAsync(
      () => ui.container.read(tokenStorageProvider).accessToken,
    ))!;
    return _Run._(tester, ui, name, code, token);
  }

  bool shows<T extends Widget>() => find.byType(T).evaluate().isNotEmpty;
  bool text(String t) => find.text(t).evaluate().isNotEmpty;

  Future<void> shoot(String state) =>
      ui.captureFrame(name, '${(++_frame).toString().padLeft(2, '0')}-$state');

  Future<T> api<T>(Future<T> Function() call) async =>
      (await tester.runAsync(() => call().timeout(eventTimeout))) as T;

  Future<Map<String, dynamic>> lobby() =>
      api(() => client.get('/lobbies/$code/', token: hostToken));

  /// Polls the server until [holds] of the lobby body.
  Future<void> until(
    bool Function(Map<String, dynamic> lobby) holds,
    String reason,
  ) async {
    await tester.runAsync(
      () => pollUntil(
        () async =>
            holds(await client.get('/lobbies/$code/', token: hostToken)),
        reason: reason,
        timeout: eventTimeout,
      ),
    );
    await ui.settle();
  }

  /// A tap whose handler talks to the server.
  Future<void> tap(Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await ui.tapAndSubmit(finder);
  }

  Finder playersGlyph(IconData glyph) => find.descendant(
    of: find.ancestor(
      of: find.text(DeckCopy.players),
      matching: find.byType(LabelledStepper),
    ),
    matching: find.byIcon(glyph),
  );

  Finder card(Object role) =>
      find.byWidgetPredicate((w) => w is RoleCard && w.role == role);

  List<Object> lit() => [
    for (final c in tester.widgetList<RoleCard>(find.byType(RoleCard)))
      if (c.lit) c.role,
  ];

  List<Object> unlit() => [
    for (final c in tester.widgetList<RoleCard>(find.byType(RoleCard)))
      if (!c.lit) c.role,
  ];

  Future<void> join(String guestName) async {
    final guest = await api(
      () => client.post(
        '/auth/guest/',
        token: '',
        data: {'display_name': guestName},
      ),
    );
    await api(
      () =>
          client.post('/lobbies/$code/join/', token: guest['access'] as String),
    );
  }

  /// The button says how many more it waits for, never "Start the game" dimmed.
  Future<void> expectDealLocked(int missing) async {
    final label = TableCopy.needMore.fill({'n': missing});
    final deal = find.widgetWithText(PrimaryButton, label);
    await ui.pumpUntil(() => deal.evaluate().isNotEmpty, reason: label);
    expect(tester.widget<PrimaryButton>(deal).onPressed, isNull);
  }
}
