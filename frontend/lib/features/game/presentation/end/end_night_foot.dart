import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../../design_system/primitives/board_pieces.dart';
import '../../../../design_system/primitives/card_link.dart';
import '../../../../design_system/skin/skin.dart';
import '../../domain/end_board_metrics.dart';
import '../../domain/night_timeline.dart';
import 'end_night.dart';
import 'end_night_links.dart';

// A step whose middle cards cannot be lifted onto the board with every name
// clear ([nightInFoot]): the cards stay in the foot, raised there, and the
// thread runs from the one who acted down over the board's lip to each, on
// the page over both, the shortest way round every other card. The board
// stands with the one who acted low in its window ([nightStandOf]).

/// The threads of the step shown down to its middle cards in the foot, in
/// the page's frame ([boardTop]: where the board's window shows the board).
/// Nothing while the middle cards are lifted onto the board.
class NightFootLinks extends StatelessWidget {
  const NightFootLinks({super.key, required this.boardTop});

  final double boardTop;

  @override
  Widget build(BuildContext context) {
    final night = EndNightScope.maybeOf(context);
    if (night == null || !night.on || night.current == null) {
      return const SizedBox.shrink();
    }
    final head = context.skin.parts.linkHead;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: ValueListenableBuilder(
            valueListenable: night.laidOut,
            builder: (context, _, _) => Builder(
              builder: (context) => NightLinks(
                night: night,
                links: const [],
                werewolf: night.current?.werewolf ?? false,
                moved: night.scrolled,
                measured: () => _measure(context, night, head),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<NightLink> _measure(BuildContext context, EndNight night, double head) {
    final step = night.current, plan = night.laidOut.value;
    final page = context.findRenderObject() as RenderBox?;
    if (step == null || plan == null || page == null || !page.hasSize) {
      return const [];
    }
    if (!nightInFoot(plan, step, nightPlayersOf(plan, night))) return const [];
    // Where the board shows, above the foot's lip.
    final window = Rect.fromLTRB(
      0,
      boardTop,
      page.size.width,
      boardTop + plan.viewHeight - EndMetrics.lip,
    );
    LaidCard? laid(CardPlace place) {
      final at = night.placeKey(place).currentContext;
      final box = at?.findRenderObject() as RenderBox?;
      if (at == null || box == null || !box.attached || !box.hasSize) {
        return null;
      }
      final rect = box.localToGlobal(Offset.zero, ancestor: page) & box.size;
      // A player's card scrolled out of the window is not there.
      if (place is PlayerPlace && !(rect.intersect(window).height > 1)) {
        return null;
      }
      return LaidCard(rect, _angleIn(at));
    }

    // Down as far as the foot of the step's middle cards, never past them
    // under the foot's words.
    final kept = [
      for (final p in step.places)
        if (p is CenterPlace) ?laid(p)?.bounds.bottom,
    ];
    if (kept.isEmpty) return const [];
    final frame = Rect.fromLTRB(
      0,
      boardTop,
      page.size.width,
      kept.reduce(math.max),
    );

    final avoid = [
      for (final place in night.placed)
        if (!step.places.contains(place))
          if (laid(place) case final card?)
            place is PlayerPlace ? card.bounds.intersect(window) : card.bounds,
      // The seals, where their cards lie.
      for (final c in plan.cards)
        if (c.sealRect case final seal?)
          if (laid(PlayerPlace(c.id)) case final card?)
            seal.shift(card.rect.topLeft - c.rect.topLeft),
    ];
    return [
      for (final t in step.threads)
        if (t.from is CenterPlace || t.to is CenterPlace)
          if ((laid(t.from), laid(t.to)) case (final a?, final b?))
            (
              from: t.from,
              to: t.to,
              link: CardLink.between(
                a,
                b,
                kind: linkKindOf(step.kind),
                frame: frame,
                head: head,
                avoid: [
                  ...avoid,
                  for (final p in step.places)
                    if (p != t.from && p != t.to) ?laid(p)?.bounds,
                ],
              ),
            ),
    ];
  }
}

/// The turn of the card drawn under [context] (0 where none is).
double _angleIn(BuildContext context) {
  double? angle;
  void visit(Element e) {
    if (angle != null) return;
    if (e.widget case BoardCard(angle: final a)) {
      angle = a;
      return;
    }
    e.visitChildren(visit);
  }

  context.visitChildElements(visit);
  return angle ?? 0;
}

/// The middle cards the step shown is about that stay in the foot for it,
/// raised there ([nightInFoot]); none before the board is planned.
Set<int> nightFootRaised(EndNight night) {
  final plan = night.laidOut.value, step = night.current;
  if (plan == null || !nightInFoot(plan, step, nightPlayersOf(plan, night))) {
    return const {};
  }
  return {
    for (final p in step!.places)
      if (p is CenterPlace) p.index,
  };
}
