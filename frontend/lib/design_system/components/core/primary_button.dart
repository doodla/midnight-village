// OLD LOOK: delete when the last old-look screen is rebuilt
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:midnight_village/design_system/tokens/app_tokens.dart';
import 'package:midnight_village/design_system/tokens/app_tokens_provider.dart';

/// The primary interactive button for the Firelit Gothic design system.
///
/// Use [PrimaryButton] for filled (default) and destructive actions.
/// Use [PrimaryButton.outlined] for secondary/cancel actions.
///
/// Set [onPressed] to null to disable.
/// Set [isLoading] to true to show a spinner and block interaction.
/// Set [isDestructive] to true to use the error color (filled variant only).
class PrimaryButton extends ConsumerWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDestructive;
  final IconData? icon;
  final bool _isOutlined;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isDestructive = false,
    this.icon,
  }) : _isOutlined = false;

  const PrimaryButton.outlined({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
  }) : _isOutlined = true,
       isDestructive = false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(activeThemeProvider);
    final effectiveOnPressed = isLoading ? null : onPressed;

    if (_isOutlined) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: effectiveOnPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: tokens.colors.onSurface,
            side: BorderSide(color: tokens.colors.outline),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: tokens.radius.medium),
          ),
          child: _buildChild(tokens),
        ),
      );
    }

    final bgColor = isDestructive ? tokens.colors.error : tokens.colors.primary;
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: effectiveOnPressed,
        style: FilledButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: tokens.colors.onPrimary,
          disabledBackgroundColor: tokens.colors.disabled,
          disabledForegroundColor: tokens.colors.onDisabled,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: tokens.radius.medium),
        ),
        child: _buildChild(tokens),
      ),
    );
  }

  Widget _buildChild(AppTokens tokens) {
    if (isLoading) {
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: tokens.colors.onPrimary,
        ),
      );
    }
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          SizedBox(width: tokens.spacing.sm),
          Text(label),
        ],
      );
    }
    return Text(label);
  }
}
