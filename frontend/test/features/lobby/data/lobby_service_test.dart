import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/api/api_exception.dart';
import 'package:midnight_village/core/api/authenticated_client.dart';
import 'package:midnight_village/features/lobby/data/lobby_service.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthenticatedClient extends Mock implements AuthenticatedClient {}

/// Canonical lobby response JSON matching the backend format.
Map<String, dynamic> _lobbyResponseJson({
  String code = 'ABC123',
  int hostId = 1,
  String status = 'waiting',
}) {
  return {
    'code': code,
    'host': {'id': hostId, 'username': 'player1', 'display_name': 'Alice'},
    'game_type': 'onuw',
    'status': status,
    'max_players': 10,
    'settings': {
      'roles': {'werewolf': 2, 'seer': 1, 'robber': 1},
    },
    'players': [
      {
        'user': {'id': hostId, 'username': 'player1', 'display_name': 'Alice'},
        'is_ready': true,
        'joined_at': '2026-03-31T06:00:00Z',
      },
    ],
    'created_at': '2026-03-31T05:55:00Z',
  };
}

void main() {
  late MockAuthenticatedClient mockClient;
  late LobbyService service;

  setUp(() {
    mockClient = MockAuthenticatedClient();
    service = LobbyService(client: mockClient);
  });

  group('LobbyService', () {
    group('createLobby', () {
      test(
        'sends POST to /lobbies/ with game_type and returns LobbyState',
        () async {
          when(
            () => mockClient.post<Map<String, dynamic>>(
              '/lobbies/',
              data: {'game_type': 'onuw'},
            ),
          ).thenAnswer(
            (_) async => Response(
              requestOptions: RequestOptions(path: '/lobbies/'),
              data: _lobbyResponseJson(),
            ),
          );

          final lobby = await service.createLobby();

          expect(lobby.code, 'ABC123');
          expect(lobby.hostId, 1);
          verify(
            () => mockClient.post<Map<String, dynamic>>(
              '/lobbies/',
              data: {'game_type': 'onuw'},
            ),
          ).called(1);
        },
      );

      test('maps DioException to ApiException', () async {
        when(
          () => mockClient.post<Map<String, dynamic>>(
            '/lobbies/',
            data: any(named: 'data'),
          ),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/lobbies/'),
            type: DioExceptionType.connectionError,
          ),
        );

        await expectLater(
          () => service.createLobby(),
          throwsA(isA<NetworkException>()),
        );
      });
    });

    group('joinLobby', () {
      test(
        'sends POST to /lobbies/<code>/join/ and returns LobbyState',
        () async {
          when(
            () =>
                mockClient.post<Map<String, dynamic>>('/lobbies/XYZ789/join/'),
          ).thenAnswer(
            (_) async => Response(
              requestOptions: RequestOptions(path: '/lobbies/XYZ789/join/'),
              data: _lobbyResponseJson(code: 'XYZ789'),
            ),
          );

          final lobby = await service.joinLobby('XYZ789');

          expect(lobby.code, 'XYZ789');
          verify(
            () =>
                mockClient.post<Map<String, dynamic>>('/lobbies/XYZ789/join/'),
          ).called(1);
        },
      );
    });

    group('leaveLobby', () {
      test('sends POST to /lobbies/<code>/leave/', () async {
        when(
          () => mockClient.post<Map<String, dynamic>>('/lobbies/ABC123/leave/'),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/lobbies/ABC123/leave/'),
            data: {'detail': 'Left lobby'},
          ),
        );

        await service.leaveLobby('ABC123');

        verify(
          () => mockClient.post<Map<String, dynamic>>('/lobbies/ABC123/leave/'),
        ).called(1);
      });
    });

    group('toggleReady', () {
      test('sends POST to /lobbies/<code>/ready/', () async {
        when(
          () => mockClient.post<Map<String, dynamic>>('/lobbies/ABC123/ready/'),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/lobbies/ABC123/ready/'),
            data: _lobbyResponseJson(),
          ),
        );

        await service.toggleReady('ABC123');

        verify(
          () => mockClient.post<Map<String, dynamic>>('/lobbies/ABC123/ready/'),
        ).called(1);
      });
    });

    group('updateRoleConfig', () {
      test('sends PATCH to /lobbies/<code>/ with settings body', () async {
        final roles = {'werewolf': 2, 'seer': 1};
        when(
          () => mockClient.patch<Map<String, dynamic>>(
            '/lobbies/ABC123/',
            data: {
              'settings': {'roles': roles},
            },
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/lobbies/ABC123/'),
            data: _lobbyResponseJson(),
          ),
        );

        final lobby = await service.updateRoleConfig('ABC123', roles);

        expect(lobby.code, 'ABC123');
        verify(
          () => mockClient.patch<Map<String, dynamic>>(
            '/lobbies/ABC123/',
            data: {
              'settings': {'roles': roles},
            },
          ),
        ).called(1);
      });
    });

    group('startGame', () {
      test(
        'sends POST to /onuw/lobbies/<code>/start/ and returns game ID',
        () async {
          when(
            () => mockClient.post<Map<String, dynamic>>(
              '/onuw/lobbies/ABC123/start/',
            ),
          ).thenAnswer(
            (_) async => Response(
              requestOptions: RequestOptions(
                path: '/onuw/lobbies/ABC123/start/',
              ),
              data: {
                'game_id': '550e8400-e29b-41d4-a716-446655440000',
                'phase': 'night',
              },
            ),
          );

          final gameId = await service.startGame('ABC123');

          expect(gameId, '550e8400-e29b-41d4-a716-446655440000');
        },
      );

      test('throws MalformedResponseException when response is null', () async {
        when(
          () => mockClient.post<Map<String, dynamic>>(
            '/onuw/lobbies/ABC123/start/',
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/onuw/lobbies/ABC123/start/'),
            data: null,
          ),
        );

        await expectLater(
          () => service.startGame('ABC123'),
          throwsA(isA<MalformedResponseException>()),
        );
      });

      test('throws MalformedResponseException when game_id missing', () async {
        when(
          () => mockClient.post<Map<String, dynamic>>(
            '/onuw/lobbies/ABC123/start/',
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/onuw/lobbies/ABC123/start/'),
            data: {'phase': 'night'},
          ),
        );

        await expectLater(
          () => service.startGame('ABC123'),
          throwsA(isA<MalformedResponseException>()),
        );
      });
    });

    group('playAgain', () {
      test(
        'sends POST to /lobbies/<code>/play-again/ and returns the lobby',
        () async {
          when(
            () => mockClient.post<Map<String, dynamic>>(
              '/lobbies/ABC123/play-again/',
            ),
          ).thenAnswer(
            (_) async => Response(
              requestOptions: RequestOptions(
                path: '/lobbies/ABC123/play-again/',
              ),
              data: _lobbyResponseJson(),
            ),
          );

          final lobby = await service.playAgain('ABC123');

          expect(lobby.code, 'ABC123');
          expect(lobby.status, 'waiting');
          expect(lobby.players, hasLength(1));
        },
      );

      test('maps 403 (not the host) to ForbiddenException', () async {
        when(
          () => mockClient.post<Map<String, dynamic>>(
            '/lobbies/ABC123/play-again/',
          ),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/lobbies/ABC123/play-again/'),
            response: Response(
              requestOptions: RequestOptions(
                path: '/lobbies/ABC123/play-again/',
              ),
              statusCode: 403,
            ),
            type: DioExceptionType.badResponse,
          ),
        );

        await expectLater(
          () => service.playAgain('ABC123'),
          throwsA(isA<ForbiddenException>()),
        );
      });
    });

    group('activeGameIdAt', () {
      Future<String?> lookUp(Map<String, dynamic> body) {
        when(
          () => mockClient.get<Map<String, dynamic>>('/onuw/me/current-game/'),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/onuw/me/current-game/'),
            data: body,
          ),
        );
        return service.activeGameIdAt('ABC123');
      }

      test('returns the game running at this table', () async {
        expect(
          await lookUp({
            'game_id': 'g2',
            'phase': 'night',
            'lobby_code': 'ABC123',
          }),
          'g2',
        );
      });

      test('is null for another table or no game', () async {
        expect(await lookUp({'game_id': 'g2', 'lobby_code': 'OTHER1'}), isNull);
        expect(await lookUp({'game': null}), isNull);
      });
    });

    group('fetchLobby', () {
      test('sends GET to /lobbies/<code>/ and returns LobbyState', () async {
        when(
          () => mockClient.get<Map<String, dynamic>>('/lobbies/ABC123/'),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/lobbies/ABC123/'),
            data: _lobbyResponseJson(),
          ),
        );

        final lobby = await service.fetchLobby('ABC123');

        expect(lobby.code, 'ABC123');
        expect(lobby.hostId, 1);
        expect(lobby.players, hasLength(1));
        verify(
          () => mockClient.get<Map<String, dynamic>>('/lobbies/ABC123/'),
        ).called(1);
      });

      test('throws MalformedResponseException when response is null', () async {
        when(
          () => mockClient.get<Map<String, dynamic>>('/lobbies/ABC123/'),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/lobbies/ABC123/'),
            data: null,
          ),
        );

        await expectLater(
          () => service.fetchLobby('ABC123'),
          throwsA(isA<MalformedResponseException>()),
        );
      });

      test('maps DioException 404 to NotFoundException', () async {
        when(
          () => mockClient.get<Map<String, dynamic>>('/lobbies/NOPE/'),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/lobbies/NOPE/'),
            response: Response(
              requestOptions: RequestOptions(path: '/lobbies/NOPE/'),
              statusCode: 404,
            ),
            type: DioExceptionType.badResponse,
          ),
        );

        await expectLater(
          () => service.fetchLobby('NOPE'),
          throwsA(isA<NotFoundException>()),
        );
      });
    });
  });
}
