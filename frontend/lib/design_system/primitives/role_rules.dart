import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../copy/copy.dart';
import '../copy/role_text.dart';
import '../layout/space.dart';
import '../skin/skin.dart';
import 'fit_line.dart';

/// A role's text under its name, the one layout on the 04 face, the role
/// sheet (03b) and every card that tells a role (owner, 24 November 2026: "I'd
/// like the copy updated with different formatting so it's easier to
/// parse"): each part a row, its small label ("Night", "Vote", "Wins") in a
/// column of its own and its short lines beside it, one line per case; then,
/// after more room and across the whole width, the shared line ("You are
/// your last card."), a rule of the game rather than of this role. Form, not
/// words, parts them: the labels' column, the room between rows, the label's
/// small bold type.
///
/// The lines are in [body] (its colour is the ink of everything here); the
/// labels in the skin's tag type, level with their first line. Where the
/// lines' column would be too narrow for its words (a small phone at large
/// text: under [roomInWords] of its widest word), each label goes above its
/// lines instead, so no word is ever broken.
class RoleRules extends StatelessWidget {
  const RoleRules(
    this.text, {
    super.key,
    required this.body,
    this.compact = false,
  });

  final RoleText text;
  final TextStyle body;

  /// Closer rows, for a card short of room (the held face's compact step).
  final bool compact;

  /// Every label the column may hold: the column is as wide as the widest,
  /// so it is the same on every role's card.
  /// The least the lines' column holds beside the labels, in widths of the
  /// role's widest word.
  static const roomInWords = 1.5;

  static const _labels = [
    RoleCopy.nightLabel,
    RoleCopy.voteLabel,
    RoleCopy.winsLabel,
  ];

  @override
  Widget build(BuildContext context) {
    final type = context.skin.typography;
    final scaler = MediaQuery.textScalerOf(context);
    final ink = body.color;
    final label = type.tag.copyWith(color: ink);
    final column = _labels
        .map((l) => _width(context, l, label, scaler))
        .reduce(math.max);
    // The label's middle on its first line's middle.
    final drop = math.max(
      0.0,
      (scaler.scale(body.fontSize!) * (body.height ?? 1) -
              scaler.scale(label.fontSize!) * (label.height ?? 1)) /
          2,
    );
    final widest = {
      for (final part in text.parts)
        for (final line in part.lines) ...line.split(' '),
    }.map((word) => _width(context, word, body, scaler)).reduce(math.max);
    return LayoutBuilder(
      builder: (context, box) {
        final beside = box.maxWidth - column - Space.sm >= roomInWords * widest;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, part) in text.parts.indexed)
              Padding(
                padding: EdgeInsets.only(
                  top: i == 0 ? 0 : (compact ? Space.xs : Space.sm),
                ),
                child: _row(
                  beside: beside,
                  label: Text(part.label, style: label),
                  labelWidth: column,
                  drop: drop,
                  lines: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    spacing: compact ? 0 : Space.xxs,
                    children: [
                      for (final line in part.lines)
                        BalancedText(line, style: body),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.only(top: compact ? Space.sm : Space.md),
              child: BalancedText(RoleCopy.shared, style: body),
            ),
          ],
        );
      },
    );
  }

  /// A part: its label in the column beside its lines, or above them.
  static Widget _row({
    required bool beside,
    required Widget label,
    required double labelWidth,
    required double drop,
    required Widget lines,
  }) => beside
      ? Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: Space.sm,
          children: [
            SizedBox(
              width: labelWidth,
              child: Padding(
                padding: EdgeInsets.only(top: drop),
                child: label,
              ),
            ),
            Expanded(child: lines),
          ],
        )
      : Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [label, lines],
        );

  static double _width(
    BuildContext context,
    String text,
    TextStyle style,
    TextScaler scaler,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textScaler: scaler,
      textDirection: Directionality.of(context),
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width.ceilToDouble();
  }
}

/// A paragraph that never ends on one word alone (a widow): set at the full
/// width, and only when its last line would hold a single word, as narrow
/// as it can be in the same number of lines (CSS's `text-wrap: balance`),
/// which brings a word or two down to keep it company.
class BalancedText extends StatelessWidget {
  const BalancedText(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final span = TextSpan(text: text, style: style);
        final painter = TextPainter(
          text: span,
          textScaler: scaler,
          textDirection: Directionality.of(context),
        );
        final width = constraints.hasBoundedWidth
            ? FitWords.widowFreeWidth(painter, constraints.maxWidth)
            : null;
        painter.dispose();
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: SizedBox(
            // A hair over the measured width: the paragraph lays out as
            // measured, whatever the rounding.
            width: width == null
                ? null
                : math.min(constraints.maxWidth, width + 0.5),
            child: Text.rich(span),
          ),
        );
      },
    );
  }
}
