import 'package:flutter/foundation.dart';

/// Environment configuration.
///
/// A build is prod unless it asks for dev: `--dart-define=ENV=dev` (local runs,
/// tests, the harness, `just screens`) is the only way to get the `/debug`
/// toolbar. A prod build also names the server it talks to: `--dart-define=API_ORIGIN=https://host`
/// (the origin only: the REST base is `<origin>/api`, the sockets use the same
/// host over wss).
///
/// The web build on Vercel also passes `--dart-define=API_SAME_ORIGIN=true`
/// (only `tool/vercel_build.sh`): its HTTP calls then go to the page's own
/// origin (`<page>/api`, which `vercel.json` rewrites to the server), so the
/// browser sends no CORS preflights. The sockets still go to `API_ORIGIN`.
/// Android, dev and tests never pass it and talk to `API_ORIGIN` as before.
class Env {
  Env._();

  static const String _env = String.fromEnvironment(
    'ENV',
    defaultValue: 'prod',
  );
  static const String _apiOrigin = String.fromEnvironment('API_ORIGIN');
  static const bool _apiSameOrigin = bool.fromEnvironment('API_SAME_ORIGIN');

  /// True in dev builds. Declared as a `const bool` (not a getter) so that
  /// `if (Env.isDev) { ... }` is provably dead-code-eliminated in prod builds
  /// — every debug toolbar / harness entry point is gated on this.
  static const bool isDev = _env == 'dev';
  static const bool isProd = _env == 'prod';

  static String get apiUrl => apiUrlFor(
    web: kIsWeb,
    sameOrigin: _apiSameOrigin,
    serverOrigin: _origin('http://localhost:8000'),
    pageOrigin: kIsWeb ? Uri.base.origin : '',
  );

  /// The REST base: the server's (`<serverOrigin>/api`), or on the web with
  /// [sameOrigin] the page's own (`<pageOrigin>/api`).
  @visibleForTesting
  static String apiUrlFor({
    required bool web,
    required bool sameOrigin,
    required String serverOrigin,
    required String pageOrigin,
  }) => '${web && sameOrigin ? pageOrigin : serverOrigin}/api';

  static String get wsBaseUrl {
    final origin = _origin('http://localhost:8000');
    return origin.replaceFirst(RegExp('^http'), 'ws');
  }

  /// The server's origin without a trailing slash: the dev default, or the
  /// one a prod build was given (a prod build without one is a build mistake).
  static String _origin(String devDefault) {
    if (!isProd) return devDefault;
    assert(
      _apiOrigin.isNotEmpty,
      'Production API_ORIGIN not configured. A build with no ENV is prod: '
      'for dev pass --dart-define=ENV=dev (or use the just recipes: '
      '`just run`, `just test`).',
    );
    return _apiOrigin.replaceFirst(RegExp(r'/+$'), '');
  }
}
