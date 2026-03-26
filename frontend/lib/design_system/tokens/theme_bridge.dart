import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_tokens.dart';
import 'app_tokens_provider.dart';

part 'theme_bridge.g.dart';

ThemeData generateThemeData(AppTokens tokens) {
  final colors = tokens.colors;
  final typography = tokens.typography;
  final radius = tokens.radius;
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: colors.primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      secondary: colors.secondary,
      onSecondary: colors.onSecondary,
      tertiary: colors.tertiary,
      surface: colors.surface,
      onSurface: colors.onSurface,
      error: colors.error,
      onError: colors.onError,
      outline: colors.outline,
      surfaceContainerHighest: colors.surface,
      surfaceContainerLow: colors.surfaceDark,
    ),
    scaffoldBackgroundColor: colors.background,
    textTheme: TextTheme(
      displayLarge: typography.displayHeading,
      headlineMedium: typography.heading,
      titleMedium: typography.subheading,
      bodyMedium: typography.body,
      bodySmall: typography.caption,
      labelLarge: typography.timerDigits,
      labelMedium: typography.lobbyCode,
      labelSmall: typography.phaseLabel,
    ),
    cardTheme: CardThemeData(
      color: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: radius.medium),
      elevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: radius.medium),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.onSurface,
        side: BorderSide(color: colors.outline),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: radius.medium),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surface,
      border: OutlineInputBorder(
        borderRadius: radius.medium,
        borderSide: BorderSide(color: colors.outline),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: colors.outline,
      thickness: 1,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
  );
}

@riverpod
ThemeData activeThemeData(Ref ref) {
  final tokens = ref.watch(activeThemeProvider);
  return generateThemeData(tokens);
}
