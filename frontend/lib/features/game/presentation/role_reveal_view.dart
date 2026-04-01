import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:midnight_village/design_system/components/game/role_card.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/tokens/app_tokens_provider.dart';

/// Seconds before the view auto-advances to the next night sub-view.
const int _kRoleRevealDurationSeconds = 4;

/// Dramatic role reveal shown at the start of the night phase.
///
/// Animates a [RoleCard] from face-down to face-up using an opacity+scale
/// transition, displays the role name, then auto-advances to the next sub-view
/// after [_kRoleRevealDurationSeconds] seconds.
///
/// The auto-advance timer is client-side. If the player returns from background
/// mid-night, reconnection logic (WP11) handles skipping to the current state.
class RoleRevealView extends ConsumerStatefulWidget {
  /// The role to reveal.
  final RoleId roleId;

  /// Called after the auto-advance timer fires.
  final VoidCallback onComplete;

  const RoleRevealView({
    super.key,
    required this.roleId,
    required this.onComplete,
  });

  @override
  ConsumerState<RoleRevealView> createState() => _RoleRevealViewState();
}

class _RoleRevealViewState extends ConsumerState<RoleRevealView>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;
  Timer? _autoAdvanceTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _animationController.forward();

    _autoAdvanceTimer = Timer(
      const Duration(seconds: _kRoleRevealDurationSeconds),
      widget.onComplete,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _autoAdvanceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(activeThemeProvider);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'You are the',
            style: tokens.typography.subheading.copyWith(
              color: tokens.colors.onBackground.withValues(alpha: 0.7),
            ),
          ),
          SizedBox(height: tokens.spacing.lg),
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Opacity(
                opacity: _opacityAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: child,
                ),
              );
            },
            child: RoleCard(roleId: widget.roleId),
          ),
          SizedBox(height: tokens.spacing.xl),
          AnimatedBuilder(
            animation: _opacityAnimation,
            builder: (context, child) =>
                Opacity(opacity: _opacityAnimation.value, child: child),
            child: Text(
              widget.roleId.displayName,
              style: tokens.typography.heading.copyWith(
                color: widget.roleId.teamColor(tokens.colors),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
