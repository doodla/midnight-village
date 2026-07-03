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
import 'package:midnight_village/features/game/presentation/timer_provider.dart';

import 'harness_config.dart';

/// Boots the REAL widget tree against the harness backend for the UI runner
/// (contract §D4), and captures `RepaintBoundary.toImage()` PNG filmstrips.
///
/// The production app bakes the dev `:8000` URLs into its clients at
/// construction. To point the SAME widget tree at the harness backend
/// (`127.0.0.1:8001`) WITHOUT touching production code, this overrides four
/// providers (see [_overrides]):
/// - `apiClientProvider` + `authenticatedClientProvider` → REST at `:8001` (the
///   latter keeps the real [AuthInterceptor] so the adopted token is injected);
/// - `gameWebSocketProvider` → null (no live socket — REST-driven; see the
///   rationale in [_overrides]);
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
    // Null out the live game WebSocket for the UI runner. An always-open
    // `dart:io` socket, when its read-events are serviced during fake-async
    // `pump`s, keeps scheduling zero-duration FAKE read-event timers that never
    // drain and trip the binding's end-of-test `!timersPending` invariant — and
    // unlike a pooled HTTP connection (which we idle-close in ~1ms), the game WS
    // is meant to stay open, so it cannot be drained. The UI runner does not
    // NEED live push: it loads authoritative per-perspective state via
    // `getGameState` (`/me/`) and drives progression through the §D2 REST
    // client, re-reading on each `switchTo`/`openGame`. `GameNotifier.build` and
    // `GameContainerScreen` both handle a null WS (no stream subscription;
    // connection state defaults to `connected`). So filmstrips reflect real
    // per-player REST state with no socket left to leak timers.
    //
    // (The live-WS handshake itself — Origin header, auth, CONNECT vs 403 — is
    // still exercised by the API runner's driveAs path and the backend tests.)
    gameWebSocketProvider.overrideWith((ref, gameId) => null),
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
      ..invalidate(gameConnectionStateProvider(gameId));
    await tester.pump();
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
    // Navigate first so the screen mounts and watches `gameProvider` (its build
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
