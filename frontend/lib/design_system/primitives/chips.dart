import 'package:flutter/material.dart';

import '../layout/space.dart';
import '../skin/dress.dart';
import '../skin/skin.dart';
import '../skin/skin_tilt.dart';
import 'tilted_paper.dart';
import 'fit_line.dart';

/// One of a few presets to choose from ("Simple", "Classic", "Chaos"; the
/// paces, S03), 44 tall. The selected one lifts and takes the selection's
/// outline (first-time play spec, copy rule 10: a selection is never a
/// fill); the others are a quiet outline.
class PresetChip extends StatelessWidget {
  const PresetChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  static const height = 44.0;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    final radius = BorderRadius.circular(skin.shape.radiusSmall);
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      child: AnimatedSlide(
        duration: Motion.quick,
        curve: Motion.curve,
        offset: Offset(0, selected ? -Space.xxs / height : 0),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            highlightColor: Colors.transparent,
            child: _outlined(
              context,
              BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  color: selected ? ground.selection : ground.hairline,
                  width: selected ? skin.shape.selectedRing : skin.shape.stroke,
                ),
              ),
              Center(
                widthFactor: 1,
                heightFactor: 1,
                child: FitWords(
                  label,
                  textAlign: TextAlign.center,
                  style: skin.typography.action.copyWith(color: ground.text),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The chip's outline round [words]: set down by hand on a dressed screen
  /// (the outline turned a hair, the same every build, the word level).
  Widget _outlined(BuildContext context, BoxDecoration outline, Widget words) {
    const padding = EdgeInsets.symmetric(horizontal: Space.mdPlus);
    if (context.dress.isPaper) {
      return TiltedPaper(
        angle: context.skin.tilt.angle(Tilt.seededRow(label)),
        duration: Motion.quick,
        decoration: outline,
        child: Container(
          constraints: const BoxConstraints(minHeight: height),
          padding: padding,
          child: words,
        ),
      );
    }
    return AnimatedContainer(
      duration: Motion.quick,
      curve: Motion.curve,
      constraints: const BoxConstraints(minHeight: height),
      padding: padding,
      decoration: outline,
      child: words,
    );
  }
}
