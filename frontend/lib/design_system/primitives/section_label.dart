import 'package:flutter/widgets.dart';

import '../skin/skin.dart';

/// A small capitalised label above a part of a screen ("At the table"), with
/// an optional note at the other end ("5 players").
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final style = context.skin.typography.label.copyWith(
      color: context.ground.quietText,
    );
    return Semantics(
      header: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(child: Text(text.toUpperCase(), style: style)),
          if (trailing case final trailing?)
            Text(trailing.toUpperCase(), style: style),
        ],
      ),
    );
  }
}
