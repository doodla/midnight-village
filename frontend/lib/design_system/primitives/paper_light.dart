import 'package:flutter/widgets.dart';

import '../skin/elevation.dart';

/// Where a screen's one light stands, as which way paper's shadow leans: every
/// shadow falls AWAY from the light (the moon high on the right throws left, a
/// low sun on the left throws long to the right, a lantern overhead throws
/// straight down). `ScreenFrame` declares it from its `Mood`; a paper shape
/// reads it through `cutPaper` and [Elevation.litBy].
///
/// [lean] is sideways travel per unit of drop: -0.5 leans left by half the
/// drop, 0 falls straight down.
class PaperLight extends InheritedWidget {
  const PaperLight({super.key, required this.lean, required super.child});

  final double lean;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PaperLight>()?.lean ?? 0;

  @override
  bool updateShouldNotify(PaperLight old) => lean != old.lean;
}

extension PaperLit on Elevation {
  /// The paper shadows of this elevation, leaning as the screen's light says.
  List<BoxShadow> litBy(BuildContext context) =>
      boxShadowsLeaning(PaperLight.of(context));
}
