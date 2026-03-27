import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:midnight_village/design_system/components/core/primary_button.dart';
import 'package:midnight_village/design_system/tokens/app_tokens_provider.dart';

/// A themed dialog with title, body text, and action buttons.
///
/// Use the named factories for common patterns:
/// - [MvDialog.confirmation] for confirm/cancel dialogs
/// - [MvDialog.info] for informational dialogs with a dismiss button
/// - [MvDialog.error] for error dialogs with an error icon and optional retry
///
/// Use [MvDialog.show] to display a dialog:
/// ```dart
/// MvDialog.show(context, MvDialog.info(
///   title: 'Done',
///   body: 'Operation completed.',
///   onDismiss: () => Navigator.of(context).pop(),
/// ));
/// ```
class MvDialog extends ConsumerWidget {
  final String title;
  final String body;
  final List<Widget> actions;
  final bool _showErrorIcon;

  const MvDialog({
    super.key,
    required this.title,
    required this.body,
    required this.actions,
  }) : _showErrorIcon = false;

  const MvDialog._withErrorIcon({
    super.key,
    required this.title,
    required this.body,
    required this.actions,
  }) : _showErrorIcon = true;

  /// Creates a confirmation dialog with confirm and cancel buttons.
  ///
  /// If [onCancel] is null, the caller is responsible for dismissing the
  /// dialog inside [onConfirm]. Typically both callbacks should call
  /// `Navigator.of(context).pop()`.
  factory MvDialog.confirmation({
    Key? key,
    required String title,
    required String body,
    required String confirmLabel,
    required VoidCallback onConfirm,
    String cancelLabel = 'Cancel',
    VoidCallback? onCancel,
  }) {
    return MvDialog(
      key: key,
      title: title,
      body: body,
      actions: [
        PrimaryButton.outlined(
          label: cancelLabel,
          onPressed: onCancel,
        ),
        PrimaryButton(
          label: confirmLabel,
          onPressed: onConfirm,
        ),
      ],
    );
  }

  /// Creates an informational dialog with a single dismiss button.
  factory MvDialog.info({
    Key? key,
    required String title,
    required String body,
    String dismissLabel = 'OK',
    VoidCallback? onDismiss,
  }) {
    return MvDialog(
      key: key,
      title: title,
      body: body,
      actions: [
        PrimaryButton(
          label: dismissLabel,
          onPressed: onDismiss,
        ),
      ],
    );
  }

  /// Creates an error dialog with an error icon above the title.
  ///
  /// If [onRetry] is provided, a retry button is shown alongside the
  /// dismiss button.
  factory MvDialog.error({
    Key? key,
    required String title,
    required String body,
    String dismissLabel = 'OK',
    VoidCallback? onDismiss,
    String? retryLabel,
    VoidCallback? onRetry,
  }) {
    final actions = <Widget>[
      PrimaryButton.outlined(
        label: dismissLabel,
        onPressed: onDismiss,
      ),
      if (onRetry != null)
        PrimaryButton(
          label: retryLabel ?? 'Retry',
          onPressed: onRetry,
          isDestructive: true,
        ),
    ];

    return MvDialog._withErrorIcon(
      key: key,
      title: title,
      body: body,
      actions: actions,
    );
  }

  /// Shows this dialog using [showDialog].
  static Future<void> show(BuildContext context, MvDialog dialog) {
    return showDialog(context: context, builder: (_) => dialog);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(activeThemeProvider);

    Widget titleWidget = Text(
      title,
      style: tokens.typography.heading.copyWith(
        color: tokens.colors.onSurface,
      ),
    );

    if (_showErrorIcon) {
      titleWidget = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            color: tokens.colors.error,
            size: 48,
          ),
          SizedBox(height: tokens.spacing.sm),
          titleWidget,
        ],
      );
    }

    return AlertDialog(
      backgroundColor: tokens.colors.surface,
      title: titleWidget,
      content: Text(
        body,
        style: tokens.typography.body.copyWith(
          color: tokens.colors.onSurface,
        ),
      ),
      actions: actions,
      shape: RoundedRectangleBorder(
        borderRadius: tokens.radius.large,
      ),
      elevation: tokens.elevation.overlay,
    );
  }
}
