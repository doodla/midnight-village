import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:midnight_village/design_system/tokens/app_tokens_provider.dart';

/// Countdown timer display for discussion and night action phases.
///
/// Pure display widget — no countdown logic. Parent provides [remaining]
/// via a Timer or server-driven state.
///
/// Timer text is ≥48dp for readability at arm's length during face-to-face play.
class GameTimer extends ConsumerWidget {
  final Duration remaining;
  final Duration total;
  final bool showUrgency;

  const GameTimer({
    super.key,
    required this.remaining,
    required this.total,
    this.showUrgency = true,
  });

  bool get _isUrgent =>
      showUrgency &&
      total.inMilliseconds > 0 &&
      remaining.inMilliseconds <= total.inMilliseconds * 0.2;

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.clamp(0, 99);
    final seconds = d.inSeconds.remainder(60).clamp(0, 59);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(activeThemeProvider);
    final timerColor = _isUrgent ? tokens.colors.timerUrgent : tokens.colors.timerNormal;
    final progress = total.inMilliseconds > 0
        ? (remaining.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 120.0,
            height: 120.0,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 4.0,
              backgroundColor: tokens.colors.outline,
              color: tokens.colors.primary,
            ),
          ),
          Text(
            _formatDuration(remaining),
            style: tokens.typography.displayHeading.copyWith(
              fontSize: 48.0,
              color: timerColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
