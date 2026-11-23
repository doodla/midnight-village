import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../layout/space.dart';
import '../skin/art_set.dart';
import '../skin/dress.dart';
import '../skin/ground.dart';
import '../skin/ground_scope.dart';
import '../skin/skin.dart';
import '../skin/system_bars.dart';
import 'art_picture.dart';
import 'layered_art.dart';
import 'mood.dart';
import 'paper_light.dart';
import 'scene_arrival.dart';

part 'screen_frame_layout.dart';

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
  backdrop(height: 520, bodyTop: 52, fadeFrom: 300),

  /// A scene that takes all the height the body leaves (S01 Join): at least
  /// [scene]'s, the body at its foot over the last of its fade, so a tall
  /// phone shows more of the village instead of an empty lower half. The
  /// body still scrolls when it cannot fit.
  fill(height: 330, bodyTop: 282, fadeFrom: 160),

  /// A quiet strip behind a title (S06 the night board): 170 tall, the body
  /// from the top margin (where a screen with no picture starts it), the
  /// picture under a veil of the ground so the title is the loudest thing,
  /// fading from 100.
  strip(height: 170, bodyTop: Space.screenTop, fadeFrom: 100, veil: 0.5);

  const TopArtLayout({
    required this.height,
    required this.bodyTop,
    required this.fadeFrom,
    this.veil = 0,
  });

  final double height;
  final double bodyTop;
  final double fadeFrom;

  /// How much of the ground lies over the whole picture (0 none), for a
  /// picture that must stay behind what is written on it.
  final double veil;
}

/// Marks everything built under a [ScreenFrame]: the context a sheet or a
/// dialog is opened from must be under one (`showSkinSheet` asserts it), for
/// that is where the screen's dress, ground and light are declared. A State's
/// own `context`, above the frame it builds, is not (it showed a card's sheet
/// plain on a paper page): open from a widget the frame's body holds, or a
/// `Builder` in it.
class FrameMark extends InheritedWidget {
  const FrameMark({super.key, required super.child});

  /// Whether [context] is under a [ScreenFrame].
  static bool under(BuildContext context) =>
      context.getInheritedWidgetOfExactType<FrameMark>() != null;

  @override
  bool updateShouldNotify(FrameMark old) => false;
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
    this.topScene,
    this.topSceneFrom,
    this.topArtExtra = 0,
    this.topArtLayout = TopArtLayout.scene,
    this.topSlot,
    this.actionGap = Space.mdPlus,
    this.fitsHeight = false,
    this.minBodyHeight,
    this.backdrop,
    this.dress,
    this.mood,
    this.moodLight = MoodLight.standard,
    this.bleed = false,
    this.actionsFollow = false,
  }) : assert(
         topArt == null || topSlot == null,
         'A screen has a top picture or a top band, not both.',
       ),
       assert(
         topScene == null || (topArt == null && topSlot == null),
         'A screen has a top picture, a layered one or a top band, only one.',
       ),
       assert(
         topScene == null ||
             topArtLayout == TopArtLayout.backdrop ||
             topArtLayout == TopArtLayout.strip,
         'A layered top picture is a backdrop or a strip.',
       );

  /// The widest the phone layout gets.
  static const maxWidth = 440.0;

  /// How far, of its own height, a top picture comes down into place when a
  /// scene brings the screen in, beyond what the screen itself travels.
  static const arrivalTravel = 0.3;

  final GroundKind ground;
  final Widget body;

  /// Stacked at the bottom, full width, primary action first (or the
  /// progress line under it, as the mocks have).
  final List<Widget> actions;

  /// A picture across the top, under the status bar, fading into the ground.
  final ArtImage? topArt;

  /// The same, drawn in layers ([LayeredArt]): at rest the flat picture it
  /// was cut from; a scene that brings the screen in moves its layers.
  final LayeredSceneId? topScene;

  /// With [topScene] as a strip: the canvas row it starts at
  /// ([LayeredArt.from]).
  final double? topSceneFrom;

  /// A picture taller than its layout by this much (the body does not move):
  /// where a screen has air to spare, the picture takes it.
  final double topArtExtra;
  final TopArtLayout topArtLayout;

  /// A full-width part above the body (`TimerBand`, `Band`), under the status
  /// bar; it lays out its own safe-area inset.
  final Widget? topSlot;

  /// Between the pinned actions.
  final double actionGap;

  /// The body is given the height above the actions and does not scroll: a
  /// body that sizes itself to that height (the night board, whose every
  /// card must be on screen).
  final bool fitsHeight;

  /// With [fitsHeight] under a [topSlot]: the least height the body is
  /// given. Where the slot leaves less (a short phone, large text), the
  /// slot and the body scroll together, the body at this height, rather
  /// than overflow.
  final double? minBodyHeight;

  /// Drawn on the ground behind everything, never taking a touch (the
  /// scanner's faint village, `FaintArt`).
  final Widget? backdrop;

  /// How the screen is dressed: [Dress.plain] (the look the game has today)
  /// or [Dress.paper] (torn, grained, pinned paper in a mood of light). The
  /// frame declares it ([DressScope]); every shared part below reads it, and a
  /// screen draws nothing of the dress itself. Null: as the screen above it
  /// is (plain, unless a [DressScope] above says otherwise: a preview, a
  /// test). Only [Dress.paper] draws the [mood]: the light the screen stands
  /// in (the ground's own, night or day, unless the screen says otherwise:
  /// the results' dawn).
  final Dress? dress;
  final MoodKind? mood;

  /// Where a lantern's pool lies on the screen ([MoodKind.lantern]).
  final MoodLight moodLight;

  /// The body runs edge to edge under the [topSlot] and down to the screen's
  /// foot (08's square: the board, and the cobbles under its button): no
  /// gutters, no gap under the band, no margin at the foot. Such a body keeps
  /// clear of the navigation bar itself.
  final bool bleed;

  /// With [TopArtLayout.fill]: the [actions] are not pinned but follow the
  /// body inside the scroll, at the foot of the page when it all fits and
  /// below the body, reached by scrolling, when it does not (01's numbers and
  /// "Get the app": quiet lines that must never take the room a button
  /// needs on a short phone or above the keyboard).
  final bool actionsFollow;

  @override
  Widget build(BuildContext context) => DressScope(
    dress: dress ?? DressScope.of(context),
    child: FrameMark(child: Builder(builder: _build)),
  );

  static MoodKind? _moodOf(GroundKind ground) => switch (ground) {
    GroundKind.night => MoodKind.night,
    GroundKind.day => MoodKind.day,
    GroundKind.paper => null,
  };

  /// The light of a dressed screen (null: plain, or the paper ground, which
  /// has none).
  MoodKind? _moodKind(BuildContext context) =>
      context.dress.isPaper ? mood ?? _moodOf(ground) : null;

  /// What the pictures and the body's lower edge fade into: the ground (on a
  /// dressed screen the mood's own, so no seam shows where a fade ends).
  Color _fade(BuildContext context, Ground colors) =>
      switch (_moodKind(context)) {
        final kind? => Mood.fadeOf(kind, context.skin.mood),
        null => colors.ground,
      };

  Widget _build(BuildContext context) {
    final colors = context.skin.ground(ground);
    final safeTop = MediaQuery.paddingOf(context).top;
    final art = topArt;
    final scene = topScene;
    final slot = topSlot;

    final padded = bleed
        ? EdgeInsets.zero
        : const EdgeInsets.symmetric(horizontal: Space.gutter);
    final under = bleed ? 0.0 : Space.lg;
    // With no actions (which keep clear of the navigation bar themselves),
    // the body's end stays above it: the screen runs under the bars.
    final bottom = bleed
        ? 0.0
        : actions.isEmpty
        ? Space.screenBottom + MediaQuery.paddingOf(context).bottom
        : Space.md;
    final Widget top;
    if (art != null && topArtLayout == TopArtLayout.fill) {
      final follow = actionsFollow && actions.isNotEmpty;
      return _frame(
        context,
        colors,
        LayoutBuilder(
          builder: (context, box) => _ScrollBody(
            fadeTo: _fade(context, colors),
            bottom: follow
                ? Space.screenBottom + MediaQuery.paddingOf(context).bottom
                : bottom,
            child: _FillTop(
              minHeight:
                  box.maxHeight -
                  (follow
                      ? Space.screenBottom +
                            MediaQuery.paddingOf(context).bottom
                      : bottom),
              art: art,
              fadeTo: _fade(context, colors),
              safeTop: safeTop,
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(padding: padded, child: body),
                  if (follow)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Space.gutter,
                        Space.md + Space.xs,
                        Space.gutter,
                        0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: actionGap,
                        children: actions,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (art != null || scene != null) {
      final layout = topArtLayout;
      top = Stack(
        children: [
          SizedBox(
            height: layout.height + topArtExtra + safeTop,
            width: double.infinity,
            // Brought in by a scene (the dusk), the picture travels further
            // than the screen: it comes down into place from above, its moon
            // arriving last.
            child: ArrivalShift(
              travel: -arrivalTravel,
              child: _TopArt(
                picture: art != null
                    ? ArtPicture(art)
                    : LayeredArt(scene!, from: topSceneFrom),
                fadeTo: _fade(context, colors),
                fadeFrom:
                    (layout.fadeFrom + topArtExtra + safeTop) /
                    (layout.height + topArtExtra + safeTop),
                veil: layout.veil,
              ),
            ),
          ),
          Padding(
            padding: padded.copyWith(top: layout.bodyTop + safeTop),
            child: body,
          ),
        ],
      );
    } else if (slot != null && fitsHeight && minBodyHeight != null) {
      final rest = Padding(
        padding: padded.copyWith(top: under),
        child: body,
      );
      return _frame(
        context,
        colors,
        Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: LayoutBuilder(
            builder: (context, box) => _ScrollBody(
              fadeTo: _fade(context, colors),
              bottom: 0,
              child: _SlotThenRest(
                viewport: box.maxHeight,
                minRest: minBodyHeight! + under,
                children: [slot, rest],
              ),
            ),
          ),
        ),
      );
    } else if (slot != null) {
      final rest = Padding(
        padding: padded.copyWith(top: under),
        child: body,
      );
      top = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        // A body that sizes itself to the height is given what is left
        // under the band.
        children: [
          slot,
          if (fitsHeight) Expanded(child: rest) else rest,
        ],
      );
    } else {
      top = Padding(
        padding: padded.copyWith(top: Space.screenTop + safeTop),
        child: body,
      );
    }

    return _frame(
      context,
      colors,
      fitsHeight
          ? Padding(
              padding: EdgeInsets.only(bottom: bottom),
              child: top,
            )
          : _ScrollBody(
              fadeTo: _fade(context, colors),
              bottom: bottom,
              child: top,
            ),
    );
  }

  /// The screen around [main] (what goes above the pinned actions).
  Widget _frame(BuildContext context, Ground colors, Widget main) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemBarsOver(colors),
      child: _scaffold(context, colors, main),
    );
  }

  Widget _scaffold(BuildContext context, Ground colors, Widget main) {
    final light = _moodKind(context);
    final stack = Stack(
      fit: StackFit.expand,
      children: [
        if (light != null)
          Mood(
            kind: light,
            // A screen with a picture of its own has no need of the village
            // behind it.
            scene: topArt == null && topScene == null,
            light: moodLight,
          ),
        if (backdrop case final backdrop?)
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: maxWidth),
              child: IgnorePointer(child: backdrop),
            ),
          ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxWidth),
            // The top runs under the status bar: each kind of top clears it
            // by itself (above).
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: main),
                if (actions.isNotEmpty &&
                    !(actionsFollow && topArtLayout == TopArtLayout.fill))
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
      ],
    );
    return Scaffold(
      backgroundColor: colors.ground,
      body: GroundScope(
        ground: ground,
        child: light == null
            ? stack
            : PaperLight(
                lean: Mood.leanOf(light, context.skin.mood),
                child: stack,
              ),
      ),
    );
  }
}
