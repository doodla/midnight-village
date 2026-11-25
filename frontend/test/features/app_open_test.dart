import 'dart:async';
import 'dart:convert';

import 'package:midnight_village/core/requests/player_request.dart';
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
import 'package:midnight_village/core/storage/token_storage.dart';
import 'package:midnight_village/core/storage/user_storage.dart';
import 'package:midnight_village/core/wakelock/wakelock_service.dart';
import 'package:midnight_village/core/websocket/reconnecting_websocket.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/load_once_bundle.dart';
import 'package:midnight_village/design_system/skin_loader.dart';
import 'package:midnight_village/design_system/skin/skin_choice.dart';
import 'package:midnight_village/features/auth/data/auth_repository.dart';
import 'package:midnight_village/features/auth/data/auth_service.dart';
import 'package:midnight_village/features/auth/domain/auth_state.dart';
import 'package:midnight_village/features/auth/presentation/auth_notifier.dart';
import 'package:midnight_village/features/game/presentation/game_socket.dart';
import 'package:midnight_village/features/game/presentation/shell/your_card_screen.dart';
import 'package:midnight_village/features/game/presentation/table_screen.dart';
import 'package:midnight_village/features/lobby/data/home_service.dart';
import 'package:midnight_village/features/lobby/presentation/at_table_screen.dart';
import 'package:midnight_village/features/lobby/presentation/home_numbers.dart';
import 'package:midnight_village/features/lobby/presentation/join_screen.dart';
import 'package:midnight_village/features/lobby/presentation/last_seat.dart';
import 'package:midnight_village/features/lobby/presentation/lobby_notifier.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/contract/contract_samples.dart';
import '../helpers/finger.dart';
import '../helpers/contract/server_json.dart';
import '../helpers/fake_wakelock_service.dart';
import '../helpers/live_game_setup.dart';
import '../helpers/mock_http_client.dart';
import '../helpers/mock_websocket.dart';

/// Opening the app as a player who has a seat: how many requests go out
/// before their screen (the floor, pinned), and that a saved account is
/// never given up for "no account" because the server could not be asked.

/// The game the phone was in: 04, its card (a recorded `/me/`).
final _me = recordedMe('me_look_stage');
String get _gameId => _me['game_id'] as String;
String get _mePath => '/onuw/games/$_gameId/me/';
int get _playerId => _me['player_id'] as int;

/// An access token as the server makes them (a JWT), ending at [exp].
String _accessToken(DateTime exp) {
  String part(Object value) =>
      base64Url.encode(utf8.encode(json.encode(value))).replaceAll('=', '');
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${part({'token_type': 'access', 'exp': exp.millisecondsSinceEpoch ~/ 1000})}.'
      'signature';
}

/// Still good for an hour, or ended an hour ago (by the phone's clock).
final _goodToken = _accessToken(sampleClockStart.add(const Duration(hours: 1)));
final _endedToken = _accessToken(
  sampleClockStart.subtract(const Duration(hours: 1)),
);

/// This device's secure storage, in memory.
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

/// A device that signed in as the player of [_me] with [access].
_Device _signedIn(String access) => _Device({
  'access_token': access,
  'refresh_token': 'refresh-token-1',
  'user_id': '$_playerId',
  'display_name': 'Ana',
});

class _Phone {
  _Phone(this.http, this.device);

  final MockHttpClient http;
  final _Device device;
  final gameWs = MockWebSocketChannel();

  /// The lobby's socket is the app's own [ReconnectingWebSocket] over a
  /// fake connection, whose opening the test may hold ([holdLobbySocket],
  /// then [openLobbySocket]); else it opens at once.
  Completer<void>? _lobbyOpens;
  void holdLobbySocket() => _lobbyOpens = Completer<void>();
  void openLobbySocket() => _lobbyOpens?.complete();
  final _sockets = <ReconnectingWebSocket>[];

  List<String> get sent => [
    for (final r in http.requests) '${r.method} ${r.path}',
  ];

  /// The app, opened: the real start (the saved account read back, the
  /// router, home, the table's shell, the real `AuthInterceptor` that sends
  /// the token and renews it on a 401) over the strict mock server.
  Future<void> open(WidgetTester tester) async {
    // The signed-in client: the app's interceptor first, then the mock
    // server (the same one the plain client and the requests list use).
    final server = http.dio.interceptors.last;
    final signedIn = Dio();
    AuthenticatedClient signedInClient(Ref ref) {
      final interceptor = AuthInterceptor(
        tokenStorage: ref.watch(tokenStorageProvider),
        unauthenticatedClient: ref.watch(apiClientProvider),
        onAuthFailure: () => ref.invalidate(authProvider),
        retryFetch: signedIn.fetch,
      );
      signedIn.interceptors
        ..clear()
        ..add(interceptor)
        ..add(server);
      return AuthenticatedClient.forTesting(dio: signedIn);
    }

    // One holder of the tokens for the app and its sockets, as in the app.
    final tokens = TokenStorage(storage: device);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(tokens),
          userStorageProvider.overrideWithValue(UserStorage(storage: device)),
          apiClientProvider.overrideWithValue(ApiClient(dio: http.dio)),
          authenticatedClientProvider.overrideWith(signedInClient),
          homeServiceProvider.overrideWithValue(
            HomeService(client: ApiClient(dio: http.dio)),
          ),
          devicePreferencesProvider.overrideWithValue(DevicePreferences()),
          lobbyWebSocketFactoryProvider.overrideWithValue((code) {
            final socket = ReconnectingWebSocket(
              url: 'ws://midnight.example/ws/lobby/$code/',
              tokenStorage: tokens,
              channelFactory: (_) =>
                  MockWebSocketChannel(opens: _lobbyOpens?.future),
            );
            _sockets.add(socket);
            unawaited(socket.connect());
            return socket;
          }),
          gameWebSocketProvider.overrideWith((ref, id) => null),
          gameWebSocketStreamProvider.overrideWith((ref, id) => gameWs.stream),
          gameConnectionStateProvider.overrideWith(
            (ref, id) => const Stream.empty(),
          ),
          appResumesProvider.overrideWith((ref) => const Stream.empty()),
          appOriginProvider.overrideWithValue(
            Uri.parse('https://midnight.example'),
          ),
          healTimingProvider.overrideWithValue(testHealTiming),
          clockProvider.overrideWithValue(() => sampleClockStart),
          wakelockServiceProvider.overrideWithValue(FakeWakelockService()),
        ],
        child: const App(),
      ),
    );
    await tester.pump();
  }

  /// Closes the app and lets its timers run out.
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    for (final socket in _sockets) {
      socket.dispose();
    }
    await tester.pump(const Duration(seconds: 1));
  }
}

/// Pumps frames (no time passes; what is due now runs) until [done]: the
/// start is a chain of storage reads and answers, each a turn or two.
Future<void> _until(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await tester.pump(Duration.zero);
  }
  expect(done(), isTrue, reason: 'never happened');
}

/// A fresh device's preferences, holding the seat [seat] (`LastSeat`) of
/// account [owner] (the player of [_me] unless given), read before the first
/// frame as `main` reads them.
Future<void> _preferences({String? seat, int? owner}) async {
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({
    if (seat != null) '${LastSeat.prefix}${owner ?? _playerId}:$seat': '1',
  });
  forgetRestoredLocalSteps();
  await restoreLocalSteps();
}

void main() {
  tearDown(forgetRestoredLocalSteps);

  group('Opening the app with a seat', () {
    testWidgets('in a game: two requests, side by side, then the game screen '
        '(no token renewal, no "which game" look-up)', (tester) async {
      await _preferences(seat: '${_me['lobby_code']}|$_gameId');
      final phone = _Phone(MockHttpClient(), _signedIn(_goodToken));
      phone.http
        ..answer('GET', '/me/table/', tableOf(_me))
        ..answer('GET', _mePath, _me);
      final table = phone.http.hold(method: 'GET', path: '/me/table/');
      final me = phone.http.hold(method: 'GET', path: _mePath);

      await phone.open(tester);

      // Both are out before either answers: the game's read does not wait
      // for the table's.
      await _until(tester, () => table.length + me.length == 2);
      expect(phone.sent, unorderedEquals(['GET /me/table/', 'GET $_mePath']));

      table.releaseAll();
      me.releaseAll();
      await _until(
        tester,
        () => find.byType(YourCardScreen).evaluate().isNotEmpty,
      );
      expect(phone.sent, hasLength(2));
      // The screens draw from the bundle the start precaches with (a
      // picture decoded from another bundle would not be found).
      final drawnFrom = DefaultAssetBundle.of(
        tester.element(find.byType(YourCardScreen)),
      );
      expect(drawnFrom, same(appAssets));
      expect(SkinLoader().bundle, same(appAssets));
      await phone.close(tester);
    });

    testWidgets('an access token past its end is renewed first: three '
        'requests, two round trips after it', (tester) async {
      await _preferences(seat: '${_me['lobby_code']}|$_gameId');
      final phone = _Phone(MockHttpClient(), _signedIn(_endedToken));
      phone.http
        ..answer(
          'POST',
          '/auth/token/refresh/',
          ContractSamples.map('http/auth/token_refreshed'),
        )
        ..answer('GET', '/me/table/', tableOf(_me))
        ..answer('GET', _mePath, _me);
      final renewal = phone.http.hold(
        method: 'POST',
        path: '/auth/token/refresh/',
      );

      await phone.open(tester);
      await _until(tester, () => renewal.length == 1);
      for (var i = 0; i < 10; i++) {
        await tester.pump();
      }
      // Nothing is read before the account is.
      expect(phone.sent, ['POST /auth/token/refresh/']);

      renewal.releaseAll();
      await _until(
        tester,
        () => find.byType(YourCardScreen).evaluate().isNotEmpty,
      );
      expect(phone.sent.first, 'POST /auth/token/refresh/');
      expect(
        phone.sent.skip(1),
        unorderedEquals(['GET /me/table/', 'GET $_mePath']),
      );
      expect(
        phone.device.values['access_token'],
        ContractSamples.map('http/auth/token_refreshed')['access'],
      );
      await phone.close(tester);
    });

    testWidgets('at a waiting table: the table and its lobby, side by side, '
        'then 02', (tester) async {
      const code = 'K7QX4M';
      final lobby = serverLobby(
        code: code,
        seats: [(id: _playerId, name: 'Ana'), (id: 2, name: 'Bo')],
        hostId: _playerId,
      );
      await _preferences(seat: code);
      final phone = _Phone(MockHttpClient(), _signedIn(_goodToken));
      phone.http
        ..answer('GET', '/me/table/', serverMyTable(code: code, isHost: true))
        ..answer('GET', '/lobbies/$code/', lobby);
      final table = phone.http.hold(method: 'GET', path: '/me/table/');

      await phone.open(tester);
      await _until(tester, () => phone.sent.length >= 2);
      expect(
        phone.sent.take(2),
        unorderedEquals(['GET /me/table/', 'GET /lobbies/$code/']),
      );

      table.releaseAll();
      await _until(
        tester,
        () => find.byType(AtTableView).evaluate().isNotEmpty,
      );
      // And the lobby once more as its socket is up (anything said before it
      // listened); the table's read out answers that opening too.
      expect(phone.sent.skip(2), ['GET /lobbies/$code/']);
      await phone.close(tester);
    });

    for (final socketFirst in const [false, true]) {
      testWidgets('at a waiting table whose game has since started, the '
          '${socketFirst ? 'socket opening before' : 'socket opening after'} '
          'the lobby answers: one read of where the phone sits', (
        tester,
      ) async {
        const code = 'K7QX4M';
        final lobby = serverLobby(
          code: code,
          seats: [(id: _playerId, name: 'Ana'), (id: 2, name: 'Bo')],
          hostId: _playerId,
          status: 'in_game',
        );
        await _preferences(seat: code);
        final phone = _Phone(MockHttpClient(), _signedIn(_goodToken))
          ..holdLobbySocket();
        phone.http
          ..answer('GET', '/me/table/', tableOf(_me))
          ..answer('GET', '/lobbies/$code/', lobby)
          ..answer('GET', _mePath, _me);
        final table = phone.http.hold(method: 'GET', path: '/me/table/');
        final lobbyRead = phone.http.hold(
          method: 'GET',
          path: '/lobbies/$code/',
        );

        await phone.open(tester);
        await _until(tester, () => lobbyRead.length == 1);
        Future<void> frames() async {
          for (var i = 0; i < 20; i++) {
            await tester.pump();
          }
        }

        if (socketFirst) {
          phone.openLobbySocket();
          await frames();
        }
        phone.http.stopHolding(method: 'GET', path: '/lobbies/$code/');
        lobbyRead.releaseAll();
        await frames();
        if (!socketFirst) {
          phone.openLobbySocket();
          await frames();
        }
        expect(table.length, 1);

        table.releaseAll();
        await _until(
          tester,
          () => find.byType(YourCardScreen).evaluate().isNotEmpty,
        );
        expect(phone.sent.where((r) => r == 'GET /me/table/'), hasLength(1));
        await phone.close(tester);
      });
    }

    testWidgets('a seat the server no longer names is let go: its screen '
        'follows /me/table/', (tester) async {
      // This device was in an earlier game; the player has since left.
      await _preferences(seat: '${_me['lobby_code']}|$_gameId');
      final phone = _Phone(MockHttpClient(), _signedIn(_goodToken));
      phone.http
        ..answer('GET', '/me/table/', serverMyTable())
        ..answer('GET', _mePath, _me)
        ..answer('GET', '/stats/online/', serverOnlineStats())
        ..answer(
          'GET',
          '/onuw/me/recent-games/',
          ContractSamples.map('http/game/recent_games_none'),
        );

      await phone.open(tester);
      await _until(tester, () => find.byType(JoinView).evaluate().isNotEmpty);
      expect(find.byType(YourCardScreen), findsNothing);
      // And it is no longer kept: the next open reads only the table.
      Future<Set<String>> kept() =>
          DevicePreferences().readFlags(LastSeat.prefix);
      for (var i = 0; i < 20 && (await kept()).isNotEmpty; i++) {
        await tester.pump(Duration.zero);
      }
      expect(await kept(), isEmpty);
      await phone.close(tester);
    });
  });

  group('A seated player is never stranded', () {
    testWidgets('no answer while the account is read back: a calm wait, '
        'never 01, tried again until the server answers', (tester) async {
      await _preferences();
      final phone = _Phone(MockHttpClient(), _signedIn(_endedToken));
      phone.http
        ..answer('POST', '/auth/token/refresh/', 'Server Error', status: 503)
        ..answer('GET', '/me/table/', tableOf(_me))
        ..answer('GET', _mePath, _me);

      int tries() =>
          phone.sent.where((s) => s == 'POST /auth/token/refresh/').length;

      await phone.open(tester);
      await _until(
        tester,
        () => find.text(BannerCopy.offline).evaluate().isNotEmpty,
      );
      expect(find.byType(OpeningWait), findsOneWidget);
      expect(find.byType(JoinView), findsNothing);
      // The account is kept.
      expect(phone.device.values['refresh_token'], 'refresh-token-1');

      // It is tried again by itself, with backoff, and 01 never shows.
      for (var i = 0; i < 6; i++) {
        await tester.pump(testHealTiming.maxRetry);
        await _until(tester, () => tries() > i + 1);
        expect(find.byType(JoinView), findsNothing);
      }

      // The server is back.
      phone.http.answer(
        'POST',
        '/auth/token/refresh/',
        ContractSamples.map('http/auth/token_refreshed'),
      );
      await tester.pump(testHealTiming.maxRetry);
      await _until(
        tester,
        () => find.byType(YourCardScreen).evaluate().isNotEmpty,
      );
      await phone.close(tester);
    });

    testWidgets('an answer that is not the server\'s (a wifi sign-in page) '
        'keeps the account and waits', (tester) async {
      await _preferences();
      final phone = _Phone(MockHttpClient(), _signedIn(_endedToken));
      phone.http.answer(
        'POST',
        '/auth/token/refresh/',
        '<html>Sign in to the wifi</html>',
        offContract: true,
      );

      await phone.open(tester);
      await _until(
        tester,
        () => find.text(BannerCopy.offline).evaluate().isNotEmpty,
      );
      await tester.pump(testHealTiming.maxRetry);
      await tester.pump(testHealTiming.maxRetry);

      expect(find.byType(OpeningWait), findsOneWidget);
      expect(find.byType(JoinView), findsNothing);
      expect(phone.device.values['refresh_token'], 'refresh-token-1');
      expect(phone.device.values['user_id'], '$_playerId');
      await phone.close(tester);
    });

    testWidgets('the server refusing the saved account (it is gone) is a '
        'fresh start on 01', (tester) async {
      await _preferences();
      final phone = _Phone(MockHttpClient(), _signedIn(_endedToken));
      phone.http
        ..answer(
          'POST',
          '/auth/token/refresh/',
          ContractSamples.map('http/auth/token_refresh_refused'),
          status: 401,
        )
        ..answer('GET', '/stats/online/', serverOnlineStats());

      await phone.open(tester);
      await _until(tester, () => find.byType(JoinView).evaluate().isNotEmpty);
      expect(tester.widget<JoinView>(find.byType(JoinView)).name, isEmpty);
      expect(phone.device.values, isEmpty);
      await phone.close(tester);
    });

    test('no new account is made over a saved one the server has not '
        'refused', () async {
      final http = MockHttpClient();
      final device = _signedIn(_goodToken);
      final repository = AuthRepository(
        authService: AuthService(apiClient: ApiClient(dio: http.dio)),
        tokenStorage: TokenStorage(storage: device),
        userStorage: UserStorage(storage: device),
      );

      await expectLater(
        repository.createGuest(Door.forTest(), displayName: 'Bo'),
        throwsA(isA<SavedAccountExists>()),
      );
      expect(http.requests, isEmpty);
      expect(device.values['user_id'], '$_playerId');
    });

    test('a new account is asked for while the saved one is read back: '
        'nothing is sent, the account is kept', () async {
      final http = MockHttpClient()
        ..answer('POST', '/auth/token/refresh/', 'Server Error', status: 503);
      final device = _signedIn(_endedToken);
      final container = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(TokenStorage(storage: device)),
          userStorageProvider.overrideWithValue(UserStorage(storage: device)),
          apiClientProvider.overrideWithValue(ApiClient(dio: http.dio)),
          healTimingProvider.overrideWithValue(testHealTiming),
          clockProvider.overrideWithValue(() => sampleClockStart),
        ],
      );
      addTearDown(container.dispose);
      final states = <AuthState>[];
      container.listen(authProvider, (_, next) => states.add(next));
      // Waits on the state itself, bounded: a test fails, it never hangs.
      for (
        var turn = 0;
        turn < 1000 &&
            !states.contains(const AuthState.initial(unanswered: true));
        turn++
      ) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(states, contains(const AuthState.initial(unanswered: true)));

      final sent = await container
          .read(authProvider.notifier)
          .createGuest(Door.forTest(), displayName: 'Bo');

      expect(sent, isFalse);
      expect(container.read(authProvider), isA<AuthInitial>());
      expect(
        http.requests.map((r) => r.path),
        everyElement('/auth/token/refresh/'),
      );
      expect(device.values['refresh_token'], 'refresh-token-1');
    });

    testWidgets('a renewal whose answer is lost is sent again with the same '
        'token and works: the account and the seat are kept', (tester) async {
      await _preferences(seat: '${_me['lobby_code']}|$_gameId');
      // The client gives up on an answer after its wait, as over a network.
      final phone = _Phone(
        MockHttpClient(timesOut: true),
        _signedIn(_endedToken),
      );
      phone.http
        ..answer(
          'POST',
          '/auth/token/refresh/',
          ContractSamples.map('http/auth/token_refreshed'),
        )
        ..answer('GET', '/me/table/', tableOf(_me))
        ..answer('GET', _mePath, _me);
      // The first renewal reaches the server; its answer never comes back.
      final lost = phone.http.hold(
        method: 'POST',
        path: '/auth/token/refresh/',
      );

      await phone.open(tester);
      await _until(tester, () => lost.length == 1);
      phone.http.stopHolding(method: 'POST', path: '/auth/token/refresh/');
      await tester.pump(AuthenticatedClient.timeout);
      // The try after it, with the healing backoff.
      await tester.pump(testHealTiming.maxRetry);
      await _until(
        tester,
        () => find.byType(YourCardScreen).evaluate().isNotEmpty,
      );

      final renewals = [
        for (final r in phone.http.requests)
          if (r.path == '/auth/token/refresh/') r.data,
      ];
      // Sent again with the same refresh token (the server, which no longer
      // blacklists a rotated token, answers it: backend test_auth.py).
      expect(renewals, [
        {'refresh': 'refresh-token-1'},
        {'refresh': 'refresh-token-1'},
      ]);
      expect(
        phone.device.values['refresh_token'],
        ContractSamples.map('http/auth/token_refreshed')['refresh'],
      );
      await phone.close(tester);
    });

    testWidgets('a token trusted by its end that the server refuses (the '
        'phone\'s clock behind): one renewal, both reads again, the screen, '
        'the account kept', (tester) async {
      await _preferences(seat: '${_me['lobby_code']}|$_gameId');
      final phone = _Phone(MockHttpClient(), _signedIn(_goodToken));
      final renewed = ContractSamples.map('http/auth/token_refreshed');
      final expired = ContractSamples.map('http/auth/token_expired');
      phone.http.answer('POST', '/auth/token/refresh/', renewed);
      // The server takes only the renewed access token.
      for (final (path, body) in [
        ('/me/table/', tableOf(_me)),
        (_mePath, _me),
      ]) {
        phone.http.answerEach(
          method: 'GET',
          path: path,
          answer: (request) {
            final good =
                request.headers['Authorization'] ==
                'Bearer ${renewed['access']}';
            phone.http.answer(
              'GET',
              path,
              good ? body : expired,
              status: good ? 200 : 401,
            );
          },
        );
      }

      await phone.open(tester);
      await _until(
        tester,
        () => find.byType(YourCardScreen).evaluate().isNotEmpty,
      );

      expect(
        phone.sent.where((s) => s == 'POST /auth/token/refresh/'),
        hasLength(1),
      );
      expect(phone.sent.where((s) => s == 'GET /me/table/'), hasLength(2));
      expect(phone.sent.where((s) => s == 'GET $_mePath'), hasLength(2));
      expect(phone.device.values['access_token'], renewed['access']);
      expect(phone.device.values['user_id'], '$_playerId');
      await phone.close(tester);
    });
  });

  group('An account that is gone (the server says 401) starts afresh', () {
    testWidgets('its renewal refused: 01, nothing kept, no wait', (
      tester,
    ) async {
      await _preferences(seat: '${_me['lobby_code']}|$_gameId');
      final phone = _Phone(MockHttpClient(), _signedIn(_endedToken));
      phone.http
        ..answer(
          'POST',
          '/auth/token/refresh/',
          ContractSamples.map('http/auth/token_refresh_user_gone'),
          status: 401,
        )
        ..answer('GET', '/stats/online/', serverOnlineStats());

      await phone.open(tester);
      await _until(tester, () => find.byType(JoinView).evaluate().isNotEmpty);

      expect(find.byType(OpeningWait), findsNothing);
      expect(phone.device.values, isEmpty);
      expect(await _keptSeats(tester), isEmpty);
      await phone.close(tester);
    });

    testWidgets('a read refused and its renewal refused (a token trusted by '
        'its end): 01, nothing kept, the seat forgotten', (tester) async {
      await _preferences(seat: '${_me['lobby_code']}|$_gameId');
      final phone = _Phone(MockHttpClient(), _signedIn(_goodToken));
      final gone = ContractSamples.map('http/auth/user_gone');
      phone.http
        ..answer('GET', '/me/table/', gone, status: 401)
        ..answer(
          'GET',
          _mePath,
          ContractSamples.map('http/auth/user_gone_game_me'),
          status: 401,
        )
        ..answer(
          'POST',
          '/auth/token/refresh/',
          ContractSamples.map('http/auth/token_refresh_user_gone'),
          status: 401,
        )
        ..answer('GET', '/stats/online/', serverOnlineStats());

      await phone.open(tester);
      await _until(tester, () => find.byType(JoinView).evaluate().isNotEmpty);

      expect(tester.widget<JoinView>(find.byType(JoinView)).name, isEmpty);
      expect(phone.device.values.containsKey('refresh_token'), isFalse);
      expect(await _keptSeats(tester), isEmpty);
      await phone.close(tester);
    });
  });

  group('The read beside /me/table/ is a quiet head start', () {
    testWidgets('a remembered game that is gone closes nothing, says '
        'nothing and never asks for the table again', (tester) async {
      await _preferences(seat: '${_me['lobby_code']}|$_gameId');
      final phone = _Phone(MockHttpClient(), _signedIn(_goodToken));
      phone.http
        ..answer('GET', '/me/table/', serverMyTable())
        ..answer(
          'GET',
          _mePath,
          ContractSamples.map('http/game/me_not_found'),
          status: 404,
        )
        ..answer('GET', '/stats/online/', serverOnlineStats())
        ..answer(
          'GET',
          '/onuw/me/recent-games/',
          ContractSamples.map('http/game/recent_games_none'),
        );
      // The game's 404 comes back before the table answers.
      final table = phone.http.hold(method: 'GET', path: '/me/table/');

      await phone.open(tester);
      await _until(tester, () => phone.sent.contains('GET $_mePath'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(testHealTiming.maxRetry);
      }
      expect(phone.sent.where((s) => s == 'GET /me/table/'), hasLength(1));
      table.releaseAll();
      await _until(tester, () => find.byType(JoinView).evaluate().isNotEmpty);

      expect(find.text(BannerCopy.tableClosed), findsNothing);
      expect(phone.sent.where((s) => s == 'GET /me/table/'), hasLength(1));
      expect(phone.sent.where((s) => s == 'GET $_mePath'), hasLength(1));
      await phone.close(tester);
    });

    testWidgets('another account\'s remembered seat is not read', (
      tester,
    ) async {
      await _preferences(seat: '${_me['lobby_code']}|$_gameId', owner: 99);
      final phone = _Phone(MockHttpClient(), _signedIn(_goodToken));
      phone.http
        ..answer('GET', '/me/table/', tableOf(_me))
        ..answer('GET', _mePath, _me);
      final table = phone.http.hold(method: 'GET', path: '/me/table/');

      await phone.open(tester);
      await _until(tester, () => table.length == 1);
      for (var i = 0; i < 10; i++) {
        await tester.pump(Duration.zero);
      }
      expect(phone.sent, ['GET /me/table/']);

      table.releaseAll();
      await _until(
        tester,
        () => find.byType(YourCardScreen).evaluate().isNotEmpty,
      );
      await phone.close(tester);
    });
  });

  group('01 never says "Not sent." for a tap that sent nothing', () {
    testWidgets('a saved account appears (another tab signed in): Start '
        'sends nothing, says nothing, and the account is read back', (
      tester,
    ) async {
      // A phone's screen, so all of 01 is in view.
      tester.view
        ..physicalSize = const Size(390 * 3, 844 * 3)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await _preferences();
      final phone = _Phone(MockHttpClient(), _Device({}));
      phone.http
        ..answer('GET', '/stats/online/', serverOnlineStats())
        ..answer('GET', '/me/table/', serverMyTable())
        ..answer(
          'GET',
          '/onuw/me/recent-games/',
          ContractSamples.map('http/game/recent_games_none'),
        );

      await phone.open(tester);
      await _until(tester, () => find.byType(JoinView).evaluate().isNotEmpty);
      // Another tab of the same browser signs in meanwhile.
      phone.device.values.addAll(_signedIn(_goodToken).values);

      await tester.enterText(find.byType(EditableText).first, 'Bo');
      await tester.pump();
      await pressLikeAFinger(tester, find.text(JoinCopy.startTable));
      // The account read back arrives as 01 again: while the scene switches,
      // the old 01 and the new one are both drawn.
      await _until(
        tester,
        () => find
            .byType(JoinView)
            .evaluate()
            .any((e) => (e.widget as JoinView).name == 'Ana'),
      );

      expect(find.text(BannerCopy.notSent), findsNothing);
      expect(phone.sent, isNot(contains('POST /auth/guest/')));
      expect(phone.sent, isNot(contains('POST /lobbies/')));
      await phone.close(tester);
    });
  });
}

/// The seats this device keeps (`LastSeat`), once its writes have landed.
Future<Set<String>> _keptSeats(WidgetTester tester) async {
  Future<Set<String>> read() => DevicePreferences().readFlags(LastSeat.prefix);
  for (var i = 0; i < 20 && (await read()).isNotEmpty; i++) {
    await tester.pump(Duration.zero);
  }
  return read();
}
