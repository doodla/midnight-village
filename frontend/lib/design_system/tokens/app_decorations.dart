import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppDecorations {
  static final visionGlow = RadialGradient(
    colors: [AppColors.tallowGold.withValues(alpha: 0.1), Colors.transparent],
  );

  static final bloodVignette = RadialGradient(
    colors: [Colors.transparent, AppColors.emberRed.withValues(alpha: 0.15)],
  );

  static final candleGlow = RadialGradient(
    center: Alignment.center,
    colors: [Colors.transparent, AppColors.voidBlack],
  );

  static const noiseOverlayAsset = 'assets/textures/noise_grain.png';
}
