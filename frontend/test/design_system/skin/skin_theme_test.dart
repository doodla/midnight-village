import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/ground_scope.dart';
import 'package:midnight_village/design_system/skin/skin.dart';
import 'package:midnight_village/design_system/skin/skin_theme.dart';

import '../../helpers/pump_skinned.dart';

/// The style a button's label was actually drawn with.
TextStyle _drawnStyle(WidgetTester tester, String label) =>
    tester.renderObject<RenderParagraph>(find.text(label)).text.style!;

void main() {
  for (final MapEntry(key: name, value: skin) in skinsUnderTest.entries) {
    group(name, () {
      final theme = skinTheme(skin);
      final type = skin.typography;

      test('the skin rides along as a theme extension', () {
        expect(theme.extension<Skin>(), same(skin));
      });

      test('Material\'s button label is the action label, not the timer', () {
        // The old theme bridge mapped labelLarge to the 48px timer digits, so
        // every Material button label was giant.
        final label = theme.textTheme.labelLarge!;
        expect(label.fontSize, type.action.fontSize);
        expect(label.fontFamily, type.action.fontFamily);
        expect(label.fontSize, lessThan(type.timerSmall.fontSize!));
      });

      test('the text theme draws from the skin\'s faces', () {
        final t = theme.textTheme;
        expect(t.displayLarge!.fontFamily, type.display.fontFamily);
        expect(t.bodyMedium!.fontFamily, type.body.fontFamily);
        expect(t.bodyMedium!.fontSize, type.body.fontSize);
        expect(t.bodyMedium!.color, skin.night.text);
      });

      test('the colour scheme is the night ground\'s roles', () {
        final scheme = theme.colorScheme;
        expect(scheme.brightness, Brightness.dark);
        expect(scheme.primary, skin.night.accent);
        expect(scheme.onPrimary, skin.night.onAccent);
        expect(scheme.surface, skin.night.ground);
        expect(scheme.error, skin.night.danger);
        expect(theme.scaffoldBackgroundColor, skin.night.ground);
      });

      test('a day theme is light, with the day ground\'s roles', () {
        final day = skinTheme(skin, ground: GroundKind.day);
        expect(day.colorScheme.brightness, Brightness.light);
        expect(day.scaffoldBackgroundColor, skin.day.ground);
        expect(day.textTheme.bodyMedium!.color, skin.day.text);
      });

      testWidgets('button labels are drawn at the skin\'s sizes', (
        tester,
      ) async {
        await pumpSkinned(
          tester,
          skin: skin,
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton(onPressed: () {}, child: const Text('Continue')),
              ElevatedButton(onPressed: () {}, child: const Text('Deal')),
              OutlinedButton(onPressed: () {}, child: const Text('Leave')),
              TextButton(onPressed: () {}, child: const Text('Change')),
            ],
          ),
        );

        for (final primary in ['Continue', 'Deal']) {
          final style = _drawnStyle(tester, primary);
          expect(style.fontSize, type.buttonLabel.fontSize, reason: primary);
          expect(style.fontFamily, type.buttonLabel.fontFamily);
          expect(
            tester.getSize(find.byType(FilledButton)).height,
            greaterThanOrEqualTo(48),
          );
        }
        for (final secondary in ['Leave', 'Change']) {
          final style = _drawnStyle(tester, secondary);
          expect(style.fontSize, type.buttonLabel.fontSize, reason: secondary);
          expect(style.fontWeight, type.buttonLabel.fontWeight);
        }
      });

      testWidgets('buttons cast no soft Material shadow', (tester) async {
        await pumpSkinned(
          tester,
          skin: skin,
          FilledButton(onPressed: () {}, child: const Text('Continue')),
        );
        final material = tester.widget<Material>(
          find.descendant(
            of: find.byType(FilledButton),
            matching: find.byType(Material),
          ),
        );
        expect(material.elevation, 0);
      });

      testWidgets('a day scope gives Material widgets the day theme', (
        tester,
      ) async {
        late ThemeData inner;
        await pumpSkinned(
          tester,
          skin: skin,
          GroundScope(
            ground: GroundKind.day,
            child: Builder(
              builder: (context) {
                inner = Theme.of(context);
                return const Text('day');
              },
            ),
          ),
        );
        expect(inner.colorScheme.primary, skin.day.accent);
        expect(_drawnStyle(tester, 'day').color, skin.day.text);
      });
    });
  }
}
