import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:midnight_village/core/api/authenticated_client.dart';
import 'package:midnight_village/core/websocket/websocket_channel.dart';
import 'package:midnight_village/features/auth/domain/auth_state.dart';
import 'package:midnight_village/features/auth/domain/user.dart';
import 'package:midnight_village/features/auth/presentation/auth_notifier.dart';
import 'package:midnight_village/features/game/data/game_service.dart';
import 'package:midnight_village/features/game/presentation/game_notifier.dart';
import 'package:midnight_village/features/game/presentation/protocol_two_game.dart';
import 'package:midnight_village/features/game/presentation/table_screen.dart';
import 'package:midnight_village/features/lobby/data/lobby_service.dart';
import 'package:midnight_village/features/lobby/presentation/lobby_notifier.dart';
import 'package:midnight_village/features/lobby/presentation/where_am_i_provider.dart';

import 'contract/contract_samples.dart';
import 'contract/server_json.dart';
import 'mock_http_client.dart';
import 'mock_websocket.dart';

export 'sheet/sheet_data.dart' show recordedMe;

/// Before every recorded deadline (the samples' games ran on 7 March 2024
/// from 21:13): no deadline fetch fires during a test unless it says so.
final sampleClockStart = DateTime.utc(2024, 3, 7, 21, 13);

/// Healing as fast as a test can wait for it.
const testHealTiming = HealTiming(
  afterDeadline: Duration(milliseconds: 10),
  poll: Duration(milliseconds: 30),
  firstRetry: Duration(milliseconds: 10),
  maxRetry: Duration(milliseconds: 40),
);

/// `/me/table/` while [me]'s game runs (finished once it is over).
Map<String, dynamic> tableOf(Map<String, dynamic> me) => serverMyTable(
  code: me['lobby_code'] as String,
  status: me['phase'] == 'results' ? 'finished' : 'in_game',
  isHost: me['is_host'] as bool,
  gameId: me['game_id'] as String,
  phase: me['phase'] as String,
);

/// An HTTP `Date` for [time].
String httpDate(DateTime time) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final t = time.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${days[t.weekday - 1]}, ${two(t.day)} ${months[t.month - 1]} '
      '${t.year} ${two(t.hour)}:${two(t.minute)}:${two(t.second)} GMT';
}

/// A [ProtocolTwoGameNotifier] (and the table screen) wired to the strict
/// HTTP mock and a fake game socket, every answer a recorded server payload.
class ProtocolTwoSetup {
  ProtocolTwoSetup._(this.container, this.http, this.ws, this.gameId);

  /// A phone whose `/me/` answers [me] (a recorded protocol-2 `/me/`), and
  /// whose `/me/table/` answers that game's table.
  factory ProtocolTwoSetup.create(
    Map<String, dynamic> me, {
    int userId = 27,
    DateTime Function()? clock,
  }) {
    final http = MockHttpClient();
    final ws = MockWebSocketChannel();
    final client = AuthenticatedClient.forTesting(dio: http.dio);
    final gameId = me['game_id'] as String;
    final resumes = StreamController<int>.broadcast();
    final connection = StreamController<WebSocketConnectionState>.broadcast();
    final setup = ProtocolTwoSetup._(
      ProviderContainer(
        overrides: [
          authProvider.overrideWithValue(
            AuthState.authenticated(User(id: userId, displayName: 'P$userId')),
          ),
          authenticatedClientProvider.overrideWithValue(client),
          gameServiceProvider.overrideWithValue(GameService(client: client)),
          lobbyServiceProvider.overrideWithValue(LobbyService(client: client)),
          gameWebSocketProvider.overrideWith((ref, id) => null),
          gameWebSocketStreamProvider.overrideWith((ref, id) => ws.stream),
          gameConnectionStateProvider.overrideWith(
            (ref, id) => connection.stream,
          ),
          appResumesProvider.overrideWith((ref) => resumes.stream),
          healTimingProvider.overrideWithValue(testHealTiming),
          clockProvider.overrideWithValue(clock ?? () => sampleClockStart),
        ],
      ),
      http,
      ws,
      gameId,
    );
    setup
      .._resumes = resumes
      .._connection = connection
      ..answerMe(me);
    return setup;
  }

  final ProviderContainer container;
  final MockHttpClient http;
  final MockWebSocketChannel ws;
  final String gameId;
  late final StreamController<int> _resumes;
  late final StreamController<WebSocketConnectionState> _connection;
  var _resumeCount = 0;

  String get _base => '/onuw/games/$gameId';

  /// What the next `GET /me/` (and `/me/table/`) answer: the server is now
  /// at [me]. [serverDate] is the answer's `Date` header.
  void answerMe(
    Map<String, dynamic> me, {
    DateTime? serverDate,
    bool table = true,
  }) {
    http
        .when(method: 'GET', path: '$_base/me/')
        .thenReturn(
          Response<dynamic>(
            requestOptions: RequestOptions(path: '$_base/me/'),
            statusCode: 200,
            data: me,
            headers: Headers.fromMap({
              if (serverDate != null) 'date': [httpDate(serverDate)],
            }),
          ),
        );
    if (table) answerTable(tableOf(me));
  }

  /// What `GET /me/table/` answers.
  void answerTable(Map<String, dynamic> body) =>
      http.answer('GET', '/me/table/', body);

  /// `POST <base><endpoint>` answers the recorded sample [sample].
  void answerPost(String endpoint, String sample, {int status = 200}) =>
      http.answer(
        'POST',
        '$_base$endpoint',
        ContractSamples.load('http/$sample'),
        status: status,
      );

  /// `POST <base><endpoint>` gives no readable answer (a 5xx).
  void failPost(String endpoint) =>
      http.answer('POST', '$_base$endpoint', 'Server Error', status: 503);

  /// The app comes back to the foreground.
  void resume() => _resumes.add(++_resumeCount);

  /// The socket drops, then is back.
  void reconnect() => _connection
    ..add(WebSocketConnectionState.reconnecting)
    ..add(WebSocketConnectionState.connected);

  ProtocolTwoGameNotifier get notifier =>
      container.read(protocolTwoGameProvider(gameId).notifier);

  ProtocolTwoGame get game =>
      container.read(protocolTwoGameProvider(gameId)).requireValue;

  /// Loads the game (the first `/me/`) and keeps it alive.
  Future<ProtocolTwoGame> load() async {
    container.listen(protocolTwoGameProvider(gameId), (_, _) {});
    return container.read(protocolTwoGameProvider(gameId).future);
  }

  /// The screen the table screen shows now (keeps it alive).
  TableScreen? get screen {
    container.listen(tableScreenProvider, (_, _) {});
    return container.read(tableScreenProvider).value;
  }

  int _count(String method, String path) =>
      http.requests.where((r) => r.method == method && r.path == path).length;

  /// Every `GET /me/` made so far.
  int get meFetches => _count('GET', '$_base/me/');

  /// Every `GET /me/table/` made so far.
  int get tableFetches => _count('GET', '/me/table/');

  /// Every POST to [endpoint] so far.
  int posts(String endpoint) => _count('POST', '$_base$endpoint');

  /// The body of the last request to [endpoint].
  dynamic lastBody(String endpoint) =>
      http.requests.lastWhere((r) => r.path == '$_base$endpoint').data;

  /// Lets every queued answer and fetch finish.
  Future<void> settle() async {
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// Waits [time] of real time, then [settle]s.
  Future<void> wait(Duration time) async {
    await Future<void>.delayed(time);
    await settle();
  }

  void dispose() {
    container.dispose();
    _resumes.close();
    _connection.close();
  }
}
