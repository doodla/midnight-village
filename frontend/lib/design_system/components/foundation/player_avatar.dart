// OLD LOOK: delete when 02 Table and the game screens (04 to 11) are rebuilt
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/avatar_size.dart';
import '../../tokens/app_tokens.dart';
import '../../tokens/app_tokens_provider.dart';

/// Circular initials avatar with deterministic hue mapping and optional sigil overlay.
///
/// Initials extraction:
/// - Single word → first letter uppercased.
/// - Two or more words → first letter of each of the first two words, uppercased.
/// - Empty or whitespace → "?".
///
/// Background hue is derived from `displayName.hashCode % 360`, producing a
/// stable color per player name. Saturation 0.4 and lightness 0.3 give muted
/// dark tones that match the gothic palette.
class PlayerAvatar extends ConsumerWidget {
  final String displayName;
  final AvatarSize size;

  /// Optional icon rendered as a small badge in the bottom-right corner.
  final IconData? sigil;

  /// Border color. Defaults to `tokens.colors.outline` when [borderWidth] > 0.
  final Color? borderColor;

  /// Border width in dp. Set to 0 (default) for no border.
  final double borderWidth;

  const PlayerAvatar({
    super.key,
    required this.displayName,
    required this.size,
    this.sigil,
    this.borderColor,
    this.borderWidth = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(activeThemeProvider);
    final hue = _deterministicHue(displayName);
    final bgColor = HSLColor.fromAHSL(1.0, hue, 0.4, 0.3).toColor();
    final initials = _extractInitials(displayName);
    final effectiveBorderColor = borderColor ?? tokens.colors.outline;

    return SizedBox(
      width: size.pixels,
      height: size.pixels,
      child: Stack(
        children: [
          Container(
            width: size.pixels,
            height: size.pixels,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: borderWidth > 0
                  ? Border.all(color: effectiveBorderColor, width: borderWidth)
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: TextStyle(
                color: tokens.colors.onSurface,
                fontSize: _fontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (sigil != null) _buildSigil(tokens),
        ],
      ),
    );
  }

  static double _deterministicHue(String name) =>
      (name.hashCode % 360).abs().toDouble();

  static String _extractInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final words = trimmed.split(RegExp(r'\s+'));
    if (words.length == 1) return words[0][0].toUpperCase();
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }

  double get _fontSize => switch (size) {
    AvatarSize.small => 14,
    AvatarSize.medium => 18,
    AvatarSize.large => 24,
  };

  Widget _buildSigil(AppTokens tokens) {
    final sigilSize = size.pixels * 0.3;
    return Positioned(
      right: 0,
      bottom: 0,
      child: Container(
        width: sigilSize,
        height: sigilSize,
        decoration: BoxDecoration(
          color: tokens.colors.surface,
          shape: BoxShape.circle,
        ),
        child: Icon(
          sigil,
          size: sigilSize * 0.7,
          color: tokens.colors.onSurface,
        ),
      ),
    );
  }
}
