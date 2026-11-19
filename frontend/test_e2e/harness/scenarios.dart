import 'scenario_dsl.dart';

/// Every reference game (23 full games + 6 night-only Doppelganger games), read
/// from `backend/tests/onuw/data/reference_games.json`. The API runner replays
/// ALL of them.
final List<ReferenceGame> allScenarios = ReferenceGame.loadAll()
    .map(
      (g) => uiCriticalIds.contains(g.id)
          ? g.withTags({ScenarioTag.uiCritical})
          : g,
    )
    .toList();

/// The representative subset the UI runner also plays through the real widget
/// tree (each needs a real WebSocket and PNG filmstrips, so it is slower):
///
/// - `1`  baseline: lone Werewolf peek, Seer, Robber; Village wins
/// - `4`  the Doppelganger copies the Robber: look result, then the follow-up
///        prompt in the SAME window; the dealt-card team rule
/// - `5`  Hunter chain + Tanner block (the full results screen)
/// - `8`  the Drunk and the Insomniac: results in window 2 arrive together and
///        the Insomniac's is the changed card
/// - `21` nobody acts: Seer/Robber/Troublemaker "do nothing" (`skip`); the
///        Drunk is in the center, since a Drunk at the table must swap
const Set<String> uiCriticalIds = {'1', '4', '5', '8', '21'};
