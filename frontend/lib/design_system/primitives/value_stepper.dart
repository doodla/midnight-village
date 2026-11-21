import 'package:flutter/material.dart';

import '../layout/space.dart';
import '../skin/skin.dart';
import 'fit_line.dart';

/// A value between a minus and a plus (S03: the number of players, each
/// length): the glyphs are round outlined buttons of the reading floor's 44,
/// the value in the heading face (or the action face, [small]) between them, as wide as [widest] so the
/// glyphs never move as it changes. A glyph with nothing to do (the value at
/// its end of the range: [onLower] or [onHigher] null) is drawn off. The
/// glyphs are spoken as [lowerLabel] and [higherLabel]; the value as itself.
class ValueStepper extends StatelessWidget {
  const ValueStepper({
    super.key,
    required this.value,
    required this.widest,
    required this.lowerLabel,
    required this.higherLabel,
    this.onLower,
    this.onHigher,
    this.quiet = false,
    this.small = false,
  });

  final String value;

  /// The widest value this stepper shows, for its width.
  final String widest;
  final String lowerLabel;
  final String higherLabel;
  final VoidCallback? onLower;
  final VoidCallback? onHigher;

  /// The value drawn in the quiet ink (a setting that does nothing tonight).
  final bool quiet;

  /// The value in the action face, not the heading: one of a list of
  /// settings (the lengths), where the names need the room.
  final bool small;

  /// The glyph buttons' side: the reading floor's touch target.
  static const glyph = 44.0;

  TextStyle _style(BuildContext context) {
    final type = context.skin.typography;
    return (small ? type.action : type.heading).copyWith(
      color: quiet ? context.ground.quietText : context.ground.text,
    );
  }

  double _valueWidth(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(text: widest, style: _style(context)),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    final width = painter.width + Space.xs;
    painter.dispose();
    return width;
  }

  /// The width the stepper takes when it has room ([widest] at full size).
  double naturalWidth(BuildContext context) =>
      2 * glyph + 2 * Space.xs + _valueWidth(context);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, room) {
      // Narrower than its natural width: the value is set smaller, the
      // glyphs keep their touch size.
      final width = room.hasBoundedWidth
          ? (room.maxWidth - 2 * glyph - 2 * Space.xs).clamp(
              0.0,
              _valueWidth(context),
            )
          : _valueWidth(context);
      return Row(
        mainAxisSize: MainAxisSize.min,
        spacing: Space.xs,
        children: [
          _Glyph(icon: Icons.remove, label: lowerLabel, onTap: onLower),
          SizedBox(
            width: width,
            child: FitLine(value, style: _style(context)),
          ),
          _Glyph(icon: Icons.add, label: higherLabel, onTap: onHigher),
        ],
      );
    },
  );
}

/// A setting's name and its [stepper] (S03): side by side, the name
/// wrapping between words; where the name's longest word would not fit
/// beside the stepper (a narrow phone, large text), the name over it and the
/// stepper at the end.
class LabelledStepper extends StatelessWidget {
  const LabelledStepper({
    super.key,
    required this.label,
    required this.style,
    required this.stepper,
  });

  final String label;
  final TextStyle style;
  final ValueStepper stepper;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    var longest = 0.0;
    for (final word in label.split(' ')) {
      final painter = TextPainter(
        text: TextSpan(text: word, style: style),
        textScaler: scaler,
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();
      if (painter.width > longest) longest = painter.width;
      painter.dispose();
    }
    final name = FitWords(label, style: style);
    return LayoutBuilder(
      builder: (context, room) {
        final beside =
            room.maxWidth - stepper.naturalWidth(context) - Space.sm >= longest;
        if (beside) {
          return Row(
            spacing: Space.sm,
            children: [
              Expanded(child: name),
              stepper,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: Space.xxs,
          children: [
            name,
            Align(alignment: AlignmentDirectional.centerEnd, child: stepper),
          ],
        );
      },
    );
  }
}

class _Glyph extends StatelessWidget {
  const _Glyph({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    final on = onTap != null;
    final ink = on ? ground.text : ground.faintText;
    return Semantics(
      button: true,
      enabled: on,
      label: label,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          highlightColor: Colors.transparent,
          child: Container(
            width: ValueStepper.glyph,
            height: ValueStepper.glyph,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: on ? ground.outline : ground.hairline,
                width: skin.shape.stroke,
              ),
            ),
            child: Icon(icon, color: ink, size: ValueStepper.glyph / 2),
          ),
        ),
      ),
    );
  }
}
