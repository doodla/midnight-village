import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/app.dart';
import 'package:midnight_village/core/api/api_client.dart';
import 'package:midnight_village/core/api/auth_interceptor.dart';
import 'package:midnight_village/core/api/authenticated_client.dart';
import 'package:midnight_village/core/healing/healing.dart';
import 'package:midnight_village/core/storage/device_preferences.dart';
import 'package:midnight_village/core/storage/tab_storage.dart';
import 'package:midnight_village/core/storage/tab_storage_provider.dart';
import 'package:midnight_village/core/storage/token_storage.dart';
import 'package:midnight_village/core/storage/user_storage.dart';
import 'package:midnight_village/core/wakelock/wakelock_service.dart';
import 'package:midnight_village/design_system/night/night_board.dart';
import 'package:midnight_village/design_system/skin/skin_choice.dart';
import 'package:midnight_village/features/auth/presentation/auth_notifier.dart';
import 'package:midnight_village/features/game/presentation/game_socket.dart';
import 'package:midnight_village/features/game/presentation/new_build_provider.dart';
import 'package:midnight_village/features/game/presentation/end/end_board_view.dart';
import 'package:midnight_village/features/game/presentation/shell/talk_screen.dart';
import 'package:midnight_village/features/game/presentation/shell/vote_screen.dart';
import 'package:midnight_village/features/game/presentation/table_screen.dart';
import 'package:midnight_village/features/lobby/data/home_service.dart';
import 'package:midnight_village/features/lobby/presentation/at_table_screen.dart';
import 'package:midnight_village/features/lobby/presentation/home_numbers.dart';
import 'package:midnight_village/features/lobby/presentation/last_seat.dart';
import 'package:midnight_village/features/lobby/presentation/lobby_notifier.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/contract/contract_samples.dart';
import '../helpers/contract/server_json.dart';
import '../helpers/fake_wakelock_service.dart';
import '../helpers/live_game_setup.dart';
import '../helpers/mock_http_client.dart';
import '../helpers/mock_websocket.dart';
import '../helpers/outcome_samples.dart';

/// An app left open on an old build renews itself (a reload of the page) at a
/// safe moment, and the reload goes through the app's own opening: a seated
/// player lands back in their seat on the same screen. Each case opens the
/// whole app with a seat, learns that the live build is another, sees the
/// reload at the moment the rule gives, and opens the app again, cold, as the
/// reloaded page does (the device's own preferences kept).

String _accessToken(DateTime exp) {
  String part(Object value) =>
      base64Url.encode(utf8.encode(json.encode(value))).replaceAll('=', '');
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${part({'token_type': 'access', 'exp': exp.millisecondsSinceEpoch ~/ 1000})}.'
      'signature';
}

class _Device extends Mock implements FlutterSecureStorage {
  _Device(this.values) {
    when(
      () => read(key: any(named: 'key')),
    ).thenAnswer((i) async => values[i.namedArguments[#key]]);
    when(
      () => write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((i) async {
      values[i.namedArguments[#key] as String] =
          i.namedArguments[#value] as String?;
    });
    when(() => delete(key: any(named: 'key'))).thenAnswer((i) async {
      values.remove(i.namedArguments[#key]);
    });
  }

  final Map<String, String?> values;
}

/// One situation of a seated player.
class _Case {
  _Case(
    this.name, {
    required this.me,
    required this.screen,
    required this.waitsForTheGame,
    this.lobby = false,
    this.results,
  });

  final String name;
  final Map<String, dynamic> me;
  final Type screen;

  Finder get finder => find.byType(screen, skipOffstage: false);

  /// A game that runs: the reload waits for the app to come back (or the next
  /// phase); at a table before the deal and at the end it goes at once.
  final bool waitsForTheGame;

  /// At a waiting table, not in a game.
  final bool lobby;
  final Map<String, dynamic>? results;
}

class _Page {
  final reloads = <String>[];

  /// The build the host says is live (the old one until a test says so).
  var live = 'old';
  final resumes = StreamController<int>.broadcast();
  var _resumed = 0;

  /// The tab's own storage: the reloaded page keeps it (a new page in the
  /// same tab), which is where the loop guard lives.
  final storage = MemoryTabStorage();

  /// The clock the away time is measured by; the tab's time away moves it.
  var clock = sampleClockStart;

  /// The tab goes to the background for a while and comes back: the page's
  /// visibility, as Flutter reports it, and the app's own resume.
  Future<void> comeBack(WidgetTester tester) async {
    final binding = tester.binding;
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
    ]) {
      binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump(const Duration(seconds: 10));
    clock = clock.add(const Duration(seconds: 10));
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      binding.handleAppLifecycleStateChanged(state);
    }
    resumes.add(++_resumed);
    await tester.pump();
  }
}

final _lobbyCode = 'K7QX4M';

Future<void> _until(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(done(), isTrue, reason: 'never happened');
}

Future<void> _open(
  WidgetTester tester, {
  required _Page page,
  required String mine,
  required Map<String, dynamic> server,
  required Map<String, dynamic> me,
  required bool lobby,
  Map<String, dynamic>? results,
}) async {
  final playerId = me['player_id'] as int;
  final gameId = me['game_id'] as String;
  final http = MockHttpClient();
  if (lobby) {
    http
      ..answer(
        'GET',
        '/me/table/',
        serverMyTable(code: _lobbyCode, isHost: true),
      )
      ..answer('GET', '/lobbies/$_lobbyCode/', server);
  } else {
    http
      ..answer('GET', '/me/table/', tableOf(me))
      ..answer('GET', '/onuw/games/$gameId/me/', me);
    // The talk tells the server it has seen the night (a request out for a moment).
    http.answer(
      'POST',
      '/onuw/games/$gameId/night-results/seen/',
      ContractSamples.map('http/game/night_results_seen'),
    );
    if (results != null) {
      http.answer('GET', '/onuw/games/$gameId/results/', results);
    }
  }
  final device = _Device({
    'access_token': _accessToken(
      sampleClockStart.add(const Duration(hours: 1)),
    ),
    'refresh_token': 'refresh-token-1',
    'user_id': '$playerId',
    'display_name': 'Ana',
  });
  final serverSide = http.dio.interceptors.last;
  final signedIn = Dio();
  AuthenticatedClient signedInClient(Ref ref) {
    signedIn.interceptors
      ..clear()
      ..add(
        AuthInterceptor(
          tokenStorage: ref.watch(tokenStorageProvider),
          unauthenticatedClient: ref.watch(apiClientProvider),
          onAuthFailure: () => ref.invalidate(authProvider),
          retryFetch: signedIn.fetch,
        ),
      )
      ..add(serverSide);
    return AuthenticatedClient.forTesting(dio: signedIn);
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(TokenStorage(storage: device)),
        userStorageProvider.overrideWithValue(UserStorage(storage: device)),
        apiClientProvider.overrideWithValue(ApiClient(dio: http.dio)),
        authenticatedClientProvider.overrideWith(signedInClient),
        homeServiceProvider.overrideWithValue(
          HomeService(client: ApiClient(dio: http.dio)),
        ),
        devicePreferencesProvider.overrideWithValue(DevicePreferences()),
        lobbyWebSocketFactoryProvider.overrideWithValue(
          (_) => MockWebSocketChannel(),
        ),
        gameWebSocketProvider.overrideWith((ref, id) => null),
        gameWebSocketStreamProvider.overrideWith(
          (ref, id) => MockWebSocketChannel().stream,
        ),
        gameConnectionStateProvider.overrideWith(
          (ref, id) => const Stream.empty(),
        ),
        appResumesProvider.overrideWith((ref) => page.resumes.stream),
        appOriginProvider.overrideWithValue(
          Uri.parse('https://midnight.example'),
        ),
        healTimingProvider.overrideWithValue(testHealTiming),
        clockProvider.overrideWithValue(() => sampleClockStart),
        wakelockServiceProvider.overrideWithValue(FakeWakelockService()),
        // The build this app is, and the one the host says is live.
        buildIdProvider.overrideWithValue(mine),
        liveBuildFetchProvider.overrideWithValue(() async => page.live),
        workerRenewalProvider.overrideWithValue(() async => true),
        pageReloadProvider.overrideWithValue(
          () async => page.reloads.add(page.live),
        ),
        tabStorageProvider.overrideWithValue(page.storage),
        newBuildClockProvider.overrideWithValue(() => page.clock),
      ],
      child: const App(),
    ),
  );
  await tester.pump();
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(minutes: 6));
}

Future<void> _device(_Case c, {bool lobby = false}) async {
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({
    '${LastSeat.prefix}${c.me['player_id']}:'
            '${lobby ? _lobbyCode : '${c.me['lobby_code']}|${c.me['game_id']}'}':
        '1',
  });
  forgetRestoredLocalSteps();
  await restoreLocalSteps();
}

void main() {
  tearDown(forgetRestoredLocalSteps);

  final seer = recordedMe('me_choose_prompt_seer');
  final cases = [
    _Case(
      'a waiting table (02)',
      me: seer,
      screen: AtTableView,
      waitsForTheGame: false,
      lobby: true,
    ),
    _Case(
      'the night (the night board)',
      me: seer,
      screen: NightBoard,
      waitsForTheGame: true,
    ),
    _Case(
      'the discussion (08)',
      me: recordedMe('me_talk_ready'),
      screen: TalkView,
      waitsForTheGame: true,
    ),
    _Case(
      'the vote (09)',
      me: recordedMe('me_voting_unpicked'),
      screen: VoteView,
      waitsForTheGame: true,
    ),
    _Case(
      'the results (the end board)',
      me: recordedMe('me_results'),
      screen: EndBoardView,
      waitsForTheGame: true,
      results: recordedResults('results'),
    ),
  ];

  group('A newer build is live', () {
    for (final c in cases) {
      final lobby = c.lobby;
      final server = serverLobby(
        code: _lobbyCode,
        seats: [
          (id: c.me['player_id'] as int, name: 'Ana'),
          (id: 2, name: 'Bo'),
        ],
        hostId: c.me['player_id'] as int,
      );

      testWidgets('${c.name}: reloaded at its moment, and the player is back '
          'in the same seat on the same screen', (tester) async {
        await _device(c, lobby: lobby);
        final page = _Page();
        await _open(
          tester,
          page: page,
          mine: 'old',
          server: server,
          me: c.me,
          lobby: lobby,
          results: c.results,
        );
        await _until(tester, () => c.finder.evaluate().isNotEmpty);

        // A new build goes live while the app is open: the slow look finds it.
        page.live = 'new';
        await tester.pump(const Duration(minutes: 5, seconds: 1));
        if (c.waitsForTheGame) {
          // A game that runs: not now ...
          expect(page.reloads, isEmpty, reason: 'it waits for a moment');
          // ... not at a phase change either, but when the app comes back.
          await page.comeBack(tester);
          await _until(tester, () => page.reloads.isNotEmpty);
        } else {
          await _until(tester, () => page.reloads.isNotEmpty);
        }
        expect(page.reloads, ['new']);

        // The reloaded page is the new build, opened cold: the same seat, the
        // same screen, and no second reload.
        await _close(tester);
        await _device(c, lobby: lobby);
        await _open(
          tester,
          page: page,
          mine: 'new',
          server: server,
          me: c.me,
          lobby: lobby,
          results: c.results,
        );
        await _until(tester, () => c.finder.evaluate().isNotEmpty);
        await page.comeBack(tester);
        await tester.pump(const Duration(seconds: 1));
        expect(page.reloads, ['new']);
        await _close(tester);
      });
    }

    testWidgets('a shell that stays the old build is not reloaded again for '
        'the same live build', (tester) async {
      final c = cases[1];
      await _device(c);
      final page = _Page()..live = 'new';
      Future<void> openOld() => _open(
        tester,
        page: page,
        mine: 'old',
        server: const {},
        me: c.me,
        lobby: false,
      );
      await openOld();
      await _until(tester, () => c.finder.evaluate().isNotEmpty);
      await page.comeBack(tester);
      await _until(tester, () => page.reloads.isNotEmpty);
      await _close(tester);

      // The page came back as the old build (a cached shell): it keeps the
      // seat and is left alone, at every moment there is.
      await openOld();
      await _until(tester, () => c.finder.evaluate().isNotEmpty);
      await page.comeBack(tester);
      await tester.pump(const Duration(minutes: 6));
      await page.comeBack(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(page.reloads, ['new'], reason: 'once, never in a loop');
      expect(c.finder, findsOneWidget);
      await _close(tester);
    });
  });
}
