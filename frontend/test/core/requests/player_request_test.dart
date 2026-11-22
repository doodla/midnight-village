import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/api/authenticated_client.dart';
import 'package:midnight_village/core/requests/player_request.dart';

import '../../helpers/mock_http_client.dart';

/// The one door every request a player's tap makes goes through
/// (`core/requests/player_request.dart`). That a write needs a [Door] is a
/// compile-time rule (the services' and the client's write methods take one,
/// and only `playerRequest` makes one); what is tested here is what the
/// compiler cannot see: the door is shut when its request is done, and the
/// lib's awaits on providers.
void main() {
  group('the door', () {
    late MockHttpClient http;
    late AuthenticatedClient client;

    setUp(() {
      http = MockHttpClient();
      client = AuthenticatedClient.forTesting(dio: http.dio);
      for (final method in ['POST', 'PATCH', 'DELETE']) {
        http.answer(method, '/x/', {'ok': true}, offContract: true);
      }
    });

    test('is open for the whole request, also after an await', () async {
      await playerRequest((door) async {
        await Future<void>.delayed(Duration.zero);
        await client.post<dynamic>(door, '/x/');
        await client.patch<dynamic>(door, '/x/');
        await client.delete<dynamic>(door, '/x/');
      });
      expect(http.requests.map((r) => r.method), ['POST', 'PATCH', 'DELETE']);
    });

    test('is shut when the request is done: a token kept in a timer or a '
        'socket callback sends nothing', () async {
      late Door kept;
      await playerRequest((door) async => kept = door);
      expect(() => client.post<dynamic>(kept, '/x/'), throwsStateError);
      expect(() => client.patch<dynamic>(kept, '/x/'), throwsStateError);
      expect(() => client.delete<dynamic>(kept, '/x/'), throwsStateError);
      expect(http.requests, isEmpty, reason: 'it never left the phone');
    });

    test('is shut also when the request failed', () async {
      late Door kept;
      await expectLater(
        playerRequest<void>((door) async {
          kept = door;
          throw StateError('no answer');
        }),
        throwsStateError,
      );
      expect(() => client.post<dynamic>(kept, '/x/'), throwsStateError);
    });

    test('a test door is for a test of a service alone', () async {
      await client.post<dynamic>(Door.forTest(), '/x/');
      expect(http.requests, hasLength(1));
    });
  });

  group('the code that waits on providers', () {
    final lib = [
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File &&
            file.path.endsWith('.dart') &&
            !file.path.endsWith('.g.dart'))
          file,
    ];

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

    test('nothing in lib makes a test door', () {
      final made = [
        for (final file in lib)
          if (!file.path.endsWith('core/requests/player_request.dart') &&
              file.readAsStringSync().contains('Door.forTest'))
            file.path,
      ];
      expect(made, isEmpty);
    });
  });
}
