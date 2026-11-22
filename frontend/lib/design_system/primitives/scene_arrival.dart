import 'package:flutter/widgets.dart';

/// Told to the screen that is arriving in a scene (`SceneSwitcher`): how far
/// the scene has brought it, 0 as it starts, 1 as it lands (already eased by
/// `Motion.curve`). A screen's own header picture reads it to travel further
/// than the rest of the screen: the layers of 04's village (the moon coming
/// down into place, the clouds drifting) and of 08's dawn (the roofs rising,
/// the sun coming up from behind the hills; `LayeredArt`). A
/// screen with no scene running is told nothing (null) and sits where it
/// rests.
class SceneArrival extends InheritedWidget {
  const SceneArrival({super.key, required this.progress, required super.child});

  final Animation<double>? progress;

  /// The arrival the nearest scene reports, or null when there is none.
  static Animation<double>? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SceneArrival>()?.progress;

  @override
  bool updateShouldNotify(SceneArrival oldWidget) =>
      oldWidget.progress != progress;
}

/// Shifts [child] by [travel] of its own height times what is left of the
/// scene's arrival (negative [travel]: up; positive: down), when a scene
/// brings it in; else leaves it where it rests.
class ArrivalShift extends StatelessWidget {
  const ArrivalShift({super.key, required this.travel, required this.child});

  final double travel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final arrival = SceneArrival.maybeOf(context);
    if (arrival == null) return child;
    return AnimatedBuilder(
      animation: arrival,
      child: child,
      builder: (context, child) => FractionalTranslation(
        translation: Offset(0, travel * (1 - arrival.value)),
        child: child,
      ),
    );
  }
}
