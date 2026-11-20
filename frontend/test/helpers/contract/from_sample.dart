import 'package:midnight_village/core/host/host_change.dart';
import 'package:midnight_village/features/game/domain/game_event.dart';
import 'package:midnight_village/features/game/domain/game_me.dart';
import 'package:midnight_village/features/game/domain/stage_progress.dart';
import 'package:midnight_village/features/lobby/domain/where_am_i.dart';
import 'package:midnight_village/features/lobby/domain/lobby_state.dart';

import 'contract_samples.dart';
import 'contract_shape.dart';
import 'server_json.dart' show withValues;

/// The app's server-backed domain objects for a test, parsed from a server
/// payload exactly as the app parses it, after checking the payload against
/// the samples. A test never builds one by constructor with values it made
/// up (`fixture_sources_test.dart` scans `test/` for that); it builds the
/// payload (a recorded sample, `serverLobby`, `serverResults`, ...) and
/// parses it here. Client-only state is then set with `copyWith`.
abstract final class FromSample {
  /// `GET /onuw/games/<id>/me/`, as `GameService.fetchMe` parses it.
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

  /// A game socket event (a recorded one, or built from one), as the phone
  /// reads it.
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

  /// A `host_changed` event (`GameEvents.hostChanged`, a map or its JSON).
  static HostChange hostChange(Object event) {
    checkSocketEvent(event);
    final decoded = ContractShape.plain(event) as Map;
    return HostChange.fromEvent(decoded.cast<String, dynamic>());
  }
}
