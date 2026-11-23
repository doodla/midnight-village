import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../layout/space.dart';
import '../skin/skin.dart';
import 'cut_paper.dart';
import 'fit_line.dart';

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
    final hintColor = _paper ? skin.paper.quietText : ground.quietText;
    final field = TextField(
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
        contentPadding: EdgeInsets.symmetric(
          horizontal: _paper ? Space.lg : Space.mdPlus,
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
      ),
    );
    return Semantics(
      textField: true,
      label: semanticLabel,
      child: Container(
        constraints: BoxConstraints(
          minHeight: _paper ? paperHeight : codeHeight,
        ),
        alignment: Alignment.centerLeft,
        decoration: _paper
            ? cutPaper(
                context,
                fill: ground.paper,
                radius: radius,
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
