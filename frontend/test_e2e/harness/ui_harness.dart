import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override, ProviderBase;
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/app.dart';
import 'package:midnight_village/core/api/api_client.dart';
import 'package:midnight_village/core/api/auth_interceptor.dart';
import 'package:midnight_village/core/api/authenticated_client.dart';
import 'package:midnight_village/core/healing/healing.dart';
import 'package:midnight_village/core/router/app_router.dart';
import 'package:midnight_village/features/auth/domain/user.dart';
import 'package:midnight_village/features/auth/presentation/auth_notifier.dart';
import 'package:midnight_village/features/game/presentation/game_socket.dart';
import 'package:midnight_village/features/game/presentation/live_game.dart';
import 'package:midnight_village/features/lobby/domain/where_am_i.dart';
import 'package:midnight_village/features/lobby/presentation/lobby_notifier.dart';
import 'package:midnight_village/features/lobby/presentation/where_am_i_provider.dart';
import 'package:midnight_village/core/websocket/reconnecting_websocket.dart';
import 'package:midnight_village/core/websocket/websocket_channel.dart';
import 'package:web_socket_channel/io.dart';

import 'harness_config.dart';

/// Boots the REAL widget tree against the harness backend for the UI runner
/// (contract §D4), and captures `RepaintBoundary.toImage()` PNG filmstrips.
///
/// The production app bakes the dev `:8000` URLs into its clients at
/// construction. To point the SAME widget tree at the harness backend
/// (`127.0.0.1:<port>`, [HarnessConfig.port]) WITHOUT touching production
/// code, this overrides these providers (see [_overrides]):
/// - `apiClientProvider` + `authenticatedClientProvider` → REST at the
///   harness (the latter keeps the real [AuthInterceptor] so the adopted
///   token is injected);
/// - `gameWebSocketProvider` and the lobby's socket factory → LIVE sockets to
///   the harness backend with the `Origin` header the server requires (built
///   inside the real async zone: see [openShell]).
class UiHarness {
  UiHarness(this.tester);

  final WidgetTester tester;
  final GlobalKey _captureKey = GlobalKey();
  late final ProviderContainer container;

  /// Pumps the app wrapped in a [RepaintBoundary] (for capture) and a
  /// [ProviderScope] re-targeted at the harness backend.
  Future<void> pumpApp() async {
    // Fresh auth state per scenario: drop any prior scenario's adopted token so
    // the app's session-restore doesn't boot with a stale (now blacklisted) JWT.
    HarnessConfig.clearSecureStorage();
    container = ProviderContainer(overrides: _overrides());
    // Idempotent safety net: tearDownHarness disposes the container explicitly,
    // but if the test throws before reaching it, this still tears down the live
    // WebSocket. ProviderContainer.dispose is safe to call twice.
    addTearDown(() {
      try {
        container.dispose();
      } catch (_) {}
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: RepaintBoundary(key: _captureKey, child: const App()),
      ),
    );
    await tester.pump();
  }

  List<Override> _overrides() => [
    // Re-target the UNAUTHENTICATED client at the harness backend too. The auth
    // bootstrap (tryRestoreSession, renewing an expired access token) and
    // guest sign-up use this client; left at the dev `:8000` URL it fires
    // async `Connection refused` errors (dev backend isn't running) that
    // surface as flaky test failures even though the perspective loads fine.
    apiClientProvider.overrideWithValue(
      ApiClient(baseUrl: HarnessConfig.apiBaseUrl),
    ),
    // Re-target the authenticated REST client at the harness backend. Keep the
    // real interceptor so the adopted token is injected per request.
    authenticatedClientProvider.overrideWith((ref) {
      final interceptor = AuthInterceptor(
        tokenStorage: ref.watch(tokenStorageProvider),
        unauthenticatedClient: ref.watch(apiClientProvider),
        onAuthFailure: () => ref.invalidate(authProvider),
      );
      return AuthenticatedClient(
        baseUrl: HarnessConfig.apiBaseUrl,
        interceptor: interceptor,
      );
    }),
    // A LIVE game socket, pointed at the harness backend with the Origin header
    // channels' OriginValidator demands (dart:io sends none): the events that
    // make the phone fetch `/me/` again arrive over it.
    //
    // It must be created in the REAL async zone ([openShell] reads this provider
    // inside `runAsync` before the screen can watch it): a socket created under
    // the automated binding's fake zone schedules zero-length fake read-event
    // timers that never drain and trip the end-of-test `!timersPending`
    // invariant. Built in the real zone its timers are real and invisible to it.
    gameWebSocketProvider.overrideWith((ref, gameId) {
      final ws = ReconnectingWebSocket(
        url: '${HarnessConfig.wsBaseUrl}/ws/game/$gameId/',
        tokenStorage: ref.watch(tokenStorageProvider),
        channelFactory: (uri) => _OriginChannel(
          IOWebSocketChannel.connect(
            uri,
            headers: {'Origin': HarnessConfig.origin},
          ),
        ),
      );
      unawaited(ws.connect());
      ref.onDispose(ws.dispose);
      return ws;
    }),
    // The lobby's socket (02 and 03), LIVE against the harness backend with
    // the Origin header, as the game's. Built when the lobby is first read:
    // [readLobby] reads it in the REAL zone.
    lobbyWebSocketFactoryProvider.overrideWith((ref) {
      final tokens = ref.watch(tokenStorageProvider);
      return (code) {
        final ws = ReconnectingWebSocket(
          url: '${HarnessConfig.wsBaseUrl}/ws/lobby/$code/',
          tokenStorage: tokens,
          channelFactory: (uri) => _OriginChannel(
            IOWebSocketChannel.connect(
              uri,
              headers: {'Origin': HarnessConfig.origin},
            ),
          ),
        );
        unawaited(ws.connect());
        return ws;
      };
    }),
  ];

  /// Drives the auth notifier to adopt [player]'s session (no refresh), then
  /// invalidates the game's providers so the prior socket is disposed and
  /// the new one attaches — exactly the §D1 `switchTo` behavior, applied to the
  /// UI runner's container.
  ///
  /// `adoptSession` writes the token+user to (mocked, in-memory) storage. Under
  /// the automated test binding even that microtask work must be flushed inside
  /// `runAsync`; the subsequent provider invalidation tears down the old
  /// player's socket so exactly one live WS remains.
  Future<void> switchTo({
    required int userId,
    required String displayName,
    required String accessToken,
    required String refreshToken,
    required String gameId,
  }) async {
    await tester.runAsync(() async {
      await container
          .read(authProvider.notifier)
          .adoptSession(
            User(id: userId, displayName: displayName),
            accessToken: accessToken,
            refreshToken: refreshToken,
          );
    });
    container
      ..invalidate(gameWebSocketProvider(gameId))
      ..invalidate(gameWebSocketStreamProvider(gameId))
      ..invalidate(gameConnectionStateProvider(gameId))
      ..invalidate(liveGameProvider(gameId))
      ..invalidate(myTableProvider);
    await tester.pump();
  }

  /// Reads `/me/table/` afresh in the REAL zone until it holds [until] (a
  /// read started under a pump, in the fake zone, never completes): after
  /// the server moved this phone (a table opened, joined or dealt; the move
  /// may still be on its way when this starts).
  Future<MyTable?> followTable({bool Function(MyTable? table)? until}) async {
    final table = await tester.runAsync(
      () => _readAgain<MyTable?>(myTableProvider, until: until),
    );
    await tester.pump();
    await settle();
    return table;
  }

  /// Reads the lobby [code] (02 and 03 show it) in the REAL zone and keeps it
  /// alive: its fetch completes and its socket is live, so the screen follows
  /// the table (players joining, a chip's answer).
  Future<void> readLobby(String code) async {
    await tester.runAsync(() async {
      await _readAgain(lobbyProvider(code));
      // Let the server put the socket in the lobby's group.
      await Future<void>.delayed(const Duration(milliseconds: 600));
    });
    await tester.pump();
    await settle();
  }

  /// [provider] built afresh in the real zone and kept alive, read again
  /// until its value holds [until]: each round invalidates it (a build a
  /// pump started meanwhile, in the fake zone, is dropped) and polls for a
  /// value, bounded.
  Future<T?> _readAgain<T>(
    ProviderBase<AsyncValue<T>> provider, {
    bool Function(T? value)? until,
  }) async {
    container.listen(provider, (_, _) {});
    final waited = Stopwatch()..start();
    while (waited.elapsed < const Duration(seconds: 20)) {
      container.invalidate(provider);
      final round = Stopwatch()..start();
      while (round.elapsed < const Duration(seconds: 3)) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        final now = container.read(provider);
        if (now.hasValue && !now.isLoading) {
          if (until == null || until(now.value)) return now.value;
          break;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    throw TimeoutException('$provider did not load as expected');
  }

  /// Opens a game: its link (`/game/<id>`), which is the table's shell
  /// (`TableShell`). Everything the shell reads first (`/me/table/`, the
  /// game's `/me/` and its socket) is built in the REAL
  /// zone and kept alive, so its network completes; every later fetch is
  /// started by a socket event or a tap made in the real zone
  /// ([tapAndSubmit]) and completes too.
  Future<void> openShell(String gameId) async {
    await tester.runAsync(() async {
      // Home (`/`) is the table's shell too, so `/me/table/` may have been
      // started under a pump, in the FAKE zone, where it never completes
      // (nor does that build's `.future`). Start it again here, in the real
      // zone, and wait for its value.
      // The game's own reads too, when a pump already started them (a phone
      // that dealt from 02 shows the game before this is called).
      container
        ..invalidate(myTableProvider)
        ..invalidate(gameWebSocketProvider(gameId))
        ..invalidate(liveGameProvider(gameId))
        ..listen(gameWebSocketProvider(gameId), (_, _) {})
        ..listen(myTableProvider, (_, _) {})
        ..listen(liveGameProvider(gameId), (_, _) {});
      final waited = Stopwatch()..start();
      while (!container.read(myTableProvider).hasValue) {
        if (waited.elapsed > const Duration(seconds: 15)) {
          throw TimeoutException('/me/table/ did not load');
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      await container
          .read(liveGameProvider(gameId).future)
          .timeout(const Duration(seconds: 15));
    });
    container.read(appRouterProvider).go('/game/$gameId');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    // Let the server put this socket in the game's groups: events sent before
    // that are not replayed (a phone recovers them by reading `/me/` again).
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 600)),
    );
  }

  /// Taps [finder] for a control whose handler makes a REAL HTTP request (a
  /// submit button). The tap runs inside `runAsync` so the request is made in
  /// the real zone (a request started under the fake zone never completes);
  /// the screen is then pumped until [until] holds.
  Future<void> tapAndSubmit(Finder finder, {bool Function()? until}) async {
    await tester.runAsync(() async {
      await tester.tap(finder);
    });
    await pumpUntil(until ?? () => true, reason: 'after submitting');
    await settle();
  }

  /// The next [captureFrame] waits out only the change of screen (one 450 ms
  /// step), not the new screen's own motion: a frame of it opening (10's rows
  /// landing, its cards not turned yet). Reset by that capture.
  bool captureMidMotion = false;

  /// Lets the phase cross-fade (400ms `AnimatedSwitcher`) finish, so the outgoing
  /// view is really gone (assertions and filmstrip frames see one screen). Two
  /// steps: a change that lands during the first starts its fade there.
  Future<void> settle() async {
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 450));
  }

  /// The router's current location URI (for diagnostics / wait conditions).
  String get currentLocation =>
      container.read(appRouterProvider).routeInformationProvider.value.uri.path;

  /// Tears the harness down cleanly so the automated binding's end-of-test
  /// `!timersPending` assertion holds.
  ///
  /// Tears the harness down cleanly so the binding's end-of-test invariants
  /// (`!timersPending`, no `UnmountedRefException`) hold. Call from a `finally`.
  ///
  /// Ordering matters:
  /// 1. Unmount the widget tree first (fake-zone `pumpWidget(SizedBox)`): each
  ///    `State.dispose()` runs, cancelling widget timers (the countdowns,
  ///    AnimatedSwitcher) and stopping provider WATCHERS — so nothing
  ///    re-reads `ref` after the next step.
  /// 2. Drain in-flight real async (router redirect / provider rebuilds kicked
  ///    off by the last pump) inside `runAsync` BEFORE disposing the container,
  ///    so those futures complete against a live container rather than throwing
  ///    `UnmountedRefException` when they touch a disposed `ref`.
  /// 3. Dispose the container (tears down providers + their resources).
  /// 4. Unmount again and advance the fake clock past every residual timer:
  ///    HTTP keep-alive idle timers (`_HttpClientConnection.startTimer`, 15 s
  ///    by default) and any heal or poll timer a late answer armed
  ///    ([HealTiming], the longest `tablePoll`), so they fire into a disposed
  ///    container and leave nothing pending, whatever the phone was doing.
  Future<void> tearDownHarness() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    container.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(_drain);
  }

  /// Longer than any timer the app or an idle connection arms.
  static final _drain =
      const HealTiming().tablePoll + const Duration(seconds: 5);

  /// Captures the current frame as a PNG inside [WidgetTester.runAsync] (raw
  /// `toImage` hangs the test clock otherwise — flutter#50783) and writes it to
  /// `integration_test/screenshots/<scenarioDir>/<frame>.png`.
  Future<void> captureFrame(String scenarioDir, String frame) async {
    if (captureMidMotion) {
      // Only the change of screen: the screen's own motion is still running.
      captureMidMotion = false;
      await tester.pump(const Duration(milliseconds: 450));
    } else {
      await settle();
    }
    await _decodeImages();
    final boundary =
        _captureKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) return;
      final dir = Directory('integration_test/screenshots/$scenarioDir')
        ..createSync(recursive: true);
      File(
        '${dir.path}/$frame.png',
      ).writeAsBytesSync(byteData.buffer.asUint8List());
    });
  }

  /// Image providers load on real I/O, which the fake clock never waits for:
  /// every image on screen is loaded for real, then drawn again, so a frame
  /// never shows a card or a token before its picture has decoded.
  Future<void> _decodeImages() async {
    final images = [
      for (final element in find.byType(Image).evaluate())
        ((element.widget as Image).image, element),
    ];
    if (images.isEmpty) return;
    await tester.runAsync(
      () => Future.wait([
        for (final (provider, context) in images)
          precacheImage(provider, context),
      ]),
    );
    await tester.pump();
  }

  /// Polls [condition] over a BOUNDED number of pump rounds, throwing if it is
  /// never satisfied. This is the only safe wait against the live reconnecting
  /// socket — `pumpAndSettle` never returns because the socket keeps scheduling
  /// reconnect/heartbeat work.
  ///
  /// [rounds] is the bound (60: about 3 s of fake clock and 3.6 s real); a
  /// wait on the server's next answer, which a loaded machine slows, may
  /// take more.
  Future<void> pumpUntil(
    bool Function() condition, {
    String? reason,
    int rounds = 60,
  }) async {
    // BOUNDED iterations, not a wall-clock loop. Each round advances the WIDGET
    // clock a small fixed step (so the 400ms phase AnimatedSwitcher settles)
    // then yields a real-time slice inside runAsync (so live WebSocket/Dio
    // frames arrive). A wall-clock loop that pumps a duration on EVERY tick
    // would keep re-arming the reconnecting socket's timers and never return —
    // capping the rounds keeps the advanced fake-time small and bounded.
    final maxRounds = rounds;
    for (var i = 0; i < maxRounds; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (condition()) return;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
    }
    await tester.pump(const Duration(milliseconds: 50));
    if (!condition()) {
      throw StateError(
        'pumpUntil exhausted $maxRounds rounds: ${reason ?? "condition false"}',
      );
    }
  }
}

/// Adapts an [IOWebSocketChannel] (which can carry the Origin header) to the
/// app's [WebSocketChannelInterface] for the harness's [ReconnectingWebSocket].
class _OriginChannel implements WebSocketChannelInterface {
  _OriginChannel(this._channel);

  final IOWebSocketChannel _channel;
  bool _closed = false;

  @override
  Stream<dynamic> get stream => _channel.stream;

  @override
  void send(dynamic data) => _channel.sink.add(data);

  @override
  Future<void> close([int? code, String? reason]) async {
    _closed = true;
    await _channel.sink.close(code, reason);
  }

  @override
  bool get isClosed => _closed;
}
