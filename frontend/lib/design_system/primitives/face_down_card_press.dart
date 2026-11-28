part of 'face_down_card.dart';

/// The hero's paper, casting [paper] of its slab; under a hold's finger
/// (04: the press `PaperFlip` hands its back, [PressScope]) it sinks toward
/// its shadow, which tightens, from the frame the finger lands, by paint
/// alone ([FaceDownCard.heroPressKeep]), and gives it back as the card turns.
Widget _heroPaper(
  BuildContext context,
  Decoration Function(Elevation) paper,
  Widget child,
) {
  final slab = context.ground.elevation.heroSlab;
  final press = PressScope.maybeOf(context);
  if (press == null) return DecoratedBox(decoration: paper(slab), child: child);
  const keep = FaceDownCard.heroPressKeep;
  return PressSink(
    press: press,
    by: slab.travel(keep),
    child: PressDecoration(
      press: press,
      rest: paper(slab),
      down: paper(slab.pressed(keep)),
      duration: Duration.zero,
      // Its own layer only while pressed: at rest it draws as before.
      child: PressLayer(press: press, child: child),
    ),
  );
}
