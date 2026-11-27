import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/deckle.dart';

// A deckled edge at rest is cut where it lies and kept, as on main: nothing
// more (no moved copy is made or kept for it), so a screen of paper costs
// what it did. Only a press's blend (`DeckleBorder.whileMoving`) keeps one
// edge per size and moves it, instead of tearing a new one every frame; and
// it starts from the resting edge of that size, so the frame the finger
// lands tears nothing.

void main() {
  test('at rest an edge is cut where it lies and no moved copy is kept', () {
    const edge = DeckleBorder(seed: 4101, depth: 2.4, step: 6);
    final kept = DeckleBorder.movedKept;
    final torn = DeckleBorder.tornCount;
    for (var i = 0; i < 5; i++) {
      edge.getOuterPath(Rect.fromLTWH(10.0 * i, 3, 120 + i.toDouble(), 40));
    }
    expect(DeckleBorder.tornCount, torn + 5);
    expect(DeckleBorder.movedKept, kept, reason: 'a rest edge kept a copy');
  });

  test('while moving, one edge per size is moved, not torn every frame', () {
    const edge = DeckleBorder(seed: 4102, depth: 2.4, step: 6);
    const size = Size(140, 44);
    final rest = edge.getOuterPath(const Offset(20, 30) & size);
    final torn = DeckleBorder.tornCount;
    final moved = <Path>[];
    DeckleBorder.whileMoving(() {
      for (var i = 1; i <= 6; i++) {
        moved.add(edge.getOuterPath(Offset(20, 30 + i * 0.25) & size));
      }
    });
    // The press's frames (the first one too) tear nothing: the resting
    // edge of that size is moved.
    expect(DeckleBorder.tornCount, torn);
    // The moved edge is the resting one, moved.
    final at = moved.last.getBounds();
    final from = rest.getBounds().shift(const Offset(0, 6 * 0.25));
    expect(at.left, closeTo(from.left, 1e-6));
    expect(at.top, closeTo(from.top, 1e-6));
    expect(at.size.width, closeTo(from.size.width, 1e-6));
    expect(at.size.height, closeTo(from.size.height, 1e-6));
  });
}
