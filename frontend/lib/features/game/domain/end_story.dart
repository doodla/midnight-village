import 'package:flutter/foundation.dart';

import '../../../design_system/copy/copy.dart';
import '../../../design_system/models/role.dart';
import 'game_outcome.dart';
import 'night_timeline.dart';

// What happened, replayed on the end board (docs/specs/frontend/end-board.md,
// section 8): the night's steps as the board plays them, from the results'
// `night_timeline` alone. Pure: no Flutter, no layout. The board reads it.

/// What a step did, as the board draws it.
enum StoryKind {
  /// A team woke and saw each other (the Werewolves, the Masons), or the
  /// Minion saw the Werewolves; a lone one woke alone.
  team,

  /// The Doppelganger looked at a card and became it.
  copy,

  /// Someone looked at a card: a player's, the middle's, their own.
  look,

  /// Someone took a card for their own: the Robber, the Drunk.
  take,

  /// Someone swapped two other players' cards: the Troublemaker.
  swap;

  /// The thread of a look is gapped; of a move, one length.
  bool get moves => this == take || this == swap;
}

/// A twine between two places on the board: a player's card or a middle card.
typedef StoryThread = ({CardPlace from, CardPlace to});

/// What a card shows at a moment of the night: the portrait and the role on
/// its strip ([cardFace]).
typedef StoryFace = ({RoleId face, RoleId strip});

/// The one rule for what a card shows, on the settled board and at every
/// step of the night. A card has one role, printed on its strip wherever it
/// goes: [role]. Its portrait is that role too, except the Doppelganger card
/// once it has copied ([copied]) and while a player holds it ([held]): its
/// holder plays the copied role (the server: "any player currently holding
/// that card inherits the copied role"), so the portrait shows it and the
/// strip still says "Doppelganger". In the middle nobody plays it: it is a
/// Doppelganger card.
StoryFace cardFace(RoleId role, {RoleId? copied, required bool held}) =>
    role == RoleId.doppelganger && copied != null && held
    ? (face: copied, strip: role)
    : (face: role, strip: role);

/// Every card's face at one moment: each player's and the middle's.
@immutable
class StoryFaces {
  const StoryFaces(this.players, this.centre);

  /// Player id -> the card in front of them.
  final Map<int, StoryFace> players;

  /// Left, Middle, Right.
  final List<StoryFace> centre;

  StoryFace at(CardPlace place) => switch (place) {
    PlayerPlace(:final playerId) => players[playerId]!,
    CenterPlace(:final index) => centre[index],
  };
}

/// One step of the night as the board plays it.
@immutable
class StoryStep {
  const StoryStep({
    required this.number,
    required this.kind,
    required this.actors,
    required this.threads,
    required this.werewolf,
    required this.line,
    required this.after,
  });

  /// 1, 2, ... in the order played (steps that did nothing are not counted).
  final int number;
  final StoryKind kind;

  /// Who acted: their cards are where the step happens.
  final List<int> actors;

  /// The twines it ties.
  final List<StoryThread> threads;

  /// The Werewolf team's act: its twine is red. Every other twine is bone.
  final bool werewolf;

  /// The step's line in the banner ([StoryCopy.line]): the role that
  /// acted, who, and what came of it.
  final String line;

  /// Every card's face once the step is done.
  final StoryFaces after;

  /// Every place the step touches: the actors' cards and both ends of every
  /// thread, each once, actors first.
  List<CardPlace> get places {
    final seen = <CardPlace>[];
    void add(CardPlace p) {
      if (!seen.contains(p)) seen.add(p);
    }

    actors.map(PlayerPlace.new).forEach(add);
    for (final t in threads) {
      add(t.from);
      add(t.to);
    }
    return seen;
  }
}

/// The night replayed: the cards as dealt, then each step that did something,
/// in the order of the rules.
@immutable
class EndStory {
  const EndStory({required this.dealt, required this.steps});

  final StoryFaces dealt;
  final List<StoryStep> steps;

  /// The faces before step [index] plays (the deal before the first).
  StoryFaces before(int index) => index == 0 ? dealt : steps[index - 1].after;

  /// The faces once the night is over: the board's settled faces.
  StoryFaces get last => steps.isEmpty ? dealt : steps.last.after;
}

/// The story of [outcome]'s night; null when the results carry no timeline
/// (the board has no "What happened" then). A step that did nothing (a role
/// that chose to do nothing) is left out; roles in the middle and the
/// Villagers never have a step.
EndStory? endStoryOf(GameOutcome outcome) {
  final timeline = outcome.timeline;
  if (timeline == null) return null;
  final names = {for (final s in outcome.seats) s.id: s.name};
  // What each card copied, from its copy on: a property of the card, drawn
  // by [cardFace] only while a player holds it.
  final copies = <String, RoleId>{};
  StoryFaces faces(CardPositions at) {
    StoryFace face(String card, {required bool held}) =>
        cardFace(timeline.cards[card]!.role, copied: copies[card], held: held);

    return StoryFaces(
      {
        for (final MapEntry(:key, :value) in at.players.entries)
          key: face(value, held: true),
      },
      [for (final card in at.center) face(card, held: false)],
    );
  }

  final dealt = faces(timeline.dealt);
  final steps = <StoryStep>[];
  for (final step in timeline.steps) {
    if (step.action == TimelineAction.skip) continue;
    if (step.action == TimelineAction.copy && step.copiedRole != null) {
      for (final actor in step.actors) {
        final card = timeline.dealt.players[actor];
        if (card != null) copies[card] = step.copiedRole!;
      }
    }
    steps.add(
      StoryStep(
        number: steps.length + 1,
        kind: _kindOf(step.action),
        actors: step.actors,
        threads: _threadsOf(step),
        werewolf: step.role.team == TeamId.werewolf,
        line: _lineOf(step, timeline, (id) => names[id] ?? ''),
        after: faces(step.positionsAfter),
      ),
    );
  }
  return EndStory(dealt: dealt, steps: steps);
}

StoryKind _kindOf(TimelineAction action) => switch (action) {
  TimelineAction.seeTeam => StoryKind.team,
  TimelineAction.copy => StoryKind.copy,
  TimelineAction.peekPlayer ||
  TimelineAction.peekCenter ||
  TimelineAction.lookOwn ||
  TimelineAction.skip => StoryKind.look,
  TimelineAction.swapWithPlayer ||
  TimelineAction.swapWithCenter => StoryKind.take,
  TimelineAction.swapOthers => StoryKind.swap,
};

/// The twines a step ties: from the one who looked to what they saw; from the
/// one who took to where they took it from; between the two cards swapped;
/// along a team that saw each other (the Minion to each Werewolf).
List<StoryThread> _threadsOf(TimelineStep step) {
  final actor = step.actors.isEmpty ? null : PlayerPlace(step.actors.first);
  List<StoryThread> fromActor(Iterable<CardPlace> to) => [
    if (actor != null)
      for (final place in to)
        if (place != actor) (from: actor, to: place),
  ];
  switch (step.action) {
    case TimelineAction.copy ||
        TimelineAction.peekPlayer ||
        TimelineAction.peekCenter:
      return fromActor(step.lookedAt.map((l) => l.place));
    case TimelineAction.seeTeam:
      final team = step.team.map(PlayerPlace.new).toList();
      if (step.role == RoleId.minion) return fromActor(team);
      return [
        for (var i = 1; i < team.length; i++) (from: team[i - 1], to: team[i]),
      ];
    case TimelineAction.swapWithPlayer || TimelineAction.swapWithCenter:
      return fromActor(step.moves.map((m) => m.from));
    case TimelineAction.swapOthers:
      final from = [for (final m in step.moves) m.from];
      return from.length < 2 ? const [] : [(from: from[0], to: from[1])];
    case TimelineAction.lookOwn || TimelineAction.skip:
      return const [];
  }
}

/// The banner's line for [step], from [StoryCopy.line]: the role that acted
/// ("Doppelganger" for a Doppelganger's follow-up), its name, and what came
/// of it, read off the cards of [timeline].
String _lineOf(
  TimelineStep step,
  NightTimeline timeline,
  String Function(int id) name,
) {
  final actor = step.actors.isEmpty ? null : step.actors.first;
  final followUp =
      step.role != RoleId.doppelganger &&
      step.doppelgangerActors.isNotEmpty &&
      step.doppelgangerActors.length == step.actors.length;
  final role = followUp
      ? RoleId.doppelganger.displayName
      : step.role.displayName;
  String roleOf(String card) => timeline.cards[card]!.role.displayName;
  final players = [
    for (final l in step.lookedAt)
      if (l.place case PlayerPlace(:final playerId)) (playerId, l.cardId),
  ];
  String line(
    StoryAct act, {
    String? as,
    List<String> names = const [],
    String other = '',
    String third = '',
    String seen = '',
    bool same = false,
  }) => StoryCopy.line(
    act,
    role: as ?? role,
    name: actor == null ? '' : name(actor),
    names: names,
    other: other,
    third: third,
    seen: seen,
    same: same,
  );

  switch (step.action) {
    case TimelineAction.copy:
      final copied = players.firstOrNull;
      return line(
        StoryAct.copies,
        other: copied == null ? '' : name(copied.$1),
        seen:
            step.copiedRole?.displayName ??
            (copied == null ? '' : roleOf(copied.$2)),
      );
    case TimelineAction.seeTeam:
      final team = step.team.map(name).toList();
      if (step.role == RoleId.minion) return line(StoryAct.minion, names: team);
      if (team.length < 2) return line(StoryAct.alone);
      return line(
        step.role == RoleId.mason ? StoryAct.masons : StoryAct.werewolves,
        names: team,
      );
    case TimelineAction.peekPlayer:
      final seen = players.firstOrNull;
      return line(
        StoryAct.seesPlayer,
        other: seen == null ? '' : name(seen.$1),
        seen: seen == null ? '' : roleOf(seen.$2),
      );
    case TimelineAction.peekCenter:
      if (step.lookedAt.length >= 2) return line(StoryAct.seesMiddle);
      return line(
        StoryAct.peeksMiddle,
        as: followUp ? null : StoryCopy.loneWerewolf,
      );
    case TimelineAction.swapWithPlayer:
      final other = step.moves
          .map((m) => m.from)
          .whereType<PlayerPlace>()
          .where((p) => !step.actors.contains(p.playerId))
          .firstOrNull;
      return line(
        StoryAct.takes,
        other: other == null ? '' : name(other.playerId),
      );
    case TimelineAction.swapOthers:
      final from = [
        for (final m in step.moves)
          if (m.from case PlayerPlace(:final playerId)) name(playerId),
      ];
      return line(
        StoryAct.swaps,
        other: from.firstOrNull ?? '',
        third: from.length < 2 ? '' : from[1],
      );
    case TimelineAction.swapWithCenter:
      return line(StoryAct.swapsMiddle);
    case TimelineAction.lookOwn || TimelineAction.skip:
      final own = step.lookedAt.firstOrNull?.cardId;
      final dealt = actor == null ? null : timeline.dealt.players[actor];
      return line(
        StoryAct.wakes,
        same: own == dealt,
        seen: own == null ? '' : roleOf(own),
      );
  }
}
