import 'sheet_data.dart';

// Every night My night's picture story tells (08, held), each a talk `/me/`.
// Most are recorded (contract_samples/http/game/me_discussion_choose_*, the
// talk of game 7, five at the table, and game 8, nine with the
// Doppelganger). The rest no recorded game has: a recorded `/me/` with its
// dealt card and its night record edited, OFF THE CONTRACT and named so
// (`offContractMe`), each record built from entries of recorded ones where
// a recording has one. They stay until a game records them.

/// The recorded talk [name] changed by [edit] into a night no recorded game
/// has: off the contract, and the caller says so ([offContract] must be
/// true).
Map<String, dynamic> offContractMe(
  String name, {
  required bool offContract,
  required void Function(Map<String, dynamic> me) edit,
}) {
  if (!offContract) {
    throw ArgumentError('an edited night is off the contract: say so');
  }
  final me = recordedMe(name);
  edit(me);
  return me;
}

/// The [i]th night record entry of the recorded `/me/` [name].
Map<String, dynamic> _entry(String name, int i) =>
    ((recordedMe(name)['night_results'] as List)[i] as Map)
        .cast<String, dynamic>();

/// A night entry of window [wave], of [type], with [info].
Map<String, dynamic> _night(int wave, String type, Map<String, Object> info) =>
    {'wave': wave, 'action_type': type, 'revealed_info': info};

/// Game 7's talk (five at the table), [dealt] dealt, its night [results].
Map<String, dynamic> _game7(String dealt, List<Map<String, dynamic>> results) =>
    offContractMe(
      'me_discussion_choose_villager',
      offContract: true,
      edit: (me) => me
        ..['your_role'] = {'original_role': dealt}
        ..['night_results'] = results,
    );

/// Game 8's talk (nine, the Doppelganger in the deck), [dealt] dealt, its
/// night [results].
Map<String, dynamic> _game8(String dealt, List<Map<String, dynamic>> results) =>
    offContractMe(
      'me_discussion_choose_insomniac',
      offContract: true,
      edit: (me) => me
        ..['your_role'] = {'original_role': dealt}
        ..['night_results'] = results,
    );

/// The Doppelganger's look at [name]'s [role] (game 8's recorded look,
/// another card).
Map<String, dynamic> _copy(String name, String role) => _entry(
  'me_discussion_choose_doppelganger',
  0,
)..['revealed_info'] = {'target_name': name, 'role': role, 'copied_role': role};

/// Recorded: a name, the talk `/me/` that tells it.
final recordedNights = <String, Map<String, dynamic> Function()>{
  'seer': () => recordedMe('me_discussion_choose_seer'),
  'seer-skipped': () => recordedMe('me_discussion_choose_seer_nothing_chosen'),
  'robber': () => recordedMe('me_discussion_choose_robber'),
  'werewolf-pair': () => recordedMe('me_discussion_choose_werewolf_pack'),
  'werewolf-lone-looked': () =>
      recordedMe('me_discussion_choose_werewolf_lone'),
  'werewolf-lone': () => recordedMe('me_talk_untimed'),
  'minion': () => recordedMe('me_discussion_choose_minion'),
  'mason': () => recordedMe('me_discussion_choose_mason'),
  'drunk': () => recordedMe('me_discussion_choose_drunk'),
  'insomniac-same': () => recordedMe('me_discussion_choose_insomniac'),
  'villager': () => recordedMe('me_discussion_choose_villager'),
  'doppelganger-seer': () => recordedMe('me_discussion_choose_doppelganger'),
  'doppelganger-minion': () =>
      recordedMe('me_discussion_choose_doppelganger_minion'),
};

/// Off the contract: the nights no recorded game has.
final editedNights = <String, Map<String, dynamic> Function()>{
  'troublemaker': () => _game7('Troublemaker', [
    _night(2, 'swap_others', {'player1_name': 'Ana', 'player2_name': 'Ben'}),
  ]),
  'seer-centre': () => _game7('Seer', [
    _entry('me_discussion_choose_doppelganger', 1)..['wave'] = 2,
  ]),
  'seer-timed-out': () => _game7('Seer', []),
  'insomniac-changed': () => _game8('Insomniac', [
    _entry('me_discussion_choose_insomniac', 0)
      ..['revealed_info'] = {'current_role': 'Seer'},
  ]),
  'minion-none': () => _game8('Minion', [
    _entry('me_discussion_choose_minion', 0)
      ..['revealed_info'] = {'teammate_names': [], 'role_acting_as': 'Minion'},
  ]),
  'mason-alone': () => _game8('Mason', [
    _entry('me_discussion_choose_mason', 0)
      ..['revealed_info'] = {'teammate_names': [], 'role_acting_as': 'Mason'},
  ]),
  'hunter': () => _game8('Hunter', []),
  'tanner': () => _game8('Tanner', []),
  'doppelganger-troublemaker': () => _game8('Doppelganger', [
    _copy('Gus', 'Troublemaker'),
    _night(1, 'swap_others', {'player1_name': 'Ben', 'player2_name': 'Cleo'}),
  ]),
  'doppelganger-robber': () => _game8('Doppelganger', [
    _copy('Gus', 'Robber'),
    _entry('me_discussion_choose_robber', 0)..['wave'] = 1,
  ]),
  'doppelganger-drunk': () => _game8('Doppelganger', [
    _copy('Gus', 'Drunk'),
    _entry('me_discussion_choose_drunk', 0)..['wave'] = 1,
  ]),
  'doppelganger-werewolf': () => _game8('Doppelganger', [
    _copy('Ida', 'Werewolf'),
    _entry('me_discussion_choose_werewolf_pack', 0),
  ]),
  'doppelganger-insomniac': () => _game8('Doppelganger', [
    _copy('Hana', 'Insomniac'),
    _entry('me_discussion_choose_insomniac', 0)
      ..['revealed_info'] = {'current_role': 'Doppelganger'},
  ]),
  'doppelganger-villager': () =>
      _game8('Doppelganger', [_copy('Fin', 'Villager')]),
  'doppelganger-nothing': () => _game8('Doppelganger', [
    _entry('me_discussion_choose_seer_nothing_chosen', 0)..['wave'] = 1,
  ]),
};

/// The fourteen stories of the mock (round 3), by its frame's name, as the
/// nights above tell them.
const mockFrames = {
  'S01-troublemaker': 'troublemaker',
  'S02-swapped-seer': 'seer',
  'S03-robber': 'robber',
  'S04-seer-one': 'seer',
  'S05-seer-centre': 'seer-centre',
  'S06-werewolf-pair': 'werewolf-pair',
  'S07-werewolf-alone': 'werewolf-lone-looked',
  'S08-minion': 'minion',
  'S09-mason': 'mason',
  'S10-drunk': 'drunk',
  'S11-insomniac-changed': 'insomniac-changed',
  'S12-insomniac-same': 'insomniac-same',
  'S13-villager': 'villager',
  'S14-doppelganger': 'doppelganger-troublemaker',
};

/// Every night, recorded first.
final allNights = {...recordedNights, ...editedNights};
