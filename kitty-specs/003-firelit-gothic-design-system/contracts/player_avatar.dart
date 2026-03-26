/// Contract: PlayerAvatar widget
///
/// Circular avatar rendering a player's initials with a deterministic
/// background hue derived from their display name. Three sizes available.
/// Present on 11 of 15 screens — the most reused player identity component.
///
/// Location: frontend/lib/design_system/components/foundation/player_avatar.dart

// ignore_for_file: unused_element

import 'package:flutter/material.dart';

/// PlayerAvatar renders a circular container with the player's initial(s)
/// and a deterministic background color.
///
/// Usage:
/// ```dart
/// PlayerAvatar(
///   displayName: 'Alice',
///   size: AvatarSize.medium,
/// )
///
/// // With sigil overlay
/// PlayerAvatar(
///   displayName: 'Bob',
///   size: AvatarSize.large,
///   sigil: Icons.check,
/// )
/// ```
///
/// Props:
///   displayName: String     — player's name (used for initials and hue)
///   size: AvatarSize        — small (32dp), medium (48dp), large (64dp)
///   sigil: IconData?        — optional badge icon overlay (bottom-right corner)
///   borderColor: Color?     — optional border color override (for selection states)
///   borderWidth: double     — border width (default: 0, meaning no border)
///
/// Initials extraction:
///   - Single word: first letter uppercased ("Alice" → "A")
///   - Two+ words: first letter of first two words ("Bob Smith" → "BS")
///   - Empty string: "?" fallback
///
/// Deterministic hue algorithm:
///   - Compute hashCode of displayName
///   - Map to HSL hue (0-360) with fixed saturation (~0.4) and lightness (~0.3)
///   - Same displayName always produces same color
///   - Colors are muted/dark to fit the Firelit Gothic palette
///
/// Size mapping (AvatarSize enum):
///   - small:  32dp circle, 14sp text
///   - medium: 48dp circle, 18sp text
///   - large:  64dp circle, 24sp text
///
/// Sigil overlay:
///   - Small circular badge positioned at bottom-right of avatar
///   - Background: tokens.colors.surface
///   - Icon: tokens.colors.onSurface, sized proportional to avatar
///
/// Implementation notes:
///   - ConsumerWidget that reads activeThemeProvider
///   - Uses ClipOval or CircleAvatar for the circular shape
///   - Text uses tokens.colors.onSurface (or computed contrast color)
///   - Sigil badge uses Positioned within a Stack
///   - No network calls — purely computed from the displayName string
///
/// Test contract:
///   - Renders correct initials for various name formats
///   - Same displayName produces identical background color (deterministic)
///   - Different displayNames produce different colors (with reasonable probability)
///   - Three sizes render at correct pixel dimensions (32, 48, 64)
///   - Sigil icon appears when provided
///   - Empty displayName shows "?" fallback
///   - Consumes tokens from activeThemeProvider
abstract class _PlayerAvatarContract {
  // Constructor: displayName, size, sigil, borderColor, borderWidth
}
