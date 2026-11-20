import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/api/authenticated_client.dart';
import 'package:midnight_village/core/healing/healing.dart';
import 'package:midnight_village/core/storage/device_preferences.dart';
import 'package:midnight_village/core/wakelock/wakelock_service.dart';
import 'package:midnight_village/core/websocket/websocket_channel.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/ground_scope.dart';
import 'package:midnight_village/design_system/skin/skin_choice.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';
import 'package:midnight_village/features/auth/domain/auth_state.dart';
import 'package:midnight_village/features/auth/domain/user.dart';
import 'package:midnight_village/features/auth/presentation/auth_notifier.dart';
import 'package:midnight_village/features/game/data/game_service.dart';
import 'package:midnight_village/features/game/presentation/game_notifier.dart';
import 'package:midnight_village/features/game/presentation/shell/table_shell.dart';
import 'package:midnight_village/features/lobby/data/lobby_service.dart';
import 'package:midnight_village/features/lobby/presentation/lobby_notifier.dart';

import 'component_sheet.dart' show SheetLearned;
import 'contract/contract_samples.dart';
import 'fake_wakelock_service.dart';
import 'mock_http_client.dart';
import 'mock_websocket.dart';
import 'protocol_two_setup.dart'
    show httpDate, sampleClockStart, tableOf, testHealTiming;

export 'protocol_two_setup.dart' show recordedMe, sampleClockStart;

/// The rebuilt shell ([TableShell]) on one phone of a recorded game, in the
/// app's theme, every answer a recorded server payload: the strict HTTP mock
/// answers `/me/` and `/me/table/` with the sample the test puts the server
/// at, the game socket is a fake the test pushes events into.
///
/// The phone's own container is the [ProviderScope]'s, so unmounting the
/// shell (end of a test, or [close]) disposes it and every timer it armed.
class ShellSetup {
  ShellSetup._(this.me, this.http, this.ws, this.wakelock);

  /// The `/me/` the server starts at (a recorded protocol-2 `/me/`).
  final Map<String, dynamic> me;
  final MockHttpClient http;
  final MockWebSocketChannel ws;
  final FakeWakelockService wakelock;
  final _resumes = StreamController<int>.broadcast();
  final _connection = StreamController<WebSocketConnectionState>.broadcast();
  var _resumeCount = 0;

  String get gameId => me['game_id'] as String;
  String get _base => '/onuw/games/$gameId';

  /// Pumps the shell for the phone of [me] (signed in as its `player_id`).
  /// [learned] is what this device was taught before ([Cue.values] for a
  /// player past their first game); [clock] is the phone's clock (the
  /// countdown reads it when no `Date` is readable); [textScale] the
  /// system's text size. [hold] holds the first `/me/` until released
  /// ([meReplies]). [sameDevice] keeps what this device stored in an
  /// earlier pump of the test (a restart).
  static Future<ShellSetup> pump(
    WidgetTester tester,
    Map<String, dynamic> me, {
    Set<Cue> learned = const {},
    DateTime? clock,
    double textScale = 1,
    bool holdMe = false,
    bool disableAnimations = false,
    bool sameDevice = false,
  }) async {
    // This device's storage (learned cues, the stage its card was seen in):
    // empty, unless the test restarts the app on the same device.
    // ignore: invalid_use_of_visible_for_testing_member
    if (!sameDevice) SharedPreferences.setMockInitialValues({});
    final setup = ShellSetup._(
      me,
      MockHttpClient(),
      MockWebSocketChannel(),
      FakeWakelockService(),
    );
    if (holdMe) {
      setup.meReplies = setup.http.hold(
        method: 'GET',
        path: '${setup._base}/me/',
      );
    }
    setup.answerMe(me);
    if (me['phase'] == 'results') setup.answerResults();
    await tester.pumpWidget(
      setup._app(
        learned: learned,
        clock: clock ?? sampleClockStart,
        textScale: textScale,
        disableAnimations: disableAnimations,
      ),
    );
    await tester.pump();
    await tester.pump();
    return setup;
  }

  /// The first `/me/`, held ([pump]'s `holdMe`).
  HeldReplies? meReplies;

  Widget _app({
    required Set<Cue> learned,
    required DateTime clock,
    required double textScale,
    required bool disableAnimations,
  }) {
    final client = AuthenticatedClient.forTesting(dio: http.dio);
    final userId = me['player_id'] as int;
    return ProviderScope(
      overrides: [
        devicePreferencesProvider.overrideWithValue(DevicePreferences()),
        learnedCuesProvider.overrideWith(() => SheetLearned(learned)),
        authProvider.overrideWithValue(
          AuthState.authenticated(User(id: userId, displayName: 'P$userId')),
        ),
        authenticatedClientProvider.overrideWithValue(client),
        gameServiceProvider.overrideWithValue(GameService(client: client)),
        lobbyServiceProvider.overrideWithValue(LobbyService(client: client)),
        gameWebSocketProvider.overrideWith((ref, id) => null),
        gameWebSocketStreamProvider.overrideWith((ref, id) => ws.stream),
        gameConnectionStateProvider.overrideWith(
          (ref, id) => _connection.stream,
        ),
        appResumesProvider.overrideWith((ref) => _resumes.stream),
        healTimingProvider.overrideWithValue(testHealTiming),
        clockProvider.overrideWithValue(() => clock),
        wakelockServiceProvider.overrideWithValue(wakelock),
      ],
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ref.watch(appThemeProvider),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: disableAnimations,
            ),
            child: GroundScope(ground: GroundKind.night, child: child!),
          ),
          home: const TableShell(),
        ),
      ),
    );
  }

  /// What the next `GET /me/` (and `/me/table/`) answer: the server is now
  /// at [me].
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

  /// `GET .../results/` answers the recorded results.
  void answerResults() => http.answer(
    'GET',
    '$_base/results/',
    ContractSamples.load('http/game/results'),
  );

  /// The app comes back to the foreground.
  void resume() => _resumes.add(++_resumeCount);

  /// The game's socket drops ([connected] false) or is back.
  void socket({required bool connected}) => _connection.add(
    connected
        ? WebSocketConnectionState.connected
        : WebSocketConnectionState.reconnecting,
  );

  int _count(String method, String path) =>
      http.requests.where((r) => r.method == method && r.path == path).length;

  /// Every `GET /me/` made so far.
  int get meFetches => _count('GET', '$_base/me/');

  /// Every POST to [endpoint] so far.
  int posts(String endpoint) => _count('POST', '$_base$endpoint');

  /// The body of the last request to [endpoint].
  dynamic lastBody(String endpoint) =>
      http.requests.lastWhere((r) => r.path == '$_base$endpoint').data;

  /// Lets answers, fetches and a screen change finish.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Unmounts the shell (its container and timers go with it).
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    // What was in flight when it went (a fetch) finishes into nothing.
    await tester.pump(const Duration(seconds: 1));
    await _resumes.close();
    await _connection.close();
  }
}
