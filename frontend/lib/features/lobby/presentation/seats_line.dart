import 'package:flutter/material.dart';

import '../../../design_system/copy/copy.dart';
import '../../../design_system/layout/space.dart';
import '../../../design_system/skin/skin.dart';

/// Who is here of how many, at a table set for a number (02 and 03, host and
/// guests alike): "3 of 8" and a seat for each, the taken ones filled. The
/// one way the table's wait is said; never card arithmetic.
/// Which seats [SeatsLine] draws.
enum SeatDots {
  /// Every seat, the taken ones filled (03).
  all,

  /// Only the places not taken (02, under which the players' rows are).
  empty,
}

class SeatsLine extends StatelessWidget {
  const SeatsLine({
    super.key,
    required this.present,
    required this.seats,
    this.dots = SeatDots.all,
  });

  final int present;
  final int seats;
  final SeatDots dots;

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
                for (var i = dots == SeatDots.all ? 0 : present; i < seats; i++)
                  Container(
                    width: Sizes.seat,
                    height: Sizes.seat,
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
