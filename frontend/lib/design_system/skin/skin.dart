import 'package:flutter/material.dart';

import 'art_set.dart';
import 'ground.dart';
import 'ground_scope.dart';
import 'skin_motion.dart';
import 'skin_shape.dart';
import 'skin_spacing.dart';
import 'skin_tilt.dart';
import 'skin_type.dart';

/// Everything a look may change, and nothing else: colours (per ground),
/// type, shape, shadows, spacing, motion, tilt and art. Screens are laid out
/// once and read all of this through `context.skin` and `context.ground`, so a
/// second look is a second [Skin], not a second set of screens. A skin carries
/// no name for layout code to test: which skin is active is not a layout
/// question.
@immutable
class Skin extends ThemeExtension<Skin> {
  const Skin({
    required this.night,
    required this.day,
    required this.paper,
    required this.typography,
    required this.shape,
    required this.spacing,
    required this.motion,
    required this.tilt,
    required this.art,
    required this.scrim,
    required this.dimmed,
  });

  final Ground night;
  final Ground day;
  final Ground paper;
  final SkinType typography;
  final SkinShape shape;
  final SkinSpacing spacing;
  final SkinMotion motion;
  final SkinTilt tilt;
  final ArtSet art;

  /// The veil behind a bottom sheet or dialog.
  final Color scrim;

  /// Opacity of things that are present but switched off.
  final double dimmed;

  Ground ground(GroundKind kind) => switch (kind) {
    GroundKind.night => night,
    GroundKind.day => day,
    GroundKind.paper => paper,
  };

  @override
  Skin copyWith({
    Ground? night,
    Ground? day,
    Ground? paper,
    SkinType? typography,
    SkinShape? shape,
    SkinSpacing? spacing,
    SkinMotion? motion,
    SkinTilt? tilt,
    ArtSet? art,
    Color? scrim,
    double? dimmed,
  }) => Skin(
    night: night ?? this.night,
    day: day ?? this.day,
    paper: paper ?? this.paper,
    typography: typography ?? this.typography,
    shape: shape ?? this.shape,
    spacing: spacing ?? this.spacing,
    motion: motion ?? this.motion,
    tilt: tilt ?? this.tilt,
    art: art ?? this.art,
    scrim: scrim ?? this.scrim,
    dimmed: dimmed ?? this.dimmed,
  );

  /// Skins are swapped, not blended: halfway through a theme animation the
  /// new one takes over.
  @override
  Skin lerp(covariant Skin? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

extension SkinContext on BuildContext {
  /// The active skin, from the theme.
  Skin get skin {
    final skin = Theme.of(this).extension<Skin>();
    if (skin == null) {
      throw FlutterError(
        'No Skin in the theme. Build the app theme with skinTheme() '
        '(lib/design_system/skin/skin_theme.dart).',
      );
    }
    return skin;
  }

  /// The colours and shadows of the ground this widget is on (see
  /// [GroundScope]).
  Ground get ground => skin.ground(GroundScope.of(this));
}
