import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/router/back_policy.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/primitives/role_card.dart';
import 'package:midnight_village/design_system/primitives/role_sheet_body.dart';
import 'package:midnight_village/features/game/domain/screen_table.dart';
import 'package:midnight_village/features/game/presentation/shell/table_shell.dart';
import 'package:midnight_village/features/game/presentation/shell/talk_screen.dart';
import 'package:midnight_village/features/game/presentation/table_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../helpers/contract/contract_samples.dart';
import '../helpers/mock_http_client.dart';
import '../helpers/shell_setup.dart';
import '../helpers/table_setup.dart';

// Back, the phone's and the browser's (owner's rules, 22 November 2026),
// through the app's own routes and its one back policy, every answer a
// recorded server payload. Back is pressed as the platform presses it: a
// `popRoute` message on the navigation channel, which Android's back button
// and gesture send, and which the web engine sends for the browser's Back
// once the app keeps one history entry (`oneHistoryEntry`).
//
// - Something open on top closes first: a sheet, the set-up page (back to
//   02), My night, the code field.
// - With nothing open: 01 leaves the app; 02 asks through the table's own
//   leave confirmation; in a game nothing happens (only Leave exits).
//
// Every screen the screen table can name is reached here from the server's
// answers and pressed; a screen added to the table without a rule and a test
// of it fails.

/// What each screen does on Back with nothing open: the owner's rules,
/// stated here, not read from the app.
const _owners = <AppScreen, BackRule>{
  AppScreen.join: BackRule.leavesApp,
  AppScreen.table: BackRule.asksToLeave,
  AppScreen.deck: BackRule.closesToTable,
  AppScreen.yourCard: BackRule.staysPut,
  AppScreen.nightBoard: BackRule.staysPut,
  AppScreen.talk: BackRule.staysPut,
  AppScreen.vote: BackRule.staysPut,
  AppScreen.count: BackRule.staysPut,
  AppScreen.results: BackRule.staysPut,
};

/// What the platform is told: that Back left the app (`SystemNavigator.pop`:
/// Android closes, the web steps off the app's history entry), and whether
/// the app takes Back itself (Android's back gesture previews leaving only
/// when it does not).
class _Platform {
  final calls = <MethodCall>[];

  bool get left => calls.any((c) => c.method == 'SystemNavigator.pop');

  bool? get appTakesBack =>
      calls
              .lastWhere(
                (c) => c.method == 'SystemNavigator.setFrameworkHandlesBack',
                orElse: () => const MethodCall('none'),
              )
              .arguments
          as bool?;

  static _Platform listen(WidgetTester tester) {
    final platform = _Platform();
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      platform.calls.add(call);
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    // The app is in front: Android hears whether the app takes Back.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    return platform;
  }
}

/// Back, as the platform sends it, then the screen settles.
Future<void> _back(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.navigation.name,
    SystemChannels.navigation.codec.encodeMethodCall(
      const MethodCall('popRoute'),
    ),
    (_) {},
  );
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The screen the table's shell shows (null outside it: 01 signed out).
AppScreen? _screen(WidgetTester tester) {
  final shell = find.byType(TableShell);
  if (shell.evaluate().isEmpty) return null;
  return ProviderScope.containerOf(
    tester.element(shell),
  ).read(tableScreenProvider).value?.screen;
}

int _requests(TableSetup setup, String method) =>
    setup.http.requests.where((r) => r.method == method).length;

Future<void> _tap(WidgetTester tester, Finder what) async {
  await tester.ensureVisible(what);
  await tester.pump();
  await tester.tap(what);
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// A game's screen through the app's routes: [sample]'s `/me/`.
Future<ShellSetup> _game(WidgetTester tester, String sample) => ShellSetup.pump(
  tester,
  recordedMe(sample),
  appRoutes: true,
  before: (s) => s.answerNightResultsSeen(),
);

void main() {
  test('every screen the table can name has the owner\'s rule', () {
    expect(
      _owners.keys.toSet(),
      AppScreen.values.toSet(),
      reason: 'a new screen needs its Back rule stated here and tested below',
    );
    for (final screen in AppScreen.values) {
      expect(backRuleFor(screen), _owners[screen], reason: screen.name);
    }
  });

  test('Android lets the app take Back (predictive back opted in)', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android:enableOnBackInvokedCallback="true"'));
  });

  group('01 Join: Back leaves the app', () {
    testWidgets('signed out', (tester) async {
      final platform = _Platform.listen(tester);
      final setup = await TableSetup.pump(tester);
      expect(find.text(JoinCopy.startTable), findsOneWidget);
      expect(platform.appTakesBack, isFalse);
      await _back(tester);
      expect(platform.left, isTrue);
      await setup.close(tester);
    });

    testWidgets('signed in at no table (the screen table\'s 01)', (
      tester,
    ) async {
      final platform = _Platform.listen(tester);
      final setup = await TableSetup.pump(tester, signedInAs: 'Ana');
      expect(_screen(tester), AppScreen.join);
      await _back(tester);
      expect(platform.left, isTrue);
      await setup.close(tester);
    });

    testWidgets('opened from a table\'s link', (tester) async {
      final platform = _Platform.listen(tester);
      final setup = await TableSetup.pump(tester, route: '/join/V9YC2J');
      expect(find.text(JoinCopy.join), findsOneWidget);
      await _back(tester);
      expect(platform.left, isTrue);
      await setup.close(tester);
    });

    testWidgets('with the code field open, Back closes it first; the next '
        'Back leaves', (tester) async {
      final platform = _Platform.listen(tester);
      final setup = await TableSetup.pump(tester, signedInAs: 'Ana');
      await _tap(tester, find.text(JoinCopy.joinTable));
      expect(find.text(JoinCopy.codeHint), findsOneWidget);
      expect(platform.appTakesBack, isTrue);

      await _back(tester);
      expect(platform.left, isFalse);
      expect(find.text(JoinCopy.codeHint), findsNothing);
      expect(find.text(JoinCopy.joinTable), findsOneWidget);
      expect(platform.appTakesBack, isFalse);

      await _back(tester);
      expect(platform.left, isTrue);
      await setup.close(tester);
    });
  });

  group(
    '02 Table: Back asks first, with the table\'s own "Stay" / "Leave"',
    () {
      testWidgets('the host: asked; Back again (or Stay) keeps the seat', (
        tester,
      ) async {
        final platform = _Platform.listen(tester);
        final setup = await TableSetup.pump(
          tester,
          lobby: v2Lobby('detail_auto_deck_5'),
          viewer: 'Ana',
        );
        expect(_screen(tester), AppScreen.table);
        expect(platform.appTakesBack, isTrue);

        await _back(tester);
        expect(find.text(TableCopy.stay), findsOneWidget);
        // Back closes the question: still at the table, nothing sent.
        await _back(tester);
        expect(find.text(TableCopy.stay), findsNothing);
        expect(_screen(tester), AppScreen.table);
        expect(_requests(setup, 'POST'), 0);
        expect(platform.left, isFalse);

        await _back(tester);
        await _tap(tester, find.text(TableCopy.stay));
        expect(_screen(tester), AppScreen.table);
        expect(_requests(setup, 'POST'), 0);
        await setup.close(tester);
      });

      testWidgets('the host says Leave: off the table, at 01; Back there '
          'leaves, even while the table still fades out', (tester) async {
        final platform = _Platform.listen(tester);
        final setup = await TableSetup.pump(
          tester,
          lobby: v2Lobby('detail_auto_deck_5'),
          viewer: 'Ana',
        );
        setup.http.answer(
          'POST',
          '/lobbies/V9YC2J/leave/',
          ContractSamples.map('http/lobby/left_owner'),
        );
        await _back(tester);
        setup.http.answer(
          'GET',
          '/me/table/',
          ContractSamples.map('http/lobby/my_table_none'),
        );
        await tester.tap(find.text(CommonCopy.leave).last);
        // Frame by frame, until 01 is the screen.
        for (var i = 0; i < 40 && _screen(tester) != AppScreen.join; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(setup.count('POST', '/lobbies/V9YC2J/leave/'), 1);
        expect(_screen(tester), AppScreen.join);
        expect(platform.left, isFalse);
        // At 01 now, while the table fades out: Back leaves the app.
        await _back(tester);
        expect(find.text(TableCopy.stay), findsNothing);
        expect(platform.left, isTrue);
        await setup.close(tester);
      });

      testWidgets(
        'a guest is asked the same (their Leave button does not ask)',
        (tester) async {
          final platform = _Platform.listen(tester);
          final setup = await TableSetup.pump(
            tester,
            lobby: v2Lobby('detail_auto_deck_5'),
            viewer: 'Ben',
          );
          expect(_screen(tester), AppScreen.table);
          await _back(tester);
          expect(find.text(TableCopy.stay), findsOneWidget);
          expect(_requests(setup, 'POST'), 0);
          await _back(tester);
          expect(find.text(TableCopy.stay), findsNothing);
          expect(platform.left, isFalse);
          await setup.close(tester);
        },
      );
    },
  );

  group('03 Deck: Back returns to the table', () {
    Future<TableSetup> deck(WidgetTester tester) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('detail_auto_deck_5'),
        viewer: 'Ana',
      );
      await _tap(tester, find.text(TableCopy.editDeck));
      expect(_screen(tester), AppScreen.deck);
      return setup;
    }

    testWidgets('back to 02, nothing sent', (tester) async {
      final platform = _Platform.listen(tester);
      final setup = await deck(tester);
      await _back(tester);
      expect(_screen(tester), AppScreen.table);
      expect(find.text(TableCopy.stay), findsNothing);
      expect(_requests(setup, 'PATCH') + _requests(setup, 'POST'), 0);
      expect(platform.left, isFalse);
      await setup.close(tester);
    });

    testWidgets('a role\'s sheet (03b) open: Back closes it, the page stays', (
      tester,
    ) async {
      final platform = _Platform.listen(tester);
      final setup = await deck(tester);
      final card = find.byType(RoleCard).first;
      await tester.ensureVisible(card);
      await tester.longPress(card);
      await tester.pumpAndSettle();
      expect(find.byType(RoleSheetBody), findsOneWidget);

      await _back(tester);
      await tester.pumpAndSettle();
      expect(find.byType(RoleSheetBody), findsNothing);
      expect(_screen(tester), AppScreen.deck);
      expect(platform.left, isFalse);
      await setup.close(tester);
    });
  });

  group('in a game Back does nothing; only Leave exits', () {
    // One recorded `/me/` per game screen, and 11 (who won) from 10.
    const samples = <String, AppScreen>{
      'me_look_stage': AppScreen.yourCard,
      'me_choose_prompt_seer': AppScreen.nightBoard,
      'me_talk_results_seen': AppScreen.talk,
      'me_voting_picked': AppScreen.vote,
      'me_results': AppScreen.count,
    };
    for (final MapEntry(key: sample, value: screen) in samples.entries) {
      testWidgets('${screen.number} ${screen.briefName} ($sample)', (
        tester,
      ) async {
        final platform = _Platform.listen(tester);
        final s = await _game(tester, sample);
        await s.settle(tester);
        expect(s.screenOn(tester), screen);
        expect(platform.appTakesBack, isTrue);
        int sent() => s.http.requests.where((r) => r.method != 'GET').length;
        final before = sent();
        await _back(tester);
        await _back(tester);
        expect(s.screenOn(tester), screen);
        expect(platform.left, isFalse);
        expect(sent(), before, reason: 'Back sends nothing');
        await s.close(tester);
      });
    }

    testWidgets('11 Results', (tester) async {
      final platform = _Platform.listen(tester);
      final s = await _game(tester, 'me_results');
      await s.settle(tester);
      await tester.tap(find.text(CountCopy.seeWhoWon));
      await s.settle(tester);
      expect(s.screenOn(tester), AppScreen.results);
      await _back(tester);
      expect(s.screenOn(tester), AppScreen.results);
      expect(platform.left, isFalse);
      await s.close(tester);
    });

    testWidgets('the night while its /me/ loads (05)', (tester) async {
      final platform = _Platform.listen(tester);
      final s = await ShellSetup.pump(
        tester,
        recordedMe('me_choose_prompt_seer'),
        appRoutes: true,
        holdMe: true,
      );
      await s.settle(tester);
      expect(s.screenOn(tester), AppScreen.nightBoard);
      await _back(tester);
      expect(s.screenOn(tester), AppScreen.nightBoard);
      expect(platform.left, isFalse);
      s.meReplies!.releaseAll();
      await s.close(tester);
    });

    testWidgets('08 with My night open: Back puts it away; then nothing', (
      tester,
    ) async {
      final platform = _Platform.listen(tester);
      final s = await _game(tester, 'me_discussion_choose_seer');
      await s.settle(tester);
      TalkView talk() => tester.widget<TalkView>(find.byType(TalkView));
      expect(talk().resultOpen, isTrue);

      await _back(tester);
      expect(talk().resultOpen, isFalse);
      expect(s.screenOn(tester), AppScreen.talk);
      await _back(tester);
      expect(s.screenOn(tester), AppScreen.talk);
      expect(platform.left, isFalse);
      await s.close(tester);
    });

    testWidgets('08 with a role\'s sheet open: Back closes it', (tester) async {
      final platform = _Platform.listen(tester);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = await _game(tester, 'me_talk_results_seen');
      await s.settle(tester);
      final card = find.byType(RoleCard).first;
      await tester.ensureVisible(card);
      await tester.longPress(card);
      await s.settle(tester);
      expect(find.byType(RoleSheetBody), findsOneWidget);
      await _back(tester);
      await s.settle(tester);
      expect(find.byType(RoleSheetBody), findsNothing);
      expect(s.screenOn(tester), AppScreen.talk);
      expect(platform.left, isFalse);
      await s.close(tester);
    });
  });

  group('one browser history entry', () {
    late List<MethodCall> navigation;

    setUp(() => navigation = []);

    void listen(WidgetTester tester) {
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.navigation, (
        call,
      ) async {
        navigation.add(call);
        return null;
      });
      addTearDown(
        () =>
            messenger.setMockMethodCallHandler(SystemChannels.navigation, null),
      );
    }

    List<MethodCall> updates() => [
      for (final c in navigation)
        if (c.method == 'routeInformationUpdated') c,
    ];

    testWidgets('every change of address replaces the one entry; history '
        'never fills (a link, then home)', (tester) async {
      listen(tester);
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('detail_auto_deck_5'),
        viewer: 'Ana',
        route: '/join/V9YC2J',
      );
      expect(_screen(tester), AppScreen.table);
      // Home, as the app goes after a join from a link.
      GoRouter.of(tester.element(find.byType(TableShell))).go('/');
      await setup.settle(tester);
      expect(_screen(tester), AppScreen.table);
      expect(
        navigation.map((c) => c.method),
        contains('selectSingleEntryHistory'),
      );
      expect(
        navigation.map((c) => c.method),
        isNot(contains('selectMultiEntryHistory')),
      );
      expect(
        [for (final u in updates()) (u.arguments as Map)['uri']],
        ['/join/V9YC2J', '/'],
      );
      for (final update in updates()) {
        expect((update.arguments as Map)['replace'], isTrue);
      }
      await setup.close(tester);
    });
  });
}
