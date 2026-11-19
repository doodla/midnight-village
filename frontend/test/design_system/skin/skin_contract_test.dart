import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/skin/art_set.dart';
import 'package:midnight_village/design_system/skin/elevation.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/skin.dart';

import '../../helpers/pump_skinned.dart';

// What every skin must give a screen, checked for each skin: complete,
// inside the brief's type scale, hard-edged, slight, and with every picture it
// names in the bundle.

List<Elevation> _elevations(Ground g) => [
  g.elevation.card,
  g.elevation.raised,
  g.elevation.slab,
  g.elevation.heroSlab,
  g.elevation.primary,
  g.elevation.selected,
  g.elevation.badge,
];

List<Color> _colours(Ground g) => [
  g.ground,
  g.panel,
  g.text,
  g.quietText,
  g.faintText,
  g.hairline,
  g.outline,
  g.edge,
  g.shadow,
  g.paper,
  g.paperEdge,
  g.accent,
  g.onAccent,
  g.selection,
  g.mark,
  g.onMark,
  g.pick,
  g.onPick,
  g.danger,
  g.onDanger,
  g.dangerText,
  g.dangerLine,
  g.disabled,
  g.onDisabled,
];

/// The brief's type scale (section 4, "Type scale"), by role.
Map<String, (TextStyle, double, double)> _scale(Skin skin) {
  final t = skin.typography;
  return {
    'display': (t.display, 26, 36),
    'headline': (t.headline, 26, 36),
    'title': (t.title, 26, 36),
    'timer': (t.timer, 64, 84),
    'timerSmall': (t.timerSmall, 64, 84),
    'bodyLarge': (t.bodyLarge, 15, 18),
    'body': (t.body, 15, 18),
    'label': (t.label, 12, 13),
    // The in-between sizes the mocks use for names, buttons and small print.
    'heading': (t.heading, 11, 26),
    'name': (t.name, 11, 26),
    'nameSmall': (t.nameSmall, 11, 26),
    'buttonLabel': (t.buttonLabel, 11, 26),
    'action': (t.action, 11, 26),
    'small': (t.small, 11, 26),
    'caption': (t.caption, 11, 26),
    'tag': (t.tag, 11, 26),
    'badge': (t.badge, 11, 26),
    'micro': (t.micro, 11, 26),
  };
}

void main() {
  late Set<String> bundledFamilies;

  setUpAll(() async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json'))
            as List<dynamic>;
    bundledFamilies = {
      for (final entry in manifest.cast<Map<String, dynamic>>())
        entry['family'] as String,
    };
  });

  for (final MapEntry(key: name, value: skin) in skinsUnderTest.entries) {
    group(name, () {
      test('every ground colour is opaque', () {
        for (final kind in GroundKind.values) {
          for (final colour in _colours(skin.ground(kind))) {
            expect(colour.a, 1, reason: '$kind $colour');
          }
        }
      });

      test('night is dark and day is light, readable across a table', () {
        expect(skin.night.ground.computeLuminance(), lessThan(0.1));
        expect(skin.day.ground.computeLuminance(), greaterThan(0.5));
      });

      test('every type role is complete, colourless and in a bundled face', () {
        for (final MapEntry(key: role, value: (style, _, _)) in _scale(
          skin,
        ).entries) {
          expect(style.fontFamily, isIn(bundledFamilies), reason: role);
          expect(style.fontSize, isNotNull, reason: role);
          expect(style.fontWeight, isNotNull, reason: role);
          expect(style.height, isNotNull, reason: role);
          expect(style.letterSpacing, isNotNull, reason: role);
          expect(style.color, isNull, reason: '$role takes its ground colour');
        }
      });

      test('every type role is inside the brief\'s scale', () {
        for (final MapEntry(key: role, value: (style, min, max)) in _scale(
          skin,
        ).entries) {
          expect(
            style.fontSize,
            inInclusiveRange(min, max),
            reason: '$role is ${style.fontSize}',
          );
        }
      });

      test('every shadow is a hard offset copy: no blur, no spread', () {
        for (final kind in GroundKind.values) {
          for (final elevation in _elevations(skin.ground(kind))) {
            for (final shadow in elevation.boxShadows) {
              expect(shadow.blurRadius, 0);
              expect(shadow.spreadRadius, 0);
            }
          }
          expect(
            skin.ground(kind).elevation.primary.layers,
            isNotEmpty,
            reason: 'the primary button stands off the $kind ground',
          );
        }
      });

      test('shapes and tilts stay slight', () {
        final shape = skin.shape;
        for (final r in [
          shape.radius,
          shape.radiusSmall,
          shape.radiusTiny,
          shape.sheetRadius,
        ]) {
          expect(r, inInclusiveRange(0, 16));
        }
        for (final v in [
          shape.rowLeadRoundness,
          shape.tokenRoundness,
          shape.badgeRoundness,
          shape.pipRoundness,
          shape.pressKeep,
        ]) {
          expect(v, inInclusiveRange(0, 1));
        }
        for (final angle in [
          skin.tilt.card,
          skin.tilt.stamp,
          skin.tilt.badge,
        ]) {
          expect(angle.abs(), lessThanOrEqualTo(10 * math.pi / 180));
        }
        expect(skin.dimmed, inExclusiveRange(0, 1));
      });

      test('every picture the art set names is in the bundle', () async {
        final art = skin.art;
        final paths = [
          for (final role in RoleId.values) art.role(role).path,
          for (final scene in Scene.values) art.scene(scene).path,
          for (final token in TokenId.values)
            if (art.token(token) case TokenPicture(:final image)) image.path,
        ];
        for (final path in paths) {
          final bytes = await rootBundle.load(path);
          expect(bytes.lengthInBytes, greaterThan(0), reason: path);
        }
      });
    });
  }

  group('art set', () {
    final art = skinsUnderTest.values.first.art;

    test('the five drawn tokens have pictures; the rest fall back', () {
      final drawn = {
        TokenId.crow,
        TokenId.key,
        TokenId.moth,
        TokenId.bell,
        TokenId.thorn,
      };
      for (final token in TokenId.values) {
        expect(
          art.token(token),
          drawn.contains(token) ? isA<TokenPicture>() : isA<TokenFallback>(),
          reason: token.name,
        );
      }
    });

    test('fallback tokens are told apart by their letters', () {
      final letters = [
        for (final token in TokenId.values)
          if (art.token(token) case TokenFallback(:final initials)) initials,
      ];
      expect(letters.toSet(), hasLength(letters.length));
    });

    test('a role is found by the name the server gives it', () {
      const server = [
        'Werewolf',
        'Minion',
        'Villager',
        'Seer',
        'Robber',
        'Troublemaker',
        'Drunk',
        'Insomniac',
        'Mason',
        'Hunter',
        'Tanner',
        'Doppelganger',
      ];
      expect(server.map(RoleId.fromServer).toSet(), RoleId.values.toSet());
      expect(RoleId.fromServer('werewolf'), isNull);
    });
  });

  test('the two skins differ in more than name: colour, type and shape', () {
    final [a, b] = skinsUnderTest.values.toList();
    expect(a.night.ground, isNot(b.night.ground));
    expect(
      a.typography.display.fontFamily,
      isNot(b.typography.display.fontFamily),
    );
    expect(a.shape.radius, isNot(b.shape.radius));
  });
}
