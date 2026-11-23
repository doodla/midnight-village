import 'dart:io';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/router/back_policy.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/deck_pile.dart';
import 'package:midnight_village/features/game/presentation/shell/talk_square.dart';
import 'package:midnight_village/design_system/primitives/role_card.dart';
import 'package:midnight_village/design_system/primitives/role_sheet_body.dart';
import 'package:midnight_village/design_system/primitives/viewfinder.dart';
import 'package:midnight_village/design_system/primitives/sheet_scaffold.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';
import 'package:midnight_village/features/auth/domain/auth_state.dart';
import 'package:midnight_village/features/lobby/presentation/join_screen.dart';
import 'package:midnight_village/features/lobby/presentation/home_gate.dart';
import 'package:midnight_village/features/game/domain/screen_table.dart';
import 'package:midnight_village/features/game/presentation/shell/table_shell.dart';
import 'package:midnight_village/features/game/presentation/table_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../helpers/contract/contract_samples.dart';
import '../helpers/game_events.dart';
import '../helpers/contract/server_json.dart' show serverMyTable;
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

/// Back, as the platform sends it.
Future<void> _press(WidgetTester tester) =>
    tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.navigation.name,
      SystemChannels.navigation.codec.encodeMethodCall(
        const MethodCall('popRoute'),
      ),
      (_) {},
    );

/// Back, then whatever it moved settles (a sheet closing, a screen
/// changing, the fetches they start).
Future<void> _back(WidgetTester tester) async {
  await _press(tester);
  await _settled(tester);
}

/// The phone's back gesture with gesture navigation, as the page under it
/// sees it (Android hands an edge swipe to the app until it claims it; Chrome
/// passes that on as touches): the finger lands at the right edge at [y] and
/// sweeps in and down, as fast as the owner's recording shows (Android's
/// pointer trace: about 1600 dp/s in, 900 dp/s down, 80 ms); the system then
/// claims the swipe (the touch is cancelled), and Back arrives.
Future<void> _edgeSwipeBack(WidgetTester tester, {required double y}) async {
  final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
  // Each touch stamped with its time, as a phone sends it (the drag's speed
  // is read from them).
  var at = tester.binding.clock.now().difference(DateTime(0));
  const frame = Duration(milliseconds: 16);
  final finger = await tester.createGesture();
  await finger.down(Offset(width - 2, y), timeStamp: at);
  for (var i = 0; i < 5; i++) {
    await tester.pump(frame);
    at += frame;
    await finger.moveBy(const Offset(-26, 15), timeStamp: at);
  }
  await tester.pump(frame);
  at += frame;
  await finger.cancel(timeStamp: at);
  await tester.pump(frame);
  await _press(tester);
  await _settled(tester);
}

/// The top edge of the sheet open now.
double _sheetTop(WidgetTester tester) =>
    tester.getRect(find.byType(SheetScaffold)).top;

/// Pumps until the app is still: no frame due for three pumps in a row
/// (an answer that lands asks for a frame again). A screen that never stops
/// moving fails.
Future<void> _settled(WidgetTester tester) async {
  var still = 0;
  for (var i = 0; i < 200 && still < 3; i++) {
    final due = tester.binding.hasScheduledFrame;
    await tester.pump(const Duration(milliseconds: 50));
    still = due ? 0 : still + 1;
  }
  expect(still, 3, reason: 'never settled');
}

/// Pumps frames until [done] (a screen with a spinner never settles).
Future<void> _until(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(done(), isTrue, reason: 'never happened');
}

/// The screen the screen table names (null where none is read: 01 signed
/// out). Its 01 is the gate's own, every other screen the table's shell's.
AppScreen? _screen(WidgetTester tester) {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(HomeGate)),
  );
  if (!container.exists(tableScreenProvider)) return null;
  return container.read(tableScreenProvider).value?.screen;
}

int _requests(TableSetup setup, String method) =>
    setup.http.requests.where((r) => r.method == method).length;

/// 01's scan action (a glyph: found by what a screen reader hears).
final _scanAction = find.byWidgetPredicate(
  (w) => w is GlyphButton && w.semanticLabel == ScanCopy.scan,
);

Future<void> _tap(WidgetTester tester, Finder what) async {
  await tester.ensureVisible(what);
  await tester.pump();
  await tester.tap(what);
  await _settled(tester);
}

/// A game's screen through the app's routes: [sample]'s `/me/`, on a phone
/// past its first game (no teaching ring breathing).
Future<ShellSetup> _game(WidgetTester tester, String sample) => ShellSetup.pump(
  tester,
  recordedMe(sample),
  learned: {...Cue.values},
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

    testWidgets('with the scanner open, Back closes it (the camera stops) '
        'and 01 is as it was; the next Back leaves', (tester) async {
      final platform = _Platform.listen(tester);
      final setup = await TableSetup.pump(tester, signedInAs: 'Ana');
      await tester.tap(_scanAction);
      await _settled(tester);
      expect(setup.scanners.single.started, isTrue);
      expect(find.text(JoinCopy.joinTable), findsNothing);
      // The scanner answers Back itself: the system is told the app takes it.
      expect(platform.appTakesBack, isTrue);

      await _back(tester);
      expect(platform.left, isFalse);
      expect(setup.scanners.single.disposed, isTrue);
      expect(find.text(JoinCopy.joinTable), findsOneWidget);
      expect(find.text('Ana'), findsOneWidget);
      expect(platform.appTakesBack, isFalse);

      await _back(tester);
      expect(platform.left, isTrue);
      await setup.close(tester);
    });

    testWidgets('with the scanner open over the code field, Back closes the '
        'scanner, then the field', (tester) async {
      final platform = _Platform.listen(tester);
      final setup = await TableSetup.pump(tester, signedInAs: 'Ana');
      await _tap(tester, find.text(JoinCopy.joinTable));
      await tester.tap(_scanAction);
      await _settled(tester);

      await _back(tester);
      expect(find.text(JoinCopy.codeHint), findsOneWidget);
      await _back(tester);
      expect(find.text(JoinCopy.codeHint), findsNothing);
      expect(platform.left, isFalse);
      await setup.close(tester);
    });
  });

  group('the opening waits: Back leaves (the seat is the server\'s)', () {
    testWidgets('the saved account being read back', (tester) async {
      final platform = _Platform.listen(tester);
      final setup = await TableSetup.pump(
        tester,
        authState: const AuthState.initial(),
      );
      expect(find.byType(OpeningWait), findsOneWidget);
      // The wait's lanterns turn, so the app is never still here.
      await _press(tester);
      await _until(tester, () => platform.left);
      await setup.close(tester);
    });

    testWidgets('a link\'s table not known yet', (tester) async {
      final platform = _Platform.listen(tester);
      late HeldReplies table;
      final setup = await TableSetup.pump(
        tester,
        signedInAs: 'Ana',
        route: '/join/V9YC2J',
        before: (s) => table = s.http.hold(method: 'GET', path: '/me/table/'),
      );
      expect(find.text(JoinCopy.join), findsNothing);
      await _press(tester);
      await _until(tester, () => platform.left);
      table.releaseAll();
      await setup.close(tester);
    });
  });

  testWidgets('"You\'re at another table.": Back goes there, as "Go there" '
      'does; never out of the app with a seat', (tester) async {
    final platform = _Platform.listen(tester);
    final setup = await TableSetup.pump(
      tester,
      lobby: v2Lobby('detail_auto_deck_5'),
      viewer: 'Ana',
      route: '/join/ABC234',
    );
    expect(find.text(BannerCopy.alreadyInLobby), findsOneWidget);
    expect(platform.appTakesBack, isTrue);
    await _back(tester);
    expect(platform.left, isFalse);
    expect(find.text(BannerCopy.alreadyInLobby), findsNothing);
    expect(_screen(tester), AppScreen.table);
    await setup.close(tester);
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

      testWidgets('a guest is asked the same by Back; their own Leave '
          'button does not ask', (tester) async {
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

        setup.http
          ..answer(
            'POST',
            '/lobbies/V9YC2J/leave/',
            ContractSamples.map('http/lobby/left'),
          )
          ..answer(
            'GET',
            '/me/table/',
            ContractSamples.map('http/lobby/my_table_none'),
          );
        await tester.tap(find.text(CommonCopy.leave));
        await tester.pump();
        expect(find.text(TableCopy.stay), findsNothing);
        await _settled(tester);
        expect(setup.count('POST', '/lobbies/V9YC2J/leave/'), 1);
        expect(_screen(tester), AppScreen.join);
        await setup.close(tester);
      });

      testWidgets('a table that is gone: Back goes home, as "Go home"', (
        tester,
      ) async {
        final platform = _Platform.listen(tester);
        final setup = await TableSetup.pump(
          tester,
          lobby: v2Lobby('detail_auto_deck_5'),
          viewer: 'Ben',
        );
        setup.http.answer(
          'GET',
          '/lobbies/V9YC2J/',
          ContractSamples.map('http/lobby/not_found'),
          status: 404,
        );
        setup.event(ContractSamples.map('ws/lobby/player_left'));
        await _settled(tester);
        expect(find.text(BannerCopy.tableClosed), findsOneWidget);

        setup.http.answer(
          'GET',
          '/me/table/',
          ContractSamples.map('http/lobby/my_table_none'),
        );
        await _back(tester);
        expect(find.text(TableCopy.stay), findsNothing);
        expect(_screen(tester), AppScreen.join);
        expect(platform.left, isFalse);
        await setup.close(tester);
      });

      testWidgets('nothing is asked while a leave is on its way', (
        tester,
      ) async {
        final setup = await TableSetup.pump(
          tester,
          lobby: v2Lobby('detail_auto_deck_5'),
          viewer: 'Ben',
        );
        setup.http
          ..answer(
            'POST',
            '/lobbies/V9YC2J/leave/',
            ContractSamples.map('http/lobby/left'),
          )
          ..answer(
            'GET',
            '/me/table/',
            ContractSamples.map('http/lobby/my_table_none'),
          );
        final leave = setup.http.hold(
          method: 'POST',
          path: '/lobbies/V9YC2J/leave/',
        );
        await tester.tap(find.text(CommonCopy.leave));
        await _until(tester, () => leave.length == 1);
        await _press(tester);
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text(TableCopy.stay), findsNothing);
        leave.releaseAll();
        await _until(tester, () => _screen(tester) == AppScreen.join);
        await setup.close(tester);
      });

      testWidgets('nothing is asked while a deal is on its way', (
        tester,
      ) async {
        final setup = await TableSetup.pump(
          tester,
          lobby: v2Lobby('detail_auto_deck_5'),
          viewer: 'Ana',
        );
        final started = ContractSamples.map('http/game/started_with_look');
        setup.http.answer(
          'POST',
          '/onuw/lobbies/V9YC2J/start/',
          started,
          status: 201,
        );
        setup.answerGame(recordedMe('me_look_stage'));
        final deal = setup.http.hold(
          method: 'POST',
          path: '/onuw/lobbies/V9YC2J/start/',
        );
        await tester.tap(find.text(TableCopy.start));
        await _until(tester, () => deal.length == 1);
        await _press(tester);
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text(TableCopy.stay), findsNothing);
        deal.releaseAll();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text(TableCopy.stay), findsNothing);
        await setup.close(tester);
      });

      testWidgets('the question closes with its screen: the host deals while '
          'a guest is asked, and the guest is at the card, nothing left', (
        tester,
      ) async {
        final setup = await TableSetup.pump(
          tester,
          lobby: v2Lobby('detail_auto_deck_5'),
          viewer: 'Ben',
        );
        await _back(tester);
        expect(find.text(TableCopy.stay), findsOneWidget);

        final dealt = recordedMe('me_look_stage');
        setup.answerGame(dealt);
        setup.http.answer(
          'GET',
          '/me/table/',
          serverMyTable(
            code: 'V9YC2J',
            status: 'in_game',
            gameId: dealt['game_id'] as String,
          ),
        );
        setup.event({
          ...ContractSamples.map('ws/lobby/game_started'),
          'game_id': dealt['game_id'],
        });
        await _until(tester, () => _screen(tester) == AppScreen.yourCard);
        // The question goes with the table.
        await _until(
          tester,
          () => find.text(TableCopy.stay).evaluate().isEmpty,
        );
        expect(_requests(setup, 'POST'), 0);
        await setup.close(tester);
      });
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

    testWidgets('a deck of the wrong size: the first Back stays on 03 and '
        'shows the count, the second goes back (never trapped)', (
      tester,
    ) async {
      final platform = _Platform.listen(tester);
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('settings_seats_lowered'),
        viewer: 'Tia',
      );
      // The button is the way in (no "Edit" while the deck is wrong).
      await _tap(tester, find.text(DeckCopy.removeCard));
      expect(_screen(tester), AppScreen.deck);
      final count = DeckCopy.countFix.fill({
        'picked': 11,
        'need': 10,
        'fix': DeckCopy.removeCard,
      });
      expect(find.text(count), findsOneWidget);

      // The first Back stays and nudges the count; the second goes back.
      await _back(tester);
      expect(_screen(tester), AppScreen.deck);
      expect(find.text(count), findsOneWidget);
      expect(platform.left, isFalse);
      await _back(tester);
      expect(_screen(tester), AppScreen.table);
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

  testWidgets('03: a hold as short as the owner\'s reads the card; a tap does '
      'not (the owner\'s recording: holds of 0.40 and 0.43 s opened nothing, '
      'taps lasted under 0.1 s)', (tester) async {
    final setup = await TableSetup.pump(
      tester,
      lobby: v2Lobby('detail_auto_deck_5'),
      viewer: 'Ana',
    );
    await _tap(tester, find.text(TableCopy.editDeck));
    // Seer: in the deck, at its most (a tap on it changes nothing).
    final seer = find.byWidgetPredicate(
      (w) => w is RoleCard && w.role == RoleId.seer,
    );
    await tester.ensureVisible(seer);
    await tester.pump();
    Future<void> press(Duration length) async {
      final finger = await tester.startGesture(tester.getCenter(seer));
      await tester.pump(length);
      await finger.up();
      await _settled(tester);
    }

    await press(const Duration(milliseconds: 90));
    expect(find.byType(RoleSheetBody), findsNothing, reason: 'a tap');
    for (var i = 0; i < 2; i++) {
      await press(const Duration(milliseconds: 400));
      expect(find.byType(RoleSheetBody), findsOneWidget, reason: 'held');
      await _back(tester);
      expect(find.byType(RoleSheetBody), findsNothing);
    }
    expect(_screen(tester), AppScreen.deck);
    await setup.close(tester);
  });

  group('one back gesture does one thing: its own touch never closes a sheet '
      '(gesture navigation, the owner\'s recording)', () {
    // The back swipe starts as a touch on the page, at the screen's edge,
    // over whatever is there: here the sheet. Were that touch to drag the
    // sheet closed, the Back that follows would find the screen under it
    // and do that screen's Back too.
    void phone(WidgetTester tester) {
      // The owner's phone: 412 wide, a sheet edge to edge.
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('03: a role\'s sheet closes; the page stays', (tester) async {
      phone(tester);
      final platform = _Platform.listen(tester);
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('detail_auto_deck_5'),
        viewer: 'Ana',
      );
      await _tap(tester, find.text(TableCopy.editDeck));
      for (var i = 0; i < 3; i++) {
        final card = find.byType(RoleCard).at(i);
        await tester.ensureVisible(card);
        await tester.pump();
        await tester.longPress(card);
        await _settled(tester);
        expect(find.byType(RoleSheetBody), findsOneWidget);

        await _edgeSwipeBack(tester, y: _sheetTop(tester) + Space.sm);
        expect(find.byType(RoleSheetBody), findsNothing, reason: 'closed');
        expect(_screen(tester), AppScreen.deck, reason: 'card $i: one Back');
      }
      expect(platform.left, isFalse);
      await setup.close(tester);
    });

    testWidgets('02: the leave question closes; it is not asked again', (
      tester,
    ) async {
      phone(tester);
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('detail_auto_deck_5'),
        viewer: 'Ana',
      );
      await _back(tester);
      expect(find.text(TableCopy.stay), findsOneWidget);

      await _edgeSwipeBack(tester, y: _sheetTop(tester) + Space.sm);
      expect(find.text(TableCopy.stay), findsNothing);
      expect(_screen(tester), AppScreen.table);
      expect(_requests(setup, 'POST'), 0);
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

    testWidgets('04: two Backs at once do nothing either', (tester) async {
      final platform = _Platform.listen(tester);
      final s = await _game(tester, 'me_look_stage');
      await s.settle(tester);
      await Future.wait([_press(tester), _press(tester)]);
      await _settled(tester);
      expect(s.screenOn(tester), AppScreen.yourCard);
      expect(platform.left, isFalse);
      await s.close(tester);
    });

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

    testWidgets('08 with My night up as it opens: Back puts it away (it is on '
        'the board, not a sheet); then nothing', (tester) async {
      final platform = _Platform.listen(tester);
      final s = await _game(tester, 'me_discussion_choose_seer');
      await s.settle(tester);
      expect(find.byType(MyNightPanel), findsOneWidget);

      await _back(tester);
      await s.settle(tester);
      expect(find.byType(MyNightPanel), findsNothing);
      expect(find.byType(DeckPile), findsWidgets);
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
      final card = find.byType(DeckPile).first;
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

  testWidgets('a sheet never outlives its screen: 08\'s role sheet closes '
      'when the vote opens', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final s = await _game(tester, 'me_talk_ready');
    await s.settle(tester);
    // My night is open on arrival: Back puts it away.
    await _back(tester);
    final card = find.byType(DeckPile).first;
    await tester.ensureVisible(card);
    await tester.longPress(card);
    await _settled(tester);
    expect(find.byType(RoleSheetBody), findsOneWidget);

    s.answerMe(recordedMe('me_voting_picked'));
    s.ws.addServerEvent(GameEvents.phaseChange(phase: 'voting'));
    await _settled(tester);
    expect(s.screenOn(tester), AppScreen.vote);
    expect(find.byType(RoleSheetBody), findsNothing);
    await s.close(tester);
  });

  group(
    'a sheet closed leaves nothing behind: the next hold opens its role',
    () {
      // The owner's report: after Back from a role's sheet, a hold on another
      // card opened nothing until the deck changed. Every way a role sheet
      // closes, then a hold on each of three other cards, on every screen that
      // opens one (02's strip, 03's grid, 08's deck).
      Future<TableSetup> table(WidgetTester tester) => TableSetup.pump(
        tester,
        lobby: v2Lobby('detail_auto_deck_5'),
        viewer: 'Ana',
      );

      Future<TableSetup> deck(WidgetTester tester) async {
        final setup = await table(tester);
        await _tap(tester, find.text(TableCopy.editDeck));
        expect(_screen(tester), AppScreen.deck);
        return setup;
      }

      /// Holds card [i] as a finger does (down, the press time, up).
      Future<void> hold(
        WidgetTester tester,
        int i, {
        PointerDeviceKind? kind,
        Type cards = RoleCard,
      }) async {
        final card = find.byType(cards).at(i);
        await tester.ensureVisible(card);
        await tester.pump();
        await tester.longPress(card, kind: kind ?? PointerDeviceKind.touch);
        await _settled(tester);
      }

      Future<void> pressClose(WidgetTester tester) async {
        await tester.tap(find.text(RoleSheetCopy.close));
        await _settled(tester);
      }

      /// Opens a sheet by [open], closes it by [close], three times over.
      Future<void> reopens(
        WidgetTester tester, {
        required Future<void> Function(int i) open,
        required Future<void> Function() close,
      }) async {
        for (var i = 0; i < 3; i++) {
          await open(i);
          expect(
            find.byType(RoleSheetBody),
            findsOneWidget,
            reason: 'card $i opens its sheet',
          );
          await close();
          expect(find.byType(RoleSheetBody), findsNothing, reason: 'closed');
        }
      }

      testWidgets('03, closed by Back', (tester) async {
        final setup = await deck(tester);
        await reopens(
          tester,
          open: (i) => hold(tester, i),
          close: () => _back(tester),
        );
        expect(_screen(tester), AppScreen.deck);
        await setup.close(tester);
      });

      testWidgets('03, closed by its Close', (tester) async {
        final setup = await deck(tester);
        await reopens(
          tester,
          open: (i) => hold(tester, i),
          close: () => pressClose(tester),
        );
        await setup.close(tester);
      });

      testWidgets('03, a mouse held and Back before it is let go', (
        tester,
      ) async {
        final setup = await deck(tester);
        for (var i = 0; i < 3; i++) {
          final card = find.byType(RoleCard).at(i);
          await tester.ensureVisible(card);
          await tester.pump();
          final mouse = await tester.startGesture(
            tester.getCenter(card),
            kind: PointerDeviceKind.mouse,
          );
          await tester.pump(const Duration(milliseconds: 700));
          expect(find.byType(RoleSheetBody), findsOneWidget);
          await _press(tester);
          await mouse.up();
          await _settled(tester);
          expect(find.byType(RoleSheetBody), findsNothing);
        }
        await setup.close(tester);
      });

      testWidgets('03, on the web (the browser\'s Back)', (tester) async {
        BackPolicy.web = true;
        BackPolicy.leaveWeb = () {};
        final setup = await deck(tester);
        await reopens(
          tester,
          open: (i) => hold(tester, i),
          close: () => _back(tester),
        );
        BackPolicy.web = false;
        await setup.close(tester);
      });

      testWidgets(
        '03, closed by the back gesture of Android (predictive back)',
        (tester) async {
          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          final setup = await deck(tester);
          Future<void> gesture(String method, [double progress = 0]) =>
              tester.binding.defaultBinaryMessenger.handlePlatformMessage(
                SystemChannels.backGesture.name,
                SystemChannels.backGesture.codec.encodeMethodCall(
                  MethodCall(method, {
                    'touchOffset': <double>[5, 300],
                    'progress': progress,
                    'swipeEdge': 0,
                  }),
                ),
                (_) {},
              );
          await reopens(
            tester,
            open: (i) => hold(tester, i),
            close: () async {
              await gesture('startBackGesture');
              await tester.pump(const Duration(milliseconds: 16));
              await gesture('updateBackGestureProgress', 0.4);
              await tester.pump(const Duration(milliseconds: 16));
              // Swiped, let go, swiped again, and let through.
              await gesture('cancelBackGesture');
              await _settled(tester);
              expect(find.byType(RoleSheetBody), findsOneWidget);
              await gesture('startBackGesture');
              await gesture('commitBackGesture');
              await _settled(tester);
            },
          );
          expect(_screen(tester), AppScreen.deck);
          debugDefaultTargetPlatformOverride = null;
          await setup.close(tester);
        },
      );

      testWidgets('03 again after Back to 02', (tester) async {
        final setup = await deck(tester);
        await hold(tester, 0);
        await _back(tester);
        await _back(tester);
        expect(_screen(tester), AppScreen.table);
        await _tap(tester, find.text(TableCopy.editDeck));
        await reopens(
          tester,
          open: (i) => hold(tester, i),
          close: () => _back(tester),
        );
        await setup.close(tester);
      });

      testWidgets('02 strip, held and closed by Back', (tester) async {
        final setup = await table(tester);
        await reopens(
          tester,
          open: (i) => hold(tester, i),
          close: () => _back(tester),
        );
        expect(_screen(tester), AppScreen.table);
        await setup.close(tester);
      });

      testWidgets('02 strip, tapped and closed by its Close', (tester) async {
        final setup = await table(tester);
        await reopens(
          tester,
          open: (i) => _tap(tester, find.byType(RoleCard).at(i)),
          close: () => pressClose(tester),
        );
        await setup.close(tester);
      });

      for (final byBack in [true, false]) {
        testWidgets('08 deck, closed by ${byBack ? 'Back' : 'its Close'}', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final s = await _game(tester, 'me_talk_results_seen');
          await s.settle(tester);
          await reopens(
            tester,
            open: (i) => hold(tester, i, cards: DeckPile),
            close: () => byBack ? _back(tester) : pressClose(tester),
          );
          expect(s.screenOn(tester), AppScreen.talk);
          await s.close(tester);
        });
      }
    },
  );

  group('on the web', () {
    var left = 0;
    setUp(() {
      left = 0;
      BackPolicy.web = true;
      BackPolicy.leaveWeb = () => left++;
    });
    tearDown(() {
      BackPolicy.web = false;
      BackPolicy.leaveWeb = () {};
    });

    testWidgets('01: Back steps back past the app\'s history entry, never '
        'through the engine\'s exit (which disarms Back where there is no '
        'page before)', (tester) async {
      final platform = _Platform.listen(tester);
      final setup = await TableSetup.pump(tester);
      await _back(tester);
      expect(left, 1);
      expect(platform.left, isFalse);
      await setup.close(tester);
    });

    testWidgets('02: the same as on a phone', (tester) async {
      final platform = _Platform.listen(tester);
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('detail_auto_deck_5'),
        viewer: 'Ben',
      );
      await _back(tester);
      expect(find.text(TableCopy.stay), findsOneWidget);
      await _back(tester);
      expect(find.text(TableCopy.stay), findsNothing);
      expect(left, 0);
      expect(platform.left, isFalse);
      await setup.close(tester);
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
