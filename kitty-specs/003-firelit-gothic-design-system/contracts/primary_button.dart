/// Contract: PrimaryButton widget
///
/// Full-width ember red filled button. The primary interactive element
/// across all 15 screens. Replaces the existing MvButton.
///
/// Location: frontend/lib/design_system/components/core/primary_button.dart

// ignore_for_file: unused_element

import 'package:flutter/material.dart';

/// PrimaryButton renders a full-width filled button with ember red background
/// and parchment text. Supports disabled, loading, outlined, and destructive states.
///
/// Usage:
/// ```dart
/// // Default filled button
/// PrimaryButton(
///   label: 'Enter the Village',
///   onPressed: () => doSomething(),
/// )
///
/// // Outlined secondary variant
/// PrimaryButton.outlined(
///   label: 'Leave',
///   onPressed: () => leave(),
/// )
///
/// // Loading state
/// PrimaryButton(
///   label: 'Joining...',
///   onPressed: () {},
///   isLoading: true,
/// )
///
/// // Disabled (null onPressed)
/// PrimaryButton(
///   label: 'Start',
///   onPressed: null,
/// )
///
/// // Destructive variant
/// PrimaryButton(
///   label: 'Delete',
///   onPressed: () => delete(),
///   isDestructive: true,
/// )
/// ```
///
/// Props:
///   label: String          — button text
///   onPressed: VoidCallback? — tap handler (null = disabled)
///   isLoading: bool        — shows spinner replacing text (default: false)
///   isDestructive: bool    — uses error color instead of primary (default: false)
///   icon: IconData?        — optional leading icon
///
/// Named constructor:
///   PrimaryButton.outlined() — transparent background with outline border
///
/// Visual spec:
///   - Default: Full-width, ember red (#B8432F) background, parchment text, 8px radius
///   - Disabled: Desaturated background (tokens.colors.disabled), non-interactive
///   - Loading: CircularProgressIndicator replaces label text
///   - Outlined: Transparent background, outline border (tokens.colors.outline), parchment text
///   - Destructive: Error color background, parchment text
///   - Min height: 56dp (filled), 48dp (outlined)
///   - Typography: label style from tokens
///
/// Implementation notes:
///   - ConsumerWidget that reads activeThemeProvider
///   - Filled variant uses FilledButton / ElevatedButton
///   - Outlined variant uses OutlinedButton
///   - Loading state sets onPressed to null (prevents double-tap)
///   - Border radius from tokens.radius.medium
///
/// Test contract:
///   - Default renders with primary color background and label text
///   - Disabled (null onPressed) renders with disabled color, is non-interactive
///   - Loading shows CircularProgressIndicator, hides label, disables interaction
///   - Outlined renders with transparent background and border
///   - Destructive renders with error color background
///   - Consumes tokens from activeThemeProvider
///   - Full-width (fills available horizontal space)
abstract class _PrimaryButtonContract {
  // Default constructor: label, onPressed, isLoading, isDestructive, icon
  // Named constructor: outlined(label, onPressed, isLoading, icon)
}
