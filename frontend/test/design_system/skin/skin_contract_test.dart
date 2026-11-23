import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/art_precache.dart';
import 'package:midnight_village/design_system/skin/art_set.dart';
import 'package:midnight_village/design_system/skin/card_back.dart';
import 'package:midnight_village/design_system/skin/end_art.dart';
import 'package:midnight_village/design_system/skin/werewolf_portrait.dart';
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

/// The type scale's caps, one per kind of text: the owner's choice of 23
/// November 2026 ("Tight sizes, but keep the serif names"; the audit is
/// `docs/design/type-audit.md`). A role may not grow past its kind's max, so
/// a mock's bigger number is converted at the cap, never copied ("the mock
/// says 26; the cap says 16"); nor shrink under its min.
enum _Kind {
  // One hero line per screen, in the display serif.
  hero(28, 36),
  // The role's name on your own card, read across the table.
  heroRole(46, 46),
  display(28, 28),
  // A screen's question.
  question(24, 24),
  heading(20, 20),
  // A player's name, wherever it is drawn.
  name(14, 16),
  button(15, 15),
  body(14, 15),
  // The word in the hold ring.
  cue(16, 16),
  // Captions, tags, badges: the floor.
  label(12, 12),
  // The talk's clock is 40 (the square, the owner's choice of 23 November
  // 2026); the vote's and the night's stay as they were.
  timer(40, 84);

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
  'heroRole': _Kind.heroRole,
  'display': _Kind.display,
  'screenTitle': _Kind.question,
  'headline': _Kind.question,
  'title': _Kind.heading,
  'tally': _Kind.heading,
  'heading': _Kind.heading,
  'name': _Kind.name,
  'nameSmall': _Kind.name,
  'buttonLabelLarge': _Kind.button,
  'buttonLabel': _Kind.button,
  'buttonLabelSmall': _Kind.button,
  'timer': _Kind.timer,
  'timerVote': _Kind.timer,
  'timerSmall': _Kind.timer,
  'bodyLarge': _Kind.body,
  'bodyStrong': _Kind.body,
  'lede': _Kind.body,
  'body': _Kind.body,
  'action': _Kind.body,
  'code': _Kind.body,
  'cue': _Kind.cue,
  'caption': _Kind.label,
  'tag': _Kind.label,
  'badge': _Kind.label,
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

      test('every type role is inside the scale\'s caps', () {
        final outside = [
          for (final MapEntry(key: role, value: style)
              in skin.typography.roles.entries)
            if (_kinds[role] case final kind?)
              if (style.fontSize! < kind.min || style.fontSize! > kind.max)
                '$role is ${style.fontSize}: the cap for a ${kind.name} is '
                    '${kind.max} (and at least ${kind.min})',
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
            for (final role in RoleId.values)
              for (final wolf in WerewolfPortrait.values)
                art.role(role, wolf: wolf),
            for (final scene in Scene.values) art.scene(scene),
            for (final back in CardBack.values) art.cardBack(back),
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

      testWidgets('every path a role portrait can be drawn from is a file in '
          'the bundle, with a game, with none, and for every portrait', (
        tester,
      ) async {
        // Enumerated from the lookups themselves, never a hand list: what
        // `context.roleArt` returns under every scope there can be, what the
        // art set returns for every portrait, what the precaches name, and
        // what every game's id chooses.
        final art = skin.art;
        final reached = <String, String>{};
        void note(ArtImage image, String how) => reached[image.path] = how;

        for (final role in RoleId.values) {
          for (final wolf in WerewolfPortrait.values) {
            note(art.role(role, wolf: wolf), 'art.role($role, $wolf)');
          }
          note(art.role(role), 'art.role($role) default');
        }
        for (final wolf in [null, ...WerewolfPortrait.values]) {
          late BuildContext inside;
          Widget probe = Builder(
            builder: (context) {
              inside = context;
              return const SizedBox();
            },
          );
          if (wolf != null) {
            probe = WerewolfPortraitScope(portrait: wolf, child: probe);
          }
          await pumpSkinned(tester, probe, skin: skin);
          for (final role in RoleId.values) {
            note(inside.roleArt(role), 'roleArt($role) under $wolf');
          }
        }
        final random = math.Random(1123);
        for (final id in [
          null,
          '',
          for (var i = 0; i < 200; i++) 'game-${random.nextInt(1 << 30)}',
        ]) {
          note(
            art.role(RoleId.werewolf, wolf: WerewolfPortrait.forGame(id)),
            'forGame($id)',
          );
        }
        for (final wolf in WerewolfPortrait.values) {
          for (final (image, _) in secretArt(skin, wolf: wolf)) {
            if (image.path.contains('/roles/')) note(image, 'secretArt');
          }
        }
        expect(
          reached.keys.where((p) => p.contains('/roles/werewolf_')),
          hasLength(WerewolfPortrait.values.length),
          reason: 'every portrait is reachable, and only those',
        );
        for (final MapEntry(key: path, value: how) in reached.entries) {
          expect(assets, contains(path), reason: '$how: $path');
          expect(
            (await rootBundle.load(path)).lengthInBytes,
            greaterThan(1000),
            reason: '$how: $path',
          );
        }
        // Nothing but the lookup builds a role path.
        for (final file in Directory('lib').listSync(recursive: true)) {
          if (file is! File ||
              !file.path.endsWith('.dart') ||
              file.path.endsWith('skin/art_set.dart')) {
            continue;
          }
          expect(
            file.readAsStringSync().contains(RegExp(r'roles/[^\x27"]*\.webp')),
            isFalse,
            reason: '${file.path} builds a role picture path itself',
          );
        }
      });

      test('every scene and card back is in the bundle, and no other file is '
          'in scenes/', () {
        final art = skin.art;
        final declared = {
          for (final scene in Scene.values) art.scene(scene).path,
          for (final back in CardBack.values) art.cardBack(back).path,
        };
        final bundled = assets
            .where((path) => path.startsWith('${art.folder}/scenes/'))
            .toSet();
        expect(bundled, declared, reason: 'a picture nothing draws is dead');
        expect(CardBack.values, hasLength(5));
      });

      test(
        'the candle\'s three cuts are in the bundle at the size the skin '
        'says, inside its view, and no other file is in its folder',
        () async {
          final art = skin.art;
          final cut = art.candleCut;
          final declared = <String>{};
          for (final c in [cut.wax, cut.flame, cut.holder]) {
            final picture = art.candleSprite(c);
            declared.add(picture.path);
            expect(assets, contains(picture.path));
            expect(await _pixels(picture.path), picture.pixels);
            // Each cut lies on the canvas the view is part of.
            expect(
              cut.view.overlaps(c.at & c.size),
              isTrue,
              reason: picture.path,
            );
          }
          final bundled = assets
              .where((path) => path.startsWith('${art.folder}/candle/'))
              .toSet();
          expect(bundled, declared);
          expect(cut.stickTop, lessThan(cut.stickBottom));
          expect(cut.view.contains(cut.wick), isTrue);
        },
      );

      test('every end board ornament is in the bundle at its declared size, '
          'and no other file is', () async {
        final art = skin.art;
        final declared = <String>{};
        for (final piece in EndPiece.values) {
          final picture = art.end.piece(piece);
          declared.add(picture.path);
          expect(assets, contains(picture.path));
          expect(await _pixels(picture.path), piece.pixels, reason: piece.file);
        }
        final bundled = assets
            .where((path) => path.startsWith('${art.folder}/end/'))
            .toSet();
        expect(bundled, declared, reason: 'an ornament nothing declares');
        // A slice lies inside its picture, its middle is not empty, and an end
        // is what the board draws (the frame about 19, the banner 128 tall).
        for (final slice in [
          SliceArt.banner,
          SliceArt.bannerRed,
          SliceArt.frame,
          SliceArt.roof,
        ]) {
          final inside = (Offset.zero & slice.pixels).inflate(0.5);
          expect(inside.contains(slice.slice.topLeft), isTrue);
          expect(inside.contains(slice.slice.bottomRight), isTrue);
          expect(slice.slice.width, greaterThan(0));
          expect(slice.slice.height, greaterThan(0));
        }
        expect(SliceArt.banner.natural.height, closeTo(128, 0.01));
        expect(SliceArt.roof.natural.height, closeTo(30, 0.01));
        expect(SliceArt.frame.ends.left, closeTo(18.8, 0.1));
        expect(SliceArt.bannerRed.slice, SliceArt.banner.slice);
        expect(SliceArt.bannerTall.top, greaterThan(0));
      });

      test('every layer of a layered scene is in the bundle at the size its '
          'scene says, and no other file is', () async {
        final art = skin.art;
        final declared = <String>{};
        for (final id in LayeredSceneId.values) {
          for (final layer in art.layeredScene(id).files) {
            final picture = art.layer(id, layer);
            declared.add(picture.path);
            expect(assets, contains(picture.path));
            expect(
              await _pixels(picture.path),
              picture.pixels,
              reason: picture.path,
            );
          }
        }
        final bundled = assets
            .where((path) => path.startsWith('${art.folder}/layers/'))
            .toSet();
        expect(
          bundled,
          declared,
          reason: 'a layer nothing draws is dead weight',
        );
      });
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
