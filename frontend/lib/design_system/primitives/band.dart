import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

import '../layout/space.dart';
import '../skin/ground.dart';
import '../skin/art_set.dart';
import '../skin/ground_scope.dart';
import '../skin/skin.dart';
import '../skin/dress.dart';
import '../skin/paper_parts.dart';
import 'deckle.dart';
import 'fit_line.dart';
import 'layered_art.dart';
import 'paper_banner.dart';
import 'world_timer.dart';

part 'timer_band.dart';

/// What a [Band] is painted in.
enum BandTone {
  /// The night ground, on a day screen (the count's header, S10).
  night,

  /// Danger, with a curved foot (the winner's band when the Werewolves win,
  /// S11). Its content is on night.
  danger,
}

/// A strip across the top of a screen, edge to edge and under the status bar,
/// with its content inset by the gutter and the safe area. Put it in
/// `ScreenFrame.topSlot`. Its content is on night.
class Band extends StatelessWidget {
  const Band({super.key, required this.child, this.tone = BandTone.night});

  final Widget child;
  final BandTone tone;

  /// The mock's band padding (S10: 30 above, 20 below).
  static const _padding = EdgeInsets.fromLTRB(
    Space.gutter,
    Space.screenBottom + 2,
    Space.gutter,
    Space.lg + Space.xxs,
  );

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final top = MediaQuery.paddingOf(context).top;
    final night = skin.night;
    final content = Padding(
      padding: _padding.add(EdgeInsets.only(top: top)),
      child: GroundScope(ground: GroundKind.night, child: child),
    );
    return switch (tone) {
      BandTone.night => ColoredBox(color: night.ground, child: content),
      BandTone.danger => CustomPaint(
        painter: _ArchedFootPainter(
          fill: night.danger,
          shadow: night.elevation.primary.layers.first.color,
          ground: context.ground.ground,
          depth: Space.xxl * 1.5 * skin.shape.archRoundness,
          shadowDepth: Space.sm,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: Space.xxl * 1.5 * skin.shape.archRoundness + Space.sm,
          ),
          child: content,
        ),
      ),
    };
  }
}

/// A band whose foot curves down in the middle, with a hard shadow below it.
class _ArchedFootPainter extends CustomPainter {
  _ArchedFootPainter({
    required this.fill,
    required this.shadow,
    required this.ground,
    required this.depth,
    required this.shadowDepth,
  });

  final Color fill;
  final Color shadow;
  final Color ground;
  final double depth;
  final double shadowDepth;

  Path _shape(Size size, double drop) {
    final foot = size.height - shadowDepth - depth;
    return Path()
      ..lineTo(size.width, 0)
      ..lineTo(size.width, foot + drop)
      ..quadraticBezierTo(
        size.width / 2,
        foot + depth * 2 + drop,
        0,
        foot + drop,
      )
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..drawRect(Offset.zero & size, Paint()..color = ground)
      ..drawPath(_shape(size, shadowDepth), Paint()..color = shadow)
      ..drawPath(_shape(size, 0), Paint()..color = fill);
  }

  @override
  bool shouldRepaint(_ArchedFootPainter old) =>
      old.fill != fill ||
      old.shadow != shadow ||
      old.ground != ground ||
      old.depth != depth ||
      old.shadowDepth != shadowDepth;
}

/// The sky's window: its foot torn off along a seeded ragged line.
class _TornFoot extends CustomClipper<Path> {
  const _TornFoot(this.parts);

  final PaperParts parts;

  @override
  Path getClip(Size size) => DeckleBorder(
    seed: deckleSeed(#sky),
    depth: parts.skyDepth,
    step: parts.skyStep,
    torn: true,
  ).getOuterPath(Offset.zero & size);

  @override
  bool shouldReclip(_TornFoot old) => old.parts != parts;
}
