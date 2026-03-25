import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_tokens.dart';
import 'app_tokens_provider.dart';

part 'theme_bridge.g.dart';

ThemeData generateThemeData(AppTokens tokens) {
  final colors = tokens.colors;
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
      surface: colors.surface,
      onSurface: colors.onSurface,
      error: colors.error,
      onError: colors.onError,
      outline: colors.outline,
    ),
    scaffoldBackgroundColor: colors.background,
    textTheme: TextTheme(
      displayLarge: tokens.typography.displayHeading,
      headlineMedium: tokens.typography.heading,
      titleMedium: tokens.typography.subheading,
      bodyMedium: tokens.typography.body,
      bodySmall: tokens.typography.caption,
      labelLarge: tokens.typography.label,
    ),
  );
}

@riverpod
ThemeData activeThemeData(Ref ref) {
  final tokens = ref.watch(activeThemeProvider);
  return generateThemeData(tokens);
}
