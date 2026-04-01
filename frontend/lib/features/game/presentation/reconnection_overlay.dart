import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/components/core/mv_loading.dart';
import '../../../design_system/tokens/app_tokens_provider.dart';

/// Semi-transparent overlay shown during WebSocket disconnection.
///
/// Displays a spinner and "Reconnecting..." text on top of the game view.
/// The underlying game content remains partially visible through the overlay,
/// providing context while communicating connection loss.
///
/// This is a presentational widget -- it does not manage WebSocket state.
/// The parent decides when to show/hide it via [isVisible].
class ReconnectionOverlay extends ConsumerWidget {
  const ReconnectionOverlay({super.key, required this.isVisible});

  /// Whether the overlay is currently displayed.
  final bool isVisible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isVisible) return const SizedBox.shrink();

    final tokens = ref.watch(activeThemeProvider);

    return Positioned.fill(
      child: ColoredBox(
        color: tokens.colors.background.withValues(alpha: 0.75),
        child: const MvLoading(message: 'Reconnecting...'),
      ),
    );
  }
}
