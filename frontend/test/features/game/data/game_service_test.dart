import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/api/authenticated_client.dart';
import 'package:midnight_village/features/game/data/game_service.dart';

import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/contract/server_json.dart';
import '../../../helpers/mock_http_client.dart';

/// Creates a [GameService] backed by a [MockHttpClient].
({GameService service, MockHttpClient http}) _createService() {
  final http = MockHttpClient();
  final client = AuthenticatedClient.forTesting(dio: http.dio, gated: false);
  final service = GameService(client: client);
  return (service: service, http: http);
}

void main() {
  group('GameService.fetchResults', () {
    test('returns raw results map', () async {
      final (:service, :http) = _createService();
      http.answer('GET', '/onuw/games/abc123/results/', serverResults());

      final results = await service.fetchResults('abc123');
      expect(results['winning_teams'], ['village']);
    });
  });

  group('GameService.fetchMe', () {
    test('a /me/ with a stage is the game, parsed', () async {
      final (:service, :http) = _createService();
      final body = ContractSamples.map('http/game/me_look_stage');
      http.answer('GET', '/onuw/games/g1/me/', body);

      final me = await service.fetchMe('g1');
      expect(me.stage, body['stage']);
    });

    test('a /me/ without a stage is a broken payload (a failed fetch, healed '
        'like any other)', () async {
      final (:service, :http) = _createService();
      http.answer(
        'GET',
        '/onuw/games/g1/me/',
        ContractSamples.map('http/game/me_look_stage')..remove('stage'),
        offContract: true,
      );

      await expectLater(service.fetchMe('g1'), throwsA(isA<FormatException>()));
    });
  });
}
