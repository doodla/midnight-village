import 'package:flutter/material.dart';

import 'ground.dart';
import 'skin.dart';
import 'skin_theme.dart';

/// Declares the ground of a subtree (night, day, or the paper of a card).
/// Below it, `context.ground` gives that ground's colours and shadows, plain
/// text and icons take its text colour, and Material widgets get a theme made
/// for it. With [fill], it also paints the ground.
///
/// Outside any scope the ground is night.
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

  static GroundKind of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_GroundMarker>()?.kind ??
      GroundKind.night;

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

class _GroundMarker extends InheritedWidget {
  const _GroundMarker({required this.kind, required super.child});

  final GroundKind kind;

  @override
  bool updateShouldNotify(_GroundMarker oldWidget) => kind != oldWidget.kind;
}
