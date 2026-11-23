import 'package:flutter/widgets.dart';

import '../../../../design_system/copy/copy.dart';
import '../../../../design_system/models/role.dart';
import '../../../../design_system/primitives/board_pieces.dart';
import '../../../../design_system/primitives/death_mark.dart';
import '../../../../design_system/primitives/one_light.dart';
import '../../../../design_system/primitives/paper_pin.dart';
import '../../../../design_system/primitives/twine.dart';
import '../../../../design_system/primitives/vote_tag.dart';
import '../../../../design_system/primitives/you_seal.dart';
import '../../../../design_system/skin/skin.dart';
import '../../domain/end_board.dart';
import '../../domain/end_board_metrics.dart';

// The pieces of a card on the settled board, each at the place the plan gave
// it, in the board's coordinates shifted by [origin] (the board's frame in the
// scrolling content). Nothing here decides a size or a place.

BoardPaper paperOf(EndCardLook look) => switch (look) {
  EndCardLook.winner => BoardPaper.winner,
  EndCardLook.loser => BoardPaper.loser,
  EndCardLook.werewolfWon => BoardPaper.werewolfWon,
  EndCardLook.werewolfLost => BoardPaper.werewolfLost,
};

/// What a screen reader says for a card: the name (and that it is you, or the
/// Hunter's pick), the role (and the dealt one), won, hanged, the votes.
String spokenCard(EndCard c, EndBoardPlan plan) {
  final hunter = plan.picks.where((p) => p.pickId == c.id).firstOrNull;
  final words = [
    if (c.you)
      EndCopy.cardYou.fill({'name': c.name})
    else if (hunter != null)
      EndCopy.cardPicked.fill({'name': c.name, 'hunter': hunter.hunterName})
    else
      EndCopy.cardName.fill({'name': c.name}),
    if (c.dealt != null)
      EndCopy.wasRole.fill({
        'now': c.strip.displayName,
        'dealt': c.dealt!.displayName,
      })
    else
      EndCopy.cardRole.fill({'role': c.strip.displayName}),
    if (c.hanged) EndCopy.hangedWord else if (c.won) EndCopy.wonWord,
    if (c.tags.isNotEmpty)
      EndCopy.votes.fill({
        'names': c.tags.map((t) => t.name).join(EndCopy.listComma),
      }),
  ];
  return words.join(' ');
}

/// The twine of every strand: from the pin at the card's foot to the hole of
/// its last tag, one length, sagging, with a paper shadow away from the light.
class StrandTwines extends StatelessWidget {
  const StrandTwines({super.key, required this.plan, required this.origin});

  final EndBoardPlan plan;
  final Offset origin;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      for (final c in plan.cards)
        if (c.pin != null)
          for (final last in _lastOfEachColumn(c))
            Positioned.fill(
              child: LitAt(
                rect: c.reach,
                child: Transform.translate(
                  offset: origin,
                  child: Twine(route: _route(c, last)),
                ),
              ),
            ),
    ],
  );

  /// The last tag of each of the strand's columns: a twine runs to each.
  static List<Rect> _lastOfEachColumn(EndCard c) => [
    for (final column in {for (final t in c.tags) t.column})
      c.tags.lastWhere((t) => t.column == column).rect,
  ];

  TwineRoute _route(EndCard c, Rect last) {
    final from = c.pin!.center;
    final to = Offset(last.left + VoteTag.holeAt, last.center.dy);
    final middle = Offset.lerp(from, to, 0.5)!;
    return TwineRoute(from, middle + const Offset(-10, 0), to);
  }
}

/// The Hunter's twine between the two cards: bone, as every twine that is not
/// a Werewolf's (the Hunter is the village's).
class HunterTwine extends StatelessWidget {
  const HunterTwine({
    super.key,
    required this.plan,
    required this.pick,
    required this.origin,
  });

  final EndBoardPlan plan;
  final EndPick pick;
  final Offset origin;

  @override
  Widget build(BuildContext context) {
    final a = plan.card(pick.hunterId), b = plan.card(pick.pickId);
    final avoid = [
      for (final c in plan.cards)
        if (c.id != a.id && c.id != b.id) c.leaned,
    ];
    return Positioned.fill(
      child: LitAt(
        rect: pick.slip,
        child: Transform.translate(
          offset: origin,
          child: Twine(route: TwineRoute.between(a.rect, b.rect, avoid: avoid)),
        ),
      ),
    );
  }
}

/// One card: the small dealt card behind it, the card, then the ribbon and
/// the "you" seal over it, all tilted about the card's own centre.
class EndCardView extends StatelessWidget {
  const EndCardView({
    super.key,
    required this.card,
    required this.plan,
    required this.origin,
  });

  final EndCard card;
  final EndBoardPlan plan;
  final Offset origin;

  @override
  Widget build(BuildContext context) {
    final c = card;
    final skin = context.skin;
    final box = c.reach.inflate(2);
    // The card's own widgets in a box of its reach, placed by the plan.
    Offset local(Rect r) => r.topLeft - box.topLeft;
    return Positioned(
      left: box.left + origin.dx,
      top: box.top + origin.dy,
      width: box.width,
      height: box.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (c.dealt != null)
            Positioned(
              left: local(c.dealtRect!).dx,
              top: local(c.dealtRect!).dy,
              width: c.dealtRect!.width,
              height: c.dealtRect!.height,
              child: LitAt(
                rect: c.dealtRect!,
                child: DealtCard(
                  role: c.dealt!,
                  size: c.dealtRect!.size,
                  rect: c.dealtRect!,
                ),
              ),
            ),
          Positioned(
            left: local(c.rect).dx,
            top: local(c.rect).dy,
            width: c.rect.width,
            height: c.rect.height,
            child: BoardCard(
              name: c.name,
              role: c.face,
              strip: c.strip.displayName,
              paper: paperOf(c.look),
              size: c.rect.size,
              portraitWidth: c.portraitWidth,
              rect: c.rect,
              angle: c.angle,
              raised: c.hanged,
              headerHeight: c.header,
              stripHeight: c.stripHeight,
              semantics: spokenCard(c, plan),
            ),
          ),
          if (c.ribbonRect != null)
            Positioned(
              left: local(c.ribbonRect!).dx,
              top: local(c.ribbonRect!).dy,
              width: c.ribbonRect!.width,
              height: c.ribbonRect!.height,
              child: LitAt(
                rect: c.ribbonRect!,
                child: DeathRibbon(width: c.ribbonRect!.width),
              ),
            ),
          if (c.sealRect != null)
            Positioned(
              left: local(c.sealRect!).dx,
              top: local(c.sealRect!).dy,
              width: c.sealRect!.width,
              height: c.sealRect!.height,
              child: LitAt(
                rect: c.sealRect!,
                child: YouSeal(token: c.token, size: c.sealRect!.width),
              ),
            ),
          if (c.pin != null)
            Positioned(
              left: local(c.pin!).dx,
              top: local(c.pin!).dy,
              child: LitAt(
                rect: c.pin!,
                child: PaperPin(ink: skin.paper.text, size: EndMetrics.pin),
              ),
            ),
        ],
      ),
    );
  }
}

/// The tags of a card's strand, one under the other.
class EndTagsView extends StatelessWidget {
  const EndTagsView({super.key, required this.card, required this.origin});

  final EndCard card;
  final Offset origin;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      for (final t in card.tags)
        Positioned(
          left: t.rect.left + origin.dx,
          top: t.rect.top + origin.dy,
          width: t.rect.width,
          child: LitAt(
            rect: t.rect,
            child: VoteTag(
              name: t.name,
              token: t.token,
              maxWidth: t.rect.width,
              height: t.rect.height,
            ),
          ),
        ),
    ],
  );
}
