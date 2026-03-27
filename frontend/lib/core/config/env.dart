/// Environment configuration.
///
/// Dev defaults with prod override via `--dart-define=ENV=prod`.
class Env {
  Env._();

  static const String _env = String.fromEnvironment('ENV', defaultValue: 'dev');

  static bool get isDev => _env == 'dev';
  static bool get isProd => _env == 'prod';

  static String get apiUrl {
    final result = switch (_env) {
      'prod' => 'https://TODO_PROD_DOMAIN/api',
      _ => 'http://localhost:8000/api',
    };
    assert(
      result != 'https://TODO_PROD_DOMAIN/api',
      'Production API URL not configured',
    );
    return result;
  }
}
