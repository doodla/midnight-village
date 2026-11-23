import 'package:flutter/material.dart';

import '../layout/space.dart';
import '../skin/dress.dart';
import '../skin/dress_style.dart';
import '../skin/skin.dart';
import 'fit_line.dart';
import 'paper_piece.dart';

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
  static const glyph = Sizes.touch;

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

  Widget _backed(BuildContext context, Widget value) => !context.dress.isPaper
      ? value
      : DecoratedBox(
          decoration: BoxDecoration(
            color: context.ground.ground.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(context.skin.shape.radius),
          ),
          child: value,
        );

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
          // Dressed up, on a backing of the ground, so the value stays readable
          // over the village behind (the moon passes under it on some phones).
          _backed(
            context,
            SizedBox(
              width: width,
              child: FitLine(value, style: _style(context)),
            ),
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
/// stepper at the end. [beside] decides it for a list that must stay even
/// (every row one way, [fitsBeside] of each). [onLabelLongPress]: a hold on
/// the name does it (a hidden switch: nothing on screen says so).
class LabelledStepper extends StatelessWidget {
  const LabelledStepper({
    super.key,
    required this.label,
    required this.style,
    required this.stepper,
    this.caption,
    this.beside,
    this.onLabelLongPress,
  });

  final String label;

  /// A few words under the name saying what it is (a timer's), in the
  /// caption face and full ink.
  final String? caption;
  final TextStyle style;
  final ValueStepper stepper;
  final bool? beside;
  final VoidCallback? onLabelLongPress;

  /// Whether the name's longest word fits beside the stepper in [width].
  bool fitsBeside(BuildContext context, double width) {
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
    return width - stepper.naturalWidth(context) - Space.sm >= longest;
  }

  @override
  Widget build(BuildContext context) {
    final words = FitWords(label, style: style);
    final hold = onLabelLongPress;
    // The hold answers on the words alone, never the room between them and
    // the stepper (a thumb near the minus must not switch anything).
    final name = hold == null
        ? words
        : Align(
            alignment: AlignmentDirectional.centerStart,
            child: GestureDetector(onLongPress: hold, child: words),
          );
    final caption = this.caption;
    final named = caption == null
        ? name
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              name,
              FitWords(
                caption,
                style: context.skin.typography.caption.copyWith(
                  color: context.ground.text,
                ),
              ),
            ],
          );
    return LayoutBuilder(
      builder: (context, room) {
        final beside = this.beside ?? fitsBeside(context, room.maxWidth);
        if (beside) {
          return Row(
            spacing: Space.sm,
            children: [
              Expanded(child: named),
              stepper,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: Space.xxs,
          children: [
            named,
            Align(alignment: AlignmentDirectional.centerEnd, child: stepper),
          ],
        );
      },
    );
  }
}

class _Glyph extends StatefulWidget {
  const _Glyph({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  State<_Glyph> createState() => _GlyphState();
}

class _GlyphState extends State<_Glyph> {
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    final onTap = widget.onTap;
    final on = onTap != null;
    final ink = on ? ground.text : ground.faintText;
    // Dressed up: a bone paper disc with the sign on it (a [PaperPiece]),
    // faded where the value is at its end; no ring.
    if (context.dress.isPaper) {
      return Semantics(
        button: true,
        enabled: on,
        label: widget.label,
        excludeSemantics: true,
        onTap: onTap,
        child: SizedBox.square(
          dimension: ValueStepper.glyph,
          child: PaperPiece(
            part: PaperPart.disc,
            id: widget.label,
            pressed: _pressed,
            enabled: on,
            child: Material(
              type: MaterialType.transparency,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onTap,
                customBorder: const CircleBorder(),
                highlightColor: Colors.transparent,
                focusColor: Colors.transparent,
                hoverColor: Colors.transparent,
                splashColor: Colors.transparent,
                onHighlightChanged: (v) => setState(() => _pressed = v),
                child: Icon(
                  widget.icon,
                  color: PaperPiece.inkOf(context, PaperPart.disc, enabled: on),
                  size: ValueStepper.glyph * Sizes.glyphInDisc,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Semantics(
      button: true,
      enabled: on,
      label: widget.label,
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
            child: Icon(
              widget.icon,
              color: ink,
              size: ValueStepper.glyph * Sizes.glyphInDisc,
            ),
          ),
        ),
      ),
    );
  }
}
