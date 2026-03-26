/// Contract: VillageAppBar widget
///
/// A themed app bar with four variants covering all game screens.
/// Present on 13 of 15 screens.
///
/// Location: frontend/lib/design_system/components/foundation/village_app_bar.dart

// ignore_for_file: unused_element

import 'package:flutter/material.dart';

/// VillageAppBar provides four named constructors for different screen contexts.
///
/// Variants:
///
/// 1. VillageAppBar.brand()
///    - Leading: Castle icon (Symbols.castle or Icons.fort)
///    - Title: "Midnight Village" in heading typography
///    - Trailing: Optional action widget (settings, profile)
///    - Screens: Welcome, Home
///
/// 2. VillageAppBar.back({required String title})
///    - Leading: Back arrow (Icons.arrow_back) that calls Navigator.pop
///    - Title: Custom text in subheading typography
///    - Trailing: Optional action widgets
///    - Screens: Lobby, Role Selection, Vote Reveal
///
/// 3. VillageAppBar.phase({required String label, Widget? trailing})
///    - Leading: None
///    - Title: Phase label in gold, small-caps (phaseLabel typography)
///    - Trailing: Timer widget slot
///    - Screens: Discussion, Voting
///
/// 4. VillageAppBar.minimal({required String roleName, IconData? icon})
///    - Leading: None
///    - Title: Role name + optional role icon
///    - Trailing: Timer ring widget slot
///    - Background: Transparent
///    - Screens: All night screens
///
/// Common props across all variants:
///   trailing: Widget?    — optional trailing action widget
///   backgroundColor: Color? — override background (default: transparent)
///
/// Implementation notes:
///   - ConsumerWidget that reads activeThemeProvider
///   - Uses PreferredSizeWidget (implements PreferredSizeWidget)
///   - Returns a Flutter AppBar with customized styling
///   - All text colors from tokens.colors.onSurface / tokens.colors.secondary
///   - Phase label uses tokens.typography.phaseLabel with letter spacing
///   - Transparent background by default (integrates with AtmosphericBackground)
///   - Icon color from tokens.colors.onSurface
///
/// Test contract:
///   - Each variant renders without overflow
///   - Brand variant shows castle icon and "Midnight Village"
///   - Back variant shows back arrow and custom title
///   - Phase variant shows gold phase label
///   - Minimal variant shows role name
///   - Trailing widget renders when provided
///   - Back arrow triggers Navigator.pop
abstract class _VillageAppBarContract {
  // Factory constructors: brand, back, phase, minimal
  // Each returns a PreferredSizeWidget
}
