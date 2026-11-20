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

/// The frame every secret is drawn in: 04's card, "You" on the night board
/// and 08's My night. One size ([sizeFor]) on the night's ground on any
/// screen, so faces stay a similar size: the role's portrait, in colour, at
/// [portraitShare] of the frame's width, its name, tag and lines, and dots
/// for the pages when there are several. Its text is set at most
/// [maxTextScale] times larger, and smaller rather than out of the frame.
///
/// Hidden information: the words are left out of what a screen reader reads
/// unless the player asked for them ([announce], the explicit activation).
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

  /// The frame's width at most; a narrower phone gets a narrower frame.
  static const maxWidth = 342.0;

  /// The frame's height, on every phone: room for a whole role card.
  static const height = 342.0;

  /// The portrait's share of the frame's width; it is 3 wide to 4 high.
  static const portraitShare = 0.3;

  /// Faces cap their own text scale.
  static const maxTextScale = 1.6;

  /// The frame on a screen [available] wide (the gutters left out).
  static Size sizeFor(double available) =>
      Size(math.min(maxWidth, available - 2 * Space.gutter), height);

  /// The biggest portrait a face draws: what is decoded ahead of a reveal.
  static Size get portraitBox {
    final width = maxWidth * portraitShare;
    return Size(width, width * 4 / 3);
  }

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
        builder: (context, constraints) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.topStart,
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: _Words(
                    page,
                    portraitWidth:
                        constraints.maxWidth * HeldFace.portraitShare,
                  ),
                ),
              ),
            ),
            if (pages > 1) _Dots(current: index, count: pages),
          ],
        ),
      ),
    );
  }
}

/// The portrait with the name and tag beside it, the lines under them (a
/// result's few lines sit beside the portrait).
class _Words extends StatelessWidget {
  const _Words(this.page, {required this.portraitWidth});

  final FacePage page;
  final double portraitWidth;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ink = skin.night.text;
    final lines = [
      for (final line in page.lines)
        Text(line, style: skin.typography.body.copyWith(color: ink)),
    ];
    final named = page.name != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: Space.sm,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: Space.md,
          children: [
            SizedBox(
              width: portraitWidth,
              height: portraitWidth * 4 / 3,
              child: _Portrait(page.portrait),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: Space.sm,
                children: [
                  if (page.name case final name?)
                    FitLine(
                      name,
                      style: skin.typography.heading.copyWith(color: ink),
                    ),
                  if (page.tag case final tag?) TagChip(tag),
                  if (!named) ...lines,
                ],
              ),
            ),
          ],
        ),
        if (named) ...lines,
      ],
    );
  }
}

/// The face's portrait: a role, or the moon.
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
        RoleFacePortrait(:final role) => ArtPicture(skin.art.role(role)),
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
