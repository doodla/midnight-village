import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/skin/ground.dart';

import '../../helpers/pump_skinned.dart';

// WCAG 2.1 AA for every text colour role on the fill it is read on, on every
// ground of every skin. All text roles must reach 4.5:1 (body text): each of
// them is used at body sizes somewhere, so none may rely on the 3:1 that
// large text is allowed.

const _bodyMinimum = 4.5;

/// WCAG 2.1 relative luminance.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double contrast(Color a, Color b) {
  final (la, lb) = (_luminance(a), _luminance(b));
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Each text colour role and the fill it is read on.
Map<String, (Color, Color)> _textPairs(Ground g) => {
  'text on ground': (g.text, g.ground),
  'quietText on ground': (g.quietText, g.ground),
  'faintText on ground': (g.faintText, g.ground),
  'dangerText on ground': (g.dangerText, g.ground),
  'selection (a picked name) on ground': (g.selection, g.ground),
  'text on panel': (g.text, g.panel),
  'quietText on panel': (g.quietText, g.panel),
  'onAccent on accent': (g.onAccent, g.accent),
  'onMark on mark': (g.onMark, g.mark),
  'onPick on pick': (g.onPick, g.pick),
  'onDanger on danger': (g.onDanger, g.danger),
  // A tag inverts its ground.
  'ground on text': (g.ground, g.text),
};

void main() {
  test('the WCAG formula gives its known answers', () {
    expect(
      contrast(const Color(0xFF000000), const Color(0xFFFFFFFF)),
      closeTo(21, 0.01),
    );
    expect(
      contrast(const Color(0xFF777777), const Color(0xFFFFFFFF)),
      closeTo(4.48, 0.01),
    );
  });

  for (final MapEntry(key: name, value: skin) in skinsUnderTest.entries) {
    for (final kind in GroundKind.values) {
      test('$name, $kind: every text role meets AA ($_bodyMinimum:1)', () {
        final failures = <String>[];
        for (final MapEntry(key: pair, value: (fg, bg)) in _textPairs(
          skin.ground(kind),
        ).entries) {
          final ratio = contrast(fg, bg);
          if (ratio < _bodyMinimum) {
            failures.add('$pair: ${ratio.toStringAsFixed(2)}:1');
          }
        }
        expect(failures, isEmpty);
      });
    }
  }
}
