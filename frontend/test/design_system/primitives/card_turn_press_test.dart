import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/faces/face_content.dart';
import 'package:midnight_village/design_system/faces/held_face.dart';
import 'package:midnight_village/design_system/feel/press_paint.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/hold_to_reveal.dart';
import 'package:midnight_village/design_system/primitives/paper_flip.dart';
import 'package:midnight_village/design_system/skin/dress.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/ground_scope.dart';
import 'package:midnight_village/design_system/skin/skin_id.dart';
import 'package:midnight_village/design_system/skin/skin_theme.dart';

// 04, your card under a finger, turning over (feel.md, "Your card"): the
// press shrinks the back and sinks it toward its shadow, and the face is
// drawn unpressed, so the press gives itself back as the turn begins and is
// gone by the edge. At the edge, where one side gives way to the other, the
// card on show never jumps in size or place, held through the turn or let go
// and turning back.

const _step = Duration(milliseconds: 1);

Future<void> _pump(WidgetTester tester, {required bool paper}) {
  tester.view.physicalSize = const Size(400, 500);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(
    MaterialApp(
      theme: skinTheme(SkinId.fallback.skin),
      builder: (context, app) =>
          GroundScope(ground: GroundKind.night, child: app!),
      home: Scaffold(
        body: DressScope(
          dress: paper ? Dress.paper : Dress.plain,
          child: GroundScope(
            ground: GroundKind.night,
            fill: true,
            child: Center(
              child: HoldToReveal(
                inPlace: true,
                target: 'Your card',
                face: FaceContent.roleText(RoleId.seer),
                cover: const FaceDownCard(
                  size: FaceDownSize.hero,
                  cardWidth: 200,
                  cardHeight: 266,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The side on show and the render box its picture is drawn by: the face
/// once it is on stage, else the hero's paper (under every press piece).
(bool, RenderBox) _side(WidgetTester tester) {
  final face = find.byType(HeldFace);
  if (face.evaluate().isNotEmpty) return (true, tester.renderObject(face));
  final paper = find.descendant(
    of: find.byType(FaceDownCard),
    matching: find.byType(PressDecoration),
  );
  return (false, tester.renderObject(paper.first));
}

/// Down the middle of [box] (where a turn about the upright axis moves
/// nothing sideways): its top and bottom on the screen.
(double, double) _ends(RenderBox box) {
  final x = box.size.width / 2;
  return (
    box.localToGlobal(Offset(x, 0)).dy,
    box.localToGlobal(Offset(x, box.size.height)).dy,
  );
}

/// One frame: which side, and how tall and how low it is drawn, each as
/// against where that side rests flat.
typedef _Frame = ({bool face, double height, double centre});

_Frame _frame(WidgetTester tester, Map<bool, (double, double)> rest) {
  final (face, box) = _side(tester);
  final (top, bottom) = _ends(box);
  final (restTop, restBottom) = rest[face]!;
  return (
    face: face,
    height: (bottom - top) / (restBottom - restTop),
    centre: (top + bottom) / 2 - (restTop + restBottom) / 2,
  );
}

/// Where the side changes in [frames], the step across it in height (a
/// share) and in place (px).
(double, double) _jump(List<_Frame> frames) {
  for (var i = 1; i < frames.length; i++) {
    final (a, b) = (frames[i - 1], frames[i]);
    if (a.face != b.face) {
      return ((b.height - a.height).abs(), (b.centre - a.centre).abs());
    }
  }
  fail('the card never went through its edge');
}

void main() {
  for (final paper in [false, true]) {
    final dress = paper ? 'dressed' : 'plain';

    testWidgets('$dress: held through the turn, no jump at the edge', (
      tester,
    ) async {
      await _pump(tester, paper: paper);
      final rest = <bool, (double, double)>{
        false: _ends(_side(tester).$2),
        // The face lies flat in the turn's own box.
        true: _ends(tester.renderObject(find.byType(PaperFlip))),
      };
      final centre = tester.getCenter(find.byType(FaceDownCard));
      final finger = await tester.startGesture(centre);
      final frames = <_Frame>[];
      final until = HoldToReveal.holdDelay + PaperFlip.turn * 2;
      for (var t = Duration.zero; t < until; t += _step) {
        await tester.pump(_step);
        frames.add(_frame(tester, rest));
      }
      final (height, place) = _jump(frames);
      expect(height, lessThan(0.002), reason: 'height jumps at the edge');
      expect(place, lessThan(0.25), reason: 'the card jumps at the edge');
      await finger.up();
      await tester.pumpAndSettle();
    });

    testWidgets('$dress: let go face up, no jump at the edge on the way '
        'back', (tester) async {
      await _pump(tester, paper: paper);
      final rest = <bool, (double, double)>{
        false: _ends(_side(tester).$2),
        true: _ends(tester.renderObject(find.byType(PaperFlip))),
      };
      final centre = tester.getCenter(find.byType(FaceDownCard));
      final finger = await tester.startGesture(centre);
      await tester.pump(HoldToReveal.holdDelay);
      await tester.pump(PaperFlip.turn * 2);
      expect(_side(tester).$1, isTrue, reason: 'face up while held');
      await finger.up();
      final frames = <_Frame>[_frame(tester, rest)];
      for (var t = Duration.zero; t < PaperFlip.turn * 2; t += _step) {
        await tester.pump(_step);
        frames.add(_frame(tester, rest));
      }
      final (height, place) = _jump(frames);
      expect(height, lessThan(0.002), reason: 'height jumps at the edge');
      expect(place, lessThan(0.25), reason: 'the card jumps at the edge');
      await tester.pumpAndSettle();
    });
  }
}
