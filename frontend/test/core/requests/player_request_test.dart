import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/api/authenticated_client.dart';
import 'package:midnight_village/core/requests/player_request.dart';

import '../../helpers/mock_http_client.dart';

/// The one door every request a player's tap makes goes through
/// (`core/requests/player_request.dart`): enforced where requests leave the
/// phone, and held for the code that sends them by a scan of `lib/`.
void main() {
  group('a gated client', () {
    late MockHttpClient http;
    late AuthenticatedClient client;

    setUp(() {
      http = MockHttpClient();
      client = AuthenticatedClient.forTesting(dio: http.dio);
      for (final method in ['POST', 'PATCH', 'DELETE', 'GET']) {
        http.answer(method, '/x/', {'ok': true}, offContract: true);
      }
    });

    test('sends nothing for a POST, PATCH or DELETE made outside the door', () {
      expect(() => client.post<dynamic>('/x/'), throwsStateError);
      expect(() => client.patch<dynamic>('/x/'), throwsStateError);
      expect(() => client.delete<dynamic>('/x/'), throwsStateError);
      expect(
        http.requests,
        isEmpty,
        reason: 'a refused request never leaves the phone',
      );
    });

    test('sends them inside the door, also after an await', () async {
      await playerRequest(() async {
        await Future<void>.delayed(Duration.zero);
        await client.post<dynamic>('/x/');
        await client.patch<dynamic>('/x/');
        await client.delete<dynamic>('/x/');
      });
      expect(http.requests.map((r) => r.method), ['POST', 'PATCH', 'DELETE']);
    });

    test('a GET is a read, not a player request', () async {
      await client.get<dynamic>('/x/');
      expect(http.requests.single.method, 'GET');
    });

    test('the door closes behind the request', () async {
      await playerRequest(() => client.post<dynamic>('/x/'));
      expect(insidePlayerRequest, isFalse);
      expect(() => client.post<dynamic>('/x/'), throwsStateError);
    });

    test('a test of a service alone can open its client', () async {
      final open = AuthenticatedClient.forTesting(dio: http.dio, gated: false);
      await open.post<dynamic>('/x/');
      expect(http.requests, hasLength(1));
    });
  });

  group('the code that sends them', () {
    final lib = [
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File &&
            file.path.endsWith('.dart') &&
            !file.path.endsWith('.g.dart'))
          file,
    ];

    // The service methods that make a POST, PATCH or DELETE as the player.
    final sends = RegExp(
      r'\.(createTable|joinLobby|leaveLobby|startGame|playAgain|patchSettings|'
      r'setDeckChip|setCustomDeck|advanceStage|endTalk|revealVotesAt|'
      r'send)\(',
    );

    test('every file that calls one sends it inside playerRequest()', () {
      final outside = <String>[];
      for (final file in lib) {
        final path = file.path;
        // The services themselves; the debug toolbar's own clients (their
        // own Dio, never the player's); a socket's own `send`.
        if (path.contains('/data/') ||
            path.contains('lib/core/debug/') ||
            path.contains('lib/features/debug/') ||
            path.contains('lib/core/websocket/')) {
          continue;
        }
        final source = file.readAsStringSync();
        if (sends.hasMatch(source) && !source.contains('playerRequest(')) {
          outside.add(path);
        }
      }
      expect(
        outside,
        isEmpty,
        reason:
            'these files call a request that a player\'s tap makes without '
            'playerRequest(): its control would not show busy, and it could '
            'double-send',
      );
    });

    test('a provider awaited by .future is held (whileHeld), never read '
        'bare: a read nobody holds is dropped mid-fetch when the screen '
        'changes, and fails a request that worked', () {
      final bare = <String>[];
      final read = RegExp(r'\.read\([^;]*\.future\s*\)', dotAll: true);
      for (final file in lib) {
        if (file.path.endsWith('core/requests/player_request.dart')) continue;
        final source = file.readAsStringSync();
        for (final match in read.allMatches(source)) {
          final before = source.substring(
            (match.start - 160).clamp(0, source.length),
            match.start,
          );
          if (!before.contains('whileHeld')) {
            bare.add('${file.path}: ${match.group(0)}');
          }
        }
      }
      expect(bare, isEmpty);
    });
  });
}
