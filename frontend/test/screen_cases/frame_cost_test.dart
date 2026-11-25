import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/art_picture.dart';
import 'package:midnight_village/design_system/primitives/still.dart';
import 'package:midnight_village/design_system/skin/art_set.dart';
import 'package:midnight_village/design_system/skin/skin_id.dart';

import '../helpers/frame_cost.dart';
import '../helpers/pump_skinned.dart';

/// The frame-cost rule sees what it must, and only that.
void main() {
  final portrait = SkinId.fallback.skin.art.role(RoleId.seer);
  const screen = Size(800, 600);

  Future<List<String>> problemsOf(WidgetTester tester, Widget child) async {
    await pumpSkinned(tester, Center(child: child));
    await tester.runAsync(() async {
      for (final e in find.byType(Image).evaluate()) {
        await precacheImage((e.widget as Image).image, e);
      }
    });
    await tester.pump();
    return frameCostProblems(tester, screen);
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

  testWidgets('a picture decoded for its box passes; at full size it fails', (
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
    expect(full, [contains('decoded 576 wide')]);
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
}
