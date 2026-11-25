import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/art_picture.dart';
import 'package:midnight_village/design_system/primitives/faint_art.dart';
import 'package:midnight_village/design_system/primitives/still.dart';
import 'package:midnight_village/design_system/skin/art_set.dart';
import 'package:midnight_village/design_system/skin/skin_id.dart';

import '../helpers/frame_cost.dart';
import '../helpers/pump_skinned.dart';
import 'not_yet_swept.dart';
import 'sweep_run.dart';

/// The frame-cost rule sees what it must, and only that; its lists name
/// only what is there.
void main() {
  final portrait = SkinId.fallback.skin.art.role(RoleId.seer);

  Future<List<String>> problemsOf(
    WidgetTester tester,
    Widget child, {
    Map<String, LayerAllowance> allowed = const {},
  }) async {
    await pumpSkinned(tester, Center(child: child));
    await tester.runAsync(() async {
      for (final e in find.byType(Image).evaluate()) {
        await precacheImage((e.widget as Image).image, e);
      }
    });
    await tester.pump();
    return frameCostProblemsWith(tester, allowed: allowed);
  }

  Widget mask(Widget child) => ShaderMask(
    blendMode: BlendMode.dstIn,
    shaderCallback: (r) => const LinearGradient(
      colors: [Colors.black, Colors.transparent],
    ).createShader(r),
    child: child,
  );

  const box = SizedBox(
    width: 60,
    height: 80,
    child: ColoredBox(color: Colors.teal),
  );

  testWidgets('a mask, an opacity and a filter at rest are each a problem', (
    tester,
  ) async {
    expect(await problemsOf(tester, mask(box)), [contains('a ShaderMask')]);
    expect(await problemsOf(tester, const Opacity(opacity: 0.5, child: box)), [
      contains('an opacity'),
    ]);
    expect(
      await problemsOf(
        tester,
        const ColorFiltered(
          colorFilter: ColorFilter.mode(Colors.red, BlendMode.multiply),
          child: box,
        ),
      ),
      [contains('a colour filter')],
    );
  });

  testWidgets('a layer is told by the app widget it is in, not Flutter\'s', (
    tester,
  ) async {
    final faint = SizedBox(width: 200, height: 200, child: FaintArt(portrait));
    expect(await problemsOf(tester, faint), [
      allOf(contains('from Opacity in FaintArt'), contains('name FaintArt')),
    ]);
    // Named, it passes, and its state used it; another state's line is
    // stale only for that state.
    const allowed = {'FaintArt': LayerAllowance('a-state', 'a faint picture')};
    resetLayerAllowances();
    expect(await problemsOf(tester, faint, allowed: allowed), isEmpty);
    expect(staleLayerAllowances('a-state', allowed: allowed), isEmpty);
    resetLayerAllowances();
    expect(await problemsOf(tester, box, allowed: allowed), isEmpty);
    expect(staleLayerAllowances('a-state', allowed: allowed), [
      contains('FaintArt is in layerAllowed for a-state'),
    ]);
    expect(staleLayerAllowances('other', allowed: allowed), isEmpty);
  });

  testWidgets('inside a Still they are one picture, no problem', (
    tester,
  ) async {
    expect(
      await problemsOf(
        tester,
        SizedBox(width: 60, height: 80, child: Still(child: mask(box))),
      ),
      isEmpty,
    );
  });

  testWidgets('a picture decoded for its box passes; larger, it fails', (
    tester,
  ) async {
    expect(
      await problemsOf(
        tester,
        SizedBox(width: 44, height: 58, child: ArtPicture(portrait)),
      ),
      isEmpty,
    );
    final full = await problemsOf(
      tester,
      SizedBox(
        width: 44,
        height: 58,
        child: Image(
          image: ArtDecode(portrait, width: portrait.pixels.width.round()),
          fit: BoxFit.cover,
        ),
      ),
    );
    expect(full, [contains('decoded 576 wide, its box asks for 144')]);
    final plain = await problemsOf(
      tester,
      SizedBox(
        width: 44,
        height: 58,
        child: Image(image: AssetImage(portrait.path), fit: BoxFit.cover),
      ),
    );
    expect(plain, [contains('without ArtImage.decodedFor')]);
  });

  test('every allowance names a widget of the app, why, and a swept state '
      'that shows it', () {
    final swept = {for (final e in sweptEntries()) e.id};
    for (final MapEntry(:key, :value) in layerAllowed.entries) {
      expect(appClasses, contains(key), reason: 'layerAllowed: $key');
      expect(value.why.length, greaterThan(20), reason: '$key says why');
      expect(swept, contains(value.seenOn), reason: '$key: ${value.seenOn}');
      expect(
        notYetSwept.containsKey(value.seenOn),
        isFalse,
        reason: '$key: ${value.seenOn} is not swept yet, so never checked',
      );
    }
    for (final MapEntry(:key, :value) in {
      ...undecodedAllowed,
      ...decodedAheadAllowed,
    }.entries) {
      expect(appClasses, contains(key), reason: key);
      expect(value.length, greaterThan(20), reason: '$key says why');
    }
  });
}
