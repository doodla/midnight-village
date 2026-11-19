import 'package:flutter/material.dart';

import '../skin/art_set.dart';
import '../skin/ground.dart';
import '../skin/ground_scope.dart';
import '../skin/skin.dart';

/// A whole screen, laid out as a stack (design brief section 3, rule 6): an
/// optional picture across the top fading into the ground, the [body]
/// (scrolling when it does not fit), and [actions] pinned to the bottom. Each
/// part starts where the one above ends, so larger text pushes things down
/// instead of overlapping. On a wide screen the phone layout is centred and
/// the ground fills the rest.
class ScreenFrame extends StatelessWidget {
  const ScreenFrame({
    super.key,
    required this.ground,
    required this.body,
    this.actions = const [],
    this.topArt,
    this.topArtHeight = 0,
    this.topArtOverlap = 0,
  });

  /// The widest the phone layout gets.
  static const maxWidth = 440.0;

  final GroundKind ground;
  final Widget body;

  /// Stacked at the bottom, full width, primary action first.
  final List<Widget> actions;

  /// A picture across the top, [topArtHeight] tall, under the status bar.
  final ArtImage? topArt;
  final double topArtHeight;

  /// How far the body reaches up into the picture's faded foot.
  final double topArtOverlap;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final colors = skin.ground(ground);
    final space = skin.spacing;
    final art = topArt;

    final padded = Padding(
      padding: EdgeInsets.symmetric(horizontal: space.gutter),
      child: body,
    );
    final top = art == null
        ? SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.only(top: space.screenTop),
              child: padded,
            ),
          )
        : Stack(
            children: [
              SizedBox(
                height: topArtHeight,
                width: double.infinity,
                child: _TopArt(art: art, fadeTo: colors.ground),
              ),
              Padding(
                padding: EdgeInsets.only(top: topArtHeight - topArtOverlap),
                child: padded,
              ),
            ],
          );

    return Scaffold(
      backgroundColor: colors.ground,
      body: GroundScope(
        ground: ground,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      bottom: actions.isEmpty ? space.screenBottom : space.md,
                    ),
                    child: top,
                  ),
                ),
                if (actions.isNotEmpty)
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        space.gutter,
                        space.xs,
                        space.gutter,
                        space.screenBottom,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: space.md,
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

/// The top picture, its lower part fading into the ground.
class _TopArt extends StatelessWidget {
  const _TopArt({required this.art, required this.fadeTo});

  final ArtImage art;
  final Color fadeTo;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Image(image: art.provider, fit: BoxFit.cover, alignment: art.focus),
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.5, 1],
            colors: [fadeTo.withValues(alpha: 0), fadeTo],
          ),
        ),
      ),
    ],
  );
}
