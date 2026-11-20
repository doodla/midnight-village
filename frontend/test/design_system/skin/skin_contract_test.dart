import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/skin/art_set.dart';
import 'package:midnight_village/design_system/skin/elevation.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/skin_id.dart';

import '../../helpers/painted_text.dart';
import '../../helpers/pump_skinned.dart';

// What every skin in the registry must give a screen, checked for each: its
// type inside the brief's scale (the rule, not ranges widened to fit a skin),
// its faces and pictures really there, hard-edged shadows, slight shapes.

List<Elevation> _elevations(Ground g) => [
  g.elevation.card,
  g.elevation.lying,
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
  g.idle,
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
  g.danger,
  g.onDanger,
  g.dangerText,
  g.dangerLine,
  g.disabled,
  g.onDisabled,
];

/// The brief's type scale (design brief section 4, "Type scale", as the
/// first-time play spec amends it: the reading floor), as a size range for
/// each kind of text.
enum _Kind {
  heading(26, 36),
  timer(64, 84),
  compactTimer(34, 34),
  count(28, 28),
  body(16, 17),
  // Names, buttons, the cue's word: read to act, 16 at least.
  inBetween(16, 24),
  // Captions under cards and tokens.
  caption(14, 15),
  // One hero line per screen, sized as its mock.
  hero(37, 46);

  const _Kind(this.min, this.max);

  final double min;
  final double max;
}

/// Every type role's kind. A new role must be added here, so it is held to
/// the scale like the rest.
const _kinds = {
  'heroTitle': _Kind.hero,
  'heroCode': _Kind.hero,
  'heroVerdict': _Kind.hero,
  'heroWinner': _Kind.hero,
  'display': _Kind.heading,
  'screenTitle': _Kind.heading,
  'headline': _Kind.heading,
  'title': _Kind.heading,
  'tally': _Kind.count,
  'heading': _Kind.inBetween,
  'name': _Kind.inBetween,
  'nameSmall': _Kind.inBetween,
  'buttonLabelLarge': _Kind.inBetween,
  'buttonLabel': _Kind.inBetween,
  'buttonLabelSmall': _Kind.inBetween,
  'timer': _Kind.timer,
  'timerVote': _Kind.timer,
  'timerSmall': _Kind.timer,
  'timerCompact': _Kind.compactTimer,
  'bodyLarge': _Kind.body,
  'lede': _Kind.body,
  'body': _Kind.body,
  'action': _Kind.body,
  'code': _Kind.body,
  'cue': _Kind.inBetween,
  'caption': _Kind.caption,
  'tag': _Kind.caption,
  'badge': _Kind.caption,
};

Future<Size> _pixels(String path) async {
  final bytes = await rootBundle.load(path);
  final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
  final frame = await codec.getNextFrame();
  final size = Size(
    frame.image.width.toDouble(),
    frame.image.height.toDouble(),
  );
  frame.image.dispose();
  codec.dispose();
  return size;
}

void main() {
  late Set<String> bundledFamilies;
  late Set<String> assets;

  setUpAll(() async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json'))
            as List<dynamic>;
    bundledFamilies = {
      for (final entry in manifest.cast<Map<String, dynamic>>())
        entry['family'] as String,
    };
    assets = (await AssetManifest.loadFromAssetBundle(
      rootBundle,
    )).listAssets().toSet();
  });

  test('every type role has a kind in the scale', () {
    final roles = SkinId.fallback.skin.typography.roles.keys.toSet();
    expect(roles, _kinds.keys.toSet());
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

      test('one warm accent, the same on every ground, and no other role is '
          'it; where it is too close to the ground it has an edge', () {
        final accent = skin.night.accent;
        for (final kind in GroundKind.values) {
          final g = skin.ground(kind);
          expect(g.accent, accent, reason: '$kind');
          // Every role but the accent itself.
          final others = _colours(g)..remove(g.accent);
          expect(
            others.where((c) => c == accent),
            isEmpty,
            reason: 'only the primary button is amber on $kind',
          );
          if (contrast(g.accent, g.ground) < 3) {
            expect(g.accentEdge, isNotNull, reason: '$kind');
            expect(contrast(g.accentEdge!, g.ground), greaterThan(3));
          }
        }
      });

      test('a selection is outlined in the ground\'s ink, never a fill '
          'colour of the accent or danger', () {
        for (final kind in GroundKind.values) {
          final g = skin.ground(kind);
          expect(g.selection, isNot(g.accent), reason: '$kind');
          expect(g.selection, isNot(g.danger), reason: '$kind');
          expect(contrast(g.selection, g.ground), greaterThan(4.5));
        }
      });

      test('night is dark and day is light, readable across a table', () {
        expect(skin.night.ground.computeLuminance(), lessThan(0.1));
        expect(skin.day.ground.computeLuminance(), greaterThan(0.5));
      });

      test('every type role is complete and colourless', () {
        for (final MapEntry(key: role, value: style)
            in skin.typography.roles.entries) {
          expect(style.fontFamily, isNotNull, reason: role);
          expect(style.fontSize, isNotNull, reason: role);
          expect(style.fontWeight, isNotNull, reason: role);
          expect(style.height, isNotNull, reason: role);
          expect(style.letterSpacing, isNotNull, reason: role);
          expect(style.color, isNull, reason: '$role takes its ground colour');
        }
      });

      test('every type role is inside the brief\'s scale', () {
        final outside = [
          for (final MapEntry(key: role, value: style)
              in skin.typography.roles.entries)
            if (_kinds[role] case final kind?)
              if (style.fontSize! < kind.min || style.fontSize! > kind.max)
                '$role is ${style.fontSize}, a ${kind.name} is '
                    '${kind.min} to ${kind.max}',
        ];
        expect(outside, isEmpty);
      });

      test('every face it names is bundled', () {
        for (final MapEntry(key: role, value: style)
            in skin.typography.roles.entries) {
          expect(
            bundledFamilies,
            contains(style.fontFamily),
            reason: '$role is in ${style.fontFamily}',
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
          shape.archRoundness,
          shape.pressKeep,
        ]) {
          expect(v, inInclusiveRange(0, 1));
        }
        final tilt = skin.tilt;
        for (final angle in [
          tilt.card,
          tilt.stamp,
          tilt.badge,
          tilt.thumb,
          tilt.hero,
          ...tilt.scatter,
        ]) {
          expect(angle.abs(), lessThanOrEqualTo(10 * math.pi / 180));
        }
        expect(tilt.scatter, isNotEmpty);
        for (final opacity in [skin.dimmed]) {
          expect(opacity, inExclusiveRange(0, 1));
        }
      });

      test(
        'every picture is in the bundle at the size its art set says',
        () async {
          final art = skin.art;
          final pictures = [
            for (final role in RoleId.values) art.role(role),
            for (final scene in Scene.values) art.scene(scene),
            for (final token in TokenId.values) art.token(token),
          ];
          for (final picture in pictures) {
            expect(
              await _pixels(picture.path),
              picture.pixels,
              reason: picture.path,
            );
          }
        },
      );
    });
  }

  group('tokens', () {
    test('every seat has a drawn token', () {
      final art = SkinId.fallback.skin.art;
      for (final token in TokenId.values) {
        expect(assets, contains(art.token(token).path));
      }
    });

    test('a token is found by the name the server gives it', () {
      expect(TokenId.fromServer('crow'), TokenId.crow);
      expect(TokenId.fromServer('scythe'), TokenId.scythe);
      // A newer server's token: the app draws a plain disc (PlayerToken).
      expect(TokenId.fromServer('owl'), isNull);
      expect(TokenId.fromServer(null), isNull);
    });
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
}
