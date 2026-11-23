import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../models/role.dart';
import '../skin/dress.dart';
import '../skin/end_art.dart';
import '../skin/werewolf_portrait.dart';
import '../skin/skin.dart';
import 'art_picture.dart';
import 'deckle.dart';
import 'fit_line.dart';
import 'one_light.dart';
import 'paper_light.dart';

export 'board_card_back.dart';

// The end board's own pieces beside the parts of piece 1: a player's card on
// the board, the small card tucked behind it, the three cards in the middle,
// the lantern's pool and the vignette, and the cobbles with their torn lip.
// Sizes are the caller's (the layout is `features/game/domain/end_board.dart`);
// every colour, alpha and shadow is the skin's (`PaperParts`) or the one
// light's (`OneLight`).

/// Which paper a board card is cut from.
enum BoardPaper {
  winner,
  loser,
  werewolfWon,
  werewolfLost,
  night,

  /// A Werewolf-team card of the deck in play (08): the darker red, so its
  /// bone words keep 7:1, its portrait in full colour.
  werewolfDeck,
}

/// A player's card pinned on the board: the name (when there is one), the
/// portrait in a 4:3 window showing the whole face with headroom, the role on
/// a tab of paper glued over the portrait's foot and the card's own. A card far
/// from the light is a little darker; one that is [raised] (hanged) casts a
/// bigger shadow. Plain, it is the words alone.
class BoardCard extends StatelessWidget {
  const BoardCard({
    super.key,
    this.name,
    required this.role,
    required this.strip,
    required this.paper,
    required this.size,
    required this.portraitWidth,
    required this.rect,
    this.angle = 0,
    this.raised = false,
    this.stripHeight = defaultStripHeight,
    this.headerHeight = defaultHeaderHeight,
    this.semantics,
  });

  /// The player's name; null on a card nobody held (the middle).
  final String? name;

  /// The portrait shown.
  final RoleId role;

  /// The role on the strip.
  final String strip;
  final BoardPaper paper;

  /// The card's size, and its portrait's width (the window is 4:3).
  final Size size;
  final double portraitWidth;

  /// Where the card lies on the board, in the board's coordinates.
  final Rect rect;

  /// Tilted this much, in radians, about its centre.
  final double angle;
  final bool raised;

  /// How tall the strip across the portrait's foot and the name's header are.
  final double stripHeight;
  final double headerHeight;

  /// What a screen reader says for the whole card.
  final String? semantics;

  static const defaultHeaderHeight = 22.0;
  static const defaultStripHeight = 17.0;
  static const inset = 4.0;

  /// The room beside the name in its header.
  static const namePad = 10.0;

  /// The tab is as wide as its words and this each side, its foot this far
  /// above the card's.
  static const stripPad = 5.0;
  static const stripUp = 1.0;

  /// Where the portrait is cut from its picture: the face and the air above
  /// it (the picture's own focus is lower, for a taller window).
  static const portraitFocus = Alignment(0, -0.56);

  Color _fill(BuildContext context) {
    final parts = context.skin.parts;
    return switch (paper) {
      BoardPaper.winner => parts.winnerPaper,
      BoardPaper.loser => parts.loserPaper,
      BoardPaper.werewolfWon => parts.werewolfWonPaper,
      BoardPaper.werewolfLost ||
      BoardPaper.werewolfDeck => parts.werewolfLostPaper,
      BoardPaper.night => parts.nightPaper,
    };
  }

  bool get _red =>
      paper == BoardPaper.werewolfWon ||
      paper == BoardPaper.werewolfLost ||
      paper == BoardPaper.werewolfDeck;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final parts = skin.parts;
    final type = skin.typography;
    final ink = _red ? parts.onTeamTag : skin.paper.text;
    final plain = !context.dress.isPaper;
    if (plain) {
      return Semantics(
        label: semantics ?? name ?? strip,
        excludeSemantics: true,
        child: Text(
          name ?? strip,
          style: type.name.copyWith(color: context.ground.text),
        ),
      );
    }
    final light = OneLight.maybeOf(context);
    final elevation = raised
        ? context.ground.elevation.selected
        : context.ground.elevation.card;
    final lean = light?.leanFor(rect) ?? PaperLight.of(context);
    final shadows = light == null
        ? elevation.boxShadowsLeaning(lean)
        : paperShadows(light, rect, elevation);
    final loser = paper == BoardPaper.loser || paper == BoardPaper.werewolfLost;
    Widget portrait = ArtPicture(context.roleArt(role), focus: portraitFocus);
    if (loser) {
      portrait = ColorFiltered(
        colorFilter: ColorFilter.mode(
          parts.boardShade.withValues(alpha: 1 - parts.loserDark),
          BlendMode.srcATop,
        ),
        child: ColorFiltered(
          colorFilter: parts.desaturate(parts.loserKeep),
          child: portrait,
        ),
      );
    }
    final fill = _fill(context);
    // No portrait (a name-only card): the words stand on the paper itself.
    final nameOnly = portraitWidth <= 0;
    final window = SizedBox(
      width: portraitWidth,
      height: portraitWidth * 3 / 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(skin.shape.radiusTiny),
        child: portrait,
      ),
    );
    // The tab lies over the portrait's foot, as wide as its words (a role
    // wider than the portrait still reads whole: the card is as wide as it).
    final stripBar = Positioned(
      left: 0,
      right: 0,
      bottom: stripUp,
      height: stripHeight,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            boxShadow: nameOnly
                ? null
                : [
                    BoxShadow(
                      color: parts.boardShade.withValues(alpha: 0.35),
                      blurRadius: 2,
                      offset: const Offset(0, -1),
                    ),
                  ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: stripPad),
            child: Center(
              widthFactor: 1,
              child: FitLine(strip, style: type.tag.copyWith(color: ink)),
            ),
          ),
        ),
      ),
    );
    final body = DecoratedBox(
      decoration: ShapeDecoration(
        color: fill,
        shadows: shadows,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(skin.shape.radiusTiny),
        ),
      ),
      child: SizedBox.fromSize(
        size: size,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Column(
              children: [
                if (name != null)
                  SizedBox(
                    height: headerHeight,
                    width: size.width,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: namePad),
                      child: FitLine(
                        name!,
                        style: type.name.copyWith(color: ink),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: inset),
                if (!nameOnly) window,
              ],
            ),
            stripBar,
          ],
        ),
      ),
    );
    final lit = light == null
        ? body
        : ColorFiltered(
            colorFilter: light.dimFilter(rect, parts.boardShade),
            child: body,
          );
    return Semantics(
      label: semantics ?? name ?? strip,
      excludeSemantics: true,
      child: angle == 0 ? lit : Transform.rotate(angle: angle, child: lit),
    );
  }
}

/// The card a player was dealt, small, older, tucked behind their own card's
/// top left corner: a sepia portrait and no words.
class DealtCard extends StatelessWidget {
  const DealtCard({
    super.key,
    required this.role,
    required this.size,
    required this.rect,
  });

  final RoleId role;
  final Size size;
  final Rect rect;

  /// Turned this much.
  static const turn = -13 * math.pi / 180;

  static const _sepia = ColorFilter.matrix(<double>[
    0.393, 0.769, 0.189, 0, 0, //
    0.349, 0.686, 0.168, 0, 0,
    0.272, 0.534, 0.131, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    if (!context.dress.isPaper) return const SizedBox.shrink();
    final skin = context.skin;
    final parts = skin.parts;
    final light = OneLight.maybeOf(context);
    final elevation = context.ground.elevation.card;
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Transform.rotate(
          angle: turn,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: parts.loserPaper,
              shadows: light == null
                  ? elevation.boxShadowsLeaning(PaperLight.of(context))
                  : paperShadows(light, rect, elevation),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(skin.shape.radiusTiny),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: SizedBox.fromSize(
                size: Size(size.width - 4, size.height - 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(skin.shape.radiusTiny),
                  child: ColorFiltered(
                    colorFilter: _sepia,
                    child: ArtPicture(
                      context.roleArt(role),
                      focus: BoardCard.portraitFocus,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The lantern's light on the board: a warm pool on each of [pools] (the living
/// winners' cards, pulled a little toward the light, laid on with the screen
/// blend), and two darkenings, round the lantern and at the board's edges, so
/// one light falls off. Everything is in the board's coordinates and scrolls
/// with it; nothing is worked out again while it moves.
class BoardLight extends StatelessWidget {
  const BoardLight({
    super.key,
    required this.size,
    required this.light,
    required this.pools,
  });

  final Size size;
  final Offset light;
  final List<Rect> pools;

  @override
  Widget build(BuildContext context) {
    if (!context.dress.isPaper) return const SizedBox.shrink();
    final parts = context.skin.parts;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: CustomPaint(
          size: size,
          painter: _LightPainter(
            light: light,
            pools: pools,
            shade: parts.boardShade,
            warm: parts.poolColor.withValues(alpha: parts.poolAlpha),
            pull: parts.poolPull,
            lanternShade: parts.vignetteLantern,
            edgeShade: parts.vignetteEdge,
          ),
        ),
      ),
    );
  }
}

class _LightPainter extends CustomPainter {
  const _LightPainter({
    required this.light,
    required this.pools,
    required this.shade,
    required this.warm,
    required this.pull,
    required this.lanternShade,
    required this.edgeShade,
  });

  final Offset light;
  final List<Rect> pools;
  final Color shade;
  final Color warm;
  final double pull;
  final double lanternShade;
  final double edgeShade;

  @override
  void paint(Canvas canvas, Size size) {
    final board = Offset.zero & size;
    // Dark at the edges.
    canvas.drawRect(
      board,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.95,
          colors: [
            shade.withValues(alpha: 0),
            shade.withValues(alpha: 0),
            shade.withValues(alpha: edgeShade),
          ],
          stops: const [0, 0.55, 1],
        ).createShader(board),
    );
    // Dark far from the lantern, light near it.
    final reach = math.max(size.width, size.height) * 0.9;
    canvas.drawRect(
      board,
      Paint()
        ..shader = RadialGradient(
          colors: [
            shade.withValues(alpha: 0),
            shade.withValues(alpha: 0),
            shade.withValues(alpha: lanternShade * 0.5),
          ],
          stops: const [0, 0.22, 1],
        ).createShader(Rect.fromCircle(center: light, radius: reach)),
    );
    // Warm on the winners, laid on with the screen blend.
    for (final pool in pools) {
      final centre = Offset.lerp(pool.center, light, pull)!;
      final radius = math.max(pool.width, pool.height) * 0.95;
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader = RadialGradient(
            colors: [
              warm,
              warm.withValues(alpha: warm.a * 0.4),
              warm.withValues(alpha: 0),
            ],
            stops: const [0, 0.5, 1],
          ).createShader(Rect.fromCircle(center: centre, radius: radius)),
      );
    }
  }

  @override
  bool shouldRepaint(_LightPainter old) =>
      light != old.light ||
      warm != old.warm ||
      shade != old.shade ||
      pull != old.pull ||
      lanternShade != old.lanternShade ||
      edgeShade != old.edgeShade ||
      !_same(pools, old.pools);

  static bool _same(List<Rect> a, List<Rect> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// The ground under the board's foot: the cobbles, with a torn lip along the
/// top edge and a soft shadow thrown up onto the board. [height] is the
/// whole of it, lip included.
class BoardFoot extends StatelessWidget {
  const BoardFoot({super.key, required this.height});

  final double height;

  static const lipDepth = 7.0;
  static const lipStep = 16.0;
  static const seed = 41;

  @override
  Widget build(BuildContext context) {
    if (!context.dress.isPaper) return SizedBox(height: height);
    final skin = context.skin;
    final parts = skin.parts;
    const shape = DeckleBorder(
      seed: seed,
      depth: lipDepth,
      step: lipStep,
      torn: true,
    );
    return IgnorePointer(
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: ShapeDecoration(
                  shape: shape,
                  color: context.ground.ground,
                  shadows: [
                    BoxShadow(
                      color: parts.boardShade.withValues(alpha: 0.55),
                      blurRadius: 10,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
              ),
              ClipPath(
                clipper: ShapeBorderClipper(shape: shape),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ArtPicture(
                      skin.art.end.piece(EndPiece.cobbles),
                      focus: Alignment.topCenter,
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            parts.boardShade.withValues(alpha: 0.45),
                            parts.boardShade.withValues(alpha: 0.2),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
