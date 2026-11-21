import 'package:flutter/material.dart';

import '../layout/space.dart';
import '../skin/ground.dart';
import '../skin/ground_scope.dart';
import '../skin/skin.dart';
import 'screen_frame.dart';

/// Opens [builder]'s [SheetScaffold] from the bottom over the scrim, on the
/// ground of the screen it is opened from (a sheet opened on a day screen is
/// lit as day).
Future<T?> showSkinSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final ground = GroundScope.of(context);
  return showModalBottomSheet<T>(
    context: context,
    builder: (sheetContext) => GroundScope(
      ground: ground,
      child: Builder(builder: builder),
    ),
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: context.skin.scrim,
    elevation: 0,
    clipBehavior: Clip.none,
    constraints: const BoxConstraints(maxWidth: ScreenFrame.maxWidth),
  );
}

/// Opens [builder]'s content as a dialog over the scrim, on the ground of the
/// screen it is opened from: a panel of that ground (the skin's dialog theme),
/// so buttons in it keep the contrast they have on the screen behind.
Future<T?> showSkinDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  final ground = GroundScope.of(context);
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: context.skin.scrim,
    builder: (dialogContext) => GroundScope(
      ground: ground,
      child: Builder(builder: builder),
    ),
  );
}

/// A sheet of paper slid up from the bottom, its top edge lit by the
/// selection colour of the ground it covers: the body, then [actions] in a
/// row (the mocks use `ButtonSize.compact` buttons here). Its content is on
/// paper.
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
    final top = BorderRadius.vertical(
      top: Radius.circular(skin.shape.sheetRadius),
    );
    final media = MediaQuery.of(context);
    return Container(
      padding: const EdgeInsets.only(top: Space.xs),
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
          Space.gutter,
          Space.lgPlus,
          Space.gutter,
          Space.screenBottom +
              media.viewPadding.bottom +
              media.viewInsets.bottom,
        ),
        child: GroundScope(
          ground: GroundKind.paper,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // A sheet taller than the screen (large text, a small phone)
              // scrolls its body; the actions stay in reach.
              Flexible(child: SingleChildScrollView(child: child)),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: Space.lg),
                Row(spacing: Space.smPlus, children: actions),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
