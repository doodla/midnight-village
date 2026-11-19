// OLD LOOK: delete when 05 Night waiting, 06 Night action, 08 Talk and 09 Vote are rebuilt
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:midnight_village/design_system/tokens/app_tokens_provider.dart';

/// Seconds threshold below which the timer switches to urgency color.
const int _kUrgencyThreshold = 10;

/// Shows a countdown timer with an urgency color shift.
///
/// Displays in MM:SS format for durations >= 60 s, and as bare seconds for
/// sub-60 s. Color shifts from [AppColorTokens.timerNormal] to
/// [AppColorTokens.timerUrgent] when [timeRemaining] drops to
/// [_kUrgencyThreshold] seconds or below.
class GameTimer extends ConsumerWidget {
  final Duration timeRemaining;

  const GameTimer({super.key, required this.timeRemaining});

  String _formatDuration(Duration d) {
    final int totalSeconds = d.inSeconds < 0 ? 0 : d.inSeconds;
    if (totalSeconds >= 60) {
      final int minutes = totalSeconds ~/ 60;
      final int seconds = totalSeconds % 60;
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return totalSeconds.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(activeThemeProvider);

    final bool isUrgent = timeRemaining.inSeconds <= _kUrgencyThreshold;
    final Color timerColor = isUrgent
        ? tokens.colors.timerUrgent
        : tokens.colors.timerNormal;

    return Semantics(
      label: 'Time remaining: ${_formatDuration(timeRemaining)}',
      child: Text(
        _formatDuration(timeRemaining),
        style: tokens.typography.heading.copyWith(color: timerColor),
        textAlign: TextAlign.center,
      ),
    );
  }
}
