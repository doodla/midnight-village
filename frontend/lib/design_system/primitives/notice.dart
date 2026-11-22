import 'package:flutter/material.dart';

import '../layout/space.dart';
import '../skin/skin.dart';
import 'fit_line.dart';
import 'text_action.dart';

/// A banner on the screen's ground (first-time play spec, "Banners and
/// errors"): one line, its [message] and, when there is one, the action that
/// answers it as a quiet word ("Not sent." and "Try again"). No box, so it
/// takes one line of the screen and nothing else; a screen reader hears it as
/// it appears.
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
      child: Row(
        spacing: Space.sm,
        children: [
          Expanded(child: FitWords(message, style: style)),
          if (action case final action?)
            TextAction(label: action, onPressed: onAction),
        ],
      ),
    );
  }
}
