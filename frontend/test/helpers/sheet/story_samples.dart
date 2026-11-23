import '../contract/contract_shape.dart';
import 'night_record.dart';
import 'sheet_data.dart';

// Every night My night's picture story tells, each a RECORDED talk `/me/`
// (contract_samples/http/game/me_discussion_choose_*, the talk of game 7,
// five at the table, and game 8, nine with the Doppelganger, and the story
// scenarios of backend/tests/contract/story_scenarios.py), by the name a
// test or a picture gives it. Nothing here is hand-built. The one change a
// test makes to a recording is `withLongNames`: names are display data, so a
// long-name check renames the players of a recording (off the contract in
// its values only), never writes a night. What a night should show is read
// from its record by `night_record.dart`, not written beside it.

/// Every night, by name: the recorded sample (under `http/game/`) that tells it.
final nightSamples = <String, String>{
  'seer': 'me_discussion_choose_seer',
  'seer-centre': 'me_discussion_choose_seer_center',
  'seer-skipped': 'me_discussion_choose_seer_nothing_chosen',
  // The server records a skip for a Seer whose window timed out
  // (night_window.py, `_timeout_action_type`): the very entry of a Seer who
  // chose nothing.
  'seer-timed-out': 'me_discussion_choose_seer_timed_out',
  'troublemaker': 'me_discussion_choose_troublemaker',
  'robber': 'me_discussion_choose_robber',
  'werewolf-pair': 'me_discussion_choose_werewolf_pack',
  'werewolf-lone-looked': 'me_discussion_choose_werewolf_lone',
  'werewolf-lone': 'me_talk_untimed',
  'minion': 'me_discussion_choose_minion',
  'minion-none': 'me_discussion_choose_minion_no_werewolves',
  'mason': 'me_discussion_choose_mason',
  'mason-alone': 'me_discussion_choose_mason_lone',
  'drunk': 'me_discussion_choose_drunk',
  'insomniac-same': 'me_discussion_choose_insomniac',
  'insomniac-changed': 'me_discussion_choose_insomniac_changed',
  'villager': 'me_discussion_choose_villager',
  'hunter': 'me_discussion_choose_hunter',
  'tanner': 'me_discussion_choose_tanner',
  'doppelganger-seer': 'me_discussion_choose_doppelganger',
  'doppelganger-minion': 'me_discussion_choose_doppelganger_minion',
  'doppelganger-troublemaker': 'me_discussion_choose_doppelganger_troublemaker',
  'doppelganger-robber': 'me_discussion_choose_doppelganger_robber',
  'doppelganger-drunk': 'me_discussion_choose_doppelganger_drunk',
  'doppelganger-drunk-timed-out':
      'me_discussion_choose_doppelganger_drunk_timed_out',
  'doppelganger-werewolf': 'me_discussion_choose_doppelganger_werewolf',
  'doppelganger-insomniac': 'me_discussion_choose_doppelganger_insomniac',
  'doppelganger-villager': 'me_discussion_choose_doppelganger_villager',
  'doppelganger-mason': 'me_discussion_choose_doppelganger_mason',
  'doppelganger-hunter': 'me_discussion_choose_doppelganger_hunter',
  'doppelganger-tanner': 'me_discussion_choose_doppelganger_tanner',
  'doppelganger-nothing': 'me_discussion_choose_doppelganger_look_timed_out',
};

/// Every night, by name: the recorded talk `/me/` that tells it (a new copy
/// each time).
final allNights = <String, Map<String, dynamic> Function()>{
  for (final MapEntry(:key, :value) in nightSamples.entries)
    key: () => recordedMe(value),
};

/// Names as a table has them (the server's run to 20 characters): some that
/// wrap between words, one a single long word; more than any night names.
const _longNames = [
  'Maximilian',
  'Annabelle Whitlock',
  'Rosa Maria',
  'Bartholomew Jones',
];

/// The recorded talk [me] with the players its night names given long names:
/// OFF THE CONTRACT in its values only (names are display data; the shape is
/// one the server sends, which [checkHttpBody] checks), and the caller says
/// so ([offContract] must be true). Each name the night record names (in the
/// order the record meets them) becomes one of the long names, in the seats
/// and in the record. Returns the body and the long names now in it.
({Map<String, dynamic> me, List<String> names}) withLongNames(
  Map<String, dynamic> me, {
  required bool offContract,
}) {
  if (!offContract) {
    throw ArgumentError('renamed players are off the contract: say so');
  }
  final named = NightRecord(me).names;
  if (named.length > _longNames.length) {
    throw StateError('a night naming ${named.length} players: add long names');
  }
  final long = {for (final (i, name) in named.indexed) name: _longNames[i]};
  for (final p in (me['players'] as List).cast<Map<String, dynamic>>()) {
    p['display_name'] = long[p['display_name']] ?? p['display_name'];
  }
  for (final e in (me['night_results'] as List).cast<Map<String, dynamic>>()) {
    final info = (e['revealed_info'] as Map).cast<String, dynamic>();
    for (final key in ['target_name', 'player1_name', 'player2_name']) {
      if (info[key] case final String n) info[key] = long[n] ?? n;
    }
    if (info['teammate_names'] case final List names) {
      info['teammate_names'] = [for (final n in names) long[n] ?? n];
    }
  }
  checkHttpBody('GET', '/onuw/games/g/me/', 200, me);
  return (me: me, names: [for (final n in named) long[n]!]);
}

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
