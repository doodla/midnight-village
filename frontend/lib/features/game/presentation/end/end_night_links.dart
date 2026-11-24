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
Map<int, Rect>? nightLiftedOf(
  EndBoardPlan plan,
  StoryStep? step, {
  Map<int, Offset> docked = const {},
  double scroll = 0,
}) {
  if (step == null || step.actors.isEmpty) return const {};
  final middles = _middlesOf(step);
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
  final size = _middleSize(plan, step);
  final lifted = <int, Rect>{};
  for (final i in middles) {
    final at = nightMiddleAt(
      plan,
      actor: lying(actor.leaned, actor.id),
      size: size,
      taken: taken,
      scroll: scroll,
    );
    if (at == null) return null;
    lifted[i] = at;
    taken.add(at);
  }
  return lifted;
}

List<int> _middlesOf(StoryStep step) => [
  for (final p in step.places)
    if (p is CenterPlace) p.index,
];

/// A middle card lifted for a step: as wide as the widest card, as tall as
/// the actor's card without its name.
Size _middleSize(EndBoardPlan plan, StoryStep step) {
  final actor = plan.card(step.actors.first);
  final widest = plan.cards
      .map((c) => c.rect.width)
      .reduce((a, b) => a > b ? a : b);
  return Size(widest, actor.rect.height - actor.header);
}

/// The step shown, as the night board lays it.
typedef NightStep = ({
  /// How far each card is moved for the step (lifted, or slid down).
  Map<int, Offset> docked,

  /// The middle cards the step is about, where they lie on the board.
  Map<int, Rect> lifted,

  /// How far the lantern slid down.
  Offset lantern,

  /// The room the step opened in the board ([nightOpeningOf]).
  double opened,

  /// Where the board stands for the step.
  double scroll,
  List<NightLink> links,
});

/// The step shown, as the night board lays it: where each card lies and
/// its links. Where a card the step lifts finds no empty board in the
/// window, or a link cannot run clear of every other card, the step opens
/// the board under the one who acted and lays its other cards there
/// ([nightOpeningOf]): nothing ever lies on a card, a name or a seal.
NightStep nightStepOf(
  EndBoardPlan plan,
  StoryStep? step, {
  required List<int> players,
  required Offset origin,
  bool deal = false,
}) {
  final view = nightViewOf(plan, players, deal: deal);
  var docked = view.docked;
  var lantern = Offset.zero;
  var opened = 0.0;
  var scroll = view.scroll;
  var lifted = view.open
      ? null
      : nightLiftedOf(plan, step, docked: docked, scroll: scroll);
  List<NightLink> tie() => nightLinksOf(
    plan,
    step,
    origin: origin,
    docked: docked,
    lifted: lifted ?? const {},
    lantern: lantern,
    scroll: scroll,
  );
  var links = lifted == null ? null : tie();
  final unclear = links == null || links.any((l) => !l.link.clear);
  if (step != null && step.actors.isNotEmpty && unclear && plan.scrolls) {
    final middles = _middlesOf(step);
    final open = nightOpeningOf(
      plan,
      actor: step.actors.first,
      players: [
        for (final p in step.places)
          if (p is PlayerPlace) p.playerId,
      ],
      middles: middles.length,
      middleSize: middles.isEmpty ? Size.zero : _middleSize(plan, step),
    );
    docked = open.docked;
    lantern = open.lantern;
    opened = open.height;
    scroll = open.scroll;
    lifted = {for (final (k, i) in middles.indexed) i: open.middles[k]};
    links = tie();
  }
  return (
    docked: docked,
    lifted: lifted ?? const {},
    lantern: lantern,
    opened: opened,
    scroll: scroll,
    links: links ?? tie(),
  );
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
/// in it), each tied between its two cards as they lie ([docked]; [lifted]:
/// the middle cards on the board; [lantern]: how far the lantern slid),
/// round every other card, seal and the lantern, inside the frame.
List<NightLink> nightLinksOf(
  EndBoardPlan plan,
  StoryStep? step, {
  required Offset origin,
  Map<int, Offset> docked = const {},
  Map<int, Rect> lifted = const {},
  Offset lantern = Offset.zero,
  double scroll = 0,
}) {
  if (step == null) return const [];
  LaidCard laid(CardPlace place) => switch (place) {
    PlayerPlace(:final playerId) => LaidCard(
      plan.card(playerId).rect.shift(origin + (docked[playerId] ?? .zero)),
      plan.card(playerId).angle,
    ),
    CenterPlace(:final index) => LaidCard(lifted[index]!.shift(origin)),
  };
  // The board's window where it stands for the step.
  final frame = Rect.fromLTWH(
    origin.dx,
    origin.dy + scroll,
    plan.boardWidth,
    plan.scrolls ? plan.viewHeight - EndMetrics.lip : plan.boardHeight,
  );
  final places = [
    ...step.places,
    for (final c in plan.cards)
      if (!step.places.contains(PlayerPlace(c.id))) PlayerPlace(c.id),
  ];
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
                plan.lantern.shift(origin + lantern),
                ...seals,
                for (final p in places)
                  if (p != t.from && p != t.to) laid(p).bounds,
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
