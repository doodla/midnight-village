/// Environment configuration.
///
/// Dev defaults with prod override via `--dart-define=ENV=prod`.
class Env {
  Env._();

  static const String _env = String.fromEnvironment('ENV', defaultValue: 'dev');

  static bool get isDev => _env == 'dev';
  static bool get isProd => _env == 'prod';

  static String get apiUrl => switch (_env) {
    'prod' => 'https://TODO_PROD_DOMAIN/api',
    _ => 'http://localhost:8000/api',
  };
}
