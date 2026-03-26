import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:midnight_village/design_system/tokens/app_tokens.dart';
import 'package:midnight_village/design_system/tokens/app_tokens_provider.dart';

/// Visual variants for [MvButton].
enum MvButtonVariant { primary, secondary, destructive }

/// A themed button that respects the active design tokens.
///
/// Set [onPressed] to null to disable the button.
/// Set [isLoading] to true to show a spinner and block interaction.
class MvButton extends ConsumerWidget {
  final String label;
  final VoidCallback? onPressed;
  final MvButtonVariant variant;
  final bool isLoading;

  const MvButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = MvButtonVariant.primary,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(activeThemeProvider);

    final effectiveOnPressed = isLoading ? null : onPressed;

    switch (variant) {
      case MvButtonVariant.primary:
        return _buildElevated(
          tokens: tokens,
          backgroundColor: tokens.colors.primary,
          foregroundColor: tokens.colors.onPrimary,
          onPressed: effectiveOnPressed,
        );
      case MvButtonVariant.secondary:
        return _buildOutlined(
          tokens: tokens,
          onPressed: effectiveOnPressed,
        );
      case MvButtonVariant.destructive:
        return _buildElevated(
          tokens: tokens,
          backgroundColor: tokens.colors.error,
          foregroundColor: tokens.colors.onError,
          onPressed: effectiveOnPressed,
        );
    }
  }

  Widget _buildElevated({
    required AppTokens tokens,
    required Color backgroundColor,
    required Color foregroundColor,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        disabledBackgroundColor: tokens.colors.disabled,
        disabledForegroundColor: tokens.colors.onDisabled,
        textStyle: tokens.typography.label,
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.md,
          vertical: tokens.spacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
      child: _buildChild(foregroundColor, tokens),
    );
  }

  Widget _buildOutlined({
    required AppTokens tokens,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: tokens.colors.onSurface,
        disabledForegroundColor: tokens.colors.onDisabled,
        textStyle: tokens.typography.label,
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.md,
          vertical: tokens.spacing.sm,
        ),
        side: BorderSide(
          color: onPressed != null
              ? tokens.colors.outline
              : tokens.colors.disabled,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
      child: _buildChild(tokens.colors.onSurface, tokens),
    );
  }

  Widget _buildChild(Color foregroundColor, AppTokens tokens) {
    if (isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
        ),
      );
    }
    return Text(label);
  }
}
