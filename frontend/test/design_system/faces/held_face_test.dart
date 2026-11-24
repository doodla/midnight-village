import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/faces/face_content.dart';
import 'package:midnight_village/design_system/faces/held_face.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/skin/skin_id.dart';

import '../../helpers/pump_skinned.dart';
import '../../helpers/sheet/sheet_data.dart';
import '../../helpers/shell_setup.dart';
import '../../helpers/truncated_text.dart';

// A face is the role card (S04). On 04 it fills the face-down card's frame,
// on every phone and text size the frame is measured on the real screen:
// the portrait keeps at least [HeldFace.minPortraitShare] of the card's
// width (a face, whole), the words step down to the compact type before the
// card is set smaller, and nothing is cut. Drawn over a screen, a face is as
// tall as its words and portrait need: no empty lower half.

/// The face's own FittedBox (the name's line has another), and how much it
/// sets its content smaller: 1 when it fits.
double _scale(WidgetTester tester) {
  final face = find
      .descendant(of: find.byType(HeldFace), matching: find.byType(FittedBox))
      .first;
  final fitted = tester.renderObject<RenderBox>(face);
  final content = tester.renderObject<RenderBox>(
    find.descendant(of: face, matching: find.byType(SizedBox)).first,
  );
  return fitted.size.height / content.size.height;
}

/// The portrait's height over the card's inner width.
double _portraitShare(WidgetTester tester) {
  final portrait = find
      .descendant(of: find.byType(HeldFace), matching: find.byType(ClipRRect))
      .first;
  final content = find
      .descendant(of: find.byType(HeldFace), matching: find.byType(FittedBox))
      .first;
  return tester.getSize(portrait).height /
      tester
          .renderObject<RenderBox>(
            find.descendant(of: content, matching: find.byType(SizedBox)).first,
          )
          .size
          .width;
}

/// The smallest of the card's lines (its body type, not the name or the
/// tag), as drawn after any setting smaller.
double _linesDrawnAt(WidgetTester tester) {
  final type = SkinId.fallback.skin.typography;
  final body = {type.body.fontSize, type.bodyLarge.fontSize};
  final sizes = [
    for (final element
        in find
            .descendant(
              of: find.byType(HeldFace),
              matching: find.byType(RichText),
            )
            .evaluate())
      if ((element.widget as RichText).text.style?.fontSize case final size?
          when body.contains(size))
        (element.widget as RichText).textScaler.scale(size),
  ];
  return sizes.reduce((a, b) => a < b ? a : b) * _scale(tester);
}

/// 04's face-down card on a [size] phone at [textScale], as the real screen
/// lays it out.
Future<Size> _frameOf(
  WidgetTester tester,
  Size size, {
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  final shell = await ShellSetup.pump(
    tester,
    recordedMe('me_look_stage'),
    textScale: textScale,
  );
  await shell.settle(tester);
  final frame = tester.getSize(find.byType(FaceDownCard));
  await shell.close(tester);
  return frame;
}

void main() {
  // Every phone and text size checked: the face whole, nothing cut. Where
  // [floor] is true the lines are at the reading floor too; on the small
  // phones at larger text the longest roles are set smaller (the type has
  // already stepped down; the role text is what it is) and the least is
  // checked to stay legible.
  const cases = [
    (phone: Size(390, 844), text: 1.0, floor: true),
    (phone: Size(390, 844), text: 1.3, floor: true),
    (phone: Size(360, 640), text: 1.0, floor: true),
    (phone: Size(360, 640), text: 1.3, floor: false),
    (phone: Size(320, 568), text: 1.0, floor: false),
    (phone: Size(320, 568), text: 1.3, floor: false),
  ];
  for (final (:phone, :text, :floor) in cases) {
    final name = '${phone.width.toInt()} x ${phone.height.toInt()}';
    testWidgets('04 on a $name phone at text x$text: every role card keeps '
        'a whole face${floor ? ', its lines at the reading floor' : ''}, '
        'nothing cut', (tester) async {
      addTearDown(tester.view.reset);
      final frame = await _frameOf(tester, phone, textScale: text);
      for (final role in RoleId.values) {
        await pumpSkinned(
          tester,
          MediaQuery(
            data: MediaQueryData.fromView(
              tester.view,
            ).copyWith(textScaler: TextScaler.linear(text)),
            child: SizedBox.fromSize(
              size: frame,
              child: HeldFace(
                content: FaceContent.roleText(role),
                page: 0,
                fill: true,
              ),
            ),
          ),
        );
        // A cramped card steps its words down on the next frame.
        await tester.pump();
        expect(tester.getSize(find.byType(HeldFace)), frame);
        expect(
          _portraitShare(tester),
          greaterThanOrEqualTo(HeldFace.minPortraitShare - 0.01),
          reason: '${role.name}: never a strip',
        );
        expect(truncatedText(tester), isEmpty, reason: role.name);
        expect(
          _linesDrawnAt(tester),
          greaterThanOrEqualTo(floor ? ReadingFloor.act : 10),
          reason: role.name,
        );
      }
    });
  }

  testWidgets('drawn over a screen it is as tall as its words and a portrait '
      'of its own shape, no taller; with less room the portrait gives way', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final face = Viewer.seer.you;
    Future<Size> pumpIn(double room) async {
      await pumpSkinned(
        tester,
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 342, maxHeight: room),
          child: HeldFace(content: face, page: 0),
        ),
      );
      await tester.pump();
      return tester.getSize(find.byType(HeldFace));
    }

    final roomy = await pumpIn(800);
    expect(roomy.height, lessThan(800), reason: 'no empty lower half');
    final tight = await pumpIn(roomy.height - 100);
    expect(tight.height, roomy.height - 100);
    expect(_scale(tester), 1, reason: 'the portrait gave way, not the words');
  });

  testWidgets('a role\'s art is never cropped: its window takes the art\'s '
      'own shape, whatever room the card has', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final art = SkinId.fallback.skin.art.rolePixels.aspectRatio;
    for (final role in RoleId.values) {
      for (final room in const [
        Size(312, 380),
        Size(312, 560),
        Size(342, 700),
      ]) {
        await pumpSkinned(
          tester,
          Center(
            child: SizedBox.fromSize(
              size: room,
              child: HeldFace(
                content: FaceContent.roleText(role),
                page: 0,
                fill: true,
              ),
            ),
          ),
        );
        await tester.pump();
        final window = tester.getSize(
          find
              .descendant(
                of: find.byType(HeldFace),
                matching: find.byType(ClipRRect),
              )
              .first,
        );
        expect(
          window.width / window.height,
          moreOrLessEquals(art, epsilon: 0.01),
          reason: '${role.name} in $room',
        );
      }
    }
  });
}
