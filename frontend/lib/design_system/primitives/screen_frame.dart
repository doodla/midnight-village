import 'package:flutter/material.dart';

import '../layout/space.dart';
import '../skin/art_set.dart';
import '../skin/ground.dart';
import '../skin/ground_scope.dart';
import '../skin/skin.dart';
import 'art_picture.dart';

/// How a picture sits across the top of a screen, from the mocks. All three
/// grow by the status bar's height, so on a phone with a notch the picture
/// still reaches the top and the body still starts below the bar.
enum TopArtLayout {
  /// A scene (S01 Join, S05 the village sleeps): 330 tall, the body from 282,
  /// fading from 160.
  scene(height: 330, bodyTop: 282, fadeFrom: 160),

  /// A strip (S02 the table): 180 tall, the body from 118, fading from 80.
  banner(height: 180, bodyTop: 118, fadeFrom: 80),

  /// A backdrop behind the whole top of the screen (S04 your card): 520 tall,
  /// the body from 52, fading from 300.
  backdrop(height: 520, bodyTop: 52, fadeFrom: 300);

  const TopArtLayout({
    required this.height,
    required this.bodyTop,
    required this.fadeFrom,
  });

  final double height;
  final double bodyTop;
  final double fadeFrom;
}

/// A whole screen, laid out as a stack (design brief section 3, rule 6): an
/// optional top (a picture behind the body's start, or a band in
/// [topSlot]), the [body] (scrolling when it does not fit, with the ground
/// fading in over its lower edge while there is more below), and [actions]
/// pinned to the bottom. Each part starts where the one above ends, so larger
/// text pushes things down instead of overlapping. On a wide screen the phone
/// layout is centred and the ground fills the rest.
///
/// Screens never build their own Scaffold: anything that must run edge to
/// edge at the top (the sun, the vote's band, the count's band) goes in
/// [topSlot], which scrolls with the body and reaches under the status bar.
class ScreenFrame extends StatelessWidget {
  const ScreenFrame({
    super.key,
    required this.ground,
    required this.body,
    this.actions = const [],
    this.topArt,
    this.topArtLayout = TopArtLayout.scene,
    this.topSlot,
    this.actionGap = Space.mdPlus,
  }) : assert(
         topArt == null || topSlot == null,
         'A screen has a top picture or a top band, not both.',
       );

  /// The widest the phone layout gets.
  static const maxWidth = 440.0;

  final GroundKind ground;
  final Widget body;

  /// Stacked at the bottom, full width, primary action first (or the
  /// progress line under it, as the mocks have).
  final List<Widget> actions;

  /// A picture across the top, under the status bar, fading into the ground.
  final ArtImage? topArt;
  final TopArtLayout topArtLayout;

  /// A full-width part above the body (`TimerBand`, `Band`), under the status
  /// bar; it lays out its own safe-area inset.
  final Widget? topSlot;

  /// Between the pinned actions.
  final double actionGap;

  @override
  Widget build(BuildContext context) {
    final colors = context.skin.ground(ground);
    final safeTop = MediaQuery.paddingOf(context).top;
    final art = topArt;
    final slot = topSlot;

    const padded = EdgeInsets.symmetric(horizontal: Space.gutter);
    final Widget top;
    if (art != null) {
      final layout = topArtLayout;
      top = Stack(
        children: [
          SizedBox(
            height: layout.height + safeTop,
            width: double.infinity,
            child: _TopArt(
              art: art,
              fadeTo: colors.ground,
              fadeFrom: (layout.fadeFrom + safeTop) / (layout.height + safeTop),
            ),
          ),
          Padding(
            padding: padded.copyWith(top: layout.bodyTop + safeTop),
            child: body,
          ),
        ],
      );
    } else if (slot != null) {
      top = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          slot,
          Padding(
            padding: padded.copyWith(top: Space.lg),
            child: body,
          ),
        ],
      );
    } else {
      top = Padding(
        padding: padded.copyWith(top: Space.screenTop + safeTop),
        child: body,
      );
    }

    return Scaffold(
      backgroundColor: colors.ground,
      body: GroundScope(
        ground: ground,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxWidth),
            // The top runs under the status bar: each kind of top clears it
            // by itself (above).
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _ScrollBody(
                    fadeTo: colors.ground,
                    bottom: actions.isEmpty ? Space.screenBottom : Space.md,
                    child: top,
                  ),
                ),
                if (actions.isNotEmpty)
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Space.gutter,
                        Space.xs,
                        Space.gutter,
                        Space.screenBottom,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: actionGap,
                        children: actions,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The body, scrolling when it does not fit. While there is more below, the
/// ground fades in over its lower edge: the board, the list or the text goes
/// on past the button.
class _ScrollBody extends StatefulWidget {
  const _ScrollBody({
    required this.fadeTo,
    required this.bottom,
    required this.child,
  });

  final Color fadeTo;
  final double bottom;
  final Widget child;

  /// How tall the fade is.
  static const fade = Space.xxl;

  @override
  State<_ScrollBody> createState() => _ScrollBodyState();
}

class _ScrollBodyState extends State<_ScrollBody> {
  final _scroll = ScrollController();
  var _more = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool _measure(ScrollMetricsNotification note) {
    final more = note.metrics.extentAfter > 0;
    if (more != _more) setState(() => _more = more);
    return false;
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      NotificationListener<ScrollMetricsNotification>(
        onNotification: _measure,
        child: NotificationListener<ScrollUpdateNotification>(
          onNotification: (note) => _measure(
            ScrollMetricsNotification(metrics: note.metrics, context: context),
          ),
          child: SingleChildScrollView(
            controller: _scroll,
            padding: EdgeInsets.only(bottom: widget.bottom),
            child: widget.child,
          ),
        ),
      ),
      if (_more)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: _ScrollBody.fade,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [widget.fadeTo.withValues(alpha: 0), widget.fadeTo],
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

/// The top picture, its lower part fading into the ground.
class _TopArt extends StatelessWidget {
  const _TopArt({
    required this.art,
    required this.fadeTo,
    required this.fadeFrom,
  });

  final ArtImage art;
  final Color fadeTo;

  /// Where the fade starts, as a fraction of the height.
  final double fadeFrom;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      ArtPicture(art),
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [fadeFrom.clamp(0, 1), 1],
            colors: [fadeTo.withValues(alpha: 0), fadeTo],
          ),
        ),
      ),
    ],
  );
}
