import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../layout/space.dart';

/// Text kept to one line that is set smaller rather than broken or clipped:
/// for names that must never break mid-word ("Doppelganger", "Troublemaker").
/// Never drawn smaller than [floor] (the label floor, 12): a tag or a chip is
/// at its token, and a line that still does not fit says so (it overflows, and
/// the screen gallery and the fit sweep fail it) rather than shrinking out of
/// sight.
class FitLine extends StatelessWidget {
  const FitLine(
    this.text, {
    super.key,
    this.style,
    this.alignment = Alignment.center,
    this.floor = ReadingFloor.caption,
  });

  final String text;
  final TextStyle? style;

  /// Where the line sits in a box wider than it (a field's hint: the start).
  final AlignmentGeometry alignment;

  /// The least size the line is drawn at, text scale included (see
  /// [FitWords.floor]).
  final double floor;

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
          final painter = TextPainter(
            text: TextSpan(text: text, style: base),
            textDirection: direction,
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          final width = painter.width;
          painter.dispose();
          if (width > constraints.maxWidth) {
            final drawn = size * scaler.scale(1);
            final least = drawn > floor ? floor / drawn : 1.0;
            final factor = math.max(
              constraints.maxWidth / width * FitWords._safety,
              least,
            );
            fitted = FitWords._scaled(base, factor);
          }
        }
        return Align(
          alignment: alignment,
          widthFactor: 1,
          heightFactor: 1,
          child: Text(text, maxLines: 1, softWrap: false, style: fitted),
        );
      },
    );
  }
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
    this.noWidow = false,
    this.floor = ReadingFloor.caption,
  });

  final String text;
  final TextStyle style;
  final TextAlign? textAlign;

  /// At most this many lines: the text is set smaller until it fits them.
  final int? maxLines;

  /// Never ends on one word alone: where the last line would hold a single
  /// word, the text is set as narrow as it can be in the same number of
  /// lines ([widowFreeWidth]), which brings a word down to keep it company;
  /// where that cannot be, it is set smaller (not under 0.8 of its size) until
  /// it can.
  final bool noWidow;

  /// The least size the text is drawn at, in the phone's own pixels of text
  /// (the label floor, 12; larger text sizes are the player's own choice):
  /// where the room is still too small the words wrap further or overflow,
  /// and the screen gallery and the fit sweep fail it, rather than shrinking
  /// out of sight.
  final double floor;

  /// Measured text is set a hair smaller than the size it fits at.
  static const _safety = 0.99;

  /// The least a title is set at to keep a word from being left alone on its
  /// last line: 0.8 of its size.
  static const _oneLineLeast = 0.8;

  /// Whether [painter]'s laid-out text ends on a word alone.
  static bool endsAlone(TextPainter painter) {
    final lines = painter.computeLineMetrics();
    if (lines.length <= 1) return false;
    final last = lines.last;
    final start = painter.getPositionForOffset(
      Offset(0, last.baseline - last.ascent / 2),
    );
    return !painter.plainText.substring(start.offset).trim().contains(' ');
  }

  /// The width to set [painter]'s text at in [width]: [width], or, when the
  /// last line would hold a single word, the narrowest width that keeps the
  /// same number of lines (CSS's `text-wrap: balance`).
  static double widowFreeWidth(TextPainter painter, double width) {
    painter.layout(maxWidth: width);
    final lines = painter.computeLineMetrics();
    if (!endsAlone(painter)) return width;
    var low = width / 2;
    var high = width;
    for (var i = 0; i < 14; i++) {
      final middle = (low + high) / 2;
      painter.layout(maxWidth: middle);
      if (painter.computeLineMetrics().length > lines.length) {
        low = middle;
      } else {
        high = middle;
      }
    }
    return high;
  }

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final base = DefaultTextStyle.of(context).style.merge(style);
    return LayoutBuilder(
      builder: (context, constraints) {
        var fitted = base;
        double? narrow;
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
          // Never drawn under the floor (a text already at or under it keeps
          // its size).
          final drawn = size * scaler.scale(1);
          final least = drawn > floor ? floor / drawn : 1.0;
          var factor = widest > room ? room / widest * _safety : 1.0;
          factor = math.max(factor, least);
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
              factor = math.max(low * _safety, least);
            }
          }
          if (factor < 1) fitted = _scaled(base, factor);
          if (noWidow) {
            TextPainter measure(TextStyle of) => TextPainter(
              text: TextSpan(text: text, style: of),
              textDirection: direction,
              textScaler: scaler,
              textAlign: textAlign ?? TextAlign.start,
            );
            // The size it is at, or smaller down to [_oneLineLeast] of the
            // role's, at which no word is left alone on the last line: a
            // balanced width in the same lines, or one line.
            final from = fitted.fontSize! / size;
            for (var f = from; f >= _oneLineLeast - 0.001; f -= 0.01) {
              final candidate = f == from ? fitted : _scaled(base, f);
              final p = measure(candidate);
              // A hair over the width found: the paragraph lays out as
              // measured, whatever the rounding, and no more than a hair, or
              // the word that was brought down fits back on the line above.
              final balanced = math.min(room, widowFreeWidth(p, room) + 0.1);
              p.layout(maxWidth: balanced);
              final alone = endsAlone(p);
              final lines = p.computeLineMetrics().length;
              p.dispose();
              if (alone || lines > (maxLines ?? lines)) continue;
              fitted = candidate;
              if (balanced < room) narrow = balanced;
              break;
            }
          }
        }
        final words = Text(text, style: fitted, textAlign: textAlign);
        if (narrow == null) return words;
        return Align(
          alignment: switch (textAlign) {
            TextAlign.center => Alignment.topCenter,
            TextAlign.right || TextAlign.end => AlignmentDirectional.topEnd,
            _ => AlignmentDirectional.topStart,
          },
          widthFactor: 1,
          heightFactor: 1,
          child: SizedBox(width: narrow, child: words),
        );
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
