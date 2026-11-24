import 'package:flutter/widgets.dart';

import '../layout/space.dart';
import '../skin/skin.dart';
import 'board_pieces.dart';

/// The foot of a day board (08's square, 09's vote): the cobbles under the
/// board ([BoardFoot]) and on them the screen's one action, [action], no
/// wider than the skin's `squareButtonWidest`, with a failed send's quiet
/// line ([notice], a `Notice`) above it. It keeps clear of the system bar
/// itself. Plain, it is the same column with no cobbles under it.
class SquareFoot extends StatelessWidget {
  const SquareFoot({super.key, required this.action, this.notice});

  /// The screen's one button (a `PrimaryButton` in one of its forms).
  final Widget action;

  /// "Not sent." with its "Try again", where the last tap got no answer.
  final Widget? notice;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      const Positioned.fill(child: BoardFoot(height: double.infinity)),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.xl,
            Space.gutter,
            Space.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: Space.sm,
            children: [
              ?notice,
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: context.skin.parts.squareButtonWidest,
                ),
                child: SizedBox(width: double.infinity, child: action),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
