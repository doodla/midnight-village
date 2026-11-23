// Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Keeps every way a test feeds server data to the app under the contract
/// guard (contract_shape.dart), so a new test cannot slip around it.
///
/// Scans `test/` and `test_screens/` for the patterns that bypass the guard:
/// a mocked HTTP client answering with whatever the test wrote, an adapter
/// serving its own bodies, a mock answering with a literal map, a
/// server-backed domain object built by constructor, a literal map parsed
/// with `fromJson`. Each rule names the only files allowed to match it, and
/// why. What it cannot see: a literal map put in a variable first and parsed
/// later, or a mock of a class it does not list.
void main() {
  final rules = <_Rule>[
    _Rule(
      'a mocked HTTP client (register answers on MockHttpClient instead)',
      example: "class _M extends Mock implements AuthenticatedClient {}",
      RegExp(r'implements\s+(AuthenticatedClient|ApiClient|Dio)\b'),
      allowed: const {},
    ),
    _Rule(
      'a mocked debug client',
      example: "class _M extends Mock implements DebugApiClient {}",
      RegExp(r'implements\s+DebugApiClient\b'),
      allowed: const {
        // Its answers all go through `_answer`, which checks each body.
        'test/core/debug/debug_table_controller_test.dart',
      },
    ),
    _Rule(
      'a Dio adapter serving its own bodies',
      example: "class _A implements HttpClientAdapter {",
      RegExp(r'implements\s+HttpClientAdapter\b'),
      allowed: const {
        // `_ServerAdapter` checks its body against the samples. The debug
        // client builds its own Dio, so MockHttpClient cannot stand in.
        'test/core/debug/debug_api_client_test.dart',
      },
    ),
    _Rule(
      'a mock answering with a literal map (answer with a checked body)',
      example:
          "when(() => c.get('/x/')).thenAnswer(\n  (_) async => {'game_id': 'g'},\n);",
      RegExp(
        r'then(Answer\(\s*\([^)]*\)\s*async\s*=>|Return\()\s*(const\s*)?'
        r'(<[^>]*>)?\{',
      ),
      allowed: const {},
    ),
    _Rule(
      'a server-backed domain object built by constructor (use FromSample)',
      example: "const GamePlayer(playerId: 1, displayName: 'A')",
      RegExp(
        r'(?<![\w.$])(GameSessionState|GamePlayer|YourRole|ActionPrompt|'
        r'ActionResult|RoleInGame|LobbyState|LobbyPlayer|HostChange|'
        r'VoteRevealData|DebugOracleState|DebugOraclePlayer|DebugNightAction)'
        r'\(',
      ),
      allowed: const {},
    ),
    _Rule(
      'a literal map parsed with fromJson (parse a sample)',
      example: "LobbyState.fromJson({'code': 'X'})",
      RegExp(r'\.fromJson\(\s*(const\s+)?(<[^>]*>)?\{'),
      allowed: const {
        // The design system's own example (User), outside this guard's
        // reach: test/design_system/ is not changed with the app's tests.
        'test/design_system/examples/unit_test_example.dart',
      },
    ),
  ];

  final files = [
    for (final root in ['test', 'test_screens'])
      ...Directory(root)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !f.path.endsWith('fixture_sources_test.dart')),
  ];

  test('there are test files to scan', () => expect(files, isNotEmpty));

  for (final rule in rules) {
    test('the rule against ${rule.what} catches it', () {
      expect(rule.pattern.hasMatch(rule.example), isTrue);
    });

    test('no test bypasses the guard with ${rule.what}', () {
      final offenders = <String>[];
      for (final file in files) {
        final path = file.path.replaceAll(r'\', '/');
        if (rule.allowed.contains(path)) continue;
        final text = file.readAsStringSync();
        for (final match in rule.pattern.allMatches(text)) {
          final line = '\n'.allMatches(text.substring(0, match.start)).length;
          offenders.add('$path:${line + 1}: ${match.group(0)}');
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('every file allowed ${rule.what} still needs it', () {
      for (final path in rule.allowed) {
        expect(
          rule.pattern.hasMatch(File(path).readAsStringSync()),
          isTrue,
          reason: '$path no longer matches: take it off the allowed list',
        );
      }
    });
  }
}

class _Rule {
  const _Rule(
    this.what,
    this.pattern, {
    required this.example,
    required this.allowed,
  });

  final String what;
  final RegExp pattern;

  /// Code the rule must catch (proves the pattern bites).
  final String example;

  /// Files (from the package root) allowed to match, each with its reason.
  final Set<String> allowed;
}
