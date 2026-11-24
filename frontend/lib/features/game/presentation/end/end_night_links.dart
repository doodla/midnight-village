import 'package:flutter/widgets.dart';

import '../../../../design_system/primitives/card_link.dart';
import '../../../../design_system/primitives/one_light.dart';
import '../../../../design_system/primitives/twine.dart';
import '../../../../design_system/skin/skin.dart';
import '../../domain/end_board.dart';
import '../../domain/end_board_cards.dart';
import '../../domain/end_board_metrics.dart';
import '../../domain/end_night_view.dart';
import '../../domain/end_story.dart';
import '../../domain/night_timeline.dart';
import 'end_night.dart';

// The links of the step shown (split from end_night_board.dart): one
// [CardLink] per thread of the step, tied between the cards as they lie on
// the night board, turned and lifted as drawn. A middle card the step is
// about is lifted onto the board beside the one who acted for the step
// ([nightLiftedOf]), so no thread leaves the board.

/// The middle cards [step] is about, each where it lies on the board for
/// the step (in the board's frame, as [EndBoardPlan]'s rects): beside the
/// card of the one who acted, clear of every card, seal and the lantern.
Map<int, Rect> nightLiftedOf(
  EndBoardPlan plan,
  StoryStep? step, {
  Map<int, Offset> docked = const {},
  double scroll = 0,
}) {
  if (step == null || step.actors.isEmpty) return const {};
  final middles = [
    for (final p in step.places)
      if (p is CenterPlace) p.index,
  ];
  if (middles.isEmpty) return const {};
  final actor = plan.card(step.actors.first);
  Rect lying(Rect r, int id) => r.shift(docked[id] ?? Offset.zero);
  final taken = [
    plan.lantern,
    for (final c in plan.cards) ...[
      lying(c.leaned, c.id),
      if (c.sealRect case final seal?) lying(seal, c.id),
    ],
  ];
  final own = {
    for (final p in step.places)
      if (p is PlayerPlace) p.playerId,
  };
  final mine = [
    for (final c in plan.cards)
      if (own.contains(c.id)) ...[
        lying(c.leaned, c.id),
        if (c.sealRect case final seal?) lying(seal, c.id),
      ],
  ];
  final widest = plan.cards
      .map((c) => c.rect.width)
      .reduce((a, b) => a > b ? a : b);
  final size = Size(widest, actor.rect.height - actor.header);
  final lifted = <int, Rect>{};
  for (final i in middles) {
    final at = nightMiddleAt(
      plan,
      actor: lying(actor.leaned, actor.id),
      size: size,
      taken: taken,
      step: mine,
      scroll: scroll,
    );
    lifted[i] = at;
    taken.add(at);
    mine.add(at);
  }
  return lifted;
}

/// The step shown, as the night board lays it: where each card lies
/// ([docked], [lifted], [level]) and its links. Where a link cannot run
/// clear of every other card, its far card is lifted beside the near one
/// for the step, as a middle card is ([nightMiddleAt]), and the links are
/// tied again.
({
  Map<int, Offset> docked,
  Map<int, Rect> lifted,
  bool level,
  List<NightLink> links,
})
nightStepOf(
  EndBoardPlan plan,
  StoryStep? step, {
  required List<int> players,
  required Offset origin,
  bool deal = false,
}) {
  final view = nightViewOf(plan, players, deal: deal);
  final docked = {...view.docked};
  final level = nightLevel(docked, players.length);
  final lifted = nightLiftedOf(plan, step, docked: docked, scroll: view.scroll);
  List<NightLink> tie() => nightLinksOf(
    plan,
    step,
    origin: origin,
    docked: docked,
    level: level,
    lifted: lifted,
    scroll: view.scroll,
  );
  var links = tie();
  final moved = <int>{};
  for (final l in links) {
    if (l.link.clear || step == null) continue;
    if (l.to case PlayerPlace(:final playerId) when !moved.contains(playerId)) {
      final near = switch (l.from) {
        PlayerPlace(:final playerId) =>
          plan.card(playerId).leaned.shift(docked[playerId] ?? Offset.zero),
        CenterPlace(:final index) => lifted[index]!,
      };
      final far = plan.card(playerId);
      Rect lying(EndCard c) => c.leaned.shift(docked[c.id] ?? Offset.zero);
      final own = {
        for (final p in step.places)
          if (p is PlayerPlace && p.playerId != playerId) p.playerId,
      };
      final at = nightMiddleAt(
        plan,
        actor: near,
        size: far.leaned.size,
        taken: [
          plan.lantern,
          ...lifted.values,
          for (final c in plan.cards)
            if (c.id != playerId) ...[
              lying(c),
              if (c.sealRect case final seal?)
                seal.shift(docked[c.id] ?? Offset.zero),
            ],
        ],
        step: [
          ...lifted.values,
          for (final c in plan.cards)
            if (own.contains(c.id)) lying(c),
        ],
        scroll: view.scroll,
      );
      docked[playerId] = at.topLeft - far.leaned.topLeft;
      moved.add(playerId);
      links = tie();
    }
  }
  return (docked: docked, lifted: lifted, level: level, links: links);
}

/// What a step's kind says as a link.
LinkKind linkKindOf(StoryKind kind) => switch (kind) {
  StoryKind.team => LinkKind.team,
  StoryKind.copy || StoryKind.look => LinkKind.look,
  StoryKind.take => LinkKind.take,
  StoryKind.swap => LinkKind.swap,
};

/// One link of the step shown: its places, and the link drawn between them.
typedef NightLink = ({CardPlace from, CardPlace to, CardLink link});

/// The links of [step] in the board's content ([origin]: the frame's place
/// in it), each tied between its two cards as they lie ([docked], [level]:
/// lifted and drawn level; [lifted]: the middle cards on the board), round
/// every other card, seal and the lantern, inside the frame.
List<NightLink> nightLinksOf(
  EndBoardPlan plan,
  StoryStep? step, {
  required Offset origin,
  Map<int, Offset> docked = const {},
  bool level = false,
  Map<int, Rect> lifted = const {},
  double scroll = 0,
}) {
  if (step == null) return const [];
  LaidCard laid(CardPlace place) => switch (place) {
    PlayerPlace(:final playerId) => () {
      final c = plan.card(playerId);
      final lift = docked[playerId];
      return LaidCard(
        c.rect.shift(origin + (lift ?? Offset.zero)),
        level && lift != null ? 0 : c.angle,
      );
    }(),
    CenterPlace(:final index) => LaidCard(lifted[index]!.shift(origin)),
  };
  // The board's window where it stands for the step.
  final frame = Rect.fromLTWH(
    origin.dx,
    origin.dy + scroll,
    plan.boardWidth,
    plan.scrolls ? plan.viewHeight - EndMetrics.lip : plan.boardHeight,
  );
  final mine = [for (final p in step.places) laid(p).bounds];
  final seals = [
    for (final c in plan.cards)
      if (c.sealRect case final seal?)
        seal.shift(origin + (docked[c.id] ?? Offset.zero)),
  ];
  return [
    for (final t in step.threads)
      if (t.from is PlayerPlace || lifted.containsKey(_index(t.from)))
        if (t.to is PlayerPlace || lifted.containsKey(_index(t.to)))
          (
            from: t.from,
            to: t.to,
            link: CardLink.between(
              laid(t.from),
              laid(t.to),
              kind: linkKindOf(step.kind),
              frame: frame,
              avoid: [
                plan.lantern.shift(origin),
                ...seals,
                for (final p in step.places)
                  if (p != t.from && p != t.to) laid(p).bounds,
                // A card the step lifted a card over is under it: the
                // thread may pass over it there.
                for (final c in plan.cards)
                  if (!step.places.contains(PlayerPlace(c.id)) &&
                      !mine.any(
                        laid(PlayerPlace(c.id)).bounds.deflate(2).overlaps,
                      ))
                    laid(PlayerPlace(c.id)).bounds,
              ],
            ),
          ),
  ];
}

int? _index(CardPlace p) => p is CenterPlace ? p.index : null;

/// The step's links, drawn from one end to the other on its clock (a
/// paint, not a build): [links] is what the tests read.
class NightLinks extends StatelessWidget {
  const NightLinks({
    super.key,
    required this.night,
    required this.links,
    required this.werewolf,
  });

  final EndNight night;
  final List<NightLink> links;

  /// The Werewolf team's act: red.
  final bool werewolf;

  @override
  Widget build(BuildContext context) {
    final ground = context.ground;
    return CustomPaint(
      size: Size.infinite,
      painter: _LinksPainter(
        night: night,
        links: links,
        color: werewolf ? context.skin.parts.werewolfWonPaper : ground.text,
        shadow:
            ground.elevation.card.layers.firstOrNull?.color ?? ground.shadow,
        light: OneLight.maybeOf(context),
      ),
    );
  }
}

/// A step's links: each drawn as far as the step's clock has come, its
/// start's end at once and its far end travelling with the thread.
class _LinksPainter extends CustomPainter {
  _LinksPainter({
    required this.night,
    required this.links,
    required this.color,
    required this.shadow,
    required this.light,
  }) : step = night.step ?? 0,
       super(repaint: night.clock);

  final EndNight night;
  final int step;
  final List<NightLink> links;
  final Color color;
  final Color shadow;
  final OneLight? light;

  @override
  void paint(Canvas canvas, Size size) {
    final drawn = night.drawn();
    if (drawn <= 0) return;
    for (final (from: _, to: _, :link) in links) {
      final full = link.route;
      TwinePainter(
        route: TwineRoute(
          full.from,
          Offset.lerp(full.from, full.control, drawn)!,
          full.at(drawn),
        ),
        kind: link.thread,
        tail: link.start,
        tip: link.end,
        color: color,
        shadow: shadow,
        lean: light?.leanFor(full.bounds) ?? 0,
      ).paint(canvas, size);
    }
  }

  @override
  bool shouldRepaint(_LinksPainter old) =>
      old.step != step ||
      old.night != night ||
      old.links != links ||
      old.color != color;
}
