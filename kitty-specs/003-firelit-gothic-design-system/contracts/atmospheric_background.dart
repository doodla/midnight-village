/// Contract: AtmosphericBackground widget
///
/// Phase-aware background wrapper that sets the visual mood for each game phase.
/// Present on ALL screens. Renders phase-specific background color from tokens
/// with optional candle glow and noise grain overlay effects.
///
/// Location: frontend/lib/design_system/components/foundation/atmospheric_background.dart

// ignore_for_file: unused_element

import 'package:flutter/material.dart';

/// The AtmosphericBackground widget renders a full-screen background
/// that adapts to the current game phase.
///
/// Usage:
/// ```dart
/// AtmosphericBackground(
///   phase: GamePhase.night,
///   child: MyScreenContent(),
/// )
/// ```
///
/// Phase → Background Color mapping (from tokens):
///   night      → tokens.colors.nightBg      (#0D0B0F) + candle glow + noise grain
///   lobby      → tokens.colors.lobbyBg      (#1A1714) + warm glow
///   discussion → tokens.colors.discussionBg (#151210) + subtle grain
///   voting     → tokens.colors.votingBg     (#12100E) + radial glow
///   results    → tokens.colors.resultsBg    (#0F0D0B)
///
/// Props:
///   phase: GamePhase       — determines background color and overlay effects
///   child: Widget          — content to render on top of the background
///   showNoiseOverlay: bool — whether to show the noise grain texture (default: true for night)
///   showGlow: bool         — whether to show the phase-specific glow effect (default: true)
///
/// Implementation notes:
///   - ConsumerWidget that reads activeThemeProvider
///   - Background color comes from tokens.colors phase background getters
///   - Candle glow uses tokens.decorations.candleGlow gradient
///   - Noise overlay uses tokens.decorations.noiseOverlayAsset at ~3% opacity
///   - Noise overlay is a pre-rendered PNG tiled via ImageRepeat.repeat
///   - Stack order: solid color → optional glow gradient → optional noise → child
///   - Must NOT rebuild child on phase changes (use RepaintBoundary if needed)
///
/// Test contract:
///   - Renders correct background color for each of 5 phases
///   - Noise overlay visible when showNoiseOverlay is true
///   - Glow effect visible when showGlow is true
///   - Child widget renders on top of background layers
///   - Consumes tokens from activeThemeProvider (test with TestThemeTokens)
abstract class _AtmosphericBackgroundContract {
  // Phase: required, determines background color and overlay effects
  // Child: required, content rendered on top of background
  // showNoiseOverlay: optional, default varies by phase (true for night/lobby)
  // showGlow: optional, default true
}
