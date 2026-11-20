import 'package:flutter/material.dart';

import 'art_set.dart';
import 'ground.dart';
import 'ground_scope.dart';
import 'skin_shape.dart';
import 'skin_tilt.dart';
import 'skin_type.dart';

/// Everything a look may change, and nothing else: art, colours (per ground),
/// type, and shape (corners, border widths, hard shadows, tilt). Spacing and
/// motion are the same in every skin and live outside it
/// (`lib/design_system/layout/space.dart`). Screens are laid out once and read
/// the look through `context.skin` and `context.ground`, so a further look is a
/// further [Skin], not a further set of screens. A skin carries no name for
/// layout code to test: which skin is active is not a layout question.
@immutable
class Skin extends ThemeExtension<Skin> {
  const Skin({
    required this.night,
    required this.day,
    required this.paper,
    required this.typography,
    required this.fonts,
    required this.shape,
    required this.tilt,
    required this.art,
    required this.scrim,
    required this.dimmed,
    required this.waiting,
    required this.recessed,
  });

  final Ground night;
  final Ground day;
  final Ground paper;
  final SkinType typography;

  /// Where the faces [typography] names come from.
  final SkinFonts fonts;
  final SkinShape shape;
  final SkinTilt tilt;
  final ArtSet art;

  /// The veil behind a bottom sheet or dialog.
  final Color scrim;

  /// Opacity of things that are present but switched off (a role not in the
  /// deck).
  final double dimmed;

  /// Opacity of a player who has not done the thing being counted yet.
  final double waiting;

  /// Opacity of choices set back from the main ones (the center cards, S06).
  final double recessed;

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
    SkinFonts? fonts,
    SkinShape? shape,
    SkinTilt? tilt,
    ArtSet? art,
    Color? scrim,
    double? dimmed,
    double? waiting,
    double? recessed,
  }) => Skin(
    night: night ?? this.night,
    day: day ?? this.day,
    paper: paper ?? this.paper,
    typography: typography ?? this.typography,
    fonts: fonts ?? this.fonts,
    shape: shape ?? this.shape,
    tilt: tilt ?? this.tilt,
    art: art ?? this.art,
    scrim: scrim ?? this.scrim,
    dimmed: dimmed ?? this.dimmed,
    waiting: waiting ?? this.waiting,
    recessed: recessed ?? this.recessed,
  );

  /// Skins are swapped whole, never blended: until a theme animation ends the
  /// old skin is drawn, then the new one. (The app switches with no theme
  /// animation at all, so no frame mixes two skins; see `App`.)
  @override
  Skin lerp(covariant Skin? other, double t) =>
      other == null || t < 1 ? this : other;
}

/// Where a skin's faces come from.
@immutable
class SkinFonts {
  /// Declared under `fonts:` in pubspec.yaml: the engine loads them at start.
  /// Only the default skin's faces should be here; every phone pays for them.
  const SkinFonts.bundled() : onDemand = const {};

  /// Plain assets, loaded with a `FontLoader` only when the skin is chosen
  /// (`lib/design_system/skin/skin_loader.dart`): family to font files.
  const SkinFonts.onDemand(this.onDemand);

  final Map<String, List<String>> onDemand;
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
