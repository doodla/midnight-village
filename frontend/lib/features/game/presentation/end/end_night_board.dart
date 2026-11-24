import 'package:flutter/widgets.dart';

import '../../../../design_system/copy/copy.dart';
import '../../../../design_system/models/role.dart';
import '../../../../design_system/primitives/board_pieces.dart';
import '../../../../design_system/primitives/end_lantern.dart';
import '../../../../design_system/primitives/one_light.dart';
import '../../../../design_system/primitives/you_seal.dart';
import '../../../../design_system/skin/ground.dart';
import '../../../../design_system/skin/ground_scope.dart';
import '../../../../design_system/skin/paper_parts.dart';
import '../../../../design_system/skin/skin.dart';
import '../../domain/end_board.dart';
import '../../domain/end_board_metrics.dart';
import '../../domain/end_story.dart';
import '../../domain/night_timeline.dart';
import 'end_cards.dart';
import 'end_night.dart';
import 'end_night_links.dart';
import 'end_reveal.dart';

// The board at night (split from end_night.dart): every card where it lies,
// showing the card in front of that player at this step, and the step's own
// thread (one step at a time: earlier steps leave only the faces they
// turned). Built again when the step changes; a tick of the step's clock
// only paints (a card turning, the twine being drawn).

/// The board at night: drawn over the hidden settled board in the board's
/// content, [origin] its frame's place there. Nothing at all by day.
class NightBoard extends StatelessWidget {
  const NightBoard({super.key, required this.plan, required this.origin});

  final EndBoardPlan plan;
  final Offset origin;

  @override
  Widget build(BuildContext context) {
    final night = EndNightScope.maybeOf(context);
    final story = night?.story;
    if (night == null || story == null || !night.on) {
      return const SizedBox.shrink();
    }
    final skin = context.skin;
    final mood = skin.mood;
    final frame = Rect.fromLTWH(
      origin.dx,
      origin.dy,
      plan.boardWidth,
      plan.boardHeight,
    );
    final players = nightPlayersOf(plan, night);
    final laid = nightStepOf(
      plan,
      night.current,
      players: players,
      origin: origin,
      deal: night.opening,
    );
    final docked = laid.docked, lifted = laid.lifted, links = laid.links;
    final lantern = laid.lantern;
    Rect at(Rect r, int id) => r.shift(origin + (docked[id] ?? Offset.zero));
    // The cards lifted to the window's edge for the step lie in front.
    final cards = [
      for (final c in plan.cards)
        if (!docked.containsKey(c.id)) c,
      for (final c in plan.cards)
        if (docked.containsKey(c.id)) c,
    ];
    return GroundScope(
      ground: GroundKind.night,
      child: OneLightScope(
        light: OneLight(nightMoonAt(plan, skin.parts)),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // The felt in the moon's cool light, the lantern out.
            Positioned.fromRect(
              rect: frame,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topLeft,
                      radius: skin.parts.nightFeltReach,
                      colors: [
                        mood.moon.withValues(alpha: mood.moonAlpha / 2),
                        mood.nightBase.withValues(alpha: mood.veilFromAlpha),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: plan.lantern.left + origin.dx + lantern.dx,
              top: plan.lantern.top + origin.dy + lantern.dy,
              // Out: its panes dark in the night's ground.
              child: ExcludeSemantics(
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    mood.nightBase.withValues(alpha: mood.veilMidAlpha),
                    BlendMode.srcATop,
                  ),
                  child: const EndLantern(lit: false),
                ),
              ),
            ),
            for (final c in cards)
              Positioned.fromRect(
                rect: at(c.rect, c.id),
                child: KeyedSubtree(
                  key: night.placeKey(PlayerPlace(c.id)),
                  child: _card(night, c),
                ),
              ),
            for (final c in cards)
              if (c.sealRect case final seal?)
                Positioned.fromRect(
                  rect: at(seal, c.id),
                  child: LitAt(
                    rect: seal,
                    child: YouSeal(token: c.token, size: seal.width),
                  ),
                ),
            // The middle cards lifted for the step, in front.
            for (final MapEntry(key: i, value: r) in lifted.entries)
              Positioned.fromRect(
                rect: r.shift(origin),
                child: KeyedSubtree(
                  key: night.placeKey(CenterPlace(i)),
                  child: _middle(night, i, r),
                ),
              ),
            Positioned.fill(
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: RepaintBoundary(
                    child: NightLinks(
                      night: night,
                      links: links,
                      werewolf: night.current?.werewolf ?? false,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A card at this step: the face it shows, turning to the new one as the
  /// step moves it; at the night's opening turning first from the result.
  Widget _card(EndNight night, EndCard c) {
    final before = night.before.players[c.id];
    final after = night.after.players[c.id];
    if (before == null || after == null) return const SizedBox.shrink();
    final box = Offset.zero & c.rect.size;
    Widget face = before == after
        ? _face(c, after)
        : RevealTurn(
            driver: night.driver,
            value: night.moveTurn,
            backAt: box,
            back: ExcludeSemantics(child: _face(c, before)),
            face: _face(c, after),
          );
    if (night.opening) {
      face = RevealTurn(
        driver: night.driver,
        value: night.dealTurn,
        backAt: box,
        back: ExcludeSemantics(child: EndCardView.faceOf(c, plan)),
        face: face,
      );
    }
    return face;
  }

  /// A middle card lifted onto the board for the step, at [rect]: as the
  /// players' cards are (the actor's portrait and strip), with no name,
  /// turning to its new face as the step moves it.
  Widget _middle(EndNight night, int i, Rect rect) {
    final before = night.before.centre[i], after = night.after.centre[i];
    final actor = plan.card(night.current!.actors.first);
    Widget face(StoryFace f) => BoardCard(
      role: f.face,
      strip: f.strip.displayName,
      paper: paperAtNight(f),
      size: rect.size,
      portraitWidth: actor.portraitWidth,
      rect: rect,
      stripHeight: actor.stripHeight,
      semantics: f.strip.displayName,
    );
    if (before == after) return face(after);
    return RevealTurn(
      driver: night.driver,
      value: night.moveTurn,
      backAt: Offset.zero & rect.size,
      back: ExcludeSemantics(child: face(before)),
      face: face(after),
    );
  }

  Widget _face(EndCard c, StoryFace f) => BoardCard(
    name: c.name,
    role: f.face,
    strip: f.strip.displayName,
    paper: paperAtNight(f),
    size: c.rect.size,
    portraitWidth: c.portraitWidth,
    rect: c.rect,
    angle: c.angle,
    headerHeight: c.header,
    stripHeight: c.stripHeight,
    semantics: [
      EndCopy.cardName.fill({'name': c.name}),
      EndCopy.cardRole.fill({'role': f.strip.displayName}),
    ].join(' '),
  );
}

/// A card's paper at night: the Werewolf team's red, the night's otherwise.
BoardPaper paperAtNight(StoryFace f) =>
    f.face.team == TeamId.werewolf ? BoardPaper.werewolfWon : BoardPaper.night;

/// Where the moon is, in the board's content: the night's one light.
Offset nightMoonAt(EndBoardPlan plan, PaperParts parts) =>
    parts.nightMoonAt +
    Offset(
      parts.nightMoonWidth / 2,
      parts.nightMoonWidth / 2 - plan.boardTop + EndMetrics.roof,
    );

/// The players' cards the step shown is about (at the deal, "you").
List<int> nightPlayersOf(EndBoardPlan plan, EndNight night) => [
  for (final p in night.current?.places ?? const <CardPlace>[])
    if (p is PlayerPlace) p.playerId,
  if (night.current == null)
    for (final c in plan.cards)
      if (c.sealRect != null) c.id,
];
