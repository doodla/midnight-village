import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/faces/face_content.dart';
import 'package:midnight_village/design_system/feel/press.dart';
import 'package:midnight_village/design_system/feel/press_paint.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/hold_to_reveal.dart';
import 'package:midnight_village/design_system/primitives/icon_action.dart';
import 'package:midnight_village/design_system/primitives/paper_scrap.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/secondary_button.dart';
import 'package:midnight_village/design_system/primitives/text_action.dart';
import 'package:midnight_village/design_system/skin/dress.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/ground_scope.dart';
import 'package:midnight_village/design_system/skin/skin_id.dart';
import 'package:midnight_village/design_system/skin/skin_theme.dart';

import '../../helpers/finger.dart';
import '../../helpers/frame_pixels.dart';

// Every pressable primitive presses through `Pressable` (feel.md principle 1):
// the frame after the finger lands is drawn pressed, a tap too quick for a
// frame still shows one, the lift returns it to the very pixels it rested
// on, reduce motion shows the pressed state with nothing travelling, and a
// press rebuilds nothing. Judged by the pixels drawn, never by a flag.

/// One part, how it is pressed, and what its tap counts.
class _Part {
  _Part(
    this.name,
    this.build, {
    this.paper = false,
    this.commits = true,
    this.restLayers = const [],
  });

  final String name;
  final Widget Function(VoidCallback tap) build;
  final bool paper;

  /// The render objects of its own layer it has at rest, as origin/main's
  /// part had before it pressed through `Pressable` (read off 862770c9):
  /// a press adds none that stays.
  final List<Type> restLayers;

  /// A tap on it acts (a hold's card does not: a tap is never a reveal).
  final bool commits;
}

Words _w(String text) => Words.forTest(text);

final _parts = [
  for (final paper in [false, true]) ...[
    _Part(
      'primary, ready',
      (tap) => PrimaryButton(label: _w('Deal the cards'), onPressed: tap),
      paper: paper,
    ),
    _Part(
      'primary, locked',
      (tap) => PrimaryButton.locked(label: _w('Ready'), onLockedTap: tap),
      paper: paper,
    ),
    _Part(
      'primary, waiting',
      (_) => const PrimaryButton.waiting(
        label: Words.forTest('Pick a name'),
        reason: 'Pick first',
      ),
      paper: paper,
      commits: false,
    ),
    _Part(
      'secondary',
      (tap) => SecondaryButton(label: _w('Do nothing'), onPressed: tap),
      paper: paper,
    ),
    _Part(
      'icon action',
      (tap) =>
          IconAction(icon: Icons.ios_share, label: 'Share', onPressed: tap),
      paper: paper,
    ),
    _Part(
      'text action',
      (tap) => TextAction(label: 'Leave', onPressed: tap),
      paper: paper,
      // Its dim was an `AnimatedOpacity` on main, a layer at full ink too.
      restLayers: const [RenderAnimatedOpacity],
    ),
    _Part(
      'scrap',
      (tap) => PaperScrap(label: _w('Edit deck'), onTap: tap),
      paper: paper,
    ),
    _Part(
      'your card (04)',
      (_) => HoldToReveal(
        inPlace: true,
        target: 'Your card',
        face: FaceContent.roleText(RoleId.seer),
        cover: const FaceDownCard(
          size: FaceDownSize.hero,
          cardWidth: 200,
          cardHeight: 266,
        ),
      ),
      paper: paper,
      commits: false,
      // The turn's back and its face, the card's own art, and the ring.
      restLayers: const [
        RenderRepaintBoundary,
        RenderRepaintBoundary,
        RenderRepaintBoundary,
        RenderAnimatedOpacity,
      ],
    ),
  ],
];

Future<void> _pump(
  WidgetTester tester,
  _Part part, {
  required VoidCallback tap,
  bool still = false,
}) {
  tester.view.physicalSize = const Size(400, 500);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(
    MaterialApp(
      theme: skinTheme(SkinId.fallback.skin),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: still),
        child: GroundScope(ground: GroundKind.night, child: app!),
      ),
      home: Scaffold(
        body: DressScope(
          dress: part.paper ? Dress.paper : Dress.plain,
          child: GroundScope(
            ground: GroundKind.night,
            fill: true,
            child: Center(child: part.build(tap)),
          ),
        ),
      ),
    ),
  );
}

Finder _of(_Part part) => find.byWidgetPredicate(
  (w) =>
      w is PrimaryButton ||
      w is SecondaryButton ||
      w is IconAction ||
      w is TextAction ||
      w is PaperScrap ||
      w is HoldToReveal,
);

/// The part and the room its shadow and its sink take round it.
Rect _room(WidgetTester tester, _Part part) =>
    tester.getRect(_of(part).first).inflate(24);

/// How many pixels of [room] differ between two frames.
int _changed(FramePixels a, FramePixels b, Rect room) {
  var n = 0;
  for (var y = room.top; y < room.bottom; y++) {
    for (var x = room.left; x < room.right; x++) {
      if (a.at(x, y) != b.at(x, y)) n++;
    }
  }
  return n;
}

/// Every place the part draws itself moved by a press (`PressSink`).
bool _travels(WidgetTester tester) {
  final sinks = tester.renderObjectList<RenderPressSink>(
    find.byType(PressSink),
  );
  for (final sink in sinks) {
    final moved = Matrix4.identity();
    if (sink.child case final child?) sink.applyPaintTransform(child, moved);
    if (moved != Matrix4.identity()) return true;
  }
  return false;
}

/// The render objects under [root] that draw in a layer of their own (a
/// repaint boundary, or one that always composites), in paint order.
List<Type> _layers(RenderObject root) {
  final out = <Type>[];
  void visit(RenderObject r) {
    // Read as the pipeline reads it, to say whether it needs a layer.
    // ignore: invalid_use_of_protected_member
    final composites = r.alwaysNeedsCompositing;
    if (r.isRepaintBoundary || composites) out.add(r.runtimeType);
    r.visitChildren(visit);
  }

  visit(root);
  return out;
}

/// Whether a press piece under the part draws the press now: a sink moved,
/// paper blended toward its pressed paper, ink dimmed. Pixels alone could be
/// another's (an `InkWell`'s splash); this is the press's own paint.
bool _drawsPressed(WidgetTester tester, _Part part) {
  var pressed = false;
  void visit(RenderObject r) {
    pressed |= switch (r) {
      RenderPressSink() => r.drawsPressed,
      RenderPressDecoration() => r.drawsPressed,
      RenderPressFade() => r.drawsPressed,
      // TextAction's dim, as on main.
      RenderAnimatedOpacity() => r.opacity.value < 1,
      _ => false,
    };
    r.visitChildren(visit);
  }

  visit(tester.renderObject(_of(part).first));
  return pressed;
}

/// [element] is Material's own: inside an `InkWell`, above what it holds.
bool _insideInk(Element element) {
  InkWell? ink;
  void look(Element e) {
    if (e.widget case final InkWell found when ink == null) ink = found;
  }

  look(element);
  element.visitAncestorElements((e) {
    look(e);
    return ink == null;
  });
  // Below the ink's child is the part's again.
  return ink != null && !_below(element, ink!.child);
}

/// [element] is [child], or inside it.
bool _below(Element element, Widget? child) {
  if (child == null) return false;
  if (identical(element.widget, child)) return true;
  var found = false;
  element.visitAncestorElements((e) {
    found = identical(e.widget, child);
    return !found;
  });
  return found;
}

void main() {
  for (final part in _parts) {
    final dress = part.paper ? 'dressed' : 'plain';
    group('${part.name}, $dress', () {
      testWidgets('pressed on the first frame after the finger lands', (
        tester,
      ) async {
        var taps = 0;
        await _pump(tester, part, tap: () => taps++);
        final room = _room(tester, part);
        final rest = await FramePixels.of(tester);
        final finger = await tester.startGesture(room.center);
        await tester.pump();
        final first = await FramePixels.of(tester);
        expect(_changed(rest, first, room), greaterThan(0));
        expect(
          _drawsPressed(tester, part),
          isTrue,
          reason: 'the change is the press\'s own paint',
        );
        await finger.up();
        await tester.pumpAndSettle();
        expect(taps, part.commits ? 1 : 0);
      });

      testWidgets('a quick tap shows a pressed frame and still commits', (
        tester,
      ) async {
        var taps = 0;
        await _pump(tester, part, tap: () => taps++);
        final room = _room(tester, part);
        final rest = await FramePixels.of(tester);
        await plainTap(
          tester,
          find.byWidget(tester.widget(_of(part).first)),
          why: 'a tap that is down and up before a frame is drawn',
        );
        await tester.pump();
        final after = await FramePixels.of(tester);
        expect(_changed(rest, after, room), greaterThan(0));
        expect(_drawsPressed(tester, part), isTrue);
        await tester.pumpAndSettle();
        expect(taps, part.commits ? 1 : 0);
      });

      testWidgets('release returns it to the pixels it rested on', (
        tester,
      ) async {
        await _pump(tester, part, tap: () {});
        final room = _room(tester, part);
        final rest = await FramePixels.of(tester);
        await pressAtLikeAFinger(tester, room.center);
        await tester.pumpAndSettle();
        expect(_changed(rest, await FramePixels.of(tester), room), 0);
      });

      testWidgets('reduce motion: the pressed state shows, nothing travels', (
        tester,
      ) async {
        await _pump(tester, part, tap: () {}, still: true);
        final room = _room(tester, part);
        final rest = await FramePixels.of(tester);
        final finger = await tester.startGesture(room.center);
        await tester.pump();
        expect(
          _changed(rest, await FramePixels.of(tester), room),
          greaterThan(0),
        );
        expect(_drawsPressed(tester, part), isTrue);
        expect(_travels(tester), isFalse);
        await finger.up();
        await tester.pump();
        expect(_changed(rest, await FramePixels.of(tester), room), 0);
      });

      testWidgets('reduce motion: a quick tap still shows one pressed frame', (
        tester,
      ) async {
        var taps = 0;
        await _pump(tester, part, tap: () => taps++, still: true);
        final room = _room(tester, part);
        final rest = await FramePixels.of(tester);
        // Read as each frame is painted: the lift comes right after it.
        var drawnPressed = false;
        var watching = true;
        addTearDown(() => watching = false);
        tester.binding.addPersistentFrameCallback((_) {
          if (!watching || _of(part).evaluate().isEmpty) return;
          drawnPressed |= _drawsPressed(tester, part);
        });
        await plainTap(
          tester,
          find.byWidget(tester.widget(_of(part).first)),
          why: 'a tap that is down and up before a frame is drawn',
        );
        await tester.pump();
        expect(
          _changed(rest, await FramePixels.of(tester), room),
          greaterThan(0),
          reason: 'the frame after a quick tap is drawn pressed',
        );
        expect(drawnPressed, isTrue, reason: 'by the press\'s own paint');
        expect(_travels(tester), isFalse);
        await tester.pump();
        expect(
          _changed(rest, await FramePixels.of(tester), room),
          0,
          reason: 'and the next one at rest again',
        );
        await tester.pumpAndSettle();
        expect(taps, part.commits ? 1 : 0);
      });

      testWidgets('at rest, before and after a press, no layer of its own '
          'that main did not have', (tester) async {
        await _pump(tester, part, tap: () {});
        await tester.pumpAndSettle();
        final root = tester.renderObject(_of(part).first);
        expect(_layers(root), part.restLayers);
        await pressAtLikeAFinger(tester, _room(tester, part).center);
        await tester.pumpAndSettle();
        expect(_layers(root), part.restLayers);
      });

      testWidgets('nothing below rebuilds on press', (tester) async {
        await _pump(tester, part, tap: () {});
        await tester.pumpAndSettle();
        final room = _room(tester, part);
        final rebuilt = <Element>[];
        debugOnRebuildDirtyWidget = (element, _) => rebuilt.add(element);
        addTearDown(() => debugOnRebuildDirtyWidget = null);
        final finger = await tester.startGesture(room.center);
        for (var i = 0; i < fingerFrames; i++) {
          await tester.pump(fingerFrame);
        }
        debugOnRebuildDirtyWidget = null;
        // Before the hold: what a press alone builds. Material's `InkWell`
        // rebuilds its own state when its tap goes down (as it did before);
        // the part round it and what it holds (its paper, its words) are
        // never built again.
        expect([
          for (final e in rebuilt)
            if (!_insideInk(e)) e.widget,
        ], isEmpty);
        await finger.cancel();
        await tester.pumpAndSettle();
      });
    });
  }
}
