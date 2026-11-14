/// The reference games as data (docs/specs/onuw/reference-games.md).
///
/// The harness does NOT keep its own copy of the scenarios: it reads the
/// machine-readable file the backend tests replay,
/// `backend/tests/onuw/data/reference_games.json`, so the server's unit tests
/// and this end-to-end harness check the SAME games and expected outcomes.
///
/// A game is: who was dealt what (player index -> card), the three center cards,
/// the night CHOICES the players make (`ch`), and the recorded outcome:
/// final cards, what each player learned during the night (`views`), teams,
/// and, for full games, the votes, who was voted out, who died, who won.
///
/// `ch` keys (all optional; a missing choice = that player does nothing):
/// - `doppel_target`  player index the Doppelganger looks at
/// - `doppel_follow`  her immediate follow-up as Seer/Robber/Troublemaker/Drunk
///                    (same shape as the matching role's choice below)
/// - `wolf_center`    center index a LONE Werewolf looks at
/// - `seer`           `["player", pid]` or `["center", [i, j]]`
/// - `robber`         player index   - `troublemaker` `[a, b]`   - `drunk` center index
library;

import 'dart:convert';
import 'dart:io';

/// Tags drive which runner picks up a game. `uiCritical` games also run through
/// the UI runner (real widgets + PNG filmstrips).
enum ScenarioTag { uiCritical }

/// One thing a player learned during the night, in the recorded shape:
/// `copied` role, `werewolves` [player idx], `masons` [player idx],
/// `saw_center` [[center idx, role]], `saw_player` [player idx, role],
/// `took` role, `own_card` role.
class ExpectedView {
  const ExpectedView(this.kind, this.value);

  factory ExpectedView.fromJson(List<dynamic> json) =>
      ExpectedView(json[0] as String, json[1]);

  final String kind;
  final Object? value;

  /// Canonical JSON text, so two views compare with plain string equality.
  String get canonical => jsonEncode([kind, value]);

  @override
  String toString() => canonical;
}

class ReferenceGame {
  ReferenceGame({
    required this.id,
    required this.title,
    required this.players,
    required this.dealt,
    required this.center,
    required this.choices,
    required this.finalCards,
    required this.finalCenter,
    required this.copied,
    required this.views,
    required this.teams,
    required this.votes,
    required this.votedOut,
    required this.dead,
    required this.winners,
    required this.won,
    required this.reason,
    this.tags = const {},
  });

  factory ReferenceGame.fromJson(Map<String, dynamic> json) {
    List<String> strings(Object? v) => (v as List).cast<String>();
    List<int> ints(Object? v) =>
        (v as List).map((e) => (e as num).toInt()).toList();
    final votesRaw = json['votes'] as Map<String, dynamic>?;
    return ReferenceGame(
      id: '${json['num']}',
      title: json['title'] as String,
      players: strings(json['players']),
      dealt: strings(json['dealt']),
      center: strings(json['center']),
      choices: Map<String, dynamic>.from(json['ch'] as Map),
      finalCards: strings(json['final']),
      finalCenter: strings(json['final_center']),
      copied: json['copied'] as String?,
      views: {
        for (final e in (json['views'] as Map<String, dynamic>).entries)
          int.parse(e.key): [
            for (final v in e.value as List)
              ExpectedView.fromJson(v as List<dynamic>),
          ],
      },
      teams: strings(json['teams']),
      votes: votesRaw == null
          ? null
          : {
              for (final e in votesRaw.entries)
                int.parse(e.key): (e.value as num?)?.toInt(),
            },
      votedOut: json.containsKey('voted_out') ? ints(json['voted_out']) : null,
      dead: json.containsKey('dead') ? ints(json['dead']) : null,
      winners: json.containsKey('winners') ? strings(json['winners']) : null,
      won: json.containsKey('won') ? ints(json['won']) : null,
      reason: json['reason'] as String?,
    );
  }

  /// `1`..`23` for the full games, `D1`..`D6` for the Doppelganger night-only ones.
  final String id;
  final String title;

  /// Display names; index = player index in every other list. FIRST is the host.
  final List<String> players;
  final List<String> dealt;
  final List<String> center;
  final Map<String, dynamic> choices;

  /// Cards each player holds / the center holds when the night is over.
  final List<String> finalCards;
  final List<String> finalCenter;

  /// The role the Doppelganger copied (null if none / not applicable).
  final String? copied;

  /// Player index -> what they learned, in order.
  final Map<int, List<ExpectedView>> views;

  /// Per player index: `werewolf` | `village` | `neutral` (Tanner), at night's end.
  final List<String> teams;

  // Full games only (the night-only games stop after the night):
  final Map<int, int?>? votes;
  final List<int>? votedOut;
  final List<int>? dead;
  final List<String>? winners;
  final List<int>? won;
  final String? reason;

  final Set<ScenarioTag> tags;

  bool get hasVotes => votes != null;
  bool get isUiCritical => tags.contains(ScenarioTag.uiCritical);

  /// Stable directory / test name, e.g. `game-04-doppelganger-chaos`.
  String get name {
    final slug = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final shownId = RegExp(r'^\d+$').hasMatch(id) ? id.padLeft(2, '0') : id;
    final short = slug.length > 40 ? slug.substring(0, 40) : slug;
    return 'game-$shownId-${short.replaceAll(RegExp(r'-+$'), '')}';
  }

  /// TitleCase role -> count for the lobby PATCH (dealt cards + center).
  Map<String, int> get roleCounts {
    final counts = <String, int>{};
    for (final role in [...dealt, ...center]) {
      counts[role] = (counts[role] ?? 0) + 1;
    }
    return counts;
  }

  ReferenceGame withTags(Set<ScenarioTag> tags) => ReferenceGame(
    id: id,
    title: title,
    players: players,
    dealt: dealt,
    center: center,
    choices: choices,
    finalCards: finalCards,
    finalCenter: finalCenter,
    copied: copied,
    views: views,
    teams: teams,
    votes: votes,
    votedOut: votedOut,
    dead: dead,
    winners: winners,
    won: won,
    reason: reason,
    tags: tags,
  );

  /// Reads `backend/tests/onuw/data/reference_games.json`, found by walking up
  /// from the working directory (`flutter test` runs from `frontend/`).
  static List<ReferenceGame> loadAll() {
    var dir = Directory.current.absolute;
    for (var i = 0; i < 6; i++) {
      final file = File(
        '${dir.path}/backend/tests/onuw/data/reference_games.json',
      );
      if (file.existsSync()) {
        final raw = jsonDecode(file.readAsStringSync()) as List<dynamic>;
        return [
          for (final g in raw)
            ReferenceGame.fromJson(g as Map<String, dynamic>),
        ];
      }
      dir = dir.parent;
    }
    throw StateError(
      'backend/tests/onuw/data/reference_games.json not found above '
      '${Directory.current.path}',
    );
  }
}
