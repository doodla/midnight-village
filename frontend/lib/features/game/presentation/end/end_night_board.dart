import 'package:flutter/widgets.dart';

import '../../../../design_system/copy/copy.dart';
import '../../../../design_system/models/role.dart';
import '../../../../design_system/primitives/board_pieces.dart';
import '../../../../design_system/primitives/end_lantern.dart';
import '../../../../design_system/primitives/one_light.dart';
import '../../../../design_system/primitives/twine.dart';
import '../../../../design_system/primitives/you_seal.dart';
import '../../../../design_system/skin/ground.dart';
import '../../../../design_system/skin/ground_scope.dart';
import '../../../../design_system/skin/paper_parts.dart';
import '../../../../design_system/skin/skin.dart';
import '../../domain/end_board.dart';
import '../../domain/end_board_metrics.dart';
import '../../domain/end_night_view.dart';
import '../../domain/end_story.dart';
import '../../domain/night_timeline.dart';
import 'end_cards.dart';
import 'end_night.dart';
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
    final docked = nightViewOf(plan, players, deal: night.opening).docked;
    final level = nightLevel(docked, players.length);
    Rect at(Rect r, int id) => r.shift(origin + (docked[id] ?? Offset.zero));
    final ties = tiesOf(plan, night.current, origin: origin, docked: docked);
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
            for (final c in cards)
              Positioned.fromRect(
                rect: at(c.rect, c.id),
                child: KeyedSubtree(
                  key: night.placeKey(PlayerPlace(c.id)),
                  child: _card(
                    night,
                    c,
                    level: level && docked.containsKey(c.id),
                  ),
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
            Positioned.fill(
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: RepaintBoundary(
                    child: _Twines(night: night, ties: ties),
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
  Widget _card(EndNight night, EndCard c, {bool level = false}) {
    final before = night.before.players[c.id];
    final after = night.after.players[c.id];
    if (before == null || after == null) return const SizedBox.shrink();
    final box = Offset.zero & c.rect.size;
    Widget face = before == after
        ? _face(c, after, level: level)
        : RevealTurn(
            driver: night.driver,
            value: night.moveTurn,
            backAt: box,
            back: ExcludeSemantics(child: _face(c, before, level: level)),
            face: _face(c, after, level: level),
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

  Widget _face(EndCard c, StoryFace f, {bool level = false}) => BoardCard(
    name: c.name,
    role: f.face,
    strip: f.strip.displayName,
    paper: paperAtNight(f),
    size: c.rect.size,
    portraitWidth: c.portraitWidth,
    rect: c.rect,
    angle: level ? 0 : c.angle,
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

/// One twine of the step shown, between two players' cards.
typedef NightTie = ({TwineRoute route, bool look, bool werewolf});

/// The twines of [step] between players' cards, each routed round the
/// other cards, in the board's content ([origin] the frame's place in it).
/// A thread to a middle card is the page's ([NightMiddleTwines]): it runs
/// down off the board to the card in the foot.
List<NightTie> tiesOf(
  EndBoardPlan plan,
  StoryStep? step, {
  required Offset origin,
  Map<int, Offset> docked = const {},
}) {
  if (step == null) return const [];
  final cards = {
    for (final c in plan.cards)
      c.id: c.leaned.shift(origin + (docked[c.id] ?? Offset.zero)),
  };
  return [
    for (final t in step.threads)
      if ((t.from, t.to) case (final PlayerPlace a, final PlayerPlace b))
        (
          route: TwineRoute.between(
            cards[a.playerId]!,
            cards[b.playerId]!,
            avoid: [
              for (final MapEntry(:key, :value) in cards.entries)
                if (key != a.playerId && key != b.playerId) value,
            ],
          ),
          look: !step.kind.moves,
          werewolf: step.werewolf,
        ),
  ];
}

/// The step's twines, drawn from one end to the other on its clock (a
/// paint, not a build).
class _Twines extends StatelessWidget {
  const _Twines({required this.night, required this.ties});

  final EndNight night;
  final List<NightTie> ties;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.infinite,
    painter: _TwinesPainter(
      night: night,
      routes: () => [for (final t in ties) (t.route, t.look, t.werewolf)],
      style: TwineStyle.of(context),
    ),
  );
}

/// How the night's twines are drawn: bone, or the Werewolf team's red
/// paper (the board's one red, read on felt), with the paper's shadow
/// thrown from the moon.
@immutable
class TwineStyle {
  const TwineStyle({
    required this.bone,
    required this.red,
    required this.shadow,
    required this.light,
  });

  factory TwineStyle.of(BuildContext context) {
    final ground = context.ground;
    return TwineStyle(
      bone: ground.text,
      red: context.skin.parts.werewolfWonPaper,
      shadow: ground.elevation.card.layers.firstOrNull?.color ?? ground.shadow,
      light: OneLight.maybeOf(context),
    );
  }

  final Color bone;
  final Color red;
  final Color shadow;
  final OneLight? light;
}

/// A step's twines: each drawn as far as the step's clock has come.
class _TwinesPainter extends CustomPainter {
  _TwinesPainter({
    required this.night,
    required this.routes,
    required this.style,
    Listenable? repaint,
  }) : step = night.step ?? 0,
       super(repaint: repaint ?? night.clock);

  final EndNight night;
  final int step;

  /// The routes (looked at when painted: one may follow a scroll), whether
  /// each is a look, and the Werewolf team's.
  final List<(TwineRoute, bool, bool)> Function() routes;
  final TwineStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final drawn = night.drawn();
    if (drawn <= 0) return;
    for (final (full, look, werewolf) in routes()) {
      TwinePainter(
        route: TwineRoute(
          full.from,
          Offset.lerp(full.from, full.control, drawn)!,
          full.at(drawn),
        ),
        kind: look ? TwineKind.look : TwineKind.move,
        color: werewolf ? style.red : style.bone,
        shadow: style.shadow,
        lean: style.light?.leanFor(full.bounds) ?? 0,
      ).paint(canvas, size);
    }
  }

  @override
  bool shouldRepaint(_TwinesPainter old) =>
      old.step != step || old.night != night || old.routes != routes;
}

/// The step's thread to a middle card: from the card of the one who acted,
/// on the board, down to the middle card in the foot, over the board's lip;
/// on the page over both, so it follows the board as it scrolls
/// ([scrolled]). Nothing when the step touches no middle card.
class NightMiddleTwines extends StatefulWidget {
  const NightMiddleTwines({super.key, required this.scrolled});

  final Listenable scrolled;

  @override
  State<NightMiddleTwines> createState() => _NightMiddleTwinesState();
}

class _NightMiddleTwinesState extends State<NightMiddleTwines> {
  final _self = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final night = EndNightScope.maybeOf(context);
    final step = night?.current;
    final threads = [
      for (final t in step?.threads ?? const <StoryThread>[])
        if (t.from is CenterPlace || t.to is CenterPlace) t,
    ];
    if (night == null || step == null || threads.isEmpty) {
      return const SizedBox.shrink();
    }
    Rect? rectOf(CardPlace place) {
      final page = _self.currentContext?.findRenderObject() as RenderBox?;
      final box =
          night.placeKey(place).currentContext?.findRenderObject()
              as RenderBox?;
      if (page == null || box == null || !box.attached || !box.hasSize) {
        return null;
      }
      return box.localToGlobal(Offset.zero, ancestor: page) & box.size;
    }

    List<(TwineRoute, bool, bool)> routes() {
      final others = [
        for (final place in night.placed)
          if (place is PlayerPlace && !step.places.contains(place))
            ?rectOf(place),
      ];
      return [
        for (final t in threads)
          if ((rectOf(t.from), rectOf(t.to)) case (final a?, final b?))
            (
              TwineRoute.between(a, b, avoid: others),
              !step.kind.moves,
              step.werewolf,
            ),
      ];
    }

    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: CustomPaint(
            key: _self,
            size: Size.infinite,
            painter: _TwinesPainter(
              night: night,
              routes: routes,
              style: TwineStyle.of(context),
              repaint: Listenable.merge([night.clock, widget.scrolled]),
            ),
          ),
        ),
      ),
    );
  }
}
