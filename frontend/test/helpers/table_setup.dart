import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:midnight_village/core/api/api_client.dart';
import 'package:midnight_village/core/api/authenticated_client.dart';
import 'package:midnight_village/core/healing/healing.dart';
import 'package:midnight_village/core/router/routes.dart';
import 'package:midnight_village/core/storage/device_preferences.dart';
import 'package:midnight_village/core/storage/token_storage.dart';
import 'package:midnight_village/core/storage/user_storage.dart';
import 'package:midnight_village/core/wakelock/wakelock_service.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/ground_scope.dart';
import 'package:midnight_village/design_system/skin/skin_choice.dart';
import 'package:midnight_village/features/auth/domain/auth_state.dart';
import 'package:midnight_village/features/auth/domain/user.dart';
import 'package:midnight_village/features/auth/presentation/auth_notifier.dart';
import 'package:midnight_village/features/lobby/data/home_service.dart';
import 'package:midnight_village/features/lobby/data/lobby_service.dart';
import 'package:midnight_village/features/lobby/presentation/home_numbers.dart';
import 'package:midnight_village/features/lobby/presentation/lobby_notifier.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'contract/contract_samples.dart';
import 'contract/server_json.dart';
import 'fake_wakelock_service.dart';
import 'mock_http_client.dart';
import 'mock_websocket.dart';
import 'protocol_two_setup.dart' show testHealTiming;

// 01 Join, 02 Table and 03 Deck through the app's real routes and providers
// (`HomeGate`, the table's shell), every answer a recorded server payload
// (contract_samples/), changed in its values only: the lobby bodies of a
// night protocol 2 table (`detail_v2_*`), `/me/table/`, the online count
// and the recent games. The lobby socket is a fake the test pushes events
// into.

/// The recorded protocol-2 lobby bodies: [players] at the table (members
/// dropped from the end, or added like the last with the tokens nobody
/// has), every name in [rename] renamed, [notReady] not ready yet (the
/// others as recorded).
///
/// - `detail_v2_auto_deck_5`: Ana's table of five, the Classic chip.
/// - `detail_v2_auto_deck_9`: nine, the Chaos chip.
/// - `detail_v2_custom_deck`: nine, Ana's own deck of twelve cards.
/// - `created_with_defaults`: Ana alone, the Simple chip, not ready.
Map<String, dynamic> v2Lobby(
  String sample, {
  int? players,
  Map<String, String> rename = const {},
  Set<String> notReady = const {},
}) {
  final body = ContractSamples.map('http/lobby/$sample');
  final members = (body['players'] as List).cast<Map<String, dynamic>>();
  final count = players ?? members.length;
  if (members.length > count) members.removeRange(count, members.length);
  const tokens = [
    'crow', 'key', 'moth', 'lantern', 'bell', //
    'thorn', 'antler', 'scythe', 'hare', 'raven',
  ];
  final unused = tokens.where((t) => !members.any((m) => m['token'] == t));
  for (final (i, token) in unused.take(count - members.length).indexed) {
    final last = members.last;
    final user = last['user'] as Map<String, dynamic>;
    final id = (user['id'] as int) + 1;
    members.add(
      withValues(last, {
        'user': withValues(user, {
          'id': id,
          'username': '00000000-0000-4000-8000-${'$id'.padLeft(12, '0')}',
          'display_name': const ['Fin', 'Gus', 'Hana', 'Ida', 'Jo'][i],
        }),
        'token': token,
      }),
    );
  }
  for (final member in members) {
    final user = member['user'] as Map<String, dynamic>;
    final name = user['display_name'] as String;
    user['display_name'] = rename[name] ?? name;
    if (notReady.contains(name)) member['is_ready'] = false;
  }
  final host = body['host'] as Map<String, dynamic>;
  host['display_name'] =
      rename[host['display_name']] ?? host['display_name'] as String;
  return body;
}

/// The id of the member named [name] in a lobby body.
int memberId(Map<String, dynamic> lobby, String name) =>
    [
          for (final m
              in (lobby['players'] as List).cast<Map<String, dynamic>>())
            if ((m['user'] as Map)['display_name'] == name)
              (m['user'] as Map)['id'],
        ].single
        as int;

/// A test's phone at 01 to 03: the app's router at [route], signed in as
/// [viewer] (a member's name in [lobby]) or signed out; the server answers
/// what the test registers.
class TableSetup {
  TableSetup._(this.lobby, this.http, this.ws, this.viewerId);

  /// The lobby body the server is at (null: the phone sits at no table).
  Map<String, dynamic>? lobby;
  final MockHttpClient http;
  final MockWebSocketChannel ws;
  int? viewerId;

  /// The links handed to the share sheet.
  final shared = <Uri>[];

  String get code => lobby!['code'] as String;

  static Future<TableSetup> pump(
    WidgetTester tester, {
    Map<String, dynamic>? lobby,
    String? viewer,
    String? signedInAs,
    int? userId,
    String route = '/',
    int online = 23,
    bool? lastWon,
    double textScale = 1,
    bool realAuth = false,
  }) async {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final viewerId = viewer == null || lobby == null
        ? null
        : memberId(lobby, viewer);
    final setup = TableSetup._(
      lobby,
      MockHttpClient(),
      MockWebSocketChannel(),
      viewerId,
    );
    final http = setup.http;
    setup.answerTable();
    http
      ..answer('GET', '/stats/online/', serverOnlineStats(players: online))
      ..answer(
        'GET',
        '/onuw/me/recent-games/',
        lastWon == null
            ? ContractSamples.map('http/game/recent_games_none')
            : serverRecentGames([
                (
                  gameId: '7d3f2c1a-5b8e-4c2d-9a6f-1e0b3c4d5e6f',
                  playerCount: 5,
                  winningTeams: ['village'],
                  youWon: lastWon,
                  seat: 0,
                ),
              ]),
      );
    if (lobby != null) setup._answerLobby();
    final name = signedInAs ?? viewer;
    final auth = name == null
        ? const AuthState.unauthenticated()
        : AuthState.authenticated(
            User(id: viewerId ?? userId ?? 900, displayName: name),
          );
    final client = AuthenticatedClient.forTesting(dio: http.dio);
    // The real sign-in: this device's storage (empty: never signed in), the
    // guest account made through the mock server.
    final storage = _MemoryStorage();
    final router = GoRouter(routes: $appRoutes, initialLocation: route);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          devicePreferencesProvider.overrideWithValue(DevicePreferences()),
          if (realAuth) ...[
            tokenStorageProvider.overrideWithValue(
              TokenStorage(storage: storage),
            ),
            userStorageProvider.overrideWithValue(
              UserStorage(storage: storage),
            ),
            apiClientProvider.overrideWithValue(ApiClient(dio: http.dio)),
          ] else
            authProvider.overrideWithValue(auth),
          authenticatedClientProvider.overrideWithValue(client),
          lobbyServiceProvider.overrideWithValue(LobbyService(client: client)),
          homeServiceProvider.overrideWithValue(
            HomeService(client: ApiClient(dio: http.dio)),
          ),
          lobbyWebSocketFactoryProvider.overrideWithValue((_) => setup.ws),
          appOriginProvider.overrideWithValue(
            Uri.parse('https://midnight.example'),
          ),
          shareLinkProvider.overrideWithValue((link) async {
            setup.shared.add(link);
          }),
          healTimingProvider.overrideWithValue(testHealTiming),
          wakelockServiceProvider.overrideWithValue(FakeWakelockService()),
        ],
        child: Consumer(
          builder: (context, ref, _) => MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: ref.watch(appThemeProvider),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: GroundScope(ground: GroundKind.night, child: child!),
            ),
            routerConfig: router,
          ),
        ),
      ),
    );
    await setup.settle(tester);
    return setup;
  }

  void _answerLobby() {
    http
      ..answer('GET', '/lobbies/$code/', lobby)
      // The phone ignores the body; the recorded answer is another table's.
      ..answer(
        'POST',
        '/lobbies/$code/ready/',
        ContractSamples.map('http/lobby/ready'),
      );
  }

  /// The server has seated this phone, as [viewer], at [body] (a table
  /// started or joined here).
  void sitAt(Map<String, dynamic> body, String viewer) {
    lobby = body;
    viewerId = memberId(body, viewer);
    _answerLobby();
    answerTable();
  }

  /// `GET /me/table/` answers where the server has this phone now.
  void answerTable() {
    final body = lobby;
    final viewer = viewerId;
    http.answer(
      'GET',
      '/me/table/',
      body == null || viewer == null
          ? serverMyTable()
          : serverMyTable(
              code: body['code'] as String,
              isHost: (body['host'] as Map)['id'] == viewer,
            ),
    );
  }

  /// The server is at [body] now: the lobby's next read, and `/me/table/`.
  void serverAt(Map<String, dynamic> body) {
    lobby = body;
    http.answer('GET', '/lobbies/$code/', body);
    answerTable();
  }

  /// The lobby socket brings [event] (a recorded event, values changed).
  void event(Map<String, dynamic> event) => ws.addServerEvent(event);

  /// `PATCH /lobbies/<code>/` answers [body] (a recorded settings answer).
  void answerPatch(Map<String, dynamic> body, {int status = 200}) =>
      http.answer('PATCH', '/lobbies/$code/', body, status: status);

  /// The bodies of every PATCH so far.
  List<Object?> get patches => [
    for (final r in http.requests)
      if (r.method == 'PATCH') (r.data as Map)['settings'],
  ];

  int count(String method, String path) =>
      http.requests.where((r) => r.method == method && r.path == path).length;

  /// Lets answers and a screen change finish.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Unmounts the app (its timers go with it).
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }
}

/// This device's secure storage, in memory.
class _MemoryStorage extends Mock implements FlutterSecureStorage {
  _MemoryStorage() {
    when(
      () => read(key: any(named: 'key')),
    ).thenAnswer((i) async => _values[i.namedArguments[#key]]);
    when(
      () => write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((i) async {
      _values[i.namedArguments[#key] as String] =
          i.namedArguments[#value] as String?;
    });
    when(() => delete(key: any(named: 'key'))).thenAnswer((i) async {
      _values.remove(i.namedArguments[#key]);
    });
  }

  final _values = <String, String?>{};
}

/// A response the strict mock gives for [path] with no readable answer.
Response<dynamic> serverError(String path) => Response<dynamic>(
  requestOptions: RequestOptions(path: path),
  statusCode: 503,
  data: 'Server Error',
);
