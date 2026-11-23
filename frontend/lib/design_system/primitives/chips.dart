import 'package:flutter/material.dart';

import '../layout/space.dart';
import '../skin/dress.dart';
import '../skin/skin.dart';
import '../skin/dress_style.dart';
import 'paper_mark.dart';
import 'paper_piece.dart';
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
    final dressed = context.dress.isPaper;
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      child: AnimatedSlide(
        duration: Motion.quick,
        curve: Motion.curve,
        offset: Offset(0, selected && !dressed ? -Space.xxs / height : 0),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            highlightColor: Colors.transparent,
            focusColor: dressed ? Colors.transparent : null,
            hoverColor: dressed ? Colors.transparent : null,
            child: dressed
                ? _tag(context)
                : AnimatedContainer(
                    duration: Motion.quick,
                    curve: Motion.curve,
                    constraints: const BoxConstraints(minHeight: height),
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.mdPlus,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      border: Border.all(
                        color: selected ? ground.selection : ground.hairline,
                        width: selected
                            ? skin.shape.selectedRing
                            : skin.shape.stroke,
                      ),
                    ),
                    child: Center(
                      widthFactor: 1,
                      heightFactor: 1,
                      child: FitWords(
                        label,
                        textAlign: TextAlign.center,
                        style: skin.typography.action.copyWith(
                          color: ground.text,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  /// Dressed up the chip is a cut-paper tag (a [PaperPiece]): bone and lifted
  /// with the paper mark on its corner when selected, a darker scrap when not;
  /// the word level. No ring, no outline.
  Widget _tag(BuildContext context) {
    // A picked chip has its own form (`PaperPart.chipPicked`: lifted bone with
    // a wax seal over its corner); the others lie flat and dim. Neither is a
    // button's (a bone scrap that lies low and wears no seal).
    final part = selected ? PaperPart.chipPicked : PaperPart.chip;
    final ink = PaperPiece.inkOf(context, part);
    return PaperMarkCorner(
      shown: selected,
      seal: true,
      child: PaperPiece(
        part: part,
        id: label,
        enabled: true,
        duration: Motion.quick,
        child: Container(
          constraints: const BoxConstraints(minHeight: height),
          padding: const EdgeInsets.symmetric(horizontal: Space.mdPlus),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: FitWords(
              label,
              textAlign: TextAlign.center,
              style: context.skin.typography.action.copyWith(color: ink),
            ),
          ),
        ),
      ),
    );
  }
}
