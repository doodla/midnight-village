// OLD LOOK: delete when 01 Join is rebuilt
@Deprecated(
  'OLD LOOK: delete when 01 Join is rebuilt. Build screens from lib/design_system/primitives/ instead.',
)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:midnight_village/design_system/tokens/app_tokens_provider.dart';

/// A themed text field with label, hint, and error support.
///
/// All visual properties are derived from the active theme tokens.
class MvTextInput extends ConsumerWidget {
  final String label;
  final String? hint;
  final String? errorText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final bool obscureText;
  final bool enabled;

  const MvTextInput({
    super.key,
    required this.label,
    this.hint,
    this.errorText,
    this.controller,
    this.onChanged,
    this.obscureText = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(activeThemeProvider);

    return TextField(
      controller: controller,
      onChanged: onChanged,
      obscureText: obscureText,
      enabled: enabled,
      style: tokens.typography.body.copyWith(color: tokens.colors.onSurface),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: tokens.typography.label.copyWith(
          color: tokens.colors.onSurface,
        ),
        hintText: hint,
        hintStyle: tokens.typography.body.copyWith(
          color: tokens.colors.disabled,
        ),
        errorText: errorText,
        errorStyle: tokens.typography.caption.copyWith(
          color: tokens.colors.error,
        ),
        filled: true,
        fillColor: tokens.colors.surface,
        enabledBorder: OutlineInputBorder(
          borderRadius: tokens.radius.medium,
          borderSide: BorderSide(color: tokens.colors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: tokens.radius.medium,
          borderSide: BorderSide(color: tokens.colors.primary, width: 2.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: tokens.radius.medium,
          borderSide: BorderSide(color: tokens.colors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: tokens.radius.medium,
          borderSide: BorderSide(color: tokens.colors.error, width: 2.0),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: tokens.radius.medium,
          borderSide: BorderSide(color: tokens.colors.disabled),
        ),
      ),
    );
  }
}
