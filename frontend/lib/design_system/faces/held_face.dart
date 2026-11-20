import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../layout/space.dart';
import '../primitives/art_picture.dart';
import '../primitives/fit_line.dart';
import '../primitives/tag_chip.dart';
import '../skin/ground.dart';
import '../skin/ground_scope.dart';
import '../skin/skin.dart';
import 'face_content.dart';

/// The one frame every secret is drawn in (first-time play spec, section 2,
/// "The held-face frame"): 04's card, "You" on the night board, 07, and
/// 08's My night. Always the same fixed size ([sizeFor]), on the night's
/// ground on any screen; at most one portrait, in the night's two colours
/// (bone on indigo, never red) and [portraitShare] of the frame's width;
/// bone text, at most two lines and a role's name; dots for the pages
/// when there are several. Its text is set at most [maxTextScale] times
/// larger, and smaller rather than out of the frame.
///
/// Hidden information: the frame's size and place never depend on what it
/// says (a long face and a short one are the same shape from the side), and
/// its words are left out of what a screen reader reads unless the player
/// asked for them ([announce], the explicit activation).
class HeldFace extends StatelessWidget {
  const HeldFace({
    super.key,
    required this.content,
    required this.page,
    this.announce = false,
  });

  final FaceContent content;

  /// Which page shows: each new hold shows the next.
  final int page;

  /// Read the page aloud (the player activated the face with a screen
  /// reader, a switch or the keyboard).
  final bool announce;

  /// The frame's width at most; narrower phones get a narrower frame of the
  /// same shape.
  static const maxWidth = 342.0;

  /// Height over width.
  static const aspect = 0.82;

  /// The portrait's share of the frame's width.
  static const portraitShare = 0.3;

  /// Faces cap their own text scale.
  static const maxTextScale = 1.6;

  /// The frame on a screen [available] wide (the gutters left out).
  static Size sizeFor(double available) {
    final width = math.min(maxWidth, available - 2 * Space.gutter);
    return Size(width, width * aspect);
  }

  /// The biggest portrait a face draws: what is decoded ahead of a reveal.
  static Size get portraitBox =>
      Size(maxWidth * portraitShare, maxWidth * aspect - 2 * Space.md);

  @override
  Widget build(BuildContext context) {
    final shown = content.pages[page % content.pages.length];
    final frame = SizedBox.fromSize(
      size: sizeFor(MediaQuery.sizeOf(context).width),
      child: GroundScope(
        ground: GroundKind.night,
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: maxTextScale,
          child: _Frame(
            page: shown,
            index: page % content.pages.length,
            pages: content.pages.length,
          ),
        ),
      ),
    );
    if (!announce) return ExcludeSemantics(child: frame);
    return Semantics(
      container: true,
      liveRegion: true,
      label: shown.spoken,
      child: ExcludeSemantics(child: frame),
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.page, required this.index, required this.pages});

  final FacePage page;
  final int index;
  final int pages;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final night = skin.night;
    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: night.ground,
        borderRadius: BorderRadius.circular(skin.shape.radius),
        border: Border.all(color: night.text, width: skin.shape.ring),
        boxShadow: night.elevation.raised.boxShadows,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final portraitWidth =
              (constraints.maxWidth + 2 * Space.md) * HeldFace.portraitShare;
          final textWidth = constraints.maxWidth - portraitWidth - Space.md;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: Space.md,
            children: [
              SizedBox(width: portraitWidth, child: _Portrait(page.portrait)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.topStart,
                        child: SizedBox(width: textWidth, child: _Words(page)),
                      ),
                    ),
                    if (pages > 1) _Dots(current: index, count: pages),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Words extends StatelessWidget {
  const _Words(this.page);

  final FacePage page;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ink = skin.night.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: Space.sm,
      children: [
        if (page.name case final name?)
          FitLine(name, style: skin.typography.heading.copyWith(color: ink)),
        if (page.tag case final tag?) TagChip(tag),
        for (final line in page.lines)
          Text(line, style: skin.typography.body.copyWith(color: ink)),
      ],
    );
  }
}

/// The face's one portrait: a role in the night's two colours, or the moon.
class _Portrait extends StatelessWidget {
  const _Portrait(this.portrait);

  final FacePortrait portrait;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final night = skin.night;
    final radius = BorderRadius.circular(skin.shape.radiusSmall);
    return ClipRRect(
      borderRadius: radius,
      child: switch (portrait) {
        RoleFacePortrait(:final role) => ColorFiltered(
          colorFilter: duotone(dark: night.ground, light: night.text),
          child: ArtPicture(skin.art.role(role)),
        ),
        MoonFacePortrait() => ColoredBox(
          color: night.panel,
          child: FittedBox(
            child: Padding(
              padding: const EdgeInsets.all(Space.sm),
              child: Icon(Icons.nightlight_round, color: night.text),
            ),
          ),
        ),
      },
    );
  }
}

/// A picture in two colours: its darks in [dark], its lights in [light], by
/// luminance (so a red in the art is a mid tone, never red).
ColorFilter duotone({required Color dark, required Color light}) {
  // One output channel: from + (to - from) x luminance (channels 0 to 255).
  List<double> row(double from, double to) {
    final span = to - from;
    return [0.2126 * span, 0.7152 * span, 0.0722 * span, 0, from * 255];
  }

  return ColorFilter.matrix([
    ...row(dark.r, light.r),
    ...row(dark.g, light.g),
    ...row(dark.b, light.b),
    0, 0, 0, 1, 0, //
  ]);
}

class _Dots extends StatelessWidget {
  const _Dots({required this.current, required this.count});

  final int current;
  final int count;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final night = skin.night;
    return Padding(
      padding: const EdgeInsets.only(top: Space.sm),
      child: Row(
        spacing: Space.xs,
        children: [
          for (var i = 0; i < count; i++)
            Container(
              width: Space.sm,
              height: Space.sm,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == current ? night.text : night.hairline,
              ),
            ),
        ],
      ),
    );
  }
}
