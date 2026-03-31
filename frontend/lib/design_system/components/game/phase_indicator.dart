import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:midnight_village/design_system/models/game_phase.dart';
import 'package:midnight_village/design_system/tokens/app_tokens_provider.dart';

/// Horizontal stepper-style indicator showing all 5 game phases,
/// with visual differentiation between past, current, and future phases.
class PhaseIndicator extends ConsumerWidget {
  final GamePhase currentPhase;

  const PhaseIndicator({super.key, required this.currentPhase});

  static const _phases = GamePhase.values;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(activeThemeProvider);
    final currentIndex = _phases.indexOf(currentPhase);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_phases.length * 2 - 1, (i) {
        if (i.isOdd) {
          // Connector line between phase dots
          final phaseIndex = i ~/ 2;
          final isPast = phaseIndex < currentIndex;
          return Expanded(
            child: Container(
              height: 2.0,
              color: isPast ? tokens.colors.primary : tokens.colors.outline,
            ),
          );
        }

        final phaseIndex = i ~/ 2;
        final phase = _phases[phaseIndex];
        final isPast = phaseIndex < currentIndex;
        final isCurrent = phaseIndex == currentIndex;

        return _PhaseStep(phase: phase, isPast: isPast, isCurrent: isCurrent);
      }),
    );
  }
}

class _PhaseStep extends ConsumerWidget {
  final GamePhase phase;
  final bool isPast;
  final bool isCurrent;

  const _PhaseStep({
    required this.phase,
    required this.isPast,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(activeThemeProvider);

    final Color dotColor;
    final Color labelColor;
    final TextStyle labelStyle;

    if (isCurrent) {
      dotColor = tokens.colors.primary;
      labelColor = tokens.colors.primary;
      labelStyle = tokens.typography.label.copyWith(
        color: labelColor,
        fontWeight: FontWeight.w700,
      );
    } else if (isPast) {
      dotColor = tokens.colors.primary;
      labelColor = tokens.colors.disabled;
      labelStyle = tokens.typography.caption.copyWith(color: labelColor);
    } else {
      dotColor = tokens.colors.outline;
      labelColor = tokens.colors.disabled;
      labelStyle = tokens.typography.caption.copyWith(color: labelColor);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isCurrent ? 12.0 : 8.0,
          height: isCurrent ? 12.0 : 8.0,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCurrent || isPast ? dotColor : Colors.transparent,
            border: Border.all(color: dotColor, width: 1.5),
          ),
          child: isPast && !isCurrent
              ? Icon(Icons.check, size: 6.0, color: tokens.colors.onPrimary)
              : null,
        ),
        const SizedBox(height: 4.0),
        Text(
          _abbreviate(phase.displayName),
          style: labelStyle,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _abbreviate(String name) {
    // Compact labels to fit on narrow screens
    return switch (name) {
      'Discussion' => 'Disc.',
      'Voting' => 'Vote',
      _ => name,
    };
  }
}
