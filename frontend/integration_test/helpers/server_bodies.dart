/// Server answers the web integration test serves from its mock.
///
/// The web build cannot read `contract_samples/` (no file system), so these
/// are written out here; `test/helpers/contract/contract_guard_test.dart`
/// checks them against the recorded samples on every `just test`.
abstract final class ServerBodies {
  /// `POST /auth/guest/` -> 201.
  static const guestCreated = {
    'access': 'test-access-token',
    'refresh': 'test-refresh-token',
    'user': {'id': 1, 'display_name': 'TestPlayer'},
  };

  /// `POST /auth/token/refresh/` -> 401: a stored token that is no longer
  /// valid (raised by the token view, so wrapped by the error handler).
  static const refreshRefused = {
    'error': {'status_code': 401, 'detail': 'Token is invalid'},
  };

  /// `GET /stats/online/` -> 200: 01's "{n} at tables".
  static const onlineStats = {'players': 6, 'tables': 1};

  /// `GET /me/table/` -> 200: at no table.
  static const myTableNone = {'table': null};

  /// `GET /onuw/me/recent-games/` -> 200: no finished game yet.
  static const recentGamesNone = {'games': <Object>[]};
}
