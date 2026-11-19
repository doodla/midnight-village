// OLD LOOK: delete when 01 Join, 02 Table and the game screens (04 to 11) are rebuilt
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:midnight_village/design_system/components/core/primary_button.dart';
import 'package:midnight_village/design_system/tokens/app_tokens_provider.dart';

/// A centered error display with an icon, message, and optional retry button.
///
/// The retry button uses the destructive variant to signal that the user
/// is recovering from an error state.
class MvError extends ConsumerWidget {
  final String message;
  final VoidCallback? onRetry;

  const MvError({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(activeThemeProvider);

    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: tokens.colors.error, size: 48),
            SizedBox(height: tokens.spacing.md),
            Text(
              message,
              style: tokens.typography.body.copyWith(
                color: tokens.colors.onBackground,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              SizedBox(height: tokens.spacing.md),
              PrimaryButton(
                label: 'Retry',
                onPressed: onRetry,
                isDestructive: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
