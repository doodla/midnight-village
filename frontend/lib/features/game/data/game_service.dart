import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/authenticated_client.dart';
import '../../../core/logging/app_logger.dart';
import '../../../features/auth/presentation/auth_notifier.dart';
import '../domain/game_me.dart';
import '../domain/game_outcome.dart';
import 'stage_requests.dart';

export 'stage_requests.dart';

part 'game_service.g.dart';

/// HTTP service for the game's requests (every
/// stage-scoped request echoes `/me/`'s `stage`).
///
/// Uses [AuthenticatedClient] for JWT-authenticated requests.
class GameService {
  GameService({required AuthenticatedClient client}) : _client = client;

  final AuthenticatedClient _client;

  /// Fetches full game results.
  ///
  /// `GET /onuw/games/{id}/results/`
  /// Returns the raw results map for the caller to parse.
  Future<Map<String, dynamic>> fetchResults(String gameId) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/onuw/games/$gameId/results/',
      );
      return response.data!;
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  // Every stage-scoped request answers a [StageReply]: a 409 is "fetch /me/
  // again", never an error.

  /// `GET /onuw/games/{id}/me/`.
  Future<GameMe> fetchMe(String gameId) async =>
      (await fetchMeTimed(gameId)).me;

  /// [fetchMe] with the server's clock at the answer (its `Date` header),
  /// when the response lets the app read it.
  Future<FetchedMe> fetchMeTimed(String gameId) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/onuw/games/$gameId/me/',
      );
      return FetchedMe(
        GameMe.fromJson(response.data!),
        serverDate: parseHttpDate(response.headers.value('date')),
      );
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// `GET /onuw/games/{id}/results/`, parsed.
  Future<GameOutcome> fetchOutcome(String gameId) async =>
      GameOutcome.fromJson(await fetchResults(gameId));

  /// Sends [request] (choose, ready, vote or the results ack) as it is.
  Future<StageReply> send(String gameId, StageRequest request) =>
      _stage(switch (request) {
        ChooseRequest() => '/onuw/games/$gameId/action/',
        ReadyRequest() => '/onuw/games/$gameId/ready/',
        VoteRequest() => '/onuw/games/$gameId/vote/',
        AckRequest() => '/onuw/games/$gameId/night-results/seen/',
      }, request.toJson());

  Future<StageReply> _stage(String path, Map<String, Object> body) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        path,
        data: body,
      );
      return StageReply(StageAnswer.taken, response.data);
    } on DioException catch (e) {
      final answer = stageAnswerOf(e);
      logger.d(
        'GameService: $path answered ${e.response?.statusCode} '
        '(${answer.name})',
      );
      return StageReply(answer);
    }
  }

  // The host's stage requests. The contract keeps them
  // (each names its stage); the screens have no button for them
  // (first-time play spec: the look, the talk and the vote never wait on the
  // host), so nothing in the app calls them. Delete them if the contract
  // drops them.

  /// Host: open the night now (look) or close the window now, for [stage].
  Future<StageAnswer> advanceStage(String gameId, {required String stage}) =>
      _hostStage('/onuw/games/$gameId/advance-wave/', stage);

  /// Host: end the talk now, for [stage].
  Future<StageAnswer> endTalk(String gameId, {required String stage}) =>
      _hostStage('/onuw/games/$gameId/end-discussion/', stage);

  /// Host: reveal the votes now, for [stage].
  Future<StageAnswer> revealVotesAt(String gameId, {required String stage}) =>
      _hostStage('/onuw/games/$gameId/reveal-votes/', stage);

  Future<StageAnswer> _hostStage(String path, String stage) async =>
      (await _stage(path, {'stage': stage})).answer;
}

/// A `/me/` and the server's clock when it answered (null: not readable,
/// e.g. a browser that is not shown the `Date` header).
@immutable
class FetchedMe {
  const FetchedMe(this.me, {this.serverDate});

  final GameMe me;
  final DateTime? serverDate;
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

final _httpDate = RegExp(
  r'^\w{3}, (\d{2}) (\w{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2}) GMT$',
);

/// An HTTP date (`Thu, 07 Mar 2024 21:13:00 GMT`, RFC 9110), or null when
/// there is none or it cannot be read.
DateTime? parseHttpDate(String? value) {
  final match = _httpDate.firstMatch(value?.trim() ?? '');
  if (match == null) return null;
  final month = _months.indexOf(match.group(2)!);
  if (month < 0) return null;
  int part(int i) => int.parse(match.group(i)!);
  return DateTime.utc(part(3), month + 1, part(1), part(4), part(5), part(6));
}

/// Provides the game service with an authenticated client.
@riverpod
GameService gameService(Ref ref) {
  return GameService(client: ref.watch(authenticatedClientProvider));
}
