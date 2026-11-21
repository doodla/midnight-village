import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/ground_scope.dart';
import 'package:midnight_village/design_system/skin/skin.dart';
import 'package:midnight_village/design_system/skin/skin_id.dart';
import 'package:midnight_village/design_system/skin/skin_theme.dart';

/// The skins every skin test runs against: the whole registry.
final skinsUnderTest = {for (final id in SkinId.values) id.label: id.skin};

/// Pumps [child] in [skin]'s theme (the default skin's when null) on [ground],
/// centred in a Material scaffold, as a screen would have it.
Future<void> pumpSkinned(
  WidgetTester tester,
  Widget child, {
  Skin? skin,
  GroundKind ground = GroundKind.night,
}) => tester.pumpWidget(
  MaterialApp(
    theme: skinTheme(skin ?? SkinId.fallback.skin),
    builder: (context, app) =>
        GroundScope(ground: GroundKind.night, child: app!),
    home: Scaffold(
      body: GroundScope(
        ground: ground,
        fill: true,
        child: Center(child: child),
      ),
    ),
  ),
);
