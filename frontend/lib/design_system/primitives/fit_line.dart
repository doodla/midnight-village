import 'package:flutter/widgets.dart';

/// Text kept to one line that is set smaller rather than broken or clipped:
/// for names that must never break mid-word ("Doppelganger", "Troublemaker").
class FitLine extends StatelessWidget {
  const FitLine(
    this.text, {
    super.key,
    this.style,
    this.alignment = Alignment.center,
  });

  final String text;
  final TextStyle? style;

  /// Where the line sits in a box wider than it (a field's hint: the start).
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: alignment,
    child: Text(text, maxLines: 1, softWrap: false, style: style),
  );
}

/// Text that may wrap between words but never inside one, and is never cut
/// short: when its longest word is wider than the space, the whole text is
/// set smaller until that word fits ("The Werewolf wins" in a narrow band,
/// with large text); with [maxLines], smaller again until it fits that many
/// lines (a button's label, a name under a card).
class FitWords extends StatelessWidget {
  const FitWords(
    this.text, {
    super.key,
    required this.style,
    this.textAlign,
    this.maxLines,
  });

  final String text;
  final TextStyle style;
  final TextAlign? textAlign;

  /// At most this many lines: the text is set smaller until it fits them.
  final int? maxLines;

  /// Measured text is set a hair smaller than the size it fits at.
  static const _safety = 0.99;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final base = DefaultTextStyle.of(context).style.merge(style);
    return LayoutBuilder(
      builder: (context, constraints) {
        var fitted = base;
        final size = base.fontSize;
        if (constraints.hasBoundedWidth && size != null) {
          final room = constraints.maxWidth;
          TextPainter painter(String text, double factor, {int? lines}) =>
              TextPainter(
                text: TextSpan(text: text, style: _scaled(base, factor)),
                textDirection: direction,
                textScaler: scaler,
                textAlign: textAlign ?? TextAlign.start,
                maxLines: lines,
              )..layout(maxWidth: lines == 1 ? double.infinity : room);
          double width(String word) {
            final p = painter(word, 1, lines: 1);
            final w = p.width;
            p.dispose();
            return w;
          }

          final widest = text
              .split(RegExp(r'\s+'))
              .where((word) => word.isNotEmpty)
              .map(width)
              .fold(0.0, (a, b) => a > b ? a : b);
          var factor = widest > room ? room / widest * _safety : 1.0;
          if (maxLines case final most?) {
            bool fits(double f) {
              final p = painter(text, f);
              final lines = p.computeLineMetrics().length;
              p.dispose();
              return lines <= most;
            }

            if (!fits(factor)) {
              var low = 0.0;
              var high = factor;
              for (var i = 0; i < 20; i++) {
                final mid = (low + high) / 2;
                fits(mid) ? low = mid : high = mid;
              }
              factor = low * _safety;
            }
          }
          if (factor < 1) fitted = _scaled(base, factor);
        }
        return Text(text, style: fitted, textAlign: textAlign);
      },
    );
  }

  static TextStyle _scaled(TextStyle style, double factor) => factor == 1
      ? style
      : style.copyWith(
          fontSize: style.fontSize! * factor,
          letterSpacing: (style.letterSpacing ?? 0) * factor,
        );
}
