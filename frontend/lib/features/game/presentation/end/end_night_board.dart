import 'package:flutter/widgets.dart';

import '../../../../design_system/copy/copy.dart';
import '../../../../design_system/layout/space.dart';
import '../../../../design_system/models/role.dart';
import '../../../../design_system/primitives/board_pieces.dart';
import '../../../../design_system/primitives/end_lantern.dart';
import '../../../../design_system/primitives/fit_line.dart';
import '../../../../design_system/primitives/one_light.dart';
import '../../../../design_system/primitives/paper_piece.dart';
import '../../../../design_system/primitives/twine.dart';
import '../../../../design_system/primitives/you_seal.dart';
import '../../../../design_system/skin/dress_style.dart';
import '../../../../design_system/skin/ground.dart';
import '../../../../design_system/skin/ground_scope.dart';
import '../../../../design_system/skin/skin.dart';
import '../../domain/end_board.dart';
import '../../domain/end_board_metrics.dart';
import '../../domain/end_story.dart';
import '../../domain/night_timeline.dart';
import 'end_cards.dart';
import 'end_night.dart';
import 'end_reveal.dart';

// The board at night (split from end_night.dart): every card where it lies,
// showing the card in front of that player at this step, the twines the
// night has tied so far and their number slips. Built again when the step
// changes; a tick of the step's clock only paints (a card turning, the
// twine being drawn).

/// How much an earlier step's twine shows.
const _earlier = 0.55;

/// A number slip on a twine.
const _numberSize = Size(26, 30);

/// Where along its twine a number slip may hang, the middle first.
const _alongs = [0.5, 0.38, 0.62, 0.28, 0.72, 0.18, 0.82];

/// The board at night: drawn over the hidden settled board in the board's
/// content, [origin] its frame's place there, [centre] where the middle cards
/// lie in the board's coordinates (under the foot: a twine to one runs down
/// off the board). Nothing at all by day.
class NightBoard extends StatelessWidget {
  const NightBoard({
    super.key,
    required this.plan,
    required this.origin,
    required this.centre,
  });

  final EndBoardPlan plan;
  final Offset origin;
  final List<Rect> centre;

  @override
  Widget build(BuildContext context) {
    final night = EndNightScope.maybeOf(context);
    final story = night?.story;
    if (night == null || story == null || !night.on) {
      return const SizedBox.shrink();
    }
    final step = night.step!;
    final skin = context.skin;
    final mood = skin.mood;
    final frame = Rect.fromLTWH(
      origin.dx,
      origin.dy,
      plan.boardWidth,
      plan.boardHeight,
    );
    final ties = tiesOf(plan, story, step, origin: origin, centre: centre);
    return GroundScope(
      ground: GroundKind.night,
      child: OneLightScope(
        light: OneLight(nightMoonAt(plan)),
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
                      radius: 1.6,
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
              left: plan.lantern.left + origin.dx,
              top: plan.lantern.top + origin.dy,
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
            for (final c in plan.cards)
              Positioned.fromRect(
                rect: c.rect.shift(origin),
                child: _card(night, c),
              ),
            for (final c in plan.cards)
              if (c.sealRect case final seal?)
                Positioned.fromRect(
                  rect: seal.shift(origin),
                  child: LitAt(
                    rect: seal,
                    child: YouSeal(token: c.token, size: seal.width),
                  ),
                ),
            Positioned.fill(
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: RepaintBoundary(
                    child: _Twines(night: night, ties: ties),
                  ),
                ),
              ),
            ),
            for (final tie in ties)
              if (tie.number case final number?)
                Positioned.fromRect(
                  rect: number,
                  child: ExcludeSemantics(
                    child: tie.step == step
                        ? revealPaint(
                            night.driver,
                            opacity: () => night.landed(),
                            child: _Number(tie.label),
                          )
                        : _Number(tie.label),
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
Offset nightMoonAt(EndBoardPlan plan) =>
    Offset(Space.xl, Space.sm - plan.boardTop + EndMetrics.roof);

/// One twine of the night, or a step's place where it has none, with its
/// number slip.
typedef NightTie = ({
  int step,
  String label,
  TwineRoute? route,
  bool look,
  bool werewolf,
  Rect? number,
});

/// Every twine tied up to step [upTo] (its own last), routed round the other
/// cards, each step's number slip hung where it covers no card and no other
/// slip; in the board's content ([origin] the frame's place in it).
List<NightTie> tiesOf(
  EndBoardPlan plan,
  EndStory story,
  int upTo, {
  required Offset origin,
  required List<Rect> centre,
}) {
  final cards = {for (final c in plan.cards) c.id: c.leaned.shift(origin)};
  final content = Rect.fromLTWH(
    origin.dx,
    origin.dy,
    plan.boardWidth,
    plan.boardHeight,
  ).deflate(EndMetrics.lip);
  Rect at(CardPlace place) => switch (place) {
    PlayerPlace(:final playerId) => cards[playerId]!,
    CenterPlace(:final index) => centre[index].shift(origin),
  };
  final taken = <Rect>[];
  bool free(Rect r) =>
      content.contains(r.topLeft) &&
      content.contains(r.bottomRight) &&
      !cards.values.any((c) => c.inflate(2).overlaps(r)) &&
      !taken.any((t) => t.inflate(2).overlaps(r));
  Rect numbered(List<Rect> candidates) {
    final r = candidates.firstWhere(free, orElse: () => candidates.first);
    taken.add(r);
    return r;
  }

  final ties = <NightTie>[];
  for (var i = 0; i <= upTo && i < story.steps.length; i++) {
    final step = story.steps[i];
    final routes = [
      for (final t in step.threads)
        TwineRoute.between(
          at(t.from),
          at(t.to),
          avoid: [
            for (final MapEntry(:key, :value) in cards.entries)
              if (PlayerPlace(key) != t.from && PlayerPlace(key) != t.to) value,
          ],
        ),
    ];
    final Rect number;
    if (routes.isNotEmpty) {
      number = numbered([
        for (final along in _alongs)
          Rect.fromCenter(
            center: routes.first.at(along),
            width: _numberSize.width,
            height: _numberSize.height,
          ),
      ]);
    } else {
      // No twine (the Insomniac, a lone Werewolf): the slip beside the card.
      final c = at(step.places.first);
      final y = c.center.dy - _numberSize.height / 2;
      number = numbered(
        [
          Rect.fromLTWH(c.left - _numberSize.width - Space.xs, y, 0, 0),
          Rect.fromLTWH(c.right + Space.xs, y, 0, 0),
          Rect.fromLTWH(c.left, c.top - _numberSize.height - Space.xs, 0, 0),
          Rect.fromLTWH(c.left, c.bottom + Space.xs, 0, 0),
        ].map((r) => r.topLeft & _numberSize).toList(),
      );
    }
    final label = '${step.number}';
    if (routes.isEmpty) {
      ties.add((
        step: i,
        label: label,
        route: null,
        look: true,
        werewolf: step.werewolf,
        number: number,
      ));
    }
    for (final (k, route) in routes.indexed) {
      ties.add((
        step: i,
        label: label,
        route: route,
        look: !step.kind.moves,
        werewolf: step.werewolf,
        number: k == 0 ? number : Rect.zero,
      ));
    }
  }
  // One number slip a step.
  return [
    for (final t in ties)
      if (t.number != Rect.zero)
        t
      else
        (
          step: -1,
          label: '',
          route: t.route,
          look: t.look,
          werewolf: t.werewolf,
          number: Rect.zero,
        ),
  ];
}

/// The night's twines: the earlier steps' dimmed, the step's own drawn from
/// one end to the other on its clock (a paint, not a build).
class _Twines extends StatelessWidget {
  const _Twines({required this.night, required this.ties});

  final EndNight night;
  final List<NightTie> ties;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    return CustomPaint(
      size: Size.infinite,
      painter: _TwinesPainter(
        night: night,
        ties: [
          for (final t in ties)
            if (t.route != null) t,
        ],
        bone: ground.text,
        // The Werewolf team's red paper: the board's one red, read on felt.
        red: skin.parts.werewolfWonPaper,
        shadow:
            ground.elevation.card.layers.firstOrNull?.color ?? ground.shadow,
        light: OneLight.maybeOf(context),
      ),
    );
  }
}

class _TwinesPainter extends CustomPainter {
  _TwinesPainter({
    required this.night,
    required this.ties,
    required this.bone,
    required this.red,
    required this.shadow,
    required this.light,
  }) : step = night.step ?? 0,
       super(repaint: night.clock);

  final EndNight night;
  final int step;
  final List<NightTie> ties;
  final Color bone;
  final Color red;
  final Color shadow;
  final OneLight? light;

  @override
  void paint(Canvas canvas, Size size) {
    for (final t in ties) {
      var route = t.route!;
      final own = t.step == step;
      if (own) {
        final drawn = night.drawn();
        if (drawn <= 0) continue;
        route = TwineRoute(
          route.from,
          Offset.lerp(route.from, route.control, drawn)!,
          route.at(drawn),
        );
      }
      TwinePainter(
        route: route,
        kind: t.look ? TwineKind.look : TwineKind.move,
        color: t.werewolf ? red : bone,
        shadow: shadow,
        lean: light?.leanFor(t.route!.bounds) ?? 0,
        alpha: own ? 1 : _earlier,
      ).paint(canvas, size);
    }
  }

  @override
  bool shouldRepaint(_TwinesPainter old) =>
      old.step != step || old.ties != ties || old.night != night;
}

/// A step's number on a small slip of bone paper.
class _Number extends StatelessWidget {
  const _Number(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => PaperPiece(
    part: PaperPart.scrap,
    id: label,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.xxs),
        child: FitLine(
          label,
          style: context.skin.typography.name.copyWith(
            color: PaperPiece.inkOf(context, PaperPart.scrap),
          ),
        ),
      ),
    ),
  );
}
