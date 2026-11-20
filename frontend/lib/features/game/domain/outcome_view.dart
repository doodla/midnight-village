import 'package:flutter/foundation.dart';

import '../../../design_system/copy/copy.dart';
import '../../../design_system/faces/face_content.dart'
    show centerName, nameList;
import '../../../design_system/models/game_result.dart';
import '../../../design_system/models/role.dart';
import '../../../design_system/night/night_pick.dart';
import 'game_outcome.dart';
import 'night_timeline.dart';

// What 10 The count and 11 Results show, read from the results body
// ([GameOutcome]) and nothing else: who voted for whom (grouped, so the rows
// can be drawn), who died and why, who won, each player's card at the deal
// and at the end, and the night in order. Every fact is the server's (death,
// the Hunter's pick, the winners, each player's team and outcome); nothing
// here applies a rule of the game.

/// One player at the end of the game, as the results name them.
@immutable
class EndSeat {
  const EndSeat._({
    required this.seat,
    required this.dealt,
    required this.now,
    required this.copied,
    required this.team,
    required this.won,
    required this.diedBy,
    required this.votedFor,
  });

  final NightSeat seat;

  /// The card dealt to them (`original_role`).
  final RoleId dealt;

  /// The card in front of them at the end (`final_role`): the one that
  /// counts, the same on 10 and 11 so the two screens cannot disagree.
  final RoleId now;

  /// When [now] is the Doppelganger: the role she copied (the timeline's
  /// `copy` step), which the card is for the rest of the game.
  final RoleId? copied;

  /// Their team at the end, as the server says (`team`).
  final TeamId team;

  /// The server's `outcome`.
  final bool won;

  /// Null: alive.
  final EliminationReason? diedBy;

  /// Whom they voted for (null: no vote).
  final int? votedFor;

  bool get died => diedBy != null;

  /// The card moved in the night.
  bool get moved => dealt != now;

  /// The role the [now] card plays: the copied role for a Doppelganger.
  RoleId get plays => copied ?? now;
}

/// Everyone at the end, in seat order (the results' `players`, with the
/// tokens and seats of its players list).
List<EndSeat> endSeatsOf(GameOutcome outcome) {
  final byId = {for (final p in outcome.result.players) p.id: p};
  final copied = outcome.timeline?.steps
      .where((s) => s.action == TimelineAction.copy)
      .firstOrNull
      ?.copiedRole;
  return [
    for (final seat in outcome.seats)
      if (byId['${seat.id}'] case final p?)
        EndSeat._(
          seat: seat,
          dealt: p.originalRole,
          now: p.finalRole,
          copied: p.finalRole == RoleId.doppelganger ? copied : null,
          team: p.team,
          won: p.isWinner,
          diedBy: p.isEliminated
              ? p.eliminationReason ?? EliminationReason.vote
              : null,
          votedFor: p.voteTargetId == null ? null : int.parse(p.voteTargetId!),
        ),
  ];
}

/// A row of the count: a player who got votes, and who gave them.
@immutable
class Accused {
  const Accused._(this.player, this.voters);

  final EndSeat player;

  /// In seat order.
  final List<NightSeat> voters;

  int get votes => voters.length;
}

/// 10: the votes, grouped by whom they named, and who dies.
@immutable
class TheCount {
  const TheCount._({
    required this.accused,
    required this.noVote,
    required this.deadByVote,
    required this.deadByHunter,
  });

  factory TheCount.of(GameOutcome outcome) {
    final seats = endSeatsOf(outcome);
    final byId = {for (final s in seats) s.seat.id: s};
    final voters = <int, List<NightSeat>>{};
    for (final s in seats) {
      if (s.votedFor case final target?) {
        (voters[target] ??= []).add(s.seat);
      }
    }
    final accused =
        [
          for (final MapEntry(:key, :value) in voters.entries)
            if (byId[key] case final player?) Accused._(player, value),
        ]..sort((a, b) {
          final byVotes = b.votes.compareTo(a.votes);
          return byVotes != 0
              ? byVotes
              : a.player.seat.seat - b.player.seat.seat;
        });
    return TheCount._(
      accused: accused,
      noVote: [
        for (final s in seats)
          if (s.votedFor == null) s.seat,
      ],
      deadByVote: [
        for (final s in seats)
          if (s.diedBy == EliminationReason.vote) s,
      ],
      deadByHunter: [
        for (final s in seats)
          if (s.diedBy == EliminationReason.hunterChain) s,
      ],
    );
  }

  /// Everyone who got a vote: most votes first, then in seat order.
  final List<Accused> accused;

  /// Who voted for nobody, in seat order.
  final List<NightSeat> noVote;

  /// Killed by the vote, in seat order.
  final List<EndSeat> deadByVote;

  /// Taken by the Hunter (the server's `hunter_chain`).
  final List<EndSeat> deadByHunter;

  /// Everyone who dies: the vote's first, then the Hunter's.
  List<EndSeat> get dead => [...deadByVote, ...deadByHunter];

  /// The headline: "Dev dies.", "Ana, Ben die." or "Nobody dies.".
  String get headline => switch (deadByVote) {
    [] when deadByHunter.isEmpty => CountCopy.nobodyDies,
    [] => _dies(deadByHunter),
    final dead => _dies(dead),
  };

  /// "{name} dies too." for the Hunter's pick (null: none, or the Hunter's
  /// pick is the headline's only death).
  String? get diesToo => deadByVote.isEmpty || deadByHunter.isEmpty
      ? null
      : CountCopy.diesToo.fill({
          'name': nameList(deadByHunter.map((s) => s.seat.name)),
        });

  static String _dies(List<EndSeat> dead) => dead.length == 1
      ? CountCopy.dies.fill({'name': dead.single.seat.name})
      : CountCopy.die.fill({'names': nameList(dead.map((s) => s.seat.name))});
}

/// Who won, as the server's `winning_teams` say.
enum Winners {
  village,
  werewolves,
  tanner,
  villageAndTanner,
  werewolvesAndTanner,
  nobody;

  factory Winners.of(List<TeamId> teams) => switch (teams.toSet()) {
    final s when s.isEmpty => nobody,
    final s when s.length == 1 && s.contains(TeamId.village) => village,
    final s when s.length == 1 && s.contains(TeamId.werewolf) => werewolves,
    final s when s.length == 1 && s.contains(TeamId.independent) => tanner,
    final s
        when s.length == 2 &&
            s.containsAll([TeamId.village, TeamId.independent]) =>
      villageAndTanner,
    final s
        when s.length == 2 &&
            s.containsAll([TeamId.werewolf, TeamId.independent]) =>
      werewolvesAndTanner,
    final other => throw FormatException('Winning teams', '$other'),
  };

  /// 11's headline.
  String get headline => switch (this) {
    village => ResultsCopy.villageWins,
    werewolves => ResultsCopy.werewolvesWin,
    tanner => ResultsCopy.tannerWins,
    villageAndTanner => ResultsCopy.villageAndTanner,
    werewolvesAndTanner => ResultsCopy.werewolvesAndTanner,
    nobody => ResultsCopy.nobodyWins,
  };

  /// The winners' portrait (none when nobody wins).
  RoleId? get portrait => switch (this) {
    village || villageAndTanner => RoleId.villager,
    werewolves || werewolvesAndTanner => RoleId.werewolf,
    tanner => RoleId.tanner,
    nobody => null,
  };

  /// The Werewolves won: the band is blood (S11).
  bool get werewolvesWon => this == werewolves || this == werewolvesAndTanner;
}

/// A card named on a timeline line: its role, and whether it is a werewolf
/// card for whoever ends holding it (the server's `werewolf`).
typedef LineCard = ({RoleId role, bool werewolf});

/// One step of the night as 11 lists it: "Robber: Ben takes Dev's card.",
/// with the cards the step showed its actor (or moved, for a swap made
/// without looking).
@immutable
class NightLine {
  const NightLine._({
    required this.number,
    required this.role,
    required this.prefix,
    required this.text,
    required this.cards,
    required this.swap,
  });

  /// 1, 2, ...
  final int number;

  /// The role acting: its portrait heads the line.
  final RoleId role;

  /// "Robber:" or, for the Doppelganger's follow-up, "Doppelganger · Seer:".
  final String prefix;

  /// The line after the prefix (3 words at most, names aside).
  final String text;

  /// The cards the step showed or moved, in order.
  final List<LineCard> cards;

  /// [cards] are two that changed places (the Troublemaker's swap).
  final bool swap;
}

/// The night in the order of the rules, a line per step of the server's
/// timeline.
List<NightLine> nightLinesOf(GameOutcome outcome) {
  final timeline = outcome.timeline;
  if (timeline == null) return const [];
  final names = {for (final s in outcome.seats) s.id: s.name};
  String name(int id) => names[id] ?? '';
  LineCard card(String id) {
    final c = timeline.cards[id]!;
    return (role: c.role, werewolf: c.werewolf);
  }

  return [for (final step in timeline.steps) _line(step, name, card)];
}

NightLine _line(
  TimelineStep step,
  String Function(int id) name,
  LineCard Function(String id) card,
) {
  final actor = step.actors.isEmpty ? '' : name(step.actors.first);
  final looked = [for (final l in step.lookedAt) card(l.cardId)];
  String pos(CardPlace place) =>
      place is CenterPlace ? centerName(place.index) : '';
  final followUp =
      step.role != RoleId.doppelganger &&
      step.doppelgangerActors.isNotEmpty &&
      step.doppelgangerActors.length == step.actors.length;
  final prefix = followUp
      ? TimelineCopy.followUpPrefix.fill({'copied': step.role.displayName})
      : TimelineCopy.prefix.fill({'role': step.role.displayName});
  var cards = looked;
  var swap = false;
  final String text;
  switch (step.action) {
    case TimelineAction.copy:
      final copied = step.lookedAt
          .map((l) => l.place)
          .whereType<PlayerPlace>()
          .firstOrNull;
      text = TimelineCopy.copies.fill({
        'a': actor,
        'b': copied == null ? '' : name(copied.playerId),
      });
    case TimelineAction.seeTeam:
      final team = step.team.map(name).toList();
      if (step.role == RoleId.minion) {
        text = team.isEmpty
            ? TimelineCopy.minionSeesNone.fill({'a': actor})
            : TimelineCopy.minionSees.fill({
                'a': actor,
                'names': nameList(team),
              });
      } else {
        text = team.length > 1
            ? TimelineCopy.seeEachOther.fill({'names': nameList(team)})
            : TimelineCopy.wakesAlone.fill({'name': actor});
      }
    case TimelineAction.peekPlayer:
      final target = step.lookedAt
          .map((l) => l.place)
          .whereType<PlayerPlace>()
          .firstOrNull;
      text = TimelineCopy.seerPlayer.fill({
        'a': actor,
        'b': target == null ? '' : name(target.playerId),
      });
    case TimelineAction.peekCenter:
      final places = step.lookedAt.map((l) => pos(l.place)).toList();
      text = places.length >= 2
          ? TimelineCopy.seerCenter.fill({
              'a': actor,
              'pos1': places[0],
              'pos2': places[1],
            })
          : TimelineCopy.loneWerewolf.fill({
              'a': actor,
              'pos': places.firstOrNull ?? '',
            });
    case TimelineAction.swapWithPlayer:
      final other = step.moves
          .map((m) => m.from)
          .whereType<PlayerPlace>()
          .where((p) => !step.actors.contains(p.playerId))
          .firstOrNull;
      text = TimelineCopy.robber.fill({
        'a': actor,
        'b': other == null ? '' : name(other.playerId),
      });
    case TimelineAction.swapOthers:
      final from = [
        for (final m in step.moves)
          if (m.from case PlayerPlace(:final playerId)) playerId,
      ];
      text = TimelineCopy.troublemaker.fill({
        'a': actor,
        'b': from.isEmpty ? '' : name(from[0]),
        'c': from.length < 2 ? '' : name(from[1]),
      });
      cards = [for (final m in step.moves) card(m.cardId)];
      swap = cards.length == 2;
    case TimelineAction.swapWithCenter:
      final taken = step.moves.where((m) => m.from is CenterPlace).firstOrNull;
      text = TimelineCopy.drunk.fill({
        'a': actor,
        'pos': taken == null ? '' : pos(taken.from),
      });
      cards = [if (taken != null) card(taken.cardId)];
    case TimelineAction.lookOwn:
      text = TimelineCopy.insomniac.fill({'a': actor});
    case TimelineAction.skip:
      text = TimelineCopy.skip.fill({'a': actor});
      cards = const [];
  }
  return NightLine._(
    number: step.step,
    role: step.role,
    prefix: prefix,
    text: text,
    cards: cards,
    swap: swap,
  );
}
