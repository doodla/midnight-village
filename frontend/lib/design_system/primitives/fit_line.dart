import 'package:flutter/widgets.dart';

/// Text kept to one line that is set smaller rather than broken or clipped:
/// for names that must never break mid-word ("Doppelganger", "Troublemaker").
class FitLine extends StatelessWidget {
  const FitLine(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(text, maxLines: 1, softWrap: false, style: style),
  );
}

/// Text that may wrap between words but never inside one: when its longest
/// word is wider than the space, the whole text is set smaller until that
/// word fits ("The Werewolf wins" in a narrow band, with large text).
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

  /// At most this many lines, the last ending in an ellipsis.
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final base = DefaultTextStyle.of(context).style.merge(style);
    return LayoutBuilder(
      builder: (context, constraints) {
        var fitted = base;
        if (constraints.hasBoundedWidth) {
          final widest = text
              .split(RegExp(r'\s+'))
              .where((word) => word.isNotEmpty)
              .map((word) {
                final painter = TextPainter(
                  text: TextSpan(text: word, style: base),
                  textDirection: direction,
                  textScaler: scaler,
                  maxLines: 1,
                )..layout();
                final width = painter.width;
                painter.dispose();
                return width;
              })
              .fold(0.0, (a, b) => a > b ? a : b);
          if (widest > constraints.maxWidth && base.fontSize != null) {
            final factor = constraints.maxWidth / widest * 0.99;
            fitted = base.copyWith(
              fontSize: base.fontSize! * factor,
              letterSpacing: (base.letterSpacing ?? 0) * factor,
            );
          }
        }
        return Text(
          text,
          style: fitted,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: maxLines == null ? null : TextOverflow.ellipsis,
        );
      },
    );
  }
}
