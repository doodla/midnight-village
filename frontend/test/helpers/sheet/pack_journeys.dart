import '../contract/contract_samples.dart';

// The cold-read pack's journeys (test_screens/playtest_pack_test.dart draws
// them, `just playtest-pack`), as data: each journey is ONE phone of ONE
// recorded game (game 7: Ana the Seer hosts, Ben the Robber, Cleo the lone
// Werewolf, Dev the Troublemaker, Esme a Villager; and Tia's table set up for
// eight, which ends before the deal), and each screen is that
// phone's own payload at a moment after the screen before it. Nothing here is
// drawn: test/playtest/pack_journeys_test.dart checks the journeys hang
// together (the same players and tokens, the same viewer, the deck in play,
// a vote that never offers the viewer, a clock that never runs backwards),
// so a cold reader never sees two games stitched into one.

/// What a step of a journey shows.
enum PackScreen {
  /// 01 on a new phone, and with the viewer's name typed.
  join,
  joinNamed,

  /// 01 opened from the table's link (its QR code), and with the name typed.
  joinLink,
  joinLinkNamed,

  /// 02 on the step's lobby body.
  table,

  /// 03 opened from 02 ("Edit"), its grid opened, a card held (03b).
  deck,
  deckEdit,
  deckRole,

  /// 04 face down, then held.
  card,
  cardHeld,

  /// 06: the board, "You" held, the viewer's picks, then Choose pressed.
  board,
  boardHeld,
  boardPicked,
  boardChosen,

  /// 08 as it opens (My night open, where the night told something), then
  /// put away, then My night held (every page of it at once).
  talkOpen,
  talk,
  talkHeld,

  /// 09 as the step's `/me/` has it; then the viewer's pick, then locked.
  vote,
  votePicked,
  voteLocked,

  /// 10 and 11 from the game's results; 11 scrolled to its end.
  count,
  results,
  resultsEnd,
}

/// One screen of a journey: what it shows, the recorded payload it is drawn
/// from (none for 01, before the phone is at a table) and, for a stage with
/// a clock, how many seconds into the stage it is.
class PackStep {
  const PackStep(this.screen, [this.sample, this.at]);

  final PackScreen screen;

  /// `contract_samples/<sample>.json`.
  final String? sample;
  final int? at;

  Map<String, dynamic>? get body =>
      sample == null ? null : ContractSamples.map(sample!);

  /// A `/me/` (a night, talk or vote payload), as opposed to a lobby or
  /// results body.
  bool get isMe => body?.containsKey('stage') ?? false;

  /// The seconds the stage's clock shows: its deadline less [at] seconds
  /// after it opened (both the server's, in the payload).
  int? get secondsLeft {
    final me = body;
    if (me == null || !isMe || at == null) return null;
    final started = DateTime.parse(me['stage_started_at'] as String);
    final deadline = DateTime.parse(me['deadline'] as String);
    return deadline.difference(started).inSeconds - at!;
  }

  /// How far through its stage, 0 to 1 (the talk's sun, the vote's bar).
  double? get share {
    final me = body;
    if (me == null || !isMe || at == null) return null;
    final started = DateTime.parse(me['stage_started_at'] as String);
    final deadline = DateTime.parse(me['deadline'] as String);
    return at! / deadline.difference(started).inSeconds;
  }
}

/// One phone's game, screen by screen.
class PackJourney {
  const PackJourney({
    required this.viewer,
    required this.host,
    required this.taps,
    required this.vote,
    required this.steps,
  });

  /// Whose phone it is (a name at game 7's table).
  final String viewer;
  final bool host;

  /// What the phone tapped on the board (the captions, in order), as its
  /// night results say it did.
  final List<String> taps;

  /// Whom it voted for, as the results say ('' for a journey that ends
  /// before the deal).
  final String vote;
  final List<PackStep> steps;
}

const _results = 'http/game/results_five';
const _lobby = 'http/lobby/settings_deck_chip';

/// Each journey's screens, in the order its phone shows them.
const packJourneys = <String, PackJourney>{
  // Ana starts the table and deals; she is the Seer, looks at Cleo's card
  // (a Werewolf) and votes for her.
  'host': PackJourney(
    viewer: 'Ana',
    host: true,
    taps: ['Cleo'],
    vote: 'Cleo',
    steps: [
      PackStep(PackScreen.join),
      PackStep(PackScreen.joinNamed),
      PackStep(PackScreen.table, 'http/lobby/created_with_defaults'),
      PackStep(PackScreen.table, _lobby),
      PackStep(PackScreen.deck, _lobby),
      PackStep(PackScreen.deckEdit, _lobby),
      PackStep(PackScreen.deckRole, _lobby),
      PackStep(PackScreen.table, _lobby),
      PackStep(PackScreen.card, 'http/game/me_look_stage'),
      PackStep(PackScreen.cardHeld, 'http/game/me_look_stage'),
      PackStep(PackScreen.board, 'http/game/me_choose_prompt_seer', 3),
      PackStep(PackScreen.boardPicked, 'http/game/me_choose_prompt_seer', 8),
      PackStep(PackScreen.boardChosen, 'http/game/me_choose_prompt_seer', 10),
      PackStep(PackScreen.talkOpen, 'http/game/me_discussion_choose_seer', 2),
      PackStep(PackScreen.talk, 'http/game/me_discussion_choose_seer', 6),
      PackStep(PackScreen.talkHeld, 'http/game/me_discussion_choose_seer', 15),
      PackStep(PackScreen.vote, 'http/game/me_voting_unpicked', 4),
      PackStep(PackScreen.votePicked, 'http/game/me_voting_picked', 20),
      PackStep(PackScreen.voteLocked, 'http/game/me_voting_locked', 24),
      PackStep(PackScreen.count, _results),
      PackStep(PackScreen.results, _results),
      PackStep(PackScreen.resultsEnd, _results),
    ],
  ),
  // Ben scans Ana's QR code; he is the Robber and takes Ana's card.
  'guest': PackJourney(
    viewer: 'Ben',
    host: false,
    taps: ['Ana'],
    vote: 'Cleo',
    steps: [
      PackStep(PackScreen.joinLink),
      PackStep(PackScreen.joinLinkNamed),
      PackStep(PackScreen.table, _lobby),
      PackStep(PackScreen.card, 'http/game/pack_look_robber'),
      PackStep(PackScreen.cardHeld, 'http/game/pack_look_robber'),
      PackStep(PackScreen.board, 'http/game/me_choose_prompt_robber', 2),
      PackStep(PackScreen.boardHeld, 'http/game/me_choose_prompt_robber', 4),
      PackStep(PackScreen.boardPicked, 'http/game/me_choose_prompt_robber', 9),
      PackStep(PackScreen.boardChosen, 'http/game/me_choose_prompt_robber', 11),
      PackStep(PackScreen.talkOpen, 'http/game/me_discussion_choose_robber', 2),
      PackStep(PackScreen.talk, 'http/game/me_discussion_choose_robber', 5),
      PackStep(
        PackScreen.talkHeld,
        'http/game/me_discussion_choose_robber',
        12,
      ),
      PackStep(PackScreen.vote, 'http/game/pack_vote_robber', 6),
      PackStep(PackScreen.votePicked, 'http/game/pack_vote_robber', 25),
      PackStep(PackScreen.voteLocked, 'http/game/pack_vote_robber', 28),
      PackStep(PackScreen.count, _results),
      PackStep(PackScreen.results, _results),
      PackStep(PackScreen.resultsEnd, _results),
    ],
  ),
  // Esme is a Villager: nothing to do at night.
  'sleeper': PackJourney(
    viewer: 'Esme',
    host: false,
    taps: [],
    vote: 'Cleo',
    steps: [
      PackStep(PackScreen.card, 'http/game/pack_look_villager'),
      PackStep(PackScreen.cardHeld, 'http/game/pack_look_villager'),
      PackStep(PackScreen.board, 'http/game/me_choose_prompt_villager', 2),
      PackStep(PackScreen.boardHeld, 'http/game/me_choose_prompt_villager', 5),
      PackStep(PackScreen.board, 'http/game/me_choose_prompt_villager', 16),
      PackStep(PackScreen.talk, 'http/game/me_discussion_choose_villager', 7),
      PackStep(
        PackScreen.talkHeld,
        'http/game/me_discussion_choose_villager',
        14,
      ),
      PackStep(PackScreen.vote, 'http/game/pack_vote_villager', 5),
      PackStep(PackScreen.votePicked, 'http/game/pack_vote_villager', 30),
      PackStep(PackScreen.voteLocked, 'http/game/pack_vote_villager', 33),
      PackStep(PackScreen.count, _results),
      PackStep(PackScreen.results, _results),
      PackStep(PackScreen.resultsEnd, _results),
    ],
  ),
  // Ana's night, read closely: what "You" says, her pick, what she saw.
  'seer': PackJourney(
    viewer: 'Ana',
    host: true,
    taps: ['Cleo'],
    vote: 'Cleo',
    steps: [
      PackStep(PackScreen.card, 'http/game/me_look_stage'),
      PackStep(PackScreen.cardHeld, 'http/game/me_look_stage'),
      PackStep(PackScreen.board, 'http/game/me_choose_prompt_seer', 2),
      PackStep(PackScreen.boardHeld, 'http/game/me_choose_prompt_seer', 5),
      PackStep(PackScreen.boardPicked, 'http/game/me_choose_prompt_seer', 9),
      PackStep(PackScreen.boardChosen, 'http/game/me_choose_prompt_seer', 10),
      PackStep(PackScreen.talkOpen, 'http/game/me_discussion_choose_seer', 2),
      PackStep(PackScreen.talk, 'http/game/me_discussion_choose_seer', 4),
      PackStep(PackScreen.talkHeld, 'http/game/me_discussion_choose_seer', 9),
      PackStep(PackScreen.vote, 'http/game/me_voting_unpicked', 3),
      PackStep(PackScreen.votePicked, 'http/game/me_voting_picked', 22),
      PackStep(PackScreen.count, _results),
      PackStep(PackScreen.results, _results),
    ],
  ),
  // Tia sets up a table for eight before anyone comes: the number, a deck
  // of her own built card by card, then the table filling one by one; only
  // seven come, she plays with seven (back to a starter deck), then an
  // eighth turns up after all and she sets eight again (the owner's set-up,
  // 21 November 2026). Before the deal: no game, no clock.
  'host-sets-8': PackJourney(
    viewer: 'Tia',
    host: true,
    taps: [],
    vote: '',
    steps: [
      PackStep(PackScreen.join),
      PackStep(PackScreen.joinNamed),
      PackStep(PackScreen.deck, 'http/lobby/settings_seats'),
      PackStep(PackScreen.deck, 'http/lobby/settings_custom_deck_building'),
      PackStep(PackScreen.deck, 'http/lobby/detail_seats_8_custom_alone'),
      PackStep(PackScreen.table, 'http/lobby/detail_seats_8_custom_alone'),
      PackStep(PackScreen.table, 'http/lobby/detail_seats_8_four_here'),
      PackStep(PackScreen.table, 'http/lobby/detail_seats_8_seven_here'),
      PackStep(PackScreen.table, 'http/lobby/settings_seats_lowered'),
      PackStep(PackScreen.table, 'http/lobby/settings_back_to_auto'),
      PackStep(PackScreen.table, 'http/lobby/detail_seats_8_full'),
    ],
  ),
};

/// A player as a screen's payload names them: id, name and token.
typedef PackPlayer = ({int id, String name, String? token});

/// The players [body] shows: a lobby's members, a `/me/`'s or the
/// results' players.
Set<PackPlayer> playersOf(Map<String, dynamic> body) => {
  for (final p in (body['players'] as List).cast<Map<String, dynamic>>())
    if (p['user'] case final Map<String, dynamic> user)
      (
        id: user['id'] as int,
        name: user['display_name'] as String,
        token: p['token'] as String?,
      )
    else
      (
        id: p['player_id'] as int,
        name: p['display_name'] as String,
        token: p['token'] as String?,
      ),
};

/// The viewer's id at the table [body] shows.
int viewerIn(Map<String, dynamic> body, String viewer) =>
    body['player_id'] as int? ??
    playersOf(body).firstWhere((p) => p.name == viewer).id;
