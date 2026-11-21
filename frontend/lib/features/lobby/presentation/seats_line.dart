import 'package:flutter/material.dart';

import '../../../design_system/copy/copy.dart';
import '../../../design_system/layout/space.dart';
import '../../../design_system/skin/skin.dart';

/// Who is here of how many, at a table set for a number (02 and 03, host and
/// guests alike): "3 of 8" and a seat for each, the taken ones filled. The
/// one way the table's wait is said; never card arithmetic.
class SeatsLine extends StatelessWidget {
  const SeatsLine({super.key, required this.present, required this.seats});

  final int present;
  final int seats;

  /// A seat's side.
  static const _seat = 14.0;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    return Row(
      spacing: Space.md,
      children: [
        Text(
          TableCopy.seated.fill({'d': present, 'n': seats}),
          style: skin.typography.title.copyWith(color: ground.text),
        ),
        Expanded(
          child: ExcludeSemantics(
            child: Wrap(
              spacing: Space.xs,
              runSpacing: Space.xs,
              children: [
                for (var i = 0; i < seats; i++)
                  Container(
                    width: _seat,
                    height: _seat,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < present ? ground.text : null,
                      border: Border.all(
                        color: i < present ? ground.text : ground.outline,
                        width: skin.shape.stroke,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
