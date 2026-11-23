import 'package:flutter/material.dart';

import '../skin/dress.dart';
import '../skin/skin.dart';

/// A line that parts one thing from the next on a plain screen, and nothing
/// at all on a paper one: paper is parted by room, never by a drawn line
/// (`dress_style.dart`). [Rule] is a hairline across; [Rule.divider] is
/// Material's own; [SideRule] is a line down a block's side (the night's
/// lines on 11).
class Rule extends StatelessWidget {
  /// A hairline of the skin's stroke across, in the ground's hairline.
  const Rule({super.key}) : _divider = null;

  /// Material's divider of [height] (01's stats), as it always was.
  const Rule.divider({super.key, required double height}) : _divider = height;

  final double? _divider;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final divider = _divider;
    if (context.dress.isPaper) {
      return SizedBox(height: divider ?? skin.shape.stroke);
    }
    if (divider != null) return Divider(height: divider);
    return Container(height: skin.shape.stroke, color: context.ground.hairline);
  }
}

/// A line down the start side of [child] ([color], [width]) on a plain
/// screen; on a paper one the room it takes and no line.
class SideRule extends StatelessWidget {
  const SideRule({
    super.key,
    required this.color,
    required this.width,
    required this.padding,
    this.margin,
    required this.child,
  });

  final Color color;
  final double width;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    margin: margin,
    padding: padding,
    decoration: context.dress.isPaper
        ? null
        : BoxDecoration(
            border: Border(
              left: BorderSide(color: color, width: width),
            ),
          ),
    child: child,
  );
}
