import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract final class AppTypography {
  static TextTheme get textTheme => TextTheme(
    // Epilogue headlines
    displayLarge: GoogleFonts.epilogue(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      color: AppColors.parchment,
      letterSpacing: 1.5,
    ),
    headlineLarge: GoogleFonts.epilogue(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: AppColors.parchment,
    ),
    headlineMedium: GoogleFonts.epilogue(
      fontSize: 20,
      fontWeight: FontWeight.w500,
      color: AppColors.parchment,
    ),
    headlineSmall: GoogleFonts.epilogue(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: AppColors.parchment,
    ),

    // DM Sans body
    bodyLarge: GoogleFonts.dmSans(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: AppColors.parchment,
    ),
    bodyMedium: GoogleFonts.dmSans(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: AppColors.parchment,
    ),
    bodySmall: GoogleFonts.dmSans(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: AppColors.parchmentMuted,
    ),

    // Space Grotesk labels
    labelLarge: GoogleFonts.spaceGrotesk(
      fontSize: 48,
      fontWeight: FontWeight.w600,
      color: AppColors.tallowGold,
    ), // Timer digits
    labelMedium: GoogleFonts.spaceGrotesk(
      fontSize: 28,
      fontWeight: FontWeight.w500,
      color: AppColors.tallowGold,
      letterSpacing: 8.0,
    ), // Lobby codes
    labelSmall: GoogleFonts.spaceGrotesk(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: AppColors.parchmentMuted,
      letterSpacing: 2.0,
    ), // Phase labels, badges
  );

  // Serif accent for atmospheric text ("The night begins...", taglines)
  static TextStyle get displaySerif => GoogleFonts.libreBaskerville(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    fontStyle: FontStyle.italic,
    color: AppColors.parchmentMuted,
  );
}
