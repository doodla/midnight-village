import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/faces/face_content.dart';
import 'package:midnight_village/design_system/faces/night_report.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/night/choose_prompt.dart';
import 'package:midnight_village/design_system/night/night_pick.dart';

import '../contract/contract_samples.dart';

// The games the component sheet's pages show, as the server recorded them
// (contract_samples/http/game/, night protocol 2). Every night input (the
// table, a phone's prompt, its faces, what it tapped) is read from those
// payloads, never written here (night_fixture_sources_test.dart checks).
//
// Game 7, five at the table: Ana the Seer (the host) looks at Cleo's card;
// Ben the Robber takes Ana's; Cleo, the lone Werewolf, looks at Left; Dev
// is the Troublemaker; Esme a Villager. Game 8, nine at the table, has the
// Doppelganger, the Drunk and the night's other roles.

/// A recorded `/me/` (`contract_samples/http/game/<name>.json`).
Map<String, dynamic> recordedMe(String name) =>
    ContractSamples.map('http/game/$name');

/// The phone a recorded prompt was sent to: the one seat its prompt does not
/// offer (every prompt offers every other player).
int selfIn(Map<String, dynamic> me) {
  final prompt = me['action_prompt'] as Map<String, dynamic>;
  final offered = ((prompt['valid_targets'] as Map)['player_ids'] as List)
      .cast<int>();
  return NightSeat.seatsOf(
    me,
  ).map((s) => s.id).firstWhere((id) => !offered.contains(id));
}

/// Game 7's table, in seat order.
final fiveSeats = NightSeat.seatsOf(recordedMe('me_choose_prompt_seer'));
final ana = fiveSeats[0];
final ben = fiveSeats[1];
final cleo = fiveSeats[2];
final dev = fiveSeats[3];
final esme = fiveSeats[4];

/// Game 8's table: the largest recorded.
final nineSeats = NightSeat.seatsOf(recordedMe('me_choose_prompt_drunk'));

/// Game 7's deck, as the strips and the builder count it.
final deckCounts = deckOf(recordedMe('me_choose_prompt_seer'));

/// A `/me/`'s `roles_in_game`.
Map<RoleId, int> deckOf(Map<String, dynamic> me) => {
  for (final entry in (me['roles_in_game'] as List).cast<Map>())
    serverRole(entry['role']): entry['count'] as int,
};

/// The deck builder's order (S03).
const deckOrder = [
  RoleId.werewolf,
  RoleId.minion,
  RoleId.mason,
  RoleId.seer,
  RoleId.robber,
  RoleId.troublemaker,
  RoleId.drunk,
  RoleId.insomniac,
  RoleId.hunter,
  RoleId.tanner,
  RoleId.doppelganger,
  RoleId.villager,
];

/// One phone of a recorded game: its `/me/` at the night board and, when
/// recorded, at the talk.
enum Viewer {
  seer('me_choose_prompt_seer', 'me_discussion_choose_seer'),
  robber('me_choose_prompt_robber', 'me_discussion_choose_robber'),
  villager('me_choose_prompt_villager', 'me_discussion_choose_villager'),
  loneWerewolf(
    'me_choose_prompt_werewolf_lone',
    'me_discussion_choose_werewolf_lone',
  ),
  troublemaker('me_choose_prompt_troublemaker', null),
  drunk('me_choose_prompt_drunk', 'me_discussion_choose_drunk'),
  doppelganger(
    'me_choose_prompt_doppelganger_look',
    'me_discussion_choose_doppelganger',
  ),
  doppelgangerFollowUp('me_choose_doppelganger_followup', null),
  windowOneSleeper('me_choose_prompt_window1_sleeper', null);

  const Viewer(this._night, this._talk);

  final String _night;
  final String? _talk;

  /// Its `/me/` at the board.
  Map<String, dynamic> get nightMe => recordedMe(_night);
  Map<String, dynamic> get talkMe => recordedMe(_talk!);

  ChoosePrompt get prompt => ChoosePrompt.fromMe(nightMe);
  List<NightSeat> get seats => NightSeat.seatsOf(nightMe);
  int get selfId => selfIn(nightMe);
  Map<RoleId, int> get deck => deckOf(nightMe);

  FaceContent get card => NightReport.fromMe(nightMe).card;
  FaceContent get you => NightReport.fromMe(nightMe).you(prompt);
  FaceContent get myNight => NightReport.fromMe(talkMe).myNight;

  /// The cards this phone tapped in the recorded game, read from what its
  /// night told it (the player it looked at or robbed, the center card it
  /// looked at or took); "You" when it was told nothing.
  List<String> get taps {
    final results = (talkMe['night_results'] as List).cast<Map>();
    if (results.isEmpty) return const [NightCopy.you];
    final info = results.last['revealed_info'] as Map;
    if (info.containsKey('roles')) {
      throw StateError(
        "A center look's result names the roles, not the cards: the server "
        'does not record which two this phone tapped.',
      );
    }
    return [
      if (info['target_name'] case final String name) name,
      if (info['card_index'] case final int index) centerName(index),
      if (info['center_card'] case {'index': final int index})
        centerName(index),
    ];
  }
}
