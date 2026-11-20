import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/app.dart';
import 'package:midnight_village/core/api/api_client.dart';
import 'package:midnight_village/core/api/auth_interceptor.dart';
import 'package:midnight_village/core/api/authenticated_client.dart';
import 'package:midnight_village/core/router/app_router.dart';
import 'package:midnight_village/features/auth/domain/user.dart';
import 'package:midnight_village/features/auth/presentation/auth_notifier.dart';
import 'package:midnight_village/features/game/presentation/game_notifier.dart';
import 'package:midnight_village/features/game/presentation/protocol_two_game.dart';
import 'package:midnight_village/features/game/presentation/shell/game_entry.dart';
import 'package:midnight_village/features/lobby/presentation/where_am_i_provider.dart';
import 'package:midnight_village/features/game/presentation/timer_provider.dart';
import 'package:midnight_village/core/websocket/reconnecting_websocket.dart';
import 'package:midnight_village/core/websocket/websocket_channel.dart';
import 'package:web_socket_channel/io.dart';

import 'harness_config.dart';

/// Boots the REAL widget tree against the harness backend for the UI runner
/// (contract §D4), and captures `RepaintBoundary.toImage()` PNG filmstrips.
///
/// The production app bakes the dev `:8000` URLs into its clients at
/// construction. To point the SAME widget tree at the harness backend
/// (`127.0.0.1:8001`) WITHOUT touching production code, this overrides these
/// providers (see [_overrides]):
/// - `apiClientProvider` + `authenticatedClientProvider` → REST at `:8001` (the
///   latter keeps the real [AuthInterceptor] so the adopted token is injected);
/// - `gameWebSocketProvider` → a LIVE socket to the harness backend with the
///   `Origin` header the server requires (built inside the real async zone: see
///   [openGame]);
/// - `gameTimerProvider` → a one-shot countdown (the production periodic timer
///   would trip the binding's end-of-test `!timersPending` invariant).
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
    // bootstrap (tryRestoreSession) and the router's `current-game` redirect use
    // this client; left at the dev `:8000` URL it fires async `Connection
    // refused` errors (dev backend isn't running) that surface as flaky test
    // failures even though the perspective itself loads fine.
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
    // channels' OriginValidator demands (dart:io sends none). The night's results
    // arrive ONLY over the socket (all together, as a window closes), so the UI
    // runner needs it to see them.
    //
    // It must be created in the REAL async zone ([openGame] reads this provider
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
    // Replace the live countdown with a SINGLE emitted value that then
    // completes. The production `gameTimer` loops on `Future.delayed(1s)`
    // forever while the deadline is in the future; that pending timer trips the
    // automated binding's end-of-test `!timersPending` assertion and there is no
    // clean way to drain an infinite periodic timer at teardown. The displayed
    // countdown is irrelevant to filmstrip capture, so a one-shot stream that
    // shows the initial remaining time and completes is the right test seam.
    gameTimerProvider.overrideWith((ref, deadline) async* {
      if (deadline == null) return;
      final remaining = deadline.difference(DateTime.now());
      yield remaining.isNegative ? Duration.zero : remaining;
    }),
  ];

  /// Drives the auth notifier to adopt [player]'s session (no refresh), then
  /// invalidates the four game providers so the prior socket is disposed and
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
      ..invalidate(gameProvider(gameId))
      ..invalidate(gameWebSocketProvider(gameId))
      ..invalidate(gameWebSocketStreamProvider(gameId))
      ..invalidate(gameConnectionStateProvider(gameId))
      ..invalidate(protocolTwoGameProvider(gameId))
      ..invalidate(myTableProvider);
    await tester.pump();
  }

  /// Reads which night [gameId] runs in the REAL zone (the game route asks
  /// before it shows anything: [GameEntry]), so the route renders at once.
  Future<void> _knowProtocol(String gameId) => tester.runAsync(() async {
    container.listen(gameProtocolProvider(gameId), (_, _) {});
    await container
        .read(gameProtocolProvider(gameId).future)
        .timeout(const Duration(seconds: 15));
  });

  /// Opens a night protocol 2 game: the rebuilt shell ([GameEntry] ->
  /// `TableShell`). Everything the shell reads first (the protocol,
  /// `/me/table/`, the game's `/me/` and its socket) is built in the REAL
  /// zone and kept alive, so its network completes; every later fetch is
  /// started by a socket event or a tap made in the real zone
  /// ([tapAndSubmit]) and completes too.
  Future<void> openShell(String gameId) async {
    await _knowProtocol(gameId);
    await tester.runAsync(() async {
      container
        ..listen(gameWebSocketProvider(gameId), (_, _) {})
        ..listen(myTableProvider, (_, _) {})
        ..listen(protocolTwoGameProvider(gameId), (_, _) {});
      await container
          .read(myTableProvider.future)
          .timeout(const Duration(seconds: 15));
      await container
          .read(protocolTwoGameProvider(gameId).future)
          .timeout(const Duration(seconds: 15));
    });
    container.read(appRouterProvider).go('/game/$gameId');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    // As [openGame]: let the server put this socket in the game's groups.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 600)),
    );
  }

  /// Navigates to the game screen for [gameId] with its state pre-loaded.
  ///
  /// `GameNotifier.build` awaits `getGameState` (real network). If that build is
  /// first triggered by a widget `pump` (the automated binding's FAKE async
  /// zone), the Dio request's socket I/O never completes and the provider hangs
  /// in `AsyncLoading` forever — the screen is stuck on its loading spinner.
  /// [SPIKE-style finding] The fix: invalidate the provider (drop any
  /// fake-zone-captured build) and await its future INSIDE `runAsync`, so the
  /// rebuild's network runs in the REAL zone. Only then pump to mount the screen
  /// — it renders straight to data, no hung load.
  Future<void> openGame(String gameId) async {
    // Create the live socket in the REAL zone first (see [_overrides]); the
    // screen then reuses this instance when it watches the provider.
    // (Listened, not read: the socket provider is autoDispose and would
    // close again before the screen watches it.)
    await tester.runAsync(() async {
      container.listen(gameWebSocketProvider(gameId), (_, _) {});
    });
    await _knowProtocol(gameId);

    // Navigate so the screen mounts and watches `gameProvider` (its build
    // starts but hangs — it was kicked off inside a pump's FAKE async zone).
    container.read(appRouterProvider).go('/game/$gameId');
    await tester.pump();

    // Now drop that fake-zone-captured build and re-run it in the REAL zone, so
    // its `getGameState` network actually completes. Tolerate a late microtask
    // boundary on `.future` — the data still lands in the provider (verified);
    // the pump below surfaces it.
    await tester.runAsync(() async {
      container.invalidate(gameProvider(gameId));
      try {
        await container
            .read(gameProvider(gameId).future)
            .timeout(const Duration(seconds: 15));
      } catch (_) {
        // fall through — the pump renders whatever state landed.
      }
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Give the server a moment to register this socket in the game's groups:
    // events sent before that are not replayed (a client recovers them by
    // re-reading `/me/`, which is what the app does on reconnect).
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

  /// True once the real game screen has mounted — the stable anchor proving
  /// switch-in + live game state rendered, as opposed to the loading spinner or
  /// the home screen.
  ///
  /// Anchored on the `PhaseIndicator`'s phase labels (`Night` + `Vote`, which
  /// render together in the indicator and never both appear on the home screen)
  /// rather than a widget type, so it survives any wrapper and does not import
  /// the design system into the harness.
  bool get gameScreenRendered =>
      find.text('Night').evaluate().isNotEmpty &&
      find.text('Vote').evaluate().isNotEmpty;

  /// Tears the harness down cleanly so the automated binding's end-of-test
  /// `!timersPending` assertion holds.
  ///
  /// Tears the harness down cleanly so the binding's end-of-test invariants
  /// (`!timersPending`, no `UnmountedRefException`) hold. Call from a `finally`.
  ///
  /// Ordering matters:
  /// 1. Unmount the widget tree first (fake-zone `pumpWidget(SizedBox)`): each
  ///    `State.dispose()` runs, cancelling widget timers (the role-reveal 4s
  ///    one-shot, AnimatedSwitcher) and stopping provider WATCHERS — so nothing
  ///    re-reads `ref` after the next step.
  /// 2. Drain in-flight real async (router redirect / provider rebuilds kicked
  ///    off by the last pump) inside `runAsync` BEFORE disposing the container,
  ///    so those futures complete against a live container rather than throwing
  ///    `UnmountedRefException` when they touch a disposed `ref`.
  /// 3. Dispose the container (tears down providers + their resources).
  /// 4. Advance the fake clock past the only residual timers — bounded ~3s HTTP
  ///    keep-alive idle timers (`_HttpClientConnection.startTimer`) — so they
  ///    fire-and-clear and leave nothing pending.
  Future<void> tearDownHarness() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    container.dispose();
    await tester.pump(const Duration(seconds: 5));
  }

  /// Captures the current frame as a PNG inside [WidgetTester.runAsync] (raw
  /// `toImage` hangs the test clock otherwise — flutter#50783) and writes it to
  /// `integration_test/screenshots/<scenarioDir>/<frame>.png`.
  Future<void> captureFrame(String scenarioDir, String frame) async {
    await settle();
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
  Future<void> pumpUntil(bool Function() condition, {String? reason}) async {
    // BOUNDED iterations, not a wall-clock loop. Each round advances the WIDGET
    // clock a small fixed step (so the 400ms phase AnimatedSwitcher settles)
    // then yields a real-time slice inside runAsync (so live WebSocket/Dio
    // frames arrive). A wall-clock loop that pumps a duration on EVERY tick
    // would keep re-arming the reconnecting socket's timers and never return —
    // capping the rounds keeps the advanced fake-time small and bounded.
    const maxRounds =
        60; // ~3s of fake clock + ~3.6s real, well under any phase
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
