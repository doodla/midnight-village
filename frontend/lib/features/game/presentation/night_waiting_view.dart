import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:midnight_village/design_system/components/game/game_timer.dart';
import 'package:midnight_village/design_system/tokens/app_tokens_provider.dart';
import 'package:midnight_village/features/game/presentation/timer_provider.dart';

/// Atmospheric waiting screen shown when the player has no action this wave.
///
/// Displays the "The village sleeps…" message with a slow pulse animation and
/// an optional countdown timer when a [deadline] is provided.
class NightWaitingView extends ConsumerStatefulWidget {
  /// Server deadline for the current wave. When null, no timer is shown.
  final DateTime? deadline;

  const NightWaitingView({super.key, this.deadline});

  @override
  ConsumerState<NightWaitingView> createState() => _NightWaitingViewState();
}

class _NightWaitingViewState extends ConsumerState<NightWaitingView>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(activeThemeProvider);
    final timerAsync = ref.watch(gameTimerProvider(widget.deadline));

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) =>
                Opacity(opacity: _pulseAnimation.value, child: child),
            child: Icon(
              Icons.nights_stay_outlined,
              size: 64,
              color: tokens.colors.villageTeam,
            ),
          ),
          SizedBox(height: tokens.spacing.xl),
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) =>
                Opacity(opacity: _pulseAnimation.value, child: child),
            child: Text(
              'The village sleeps\u2026',
              style: tokens.typography.subheading.copyWith(
                color: tokens.colors.onBackground.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (widget.deadline != null) ...[
            SizedBox(height: tokens.spacing.xxl),
            GameTimer(timeRemaining: timerAsync.asData?.value ?? Duration.zero),
          ],
        ],
      ),
    );
  }
}
