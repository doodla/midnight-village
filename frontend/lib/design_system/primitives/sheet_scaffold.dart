import 'package:flutter/material.dart';

import '../skin/ground.dart';
import '../skin/ground_scope.dart';
import '../skin/skin.dart';
import 'screen_frame.dart';

/// Opens [builder]'s [SheetScaffold] from the bottom over a scrim.
Future<T?> showSkinSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) => showModalBottomSheet<T>(
  context: context,
  builder: builder,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  barrierColor: context.skin.scrim,
  elevation: 0,
  clipBehavior: Clip.none,
  constraints: const BoxConstraints(maxWidth: ScreenFrame.maxWidth),
);

/// A sheet of paper slid up from the bottom, its top edge lit by the
/// selection colour of the ground it covers: the body, then [actions] in a
/// row. Its content is on paper.
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    super.key,
    required this.child,
    this.actions = const [],
  });

  final Widget child;

  /// Buttons along the bottom; each takes its own width unless wrapped in
  /// [Expanded].
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final space = skin.spacing;
    final top = BorderRadius.vertical(
      top: Radius.circular(skin.shape.sheetRadius),
    );
    final media = MediaQuery.of(context);
    return Container(
      padding: EdgeInsets.only(top: space.xs),
      decoration: BoxDecoration(
        color: context.ground.selection,
        borderRadius: top,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: context.ground.paper,
          borderRadius: top,
        ),
        padding: EdgeInsets.fromLTRB(
          space.gutter,
          space.lg,
          space.gutter,
          space.screenBottom +
              media.viewPadding.bottom +
              media.viewInsets.bottom,
        ),
        child: GroundScope(
          ground: GroundKind.paper,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              child,
              if (actions.isNotEmpty) ...[
                SizedBox(height: space.lg),
                Row(spacing: space.md, children: actions),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
