import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../layout/space.dart';
import '../skin/dress.dart';
import '../skin/game_scopes.dart';
import '../skin/ground.dart';
import '../skin/ground_scope.dart';
import '../skin/skin.dart';
import '../skin/system_bars.dart';
import 'paper_grain.dart';
import 'screen_frame.dart';

/// Opens [builder]'s [SheetScaffold] from the bottom over the scrim, on the
/// ground of the screen it is opened from (a sheet opened on a day screen is
/// lit as day). It closes by its own button, a tap on the scrim, or Back;
/// never by a drag. A phone's back gesture (an edge swipe, gesture
/// navigation) reaches the page as a touch until the system claims it and
/// cancels it: a sheet that could be dragged was swept shut by that touch,
/// and the Back after it then did the screen's Back too (03 went to 02; 02
/// asked to leave again). A sheet is dressed as the screen it is opened from
/// is ([DressScope]).
Future<T?> showSkinSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final scopes = GameScopes.capture(context);
  return showModalBottomSheet<T>(
    context: context,
    builder: (sheetContext) => scopes.wrap(Builder(builder: builder)),
    isScrollControlled: true,
    // One back gesture, one thing: its touch never moves the sheet.
    enableDrag: false,
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
  final scopes = GameScopes.capture(context);
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: context.skin.scrim,
    builder: (dialogContext) => scopes.wrap(Builder(builder: builder)),
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
    // The navigation bar's icons are over the paper here.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemBarsOver(skin.ground(GroundKind.paper)),
      child: _sheet(context, top, media),
    );
  }

  Widget _sheet(BuildContext context, BorderRadius top, MediaQueryData media) {
    final dressed = context.dress.isPaper;
    // Dressed up the sheet has no lit edge (a strip of the selection's colour
    // along its top was a line): the torn paper is its edge.
    final sheet = Container(
      padding: dressed ? EdgeInsets.zero : const EdgeInsets.only(top: Space.xs),
      decoration: dressed
          ? null
          : BoxDecoration(color: context.ground.selection, borderRadius: top),
      child: Container(
        decoration: BoxDecoration(
          color: context.ground.paper,
          image: dressed ? PaperGrain.image : null,
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
    // Dressed up the top edge is torn, not cut: a sheet of paper pulled from
    // a pad.
    return dressed ? ClipPath(clipper: const TornTop(), child: sheet) : sheet;
  }
}

/// The torn top edge of a sheet: a seeded line that wanders a few pixels, so
/// every sheet is torn the same way on every phone. Cut once per size; a
/// sheet is one piece of paper, never one per list item.
class TornTop extends CustomClipper<Path> {
  const TornTop();

  /// The tear: its step along the edge and how far it wanders.
  static const step = 9.0;
  static const wander = 3.0;

  @override
  Path getClip(Size size) {
    final random = math.Random(5);
    final path = Path()..moveTo(0, wander);
    for (var x = step; x < size.width + step; x += step) {
      path.lineTo(math.min(x, size.width), random.nextDouble() * wander);
    }
    return path
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(TornTop old) => false;
}
