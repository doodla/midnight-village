// OLD LOOK: delete when 01 Join, 02 Table and the game screens (04 to 11) are rebuilt
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/game_phase.dart';
import '../../tokens/app_tokens.dart';
import '../../tokens/app_tokens_provider.dart';

/// Phase-aware full-screen background with optional candle glow and noise grain.
///
/// Stack layer order (bottom → top):
///   1. Solid phase background color
///   2. Candle glow gradient (optional)
///   3. Noise grain overlay at 3% opacity (optional)
///   4. Child content (inside RepaintBoundary)
class AtmosphericBackground extends ConsumerWidget {
  final GamePhase phase;
  final Widget child;
  final bool showNoiseOverlay;
  final bool showGlow;

  const AtmosphericBackground({
    super.key,
    required this.phase,
    required this.child,
    this.showNoiseOverlay = true,
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(activeThemeProvider);

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: _backgroundColorForPhase(tokens)),
        if (showGlow)
          DecoratedBox(
            decoration: BoxDecoration(gradient: tokens.decorations.candleGlow),
          ),
        if (showNoiseOverlay)
          Opacity(
            opacity: 0.03,
            child: Image.asset(
              tokens.decorations.noiseOverlayAsset,
              repeat: ImageRepeat.repeat,
              fit: BoxFit.none,
            ),
          ),
        RepaintBoundary(child: child),
      ],
    );
  }

  Color _backgroundColorForPhase(AppTokens tokens) {
    return switch (phase) {
      GamePhase.night => tokens.colors.nightBg,
      GamePhase.lobby => tokens.colors.lobbyBg,
      GamePhase.discussion => tokens.colors.discussionBg,
      GamePhase.voting => tokens.colors.votingBg,
      GamePhase.results => tokens.colors.resultsBg,
    };
  }
}
