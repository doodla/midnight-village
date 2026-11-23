import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../skin/elevation.dart';
import '../skin/end_art.dart';
import '../skin/mood_palette.dart';
import 'paper_light.dart';

/// The one light of a board that has a light point, not just a side: where it
/// stands, in the board's own coordinates (the end board's lantern; while the
/// night is replayed, the moon). Every shadow on the board falls AWAY from it,
/// down and sideways, which is [PaperLight]'s lean worked out per piece: a
/// card left of the lantern throws left, one under it straight down, one right
/// of it right. [PaperLight] stays the screen's light for everything that is
/// not on a board; [LitAt] makes a piece lit by this one.
///
/// A rectangle given to any of its functions is in the same coordinates as
/// [point], so the lean is the same however the board is scrolled: nothing is
/// worked out again while it moves.
@immutable
class OneLight {
  const OneLight(this.point);

  /// The lantern, hung in [box] (its place on the board, the size it is
  /// drawn): the light is the centre of its panes (`EndArt.lanternLight`).
  factory OneLight.lantern(Rect box) => OneLight(
    box.topLeft +
        Offset(
          EndArt.lanternLight.dx * box.width,
          EndArt.lanternLight.dy * box.height,
        ),
  );

  /// A mood's lantern (`MoodKind.lantern`: where `MoodPalette.lanternAt`
  /// puts its pool) on a screen of [size]: the same light a screen without a
  /// board is lit by, as a point.
  factory OneLight.ofMood(
    Size size,
    MoodPalette palette, {
    bool high = false,
  }) => OneLight(
    (high ? palette.lanternHighAt : palette.lanternAt).alongSize(size),
  );

  /// Where the light stands.
  final Offset point;

  /// How far a piece may lean, sideways per unit of drop: 45 degrees.
  static const mostLean = 1.0;

  /// A piece level with the light still falls down: its lean is its sideways
  /// distance over at least this much height, so the lean is gentle where it
  /// is level and does not run away.
  static const softness = 80.0;

  /// How the paper darkens with the distance from the light: none within
  /// [nearReach], then [darkest] of it at [farReach] and beyond.
  static const nearReach = 60.0;
  static const farReach = 420.0;
  static const darkest = 0.28;

  /// Which way the shadow of a piece at [rect] leans: away from the light,
  /// sideways per unit of drop (the sign [PaperLight] uses: negative leans
  /// left).
  double leanFor(Rect rect) {
    final from = rect.center - point;
    final lean = from.dx / math.max(from.dy.abs(), softness);
    return lean.clamp(-mostLean, mostLean);
  }

  /// The paper shadows of a piece at [rect] lying [elevation] above what is
  /// under it: down and away from the light.
  List<BoxShadow> shadows(Rect rect, Elevation elevation) =>
      elevation.boxShadowsLeaning(leanFor(rect));

  /// How much darker a piece at [rect] is than one in the light's own pool:
  /// 0 near it, up to [darkest] far away.
  double darknessAt(Rect rect) {
    final away = (rect.center - point).distance;
    return darkest *
        ((away - nearReach) / (farReach - nearReach)).clamp(0.0, 1.0);
  }

  /// The colour filter for [darknessAt]: a black laid over by that much.
  ColorFilter dimFilter(Rect rect, Color shade) => ColorFilter.mode(
    shade.withValues(alpha: darknessAt(rect)),
    BlendMode.srcATop,
  );

  /// The board's light, from the nearest [OneLightScope].
  static OneLight? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OneLightScope>()?.light;

  @override
  bool operator ==(Object other) => other is OneLight && other.point == point;

  @override
  int get hashCode => point.hashCode;
}

/// Declares a board's [OneLight] for everything below it.
class OneLightScope extends InheritedWidget {
  const OneLightScope({super.key, required this.light, required super.child});

  final OneLight light;

  @override
  bool updateShouldNotify(OneLightScope old) => light != old.light;
}

/// The paper shadows of a piece at [rect] on the board lit by [light]: a
/// plain function of the light, the place and the lift, the one every card,
/// tag, scrap and pin of the board goes through.
List<BoxShadow> paperShadows(OneLight light, Rect rect, Elevation elevation) =>
    light.shadows(rect, elevation);

/// A piece of a board, lit by its [OneLightScope]: everything below it (a
/// `PaperPiece`, a pin, a twine) throws its shadow away from the board's light
/// as seen from [rect], the piece's place in the board's coordinates. With no
/// board light above it, it changes nothing.
class LitAt extends StatelessWidget {
  const LitAt({super.key, required this.rect, required this.child});

  final Rect rect;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final light = OneLight.maybeOf(context);
    if (light == null) return child;
    return PaperLight(lean: light.leanFor(rect), child: child);
  }
}
