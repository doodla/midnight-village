// One phone's night as the server records it, read for a test to judge the
// picture story by. Written from the API contract (docs/specs/onuw/
// api-contract-v2.md, "Own results") and from nothing in lib/: it names no
// app class, so the story and this reading cannot share a mistake. It is
// built from a talk `/me/` (recorded), and says what a player would expect
// to see on their story: which other cards, face up in which role or face
// down, which names the sentence must carry.
//
// What the contract says of a night's entries (`night_results[]`: `wave`,
// `action_type`, `revealed_info`):
//   peek_player       a card looked at: `target_name`, `role` (a Doppelganger's
//                     look carries `copied_role` too: her copy)
//   peek_center       centre cards looked at: `roles`, `center_indices`
//   swap_with_player  the Robber's: `target_name`, the card now hers `new_role`
//   swap_others       the Troublemaker's: `player1_name`, `player2_name`, unseen
//   swap_with_center  the Drunk's: `card_index`, unseen
//   see_team          who else: `teammate_names`, `role_acting_as`; a lone
//                     Werewolf may carry the centre card looked at (`center_card`)
//   insomniac         `current_role`, the card at the end of the night
//   skip              chose nothing (`nothing_chosen`)

/// One entry of `night_results`.
typedef RecordEntry = ({int wave, String type, Map<String, dynamic> info});

/// The three centre cards, left to right (`center_indices` 0, 1, 2).
const _centre = ['Left', 'Middle', 'Right'];

/// A card expected on a story: its tab and its role in the server's words,
/// or 'down' for a card not seen.
String card(String label, [String? role]) => '$label:${role ?? 'down'}';

class NightRecord {
  NightRecord(Map<String, dynamic> me)
    : dealt = (me['your_role'] as Map)['original_role'] as String,
      entries = [
        for (final e in (me['night_results'] as List).cast<Map>())
          (
            wave: e['wave'] as int,
            type: e['action_type'] as String,
            info: (e['revealed_info'] as Map).cast<String, dynamic>(),
          ),
      ],
      table = [
        for (final p in (me['players'] as List).cast<Map>())
          if (p['player_id'] != me['player_id']) p['display_name'] as String,
      ];

  /// The role dealt to this phone.
  final String dealt;
  final List<RecordEntry> entries;

  /// The names of the other players at the table.
  final List<String> table;

  bool get isDoppelganger => dealt == 'Doppelganger';

  /// The Doppelganger's look: the entry that says what she copied.
  RecordEntry? get copy =>
      entries.where((e) => e.info.containsKey('copied_role')).firstOrNull;

  String? get copiedName => copy?.info['target_name'] as String?;
  String? get copiedRole => copy?.info['copied_role'] as String?;

  /// What the night did besides the copy: the entries that are not a skip.
  List<RecordEntry> get acts => [
    for (final e in entries)
      if (e != copy && e.type != 'skip') e,
  ];

  /// Nothing happened to see: no copy, and nothing but skips (or no entry).
  bool get sleeps => copy == null && acts.isEmpty;

  /// Every other card the story shows, as [card] writes it, in no order: the
  /// copy first, then what each entry shows.
  List<String> get cards => [
    if (copy != null) card(copiedName!, copiedRole),
    for (final e in acts) ...cardsOf(e),
  ];

  List<String> cardsOf(RecordEntry e) {
    final info = e.info;
    List<String> centre({Map<int, String> seen = const {}}) => [
      for (var i = 0; i < _centre.length; i++) card(_centre[i], seen[i]),
    ];
    switch (e.type) {
      case 'peek_player':
        return [card(info['target_name'] as String, info['role'] as String)];
      case 'peek_center':
        final roles = (info['roles'] as List).cast<String>();
        final at = (info['center_indices'] as List).cast<int>();
        return centre(
          seen: {for (var i = 0; i < at.length; i++) at[i]: roles[i]},
        );
      case 'swap_with_player':
        return [
          card(info['target_name'] as String, info['new_role'] as String),
        ];
      case 'swap_others':
        return [
          card(info['player1_name'] as String),
          card(info['player2_name'] as String),
        ];
      case 'swap_with_center':
        return centre();
      case 'see_team':
        final team = info['role_acting_as'] == 'Mason' ? 'Mason' : 'Werewolf';
        final looked = info['center_card'] as Map?;
        return [
          for (final n in (info['teammate_names'] as List).cast<String>())
            card(n, team),
          if (looked != null)
            ...centre(seen: {looked['index'] as int: looked['role'] as String}),
        ];
      case 'insomniac':
        return [card('Now', info['current_role'] as String)];
    }
    throw StateError('the contract has no "${e.type}" in a night record');
  }

  /// Every name the record names (not this phone's own), in the order met.
  List<String> get names {
    final out = <String>[];
    void add(Object? n) {
      if (n is String && !out.contains(n)) out.add(n);
    }

    add(copiedName);
    for (final e in acts) {
      add(e.info['target_name']);
      add(e.info['player1_name']);
      add(e.info['player2_name']);
      for (final n in (e.info['teammate_names'] as List? ?? const [])) {
        add(n);
      }
    }
    return out;
  }

  /// The names the one sentence must carry: whom she copied; whom a Seer
  /// looked at or a Robber took from; whom a Troublemaker swapped; and a
  /// team (Werewolves, Masons, the Minion's pack) for a player who was dealt
  /// that role (a Doppelganger's sentence is about her copy).
  List<String> get sentenceNames => [
    if (copiedName != null) copiedName!,
    for (final e in acts) ...[
      if (e.type == 'peek_player' || e.type == 'swap_with_player')
        e.info['target_name'] as String,
      if (e.type == 'swap_others') ...[
        e.info['player1_name'] as String,
        e.info['player2_name'] as String,
      ],
      if (e.type == 'see_team' && !isDoppelganger)
        ...(e.info['teammate_names'] as List).cast<String>(),
    ],
  ];

  /// The roles the one sentence must say: the card a Seer saw or a Robber
  /// took, the Insomniac's card at the end; for a Doppelganger whose copy
  /// went on to nothing in the first window, what she copied.
  List<String> get sentenceRoles => [
    for (final e in acts)
      if (!isDoppelganger) ...[
        if (e.type == 'peek_player') e.info['role'] as String,
        if (e.type == 'swap_with_player') e.info['new_role'] as String,
        if (e.type == 'insomniac') e.info['current_role'] as String,
      ],
    if (isDoppelganger && copy != null && !acts.any((e) => e.wave == 1))
      copiedRole!,
  ];
}
