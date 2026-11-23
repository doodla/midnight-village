import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/deckle.dart';

/// The fill of a paper decoration: a plain box's or a torn sheet's.
Color? paperColor(Decoration d) => switch (d) {
  ShapeDecoration(:final color) => color,
  BoxDecoration(:final color) => color,
  _ => null,
};

/// The shadows of a paper decoration, outermost first.
List<BoxShadow> paperShadows(Decoration d) => switch (d) {
  ShapeDecoration(:final shadows) => shadows ?? const [],
  BoxDecoration(:final boxShadow) => boxShadow ?? const [],
  _ => const [],
};

/// The edge line of a paper decoration (none: `BorderSide.none`).
BorderSide paperEdge(Decoration d) => switch (d) {
  ShapeDecoration(:final shape) when shape is DeckleBorder => shape.side,
  BoxDecoration(:final border) when border is Border => border.top,
  _ => BorderSide.none,
};

/// The first decoration found among the animated containers under [of]
/// (a plaque's paper sits one container in, under its tilt).
Decoration paperUnder(WidgetTester tester, Finder of) => tester
    .widgetList<AnimatedContainer>(
      find.descendant(of: of, matching: find.byType(AnimatedContainer)),
    )
    .map((c) => c.decoration)
    .whereType<Decoration>()
    .first;
