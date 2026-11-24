import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../../design_system/primitives/board_pieces.dart';
import '../../../../design_system/primitives/card_link.dart';
import '../../../../design_system/primitives/one_light.dart';
import '../../../../design_system/primitives/twine.dart';
import '../../../../design_system/skin/paper_parts.dart';
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
// ([nightLiftedOf]), so no thread leaves the board; where no lift leaves
// every name clear, it stays in the foot, raised there, and its thread runs
// down to it (end_night_foot.dart).

/// How much of the back card of a fanned pair shows past the front one,
/// across: its strip all, and this share of its face.
const _fanShows = 2 / 3;

/// The middle cards [step] is about, each where it lies on the board for
/// the step (in the board's frame, as [EndBoardPlan]'s rects): beside the
/// card of the one who acted, clear of every card, seal, name and the
/// lantern; side by side, or else (two of them) fanned, the second over the
/// first, each showing its strip and the most of its face. Where neither
/// leaves every name clear: none (empty), and the cards stay in the foot.
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
  final own = {
    for (final p in step.places)
      if (p is PlayerPlace) p.playerId,
  };
  final widest = plan.cards
      .map((c) => c.rect.width)
      .reduce((a, b) => a > b ? a : b);
  final size = Size(widest, actor.rect.height - actor.header);
  final names = [
    for (final c in plan.cards) nightNameOf(c, docked[c.id] ?? Offset.zero),
  ];
  final under = [
    for (final c in plan.cards)
      if (own.contains(c.id) && c.id != actor.id) lying(c.leaned, c.id),
  ];
  // Where the next card of [size] may lie, clear of [taken] (every card and
  // seal, and the cards lifted before it) and of the step's own ([mine]).
  Rect? place(Size size, List<Rect> taken, List<Rect> mine) =>
      nightMiddleClearAt(
        plan,
        actor: lying(actor.leaned, actor.id),
        size: size,
        taken: taken,
        step: mine,
        names: names,
        under: under,
        scroll: scroll,
      );
  List<Rect> taken() => [
    plan.lantern,
    for (final c in plan.cards) ...[
      lying(c.leaned, c.id),
      if (c.sealRect case final seal?) lying(seal, c.id),
    ],
  ];
  List<Rect> mine() => [
    for (final c in plan.cards)
      if (own.contains(c.id)) ...[
        lying(c.leaned, c.id),
        if (c.sealRect case final seal?) lying(seal, c.id),
      ],
  ];
  // Side by side.
  final apart = <int, Rect>{};
  final clearOf = taken(), steps = mine();
  for (final i in middles) {
    final at = place(size, clearOf, steps);
    if (at == null) break;
    apart[i] = at;
    clearOf.add(at);
    steps.add(at);
  }
  if (apart.length == middles.length) return apart;
  // Fanned: the second lies over the first's far side, raised by the
  // first's strip, so its strip and the most of its face show.
  if (middles.length == 2) {
    final rise = BoardCard.stripUp + actor.stripHeight + BoardCard.stripUp;
    final across = size.width * _fanShows;
    final pair = Size(across + size.width, size.height + rise);
    if (place(pair, taken(), mine()) case final at?) {
      return {
        middles.first: Rect.fromLTWH(
          at.left,
          at.top + rise,
          size.width,
          size.height,
        ),
        middles.last: Rect.fromLTWH(
          at.left + across,
          at.top,
          size.width,
          size.height,
        ),
      };
    }
  }
  return const {};
}

/// Whether the step's middle cards stay in the foot for [step] (none can be
/// lifted with every name clear, [nightLiftedOf]): the board then stands
/// with the one who acted as low in the window as it can, over the foot.
bool nightInFoot(EndBoardPlan plan, StoryStep? step, List<int> players) {
  if (!_aboutMiddles(step)) return false;
  final view = nightViewOf(plan, players);
  return nightLiftedOf(
    plan,
    step,
    docked: view.docked,
    scroll: view.scroll,
  ).isEmpty;
}

/// Whether [step] is about a middle card, and someone acted for it.
bool _aboutMiddles(StoryStep? step) =>
    step != null &&
    step.actors.isNotEmpty &&
    step.places.any((p) => p is CenterPlace);

/// Where the board stands for [step] ([nightViewOf]): as low as it can with
/// the step's cards in view where its middle cards stay in the foot
/// ([nightInFoot]), so the thread down to them is short.
({double scroll, Map<int, Offset> docked}) nightStandOf(
  EndBoardPlan plan,
  StoryStep? step,
  List<int> players, {
  bool deal = false,
}) => !deal && nightInFoot(plan, step, players)
    ? _lowView(plan, players)
    : nightViewOf(plan, players, deal: deal);

/// The board standing for a step whose middle cards stay in the foot: as
/// low as it can with the step's cards whole in the window, but no lower
/// than leaves the cards under them hidden under the foot's lip, so the
/// one who acted is the lowest card in view and its thread runs straight
/// down.
({double scroll, Map<int, Offset> docked}) _lowView(
  EndBoardPlan plan,
  List<int> players,
) {
  final view = nightViewOf(plan, players, deal: true);
  if (!plan.scrolls || players.isEmpty) return view;
  final seen = plan.viewHeight - EndMetrics.lip;
  final step = [
    for (final id in players)
      if (plan.card(id).sealRect case final seal?)
        plan.card(id).leaned.expandToInclude(seal)
      else
        plan.card(id).leaned,
  ];
  final bottom = step.map((r) => r.bottom).reduce(math.max);
  final under = [
    for (final c in plan.cards)
      if (!players.contains(c.id) && c.leaned.center.dy > bottom) c.leaned.top,
  ];
  if (under.isEmpty) return view;
  final top = step.map((r) => r.top).reduce(math.min);
  // The cards under them just under the lip: lower than the board stands
  // for the deal, where their tops would peek over it.
  final low = under.reduce(math.min) - seen;
  // Only while the step's cards stay whole in the window.
  if (low < 0 || low >= view.scroll || top < low) return view;
  return (scroll: low, docked: view.docked);
}

/// The step shown, as the night board lays it: where each card lies
/// ([docked], [lifted], [level]) and its links. Where a link cannot run
/// clear of every other card, its far card is lifted beside the near one
/// for the step, as a middle card is ([nightMiddleAt]), and the links are
/// tied again. [inFoot]: whether the step's middle cards stay in the foot,
/// as the foot was told ([EndNight.laidOut]), so the two never both hold a
/// card; null: as this [plan] has it.
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
  bool? inFoot,
  double head = TwinePainter.headLength,
}) {
  final first = nightViewOf(plan, players, deal: deal);
  final lifted = inFoot ?? false
      ? const <int, Rect>{}
      : nightLiftedOf(plan, step, docked: first.docked, scroll: first.scroll);
  // In the foot: the board stands low ([nightStandOf]), and the middle
  // cards' threads are the page's (end_night_foot.dart).
  final low = inFoot ?? (lifted.isEmpty && _aboutMiddles(step));
  final view = low ? _lowView(plan, players) : first;
  final scroll = view.scroll;
  final docked = {...view.docked};
  final level = nightLevel(docked, players.length);
  List<NightLink> tie() => nightLinksOf(
    plan,
    head: head,
    step,
    origin: origin,
    docked: docked,
    level: level,
    lifted: lifted,
    scroll: scroll,
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
        names: [
          for (final c in plan.cards)
            if (c.id != playerId) nightNameOf(c, docked[c.id] ?? Offset.zero),
        ],
        under: [
          for (final c in plan.cards)
            if (own.contains(c.id)) lying(c),
        ],
        scroll: scroll,
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
  double head = TwinePainter.headLength,
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
  // The step's cards on the board (a middle card kept in the foot is not).
  final shown = [
    for (final p in step.places)
      if (p is PlayerPlace || lifted.containsKey(_index(p))) p,
  ];
  final mine = [for (final p in shown) laid(p).bounds];
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
              head: head,
              avoid: [
                plan.lantern.shift(origin),
                ...seals,
                for (final p in shown)
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
/// paint, not a build): [linksNow] is what the tests read.
class NightLinks extends StatelessWidget {
  const NightLinks({
    super.key,
    required this.night,
    required this.links,
    required this.werewolf,
    this.measured,
    this.moved,
  });

  final EndNight night;
  final List<NightLink> links;

  /// Links tied as the cards lie when painted (a thread down to the foot,
  /// [NightFootLinks]), in place of [links]; painted again as [moved] moves.
  final List<NightLink> Function()? measured;
  final Listenable? moved;

  /// The Werewolf team's act: red.
  final bool werewolf;

  /// The links as they are drawn now.
  List<NightLink> linksNow() => measured?.call() ?? links;

  @override
  Widget build(BuildContext context) {
    final ground = context.ground;
    return CustomPaint(
      size: Size.infinite,
      painter: _LinksPainter(
        night: night,
        links: linksNow,
        color: werewolf ? context.skin.parts.werewolfWonPaper : ground.text,
        shadow:
            ground.elevation.card.layers.firstOrNull?.color ?? ground.shadow,
        light: OneLight.maybeOf(context),
        parts: context.skin.parts,
        moved: moved,
        key: measured == null ? links : null,
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
    required this.parts,
    required this.key,
    Listenable? moved,
  }) : step = night.step ?? 0,
       super(repaint: Listenable.merge([night.clock, moved]));

  final EndNight night;
  final int step;
  final List<NightLink> Function() links;

  /// What the links are (null: measured as painted, so always painted).
  final Object? key;
  final Color color;
  final Color shadow;
  final OneLight? light;

  /// The links' sizes (the skin's).
  final PaperParts parts;

  @override
  void paint(Canvas canvas, Size size) {
    final drawn = night.drawn();
    if (drawn <= 0) return;
    for (final (from: _, to: _, :link) in links()) {
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
        width: parts.linkWidth,
        headSize: parts.linkHead,
        dotSize: parts.linkDot,
        dash: parts.linkDash,
        gap: parts.linkGap,
      ).paint(canvas, size);
    }
  }

  @override
  bool shouldRepaint(_LinksPainter old) =>
      old.step != step ||
      old.night != night ||
      key == null ||
      old.key != key ||
      old.color != color ||
      old.parts != parts;
}
