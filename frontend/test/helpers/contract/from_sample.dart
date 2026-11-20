import 'package:midnight_village/core/host/host_change.dart';
import 'package:midnight_village/features/game/domain/game_event.dart';
import 'package:midnight_village/features/game/domain/game_me.dart';
import 'package:midnight_village/features/game/domain/stage_progress.dart';
import 'package:midnight_village/features/game/domain/game_session_state.dart';
import 'package:midnight_village/features/lobby/domain/where_am_i.dart';
import 'package:midnight_village/features/game/domain/night_state.dart';
import 'package:midnight_village/features/game/domain/voting_state.dart';
import 'package:midnight_village/features/lobby/domain/lobby_state.dart';

import 'contract_samples.dart';
import 'contract_shape.dart';
import 'server_json.dart' show withValues;

/// The app's server-backed domain objects for a test, parsed from a server
/// payload exactly as the app parses it, after checking the payload against
/// the samples. A test never builds one by constructor with values it made
/// up (`contract_guard_test.dart` scans `test/` for that); it builds the
/// payload (`GameMeJsonBuilder`, `serverLobby`, `serverPrompt`, ... or a
/// sample) and parses it here. Client-only state (which view is on screen,
/// what was shown) is then set with `copyWith`.
abstract final class FromSample {
  /// `GET /onuw/games/<id>/me/`, as `GameService` parses it.
  static GameSessionState game(Map<String, dynamic> me) {
    checkHttpBody('GET', '/onuw/games/${me['game_id']}/me/', 200, me);
    return gameStateFromServer(me);
  }

  /// `GET /onuw/games/<id>/me/` of a night protocol 2 game, as
  /// `GameService.fetchMe` parses it.
  static GameMe gameMe(Map<String, dynamic> me) {
    checkHttpBody('GET', '/onuw/games/${me['game_id']}/me/', 200, me);
    return GameMe.fromJson(me);
  }

  /// Counts for [stage] (`look`, `talk`, `vote`), as the `progress` event and
  /// `/me/` carry them, built from the recorded event.
  static StageProgress progress(
    String stage, {
    required int done,
    required int needed,
  }) {
    final event = withValues(ContractSamples.map('ws/game/progress_$stage'), {
      'done': done,
      'needed': needed,
    });
    checkSocketEvent(event);
    return StageProgress.fromJson(event);
  }

  /// A game socket event (a recorded one, or built from one), as a
  /// protocol-2 phone reads it.
  static GameEvent event(Object event) {
    checkSocketEvent(event);
    return GameEvent.parse(ContractShape.plain(event));
  }

  /// `GET /me/table/` (null: at no table).
  static MyTable? myTable(Map<String, dynamic> body) {
    checkHttpBody('GET', '/me/table/', 200, body);
    return MyTable.parse(body);
  }

  /// A lobby body (`GET /lobbies/<code>/` and the other lobby answers).
  static LobbyState lobby(Map<String, dynamic> body) {
    checkHttpBody('GET', '/lobbies/${body['code']}/', 200, body);
    return LobbyState.fromJson(body);
  }

  /// A prompt as `/me/` and the `action_prompt` event carry it
  /// (`serverPrompt`).
  static ActionPrompt prompt(Map<String, dynamic> prompt) {
    checkSocketEvent({'type': 'action_prompt', ...prompt});
    return ActionPrompt.fromJson(prompt);
  }

  /// A night result as `/me/`'s `night_results` and the `action_result` event
  /// carry it (`serverNightResult`).
  static ActionResult result(Map<String, dynamic> result) {
    checkSocketEvent({'type': 'action_result', ...result});
    return actionResultFromServer(result);
  }

  /// A `vote_reveal` event (`GameEvents.voteReveal`, a map or its JSON).
  static VoteRevealData voteReveal(Object event) {
    checkSocketEvent(event);
    final decoded = ContractShape.plain(event) as Map;
    return VoteRevealData.fromEvent(decoded.cast<String, dynamic>());
  }

  /// A `host_changed` event (`GameEvents.hostChanged`, a map or its JSON).
  static HostChange hostChange(Object event) {
    checkSocketEvent(event);
    final decoded = ContractShape.plain(event) as Map;
    return HostChange.fromEvent(decoded.cast<String, dynamic>());
  }
}
