import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../layout/space.dart';
import '../skin/dress.dart';
import '../skin/dress_style.dart';
import '../skin/skin.dart';
import 'deckled_paper.dart';
import 'fit_line.dart';
import 'paper_piece.dart';

/// A text field in the skin (S01):
/// - [SkinField.paper]: a piece of paper raised off the ground, the words in
///   the heading face (your name), 56 tall;
/// - [SkinField.code]: an outline on the ground, the words tracked out in
///   capitals (a table code), 52 tall.
class SkinField extends StatelessWidget {
  const SkinField.paper({
    super.key,
    this.controller,
    this.hint,
    this.semanticLabel,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.maxLength,
    this.inputFormatters = const [],
    this.autofocus = false,
    this.focusNode,
  }) : _paper = true;

  const SkinField.code({
    super.key,
    this.controller,
    this.hint,
    this.semanticLabel,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.maxLength,
    this.inputFormatters = const [],
    this.autofocus = false,
    this.focusNode,
  }) : _paper = false;

  final TextEditingController? controller;
  final String? hint;
  final String? semanticLabel;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final int? maxLength;
  final List<TextInputFormatter> inputFormatters;

  /// Takes the focus when it first shows (01's empty name).
  final bool autofocus;
  final FocusNode? focusNode;
  final bool _paper;

  static const paperHeight = 48.0;
  static const codeHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    final type = skin.typography;
    final radius = BorderRadius.circular(skin.shape.radius);
    final style = _paper
        ? type.name.copyWith(color: skin.paper.text)
        : type.code.copyWith(color: ground.text);
    final line = MediaQuery.textScalerOf(
      context,
    ).scale((style.fontSize ?? 0) * (style.height ?? 1));
    final constraints = BoxConstraints(
      minHeight: _paper ? paperHeight : codeHeight,
    );
    final hintColor = _paper ? skin.paper.quietText : ground.quietText;
    // The cursor blinks twice a second while the field has the focus: in its
    // own repaint boundary, a blink repaints the field and not the screen.
    final field = RepaintBoundary(
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: textInputAction,
        maxLength: maxLength,
        inputFormatters: inputFormatters,
        autofocus: autofocus,
        focusNode: focusNode,
        textCapitalization: _paper
            ? TextCapitalization.words
            : TextCapitalization.characters,
        style: style,
        cursorColor: _paper ? skin.paper.text : ground.selection,
        decoration: InputDecoration(
          // Set smaller on a narrow field with large text, never cut short.
          hint: hint == null
              ? null
              : FitLine(
                  hint!,
                  style: style.copyWith(color: hintColor),
                  alignment: AlignmentDirectional.centerStart,
                ),
          counterText: '',
          isDense: true,
          filled: false,
          // The line of text is padded out to the paper's height, so the whole
          // paper takes the finger, not only the line (and larger text grows
          // it).
          contentPadding: EdgeInsets.symmetric(
            horizontal: _paper ? Space.lg : Space.mdPlus,
            vertical: math.max(0, (constraints.minHeight - line) / 2),
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
    // Dressed up the field is a piece of paper (a bone scrap for the name, a
    // panel for the code): no outline. The paper never moves with the focus
    // (the cursor shows it): a web browser takes the focus away on the touch
    // that lands anywhere else, and the field must not drop as that part
    // sinks (the owner, 28 November 2026).
    final dressed = context.dress.isPaper;
    return Semantics(
      textField: true,
      label: semanticLabel,
      child: dressed
          ? ConstrainedBox(
              constraints: constraints,
              child: PaperPiece(
                part: _paper ? PaperPart.scrap : PaperPart.panel,
                id: (semanticLabel, #field),
                child: Align(alignment: Alignment.centerLeft, child: field),
              ),
            )
          : Container(
              constraints: constraints,
              alignment: Alignment.centerLeft,
              decoration: _paper
                  ? deckledPaper(
                      context,
                      fill: ground.paper,
                      id: (semanticLabel, #field),
                      elevation: ground.elevation.raised,
                    )
                  : BoxDecoration(
                      borderRadius: radius,
                      border: Border.all(
                        color: ground.outline,
                        width: skin.shape.stroke,
                      ),
                    ),
              child: field,
            ),
    );
  }
}
