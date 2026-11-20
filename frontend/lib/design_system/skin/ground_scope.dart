import 'package:flutter/material.dart';

import 'ground.dart';
import 'skin.dart';
import 'skin_theme.dart';

/// Declares the ground of a subtree (night, day, or the paper of a card).
/// Below it, `context.ground` gives that ground's colours and shadows, plain
/// text and icons take its text colour, and Material widgets get a theme made
/// for it. With [fill], it also paints the ground.
///
/// Every ground is declared: the app declares night at its root (`App`),
/// `ScreenFrame`, `PaperCard` and the bands declare theirs, and a sheet or
/// dialog carries the ground of the screen that opened it (the scope is an
/// [InheritedTheme], which routes capture). Asking for the ground with no
/// scope above is a mistake, and fails in debug builds.
class GroundScope extends StatelessWidget {
  const GroundScope({
    super.key,
    required this.ground,
    required this.child,
    this.fill = false,
  });

  final GroundKind ground;
  final Widget child;
  final bool fill;

  /// The ground of [context]. Asserts that one is declared; a release build
  /// that somehow has none gets night rather than a crash.
  static GroundKind of(BuildContext context) {
    final kind = maybeOf(context);
    assert(
      kind != null,
      'No GroundScope above this widget, so its ground (night, day or '
      'paper) is unknown. Wrap the screen in a ScreenFrame or a GroundScope; '
      'the app root declares night (App), tests use pumpSkinned.',
    );
    return kind ?? GroundKind.night;
  }

  /// The ground of [context], or null when none is declared.
  static GroundKind? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_GroundMarker>()?.kind;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final colors = skin.ground(ground);
    final scoped = _GroundMarker(
      kind: ground,
      child: Theme(
        data: skinTheme(skin, ground: ground),
        child: DefaultTextStyle(
          style: skin.typography.body.copyWith(color: colors.text),
          child: IconTheme.merge(
            data: IconThemeData(color: colors.text),
            child: child,
          ),
        ),
      ),
    );
    return fill ? ColoredBox(color: colors.ground, child: scoped) : scoped;
  }
}

/// Carried into routes by [InheritedTheme.capture], so a sheet or dialog is
/// on the ground of the screen that opened it.
class _GroundMarker extends InheritedTheme {
  const _GroundMarker({required this.kind, required super.child});

  final GroundKind kind;

  @override
  Widget wrap(BuildContext context, Widget child) =>
      GroundScope(ground: kind, child: child);

  @override
  bool updateShouldNotify(_GroundMarker oldWidget) => kind != oldWidget.kind;
}
