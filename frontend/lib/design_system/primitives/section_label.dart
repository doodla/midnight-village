import 'package:flutter/widgets.dart';

import '../layout/space.dart';
import '../skin/skin.dart';

/// A small capitalised label above a part of a screen ("At the table"), with
/// an optional note at the other end ("5 players"), or [centred] over a
/// centred part ("Center", S06; "You looked at", S07).
class SectionLabel extends StatelessWidget {
  const SectionLabel(
    this.text, {
    super.key,
    this.trailing,
    this.centred = false,
  }) : assert(!centred || trailing == null, 'A centred label has no note.');

  final String text;
  final String? trailing;
  final bool centred;

  @override
  Widget build(BuildContext context) {
    final style = context.skin.typography.label.copyWith(
      color: context.ground.quietText,
    );
    if (centred) {
      return Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          textAlign: TextAlign.center,
          style: style,
        ),
      );
    }
    return Semantics(
      header: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        spacing: Space.sm,
        children: [
          Expanded(child: Text(text.toUpperCase(), style: style)),
          if (trailing case final trailing?)
            Flexible(
              child: Text(
                trailing.toUpperCase(),
                textAlign: TextAlign.end,
                style: style,
              ),
            ),
        ],
      ),
    );
  }
}
