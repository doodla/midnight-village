import 'package:flutter/material.dart';

import '../layout/space.dart';
import '../skin/skin.dart';
import 'fit_line.dart';
import 'panels.dart';
import 'secondary_button.dart';

/// A banner on the screen's ground (first-time play spec, "Banners and
/// errors"): its [message] and, when there is one, the action that answers
/// it ("Not sent." with "Try again"). A screen reader hears it as it
/// appears.
class Notice extends StatelessWidget {
  const Notice({super.key, required this.message, this.action, this.onAction})
    : assert((action == null) == (onAction == null));

  final String message;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final style = context.skin.typography.body.copyWith(
      color: context.ground.text,
    );
    return Semantics(
      liveRegion: true,
      child: OutlinePanel(
        child: Row(
          spacing: Space.md,
          children: [
            Expanded(child: FitWords(message, style: style)),
            if (action case final action?)
              SecondaryButton(label: action, onPressed: onAction),
          ],
        ),
      ),
    );
  }
}
