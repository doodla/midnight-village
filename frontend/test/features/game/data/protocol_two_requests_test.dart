import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/api/api_client.dart';
import 'package:midnight_village/core/api/authenticated_client.dart';
import 'package:midnight_village/design_system/night/night_pick.dart';
import 'package:midnight_village/features/game/data/game_service.dart';
import 'package:midnight_village/features/game/domain/game_me.dart';
import 'package:midnight_village/features/lobby/data/home_service.dart';
import 'package:midnight_village/features/lobby/data/lobby_service.dart';
import 'package:midnight_village/features/lobby/domain/lobby_state.dart';

import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/contract/from_sample.dart';
import '../../../helpers/mock_http_client.dart';
import '../../../helpers/sheet/sheet_data.dart' show recordedMe;

const _game = '/onuw/games/g7';

void main() {
  late MockHttpClient http;
  late GameService service;

  setUp(() {
    http = MockHttpClient();
    service = GameService(
      client: AuthenticatedClient.forTesting(dio: http.dio),
    );
  });

  void answer(String endpoint, String sample, {int status = 200}) =>
      http.answer(
        'POST',
        '$_game$endpoint',
        ContractSamples.load('http/$sample'),
        status: status,
      );

  dynamic sent() => http.requests.last.data;

  group('choose', () {
    final seer = FromSample.gameMe(recordedMe('me_choose_prompt_seer'));
    final picks = [const CenterPick(0), const CenterPick(2)];

    test('sends the picks in tap order and echoes the stage', () async {
      answer('/action/', 'game/choose_submitted_seer');
      final reply = await service.send(
        'g7',
        ChooseRequest.of(seer.prompt!, picks),
      );
      expect(reply.answer, ChooseAnswer.taken);
      expect(sent(), {
        'action_type': 'choose',
        'picks': [
          {'center_index': 0},
          {'center_index': 2},
        ],
        'stage': seer.stage,
      });
    });

    test('carries the prompt\'s chosen count, not sent yet', () {
      final followUp = FromSample.gameMe(
        recordedMe('me_choose_doppelganger_followup'),
      ).prompt!;
      final request = ChooseRequest.of(followUp, const [SelfPick()]);
      expect(request.chosen, 1);
      expect(request.toJson().containsKey('chosen'), isFalse);
      expect(request.toJson()['picks'], [
        {'self': true},
      ]);
    });

    test('never sends more picks than the prompt takes', () {
      expect(
        () => ChooseRequest.of(seer.prompt!, [
          const CenterPick(0),
          const CenterPick(1),
          const CenterPick(2),
        ]),
        throwsArgumentError,
      );
    });

    for (final (sample, status, expected) in [
      ('game/choose_wrong_stage', 409, ChooseAnswer.stale),
      ('game/choose_already_chosen', 409, ChooseAnswer.stale),
      ('game/choose_window1_third_refused', 409, ChooseAnswer.stale),
      ('game/choose_bad_request', 400, ChooseAnswer.refused),
      ('game/choose_stage_missing', 400, ChooseAnswer.refused),
    ]) {
      test('$sample ($status) is ${expected.name}, never an error', () async {
        answer('/action/', sample, status: status);
        expect(
          (await service.send(
            'g7',
            ChooseRequest.of(seer.prompt!, picks),
          )).answer,
          expected,
        );
      });
    }

    test('no readable answer (a 5xx) is notSent', () async {
      http.answer('POST', '$_game/action/', 'Bad Gateway', status: 502);
      expect(
        (await service.send(
          'g7',
          ChooseRequest.of(seer.prompt!, picks),
        )).answer,
        ChooseAnswer.notSent,
      );
    });

    test('no answer at all is notSent', () {
      final lost = DioException.connectionError(
        requestOptions: RequestOptions(path: '$_game/action/'),
        reason: 'offline',
      );
      expect(stageAnswerOf(lost), ChooseAnswer.notSent);
    });
  });

  group('ready, vote, acknowledge', () {
    test('ready echoes the stage', () async {
      final look = FromSample.gameMe(recordedMe('me_look_stage'));
      answer('/ready/', 'game/ready_look');
      final reply = await service.send(
        'g7',
        ReadyRequest(look.stage!, ready: true),
      );
      expect(reply.answer, ChooseAnswer.taken);
      expect(reply.body!['ready'], isTrue, reason: 'the server echoes it');
      expect(sent(), {'ready': true, 'stage': look.stage});
    });

    test('a ready for a stage that is over is stale', () async {
      answer('/ready/', 'game/ready_wrong_stage', status: 409);
      expect(
        (await service.send(
          'g7',
          const ReadyRequest('look.x', ready: true),
        )).answer,
        ChooseAnswer.stale,
      );
    });

    test('a pick and a lock both carry the target and the stage', () async {
      final vote = FromSample.gameMe(recordedMe('me_voting_picked'));
      answer('/vote/', 'game/vote_picked');
      final picked = await service.send(
        'g7',
        VoteRequest(vote.stage!, targetId: 29, lock: false),
      );
      expect(picked.body!['target_player_id'], 29, reason: 'echoed');
      expect(sent(), {
        'target_player_id': 29,
        'lock': false,
        'stage': vote.stage,
      });
      answer('/vote/', 'game/vote_locked_v2');
      await service.send(
        'g7',
        VoteRequest(vote.stage!, targetId: 29, lock: true),
      );
      expect(sent(), {
        'target_player_id': 29,
        'lock': true,
        'stage': vote.stage,
      });
    });

    for (final (sample, status, expected) in [
      ('game/vote_after_reveal', 409, ChooseAnswer.stale),
      ('game/vote_already_locked', 409, ChooseAnswer.stale),
      ('game/vote_self_v2', 400, ChooseAnswer.refused),
    ]) {
      test('vote: $sample is ${expected.name}', () async {
        answer('/vote/', sample, status: status);
        expect(
          (await service.send(
            'g7',
            const VoteRequest('vote.x', targetId: 1, lock: true),
          )).answer,
          expected,
        );
      });
    }

    test('night results acknowledged as a count', () async {
      answer('/night-results/seen/', 'game/night_results_seen');
      final reply = await service.send('g7', const AckRequest(1));
      expect(reply.body!['night_results_seen'], 1);
      expect(sent(), {'seen': 1});
    });
  });

  group("the host's stage requests echo the stage", () {
    for (final (endpoint, sample, call) in [
      (
        '/advance-wave/',
        'game/advance_wave',
        (GameService s) => s.advanceStage('g7', stage: 'w2.x'),
      ),
      (
        '/end-discussion/',
        'game/end_discussion',
        (GameService s) => s.endTalk('g7', stage: 'w2.x'),
      ),
      (
        '/reveal-votes/',
        'game/reveal_votes',
        (GameService s) => s.revealVotesAt('g7', stage: 'w2.x'),
      ),
    ]) {
      test(endpoint, () async {
        answer(endpoint, sample);
        expect(await call(service), ChooseAnswer.taken);
        expect(sent(), {'stage': 'w2.x'});
      });
    }
  });

  test('the server clock is read from the Date header', () {
    expect(
      parseHttpDate('Thu, 07 Mar 2024 21:13:05 GMT'),
      DateTime.utc(2024, 3, 7, 21, 13, 5),
    );
    expect(parseHttpDate(null), isNull);
    expect(parseHttpDate('yesterday'), isNull);
  });

  test('fetchMe reads a protocol-2 /me/', () async {
    http.answer('GET', '$_game/me/', recordedMe('me_look_stage'));
    final me = await service.fetchMe('g7');
    expect(me.phase, GamePhase.night);
    expect(me.inLook, isTrue);
  });

  group('the table', () {
    late LobbyService lobby;
    setUp(() {
      lobby = LobbyService(
        client: AuthenticatedClient.forTesting(dio: http.dio),
      );
    });

    test('a table for the new screens asks for the v2 defaults', () async {
      http.answer(
        'POST',
        '/lobbies/',
        ContractSamples.load('http/lobby/created_with_defaults'),
        status: 201,
      );
      final table = await lobby.createTable();
      expect(sent(), {'game_type': 'onuw', 'defaults': 'v2'});
      expect(table.table.isProtocolTwo, isTrue);
    });

    test('a deck chip puts the deck back to automatic', () async {
      http.answer(
        'PATCH',
        '/lobbies/R5ZD3H/',
        ContractSamples.load('http/lobby/settings_deck_chip'),
      );
      final table = await lobby.setDeckChip('R5ZD3H', DeckChip.simple);
      expect(sent(), {
        'settings': {'deck': 'auto', 'deck_chip': 'simple'},
      });
      expect(table.table.autoDeck, isTrue);
    });

    test('editing the cards makes the deck custom', () async {
      http.answer(
        'PATCH',
        '/lobbies/K7QX4M/',
        ContractSamples.load('http/lobby/settings_updated'),
      );
      await lobby.setCustomDeck('K7QX4M', {'Werewolf': 2, 'Seer': 1});
      expect(sent(), {
        'settings': {
          'deck': 'custom',
          'roles': {'Werewolf': 2, 'Seer': 1},
        },
      });
    });

    test('where am I, and recent games', () async {
      http.answer(
        'GET',
        '/me/table/',
        ContractSamples.load('http/lobby/my_table_night'),
      );
      expect((await lobby.fetchMyTable())!.gameId, isNotNull);
      http.answer(
        'GET',
        '/me/table/',
        ContractSamples.load('http/lobby/my_table_none'),
      );
      expect(await lobby.fetchMyTable(), isNull);
      http.answer(
        'GET',
        '/onuw/me/recent-games/',
        ContractSamples.load('http/game/recent_games'),
      );
      expect(await lobby.fetchRecentGames(), hasLength(1));
    });

    test('players at tables, asked without logging in', () async {
      http.answer(
        'GET',
        '/stats/online/',
        ContractSamples.load('http/core/online_stats'),
      );
      final home = HomeService(client: ApiClient(dio: http.dio));
      expect((await home.fetchOnline()).players, 6);
      expect(http.requests.last.headers.containsKey('Authorization'), isFalse);
    });
  });
}
