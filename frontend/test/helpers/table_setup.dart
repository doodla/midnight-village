import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:midnight_village/core/api/api_client.dart';
import 'package:midnight_village/core/api/authenticated_client.dart';
import 'package:midnight_village/core/healing/healing.dart';
import 'package:midnight_village/core/host/app_download.dart';
import 'package:midnight_village/core/router/back_policy.dart';
import 'package:midnight_village/core/router/routes.dart';
import 'package:midnight_village/core/storage/device_preferences.dart';
import 'package:midnight_village/core/storage/token_storage.dart';
import 'package:midnight_village/core/storage/user_storage.dart';
import 'package:midnight_village/core/wakelock/wakelock_service.dart';
import 'package:midnight_village/core/websocket/reconnecting_websocket.dart';
import 'package:midnight_village/core/websocket/websocket_channel.dart'
    show WebSocketConnectionState;
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/ground_scope.dart';
import 'package:midnight_village/design_system/skin/skin_choice.dart';
import 'package:midnight_village/features/auth/domain/auth_state.dart';
import 'package:midnight_village/features/auth/domain/user.dart';
import 'package:midnight_village/features/auth/presentation/auth_notifier.dart';
import 'package:midnight_village/features/game/presentation/game_socket.dart';
import 'package:midnight_village/features/lobby/data/home_service.dart';
import 'package:midnight_village/features/lobby/data/lobby_service.dart';
import 'package:midnight_village/features/lobby/presentation/home_numbers.dart';
import 'package:midnight_village/features/lobby/presentation/lobby_notifier.dart';
import 'package:midnight_village/features/lobby/presentation/scan/code_scanner.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'contract/contract_samples.dart';
import 'contract/server_json.dart';
import 'fake_code_scanner.dart';
import 'fake_wakelock_service.dart';
import 'mock_http_client.dart';
import 'mock_websocket.dart';
import 'live_game_setup.dart' show testHealTiming;
import 'text_scale.dart';

// 01 Join, 02 Table and 03 Deck through the app's real routes and providers
// (`HomeGate`, the table's shell), every answer a recorded server payload
// (contract_samples/), changed in its values only: the lobby bodies of a
// table made with `defaults: "v2"` (`detail_*`), `/me/table/`, the online count
// and the recent games. The lobby socket is a fake the test pushes events
// into.

/// The recorded lobby bodies, every name in [rename] renamed.
/// The member count, the deck, its preview and the `deal` verdict are the
/// server's, as recorded: a test picks the sample of its situation.
///
/// The older recordings (`detail_auto_deck_*`, `detail_custom_deck`,
/// `created_with_defaults`) were made with no socket open, so they say every
/// phone has dropped: unless [asRecorded], every member is `connected` but
/// those in [dropped].
///
/// - `detail_auto_deck_5`: Ana's table of five, the Classic chip.
/// - `detail_auto_deck_9`: nine, the Chaos chip.
/// - `detail_custom_deck`: nine, Ana's own deck of twelve cards.
/// - `created_with_defaults`: Ana alone, the Simple chip.
/// - `detail_deck_<chip>_4` and `_7`: Kai's table of four or seven, that
///   chip, its cards.
/// - `detail_custom_deck_ok`, `_short`: Kai's own deck of ten for seven,
///   then an eighth player: one card short.
/// - `detail_member_dropped`: Kai's four, Noa's phone dropped.
Map<String, dynamic> v2Lobby(
  String sample, {
  Map<String, String> rename = const {},
  Set<String> dropped = const {},
  bool asRecorded = false,
}) {
  final body = ContractSamples.map('http/lobby/$sample');
  final members = (body['players'] as List).cast<Map<String, dynamic>>();
  for (final member in members) {
    final user = member['user'] as Map<String, dynamic>;
    final name = user['display_name'] as String;
    if (!asRecorded) member['connected'] = !dropped.contains(name);
    user['display_name'] = rename[name] ?? name;
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

  /// A dealt game's socket.
  final gameWs = MockWebSocketChannel();

  /// With `reconnectingSocket`: every connection the lobby's socket made,
  /// the last one the live one ([dropLobbySocket] closes it).
  final lobbyConnections = <MockWebSocketChannel>[];
  bool _reconnecting = false;

  /// The lobby socket's connection is lost (`reconnectingSocket` only): the
  /// app's own socket tries again after its backoff (a second), and the
  /// server's events meanwhile reach nobody ([event] drops them).
  Future<void> dropLobbySocket() => lobbyConnections.last.close();

  /// With `slowLobbySocket`: the lobby socket's first connection is open
  /// (the server listens to it) only from now on.
  void openLobbySocket() => _firstOpens?.complete();
  Completer<void>? _firstOpens;
  final _open = <MockWebSocketChannel>{};

  /// The dealt game's `GET /me/` answers [me] (a recorded `/me/`; its
  /// `game_id` is the game's).
  void answerGame(Map<String, dynamic> me) =>
      http.answer('GET', '/onuw/games/${me['game_id']}/me/', me);

  /// The links handed to the share sheet.
  final shared = <Uri>[];

  /// Every camera 01's scan action has opened, the last one the live one.
  final scanners = <FakeCodeScanner>[];

  /// The device has no share sheet: Share copies the link.
  var shareCopies = false;

  /// How many times "Get the app" was tapped (only with `androidWeb`).
  var appDownloads = 0;

  String get code => lobby!['code'] as String;

  /// Where the app is served from in these tests (the QR code's link).
  static final _webOrigin = Uri.parse('https://midnight.example');

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
    double keyboard = 0,
    bool realAuth = false,
    bool lobbyDown = false,
    bool webAddress = true,

    /// The page runs in an Android browser: 01 offers the app's download.
    bool androidWeb = false,
    bool timesOut = true,
    AuthState? authState,

    /// The lobby's socket is the app's own [ReconnectingWebSocket] over
    /// fake connections, so a test can drop it ([dropLobbySocket]).
    bool reconnectingSocket = false,

    /// With `reconnectingSocket`: its first connection opens only when the
    /// test says ([openLobbySocket]); events meanwhile reach nobody.
    bool slowLobbySocket = false,

    /// A dealt game's socket never opens (the server refuses it to a phone
    /// that is not a player); else it opens at once.
    bool gameSocketRefused = false,

    /// How the phone heals (the test's fast one unless given: a test of how
    /// long a miss lasts gives the phone's own, `const HealTiming()`).
    HealTiming healTiming = testHealTiming,

    /// The camera a tap on scan opens (a fake the test drives).
    FakeCodeScanner Function()? scanner,
    bool settle = true,
    void Function(TableSetup setup)? before,
  }) async {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final viewerId = viewer == null || lobby == null
        ? null
        : memberId(lobby, viewer);
    final setup = TableSetup._(
      lobby,
      // The app's client gives up after its wait: so does this one (not in
      // a picture that holds an answer and never waits it out).
      MockHttpClient(timesOut: timesOut),
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
    // The lobby cannot be read (no answer) until the test says it can.
    if (lobby != null && lobbyDown) {
      http.answer(
        'GET',
        '/lobbies/${setup.code}/',
        'Server Error',
        status: 503,
      );
    }
    final name = signedInAs ?? viewer;
    final auth =
        authState ??
        (name == null
            ? const AuthState.unauthenticated()
            : AuthState.authenticated(
                User(id: viewerId ?? userId ?? 900, displayName: name),
              ));
    final client = AuthenticatedClient.forTesting(dio: http.dio);
    // The real sign-in: this device's storage (empty: never signed in), the
    // guest account made through the mock server.
    final storage = _MemoryStorage();
    setup._reconnecting = reconnectingSocket;
    if (slowLobbySocket) setup._firstOpens = Completer<void>();
    WebSocketChannelInterface lobbySocket(String code) {
      if (!reconnectingSocket) return setup.ws;
      final socket = ReconnectingWebSocket(
        url: 'ws://midnight.example/ws/lobby/$code/',
        tokenStorage: TokenStorage(storage: storage),
        channelFactory: (_) {
          final opens = setup.lobbyConnections.isEmpty
              ? setup._firstOpens?.future
              : null;
          final connection = MockWebSocketChannel(opens: opens);
          setup.lobbyConnections.add(connection);
          unawaited(connection.ready.then((_) => setup._open.add(connection)));
          return connection;
        },
      );
      unawaited(socket.connect());
      return socket;
    }

    // The test's changes to the answers, before the first frame.
    before?.call(setup);
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
          lobbyWebSocketFactoryProvider.overrideWithValue(lobbySocket),
          // A dealt game's socket (its `/me/` is read from the deal on).
          gameWebSocketProvider.overrideWith((ref, id) => null),
          gameWebSocketStreamProvider.overrideWith(
            (ref, id) => setup.gameWs.stream,
          ),
          if (gameSocketRefused)
            gameConnectionStateProvider.overrideWith(
              (ref, id) => const Stream<WebSocketConnectionState>.empty(),
            ),
          // Without: an app build that knows no web address (no QR code).
          appOriginProvider.overrideWithValue(webAddress ? _webOrigin : null),
          appDownloadProvider.overrideWithValue(
            androidWeb ? AppDownload(() => setup.appDownloads++) : null,
          ),
          shareLinkProvider.overrideWithValue((link) async {
            setup.shared.add(link);
            return setup.shareCopies;
          }),
          codeScannerFactoryProvider.overrideWithValue(() {
            final camera = (scanner ?? FakeCodeScanner.new)();
            setup.scanners.add(camera);
            return camera;
          }),
          healTimingProvider.overrideWithValue(healTiming),
          wakelockServiceProvider.overrideWithValue(FakeWakelockService()),
        ],
        child: Consumer(
          builder: (context, ref, _) => MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: ref.watch(appThemeProvider),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: ambientTextScaler(context, textScale),
                // The phone's keyboard, up (a field focused).
                viewInsets: EdgeInsets.only(bottom: keyboard),
              ),
              child: GroundScope(ground: GroundKind.night, child: child!),
            ),
            // As the app keeps it: one browser history entry.
            routerConfig: oneHistoryEntry(router),
          ),
        ),
      ),
    );
    if (settle) await setup.settle(tester);
    return setup;
  }

  void _answerLobby() {
    http.answer('GET', '/lobbies/$code/', lobby);
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

  /// The lobby socket brings [event] (a recorded event, values changed);
  /// with `reconnectingSocket`, only while its connection is up.
  void event(Map<String, dynamic> event) {
    if (!_reconnecting) return ws.addServerEvent(event);
    final live = lobbyConnections.lastOrNull;
    if (live != null && _open.contains(live)) live.addServerEvent(event);
  }

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

  /// The server has this phone at no table (`/me/table/`) from the moment a
  /// leave from [table] reaches it, answered or not, and not before: the
  /// table's slow poll (50 ms in tests, 15 s on a phone) runs while a finger
  /// is down, and a server that said "no table" before the leave would move
  /// the phone off the table under the finger, which no phone sees.
  void offTheTableOnceLeft(String table) => http.answerEach(
    method: 'POST',
    path: '/lobbies/$table/leave/',
    answer: (_) => http.answer(
      'GET',
      '/me/table/',
      ContractSamples.map('http/lobby/my_table_none'),
    ),
  );

  /// Lets answers and a screen change finish: [settleFor] of the app's
  /// time, drawn frame by frame only while something is moving. Once the
  /// screen is still, the rest of the time passes in one step (its timers
  /// still fire), and whatever that sets moving is drawn out too. A screen
  /// that never stops moving gets every frame, as before.
  ///
  /// (It used to draw twelve frames after every tap, moving or not: a test
  /// of fifty taps spent twenty seconds drawing a still screen.)
  Future<void> settle(WidgetTester tester) async {
    var left = settleFor;
    while (left > Duration.zero) {
      await tester.pump(_frame);
      left -= _frame;
      if (!tester.binding.hasScheduledFrame) break;
    }
    if (left == Duration.zero) return;
    await tester.pump(left);
    for (
      var i = 0;
      i < _settleFrames && tester.binding.hasScheduledFrame;
      i++
    ) {
      await tester.pump(_frame);
    }
  }

  static const _frame = Duration(milliseconds: 50);
  static const _settleFrames = 12;

  /// How much of the app's time a [settle] lets pass.
  static const settleFor = Duration(milliseconds: 600);

  /// Unmounts the app (its timers go with it; an answer still held runs
  /// out the client's wait).
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(AuthenticatedClient.timeout + const Duration(seconds: 1));
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
