import 'package:midnight_village/core/host/host_change.dart';
import 'package:midnight_village/features/game/domain/game_session_state.dart';
import 'package:midnight_village/features/game/domain/night_state.dart';
import 'package:midnight_village/features/lobby/domain/lobby_state.dart';

import 'contract_shape.dart';

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

  /// A `host_changed` event (`GameEvents.hostChanged`, a map or its JSON).
  static HostChange hostChange(Object event) {
    checkSocketEvent(event);
    final decoded = ContractShape.plain(event) as Map;
    return HostChange.fromEvent(decoded.cast<String, dynamic>());
  }
}
