import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/twine.dart';

// A twine's head (a night's story, 08 held): a filled triangle at the far
// end, the way the card went or the look's way, on a solid thread and a
// gapped one alike; without it the thread ends as it always did.

TwinePainter _painter(TwineKind kind, {required bool head}) => TwinePainter(
  route: const TwineRoute(Offset(10, 10), Offset(60, 10), Offset(110, 10)),
  kind: kind,
  color: Colors.white,
  shadow: Colors.black,
  lean: 0,
  head: head,
);

void main() {
  for (final kind in TwineKind.values) {
    test('${kind.name}: the head reaches the end and is wider than the '
        'thread', () {
      final plain = _painter(kind, head: false).thread().getBounds();
      final headed = _painter(kind, head: true).thread().getBounds();
      // The tip is the route's end.
      expect(headed.right, closeTo(110, 0.5));
      // The head is wider across than the thread.
      expect(headed.height, greaterThan(plain.height + 4));
      expect(headed.height, closeTo(TwinePainter.headLength, 0.5));
      // Only the far end: the near end is where it was.
      expect(headed.left, closeTo(plain.left, 0.01));
    });
  }

  test('the head turns along the thread: pointing down on a falling one', () {
    const painter = TwinePainter(
      route: TwineRoute(Offset(10, 0), Offset(10, 50), Offset(10, 100)),
      kind: TwineKind.move,
      color: Colors.white,
      shadow: Colors.black,
      lean: 0,
      head: true,
    );
    final bounds = painter.thread().getBounds();
    expect(bounds.bottom, closeTo(100, 0.5));
    expect(bounds.width, closeTo(TwinePainter.headLength, 0.5));
  });
}
