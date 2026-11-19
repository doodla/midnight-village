import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/api/api_exception.dart';
import 'package:midnight_village/core/api/authenticated_client.dart';
import 'package:midnight_village/features/game/data/game_service.dart';

import '../../../helpers/mock_http_client.dart';

/// Creates a [GameService] backed by a [MockHttpClient].
({GameService service, MockHttpClient http}) _createService() {
  final http = MockHttpClient();
  final client = AuthenticatedClient.forTesting(dio: http.dio);
  final service = GameService(client: client);
  return (service: service, http: http);
}

void main() {
  group('GameService.getGameState', () {
    test('returns GameSessionState from successful response', () async {
      final (:service, :http) = _createService();
      http
          .when(method: 'GET', path: '/onuw/games/abc123/me/')
          .thenReturn(
            Response(
              requestOptions: RequestOptions(path: '/onuw/games/abc123/me/'),
              statusCode: 200,
              data: {
                'game_id': 'abc123',
                'phase': 'night',
                'current_wave': 1,
                'deadline': null,
                'your_role': {'original_role': 'seer', 'has_acted': false},
                'players': [
                  {'player_id': 1, 'display_name': 'Alice'},
                ],
                'roles_in_game': [],
              },
            ),
          );

      final state = await service.getGameState('abc123');
      expect(state.gameId, 'abc123');
      expect(state.phase, 'night');
      expect(state.players.length, 1);
      expect(state.yourRole.originalRole, 'seer');
    });

    test('throws MalformedResponseException on null body', () async {
      final (:service, :http) = _createService();
      http
          .when(method: 'GET', path: '/onuw/games/abc123/me/')
          .thenReturn(
            Response(
              requestOptions: RequestOptions(path: '/onuw/games/abc123/me/'),
              statusCode: 200,
              data: null,
            ),
          );

      expect(
        () => service.getGameState('abc123'),
        throwsA(isA<MalformedResponseException>()),
      );
    });
  });

  group('GameService.submitAction', () {
    test('sends correct payload', () async {
      final (:service, :http) = _createService();
      http
          .when(method: 'POST', path: '/onuw/games/abc123/action/')
          .thenReturn(
            Response(
              requestOptions: RequestOptions(
                path: '/onuw/games/abc123/action/',
              ),
              statusCode: 200,
              data: {'status': 'submitted'},
            ),
          );

      await service.submitAction('abc123', 'peek_player', {'player_id': 3});
    });

    test('treats 409 as success (already acted)', () async {
      final (:service, :http) = _createService();
      http.dio.interceptors.clear();
      http.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response(
                  requestOptions: options,
                  statusCode: 409,
                  data: {'detail': 'Already acted'},
                ),
                type: DioExceptionType.badResponse,
              ),
            );
          },
        ),
      );

      // Should not throw.
      await service.submitAction('abc123', 'peek_player', {'player_id': 3});
    });

    test('throws on 400 (invalid action)', () async {
      final (:service, :http) = _createService();
      http.dio.interceptors.clear();
      http.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response(
                  requestOptions: options,
                  statusCode: 400,
                  data: {'detail': 'Invalid action'},
                ),
                type: DioExceptionType.badResponse,
              ),
            );
          },
        ),
      );

      expect(
        () => service.submitAction('abc123', 'bad_action', {}),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('GameService.submitVote', () {
    test('sends correct payload', () async {
      final (:service, :http) = _createService();
      http
          .when(method: 'POST', path: '/onuw/games/abc123/vote/')
          .thenReturn(
            Response(
              requestOptions: RequestOptions(path: '/onuw/games/abc123/vote/'),
              statusCode: 200,
              data: {'status': 'submitted'},
            ),
          );

      await service.submitVote('abc123', 3);
    });

    test('treats 409 as success (already voted)', () async {
      final (:service, :http) = _createService();
      http.dio.interceptors.clear();
      http.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response(
                  requestOptions: options,
                  statusCode: 409,
                  data: {'detail': 'Already voted'},
                ),
                type: DioExceptionType.badResponse,
              ),
            );
          },
        ),
      );

      await service.submitVote('abc123', 3);
    });
  });

  group('GameService.endDiscussion', () {
    test('sends POST to correct endpoint', () async {
      final (:service, :http) = _createService();
      http
          .when(method: 'POST', path: '/onuw/games/abc123/end-discussion/')
          .thenReturn(
            Response(
              requestOptions: RequestOptions(
                path: '/onuw/games/abc123/end-discussion/',
              ),
              statusCode: 200,
              data: {'status': 'voting_started'},
            ),
          );

      await service.endDiscussion('abc123');
    });
  });

  group('GameService.fetchResults', () {
    test('returns raw results map', () async {
      final (:service, :http) = _createService();
      http
          .when(method: 'GET', path: '/onuw/games/abc123/results/')
          .thenReturn(
            Response(
              requestOptions: RequestOptions(
                path: '/onuw/games/abc123/results/',
              ),
              statusCode: 200,
              data: {
                'winning_teams': ['village'],
                'players': [],
              },
            ),
          );

      final results = await service.fetchResults('abc123');
      expect(results['winning_teams'], ['village']);
    });

    test('throws MalformedResponseException on null body', () async {
      final (:service, :http) = _createService();
      http
          .when(method: 'GET', path: '/onuw/games/abc123/results/')
          .thenReturn(
            Response(
              requestOptions: RequestOptions(
                path: '/onuw/games/abc123/results/',
              ),
              statusCode: 200,
              data: null,
            ),
          );

      expect(
        () => service.fetchResults('abc123'),
        throwsA(isA<MalformedResponseException>()),
      );
    });
  });

  group('GameService night_results, presence and host calls', () {
    Response<dynamic> ok(String path, dynamic data) => Response(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: data,
    );

    test(
      'getGameState parses night_results in the action_result shape',
      () async {
        final (:service, :http) = _createService();
        http
            .when(method: 'GET', path: '/onuw/games/g1/me/')
            .thenReturn(
              ok('/onuw/games/g1/me/', {
                'game_id': 'g1',
                'phase': 'discussion',
                'your_role': {'original_role': 'seer', 'has_acted': true},
                'players': [
                  {'player_id': 1, 'display_name': 'Alice', 'connected': false},
                ],
                'night_results': [
                  {
                    'wave': 2,
                    'action_type': 'peek_center',
                    'revealed_info': {
                      'cards': ['werewolf'],
                    },
                  },
                ],
              }),
            );

        final state = await service.getGameState('g1');

        expect(state.nightResults, hasLength(1));
        expect(state.nightResults.single.wave, 2);
        expect(
          state.nightResults.single.revealedInfo['action_type'],
          'peek_center',
        );
        expect(state.players.single.connected, isFalse);
      },
    );

    test(
      'fetchPresence maps player ids to connected, absent means connected',
      () async {
        final (:service, :http) = _createService();
        http
            .when(method: 'GET', path: '/onuw/games/g1/players/')
            .thenReturn(
              ok('/onuw/games/g1/players/', {
                'players': [
                  {'player_id': 1, 'display_name': 'Alice', 'connected': false},
                  {'player_id': 2, 'display_name': 'Bob'},
                ],
              }),
            );

        expect(await service.fetchPresence('g1'), {1: false, 2: true});
      },
    );

    test('advanceNight posts to advance-wave', () async {
      final (:service, :http) = _createService();
      http
          .when(method: 'POST', path: '/onuw/games/g1/advance-wave/')
          .thenReturn(
            ok('/onuw/games/g1/advance-wave/', {'status': 'advanced'}),
          );

      await service.advanceNight('g1');

      expect(http.requests.single.path, '/onuw/games/g1/advance-wave/');
    });

    test('revealVotes posts to reveal-votes', () async {
      final (:service, :http) = _createService();
      http
          .when(method: 'POST', path: '/onuw/games/g1/reveal-votes/')
          .thenReturn(
            ok('/onuw/games/g1/reveal-votes/', {'status': 'revealed'}),
          );

      await service.revealVotes('g1');

      expect(http.requests.single.path, '/onuw/games/g1/reveal-votes/');
    });
  });
}
