import 'package:midnight_village/features/game/domain/screen_table.dart';

import 'contract_samples.dart';

/// The screen each recorded `/me/` is, stated per sample (the
/// first-time play spec, section 3, as amended by sections 7 and 8), at its
/// own game's table with no local step taken. A recorded sample missing here
/// fails `screen_table_test.dart`.
const meScreens = <String, AppScreen>{
  'me_auto_deck_5': AppScreen.yourCard,
  'me_auto_deck_9': AppScreen.yourCard,
  'me_look_stage': AppScreen.yourCard,
  'me_look_ready': AppScreen.yourCard,
  'me_choose_prompt_doppelganger_look': AppScreen.nightBoard,
  'me_choose_doppelganger_followup': AppScreen.nightBoard,
  'me_choose_prompt_window1_sleeper': AppScreen.nightBoard,
  'me_choose_prompt_drunk': AppScreen.nightBoard,
  'me_choose_prompt_insomniac': AppScreen.nightBoard,
  'me_choose_prompt_mason': AppScreen.nightBoard,
  'me_choose_prompt_minion': AppScreen.nightBoard,
  'me_choose_prompt_robber': AppScreen.nightBoard,
  'me_choose_prompt_seer': AppScreen.nightBoard,
  'me_choose_prompt_troublemaker': AppScreen.nightBoard,
  'me_choose_prompt_villager': AppScreen.nightBoard,
  'me_choose_prompt_werewolf_lone': AppScreen.nightBoard,
  'me_choose_prompt_werewolf_pack': AppScreen.nightBoard,
  'me_choose_chosen': AppScreen.nightBoard,
  'me_choose_doppelganger_minion_followup': AppScreen.nightBoard,
  'me_discussion_choose_doppelganger': AppScreen.talk,
  'me_discussion_choose_doppelganger_minion': AppScreen.talk,
  'me_discussion_choose_drunk': AppScreen.talk,
  'me_discussion_choose_insomniac': AppScreen.talk,
  'me_discussion_choose_mason': AppScreen.talk,
  'me_discussion_choose_minion': AppScreen.talk,
  'me_discussion_choose_robber': AppScreen.talk,
  'me_discussion_choose_seer': AppScreen.talk,
  'me_discussion_choose_seer_nothing_chosen': AppScreen.talk,
  'me_discussion_choose_villager': AppScreen.talk,
  'me_discussion_choose_werewolf_lone': AppScreen.talk,
  'me_discussion_choose_werewolf_pack': AppScreen.talk,
  'me_talk_ready': AppScreen.talk,
  'me_talk_results_seen': AppScreen.talk,
  'me_talk_ten': AppScreen.talk,
  'me_talk_untimed': AppScreen.talk,
  'me_discussion_acting_host': AppScreen.talk,
  'me_voting_unpicked': AppScreen.vote,
  'me_voting_picked': AppScreen.vote,
  'me_voting_locked': AppScreen.vote,
  'me_voting_ten': AppScreen.vote,
  'me_voting_untimed': AppScreen.vote,
  'me_results': AppScreen.count,
};

/// Every recorded `/me/` sample, by its name under `http/game/`.
List<String> meSamples() => [
  for (final s in ContractSamples.index)
    if (s.isHttp && s.status == 200 && s.matchesPath('/onuw/games/g/me/'))
      s.name.substring('http/game/'.length),
];

/// Every recorded lobby body (a lobby answer, or `lobby_update`'s data),
/// with its sample's name.
List<(String, Map<String, dynamic>)> lobbyBodies() => [
  for (final s in ContractSamples.index)
    if (s.isHttp &&
        s.name.startsWith('http/lobby/') &&
        (s.status == 200 || s.status == 201) &&
        ContractSamples.map(s.name).containsKey('code'))
      (s.name, ContractSamples.map(s.name)),
  (
    'ws/lobby/lobby_update',
    (ContractSamples.map('ws/lobby/lobby_update')['data'] as Map)
        .cast<String, dynamic>(),
  ),
];
