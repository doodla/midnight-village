import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/drawn.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/secondary_button.dart';
import 'package:midnight_village/design_system/skin/dress.dart';
import 'package:midnight_village/design_system/skin/dress_inventory.dart';
import 'package:midnight_village/design_system/skin/dress_style.dart';
import 'package:midnight_village/design_system/skin/ground.dart';

import '../../helpers/parts_catalogue.dart';
import '../../helpers/pump_skinned.dart';

// One language for paper, and the mechanism that keeps it: (a) no component
// paints a stroke, outline or border on a paper screen (outside the named
// drawings, `Drawn`); (b) every primitive is in the inventory with both of its
// dresses, and every paper piece takes its look from the one table; (c) no
// screen builds a raw Material button, chip, divider or border itself.

/// The paint calls that make a line: a stroked shape, a line, a ring.
const _lineCalls = {#drawLine, #drawDRRect, #drawPoints, #drawRawPoints};
const _shapeCalls = {
  #drawPath,
  #drawRect,
  #drawRRect,
  #drawCircle,
  #drawOval,
  #drawArc,
};

/// Walks the paint of [root] and returns every stroke, ring or text line it
/// draws, leaving out whatever sits in a [Drawn].
List<String> strokesIn(RenderObject root) {
  final canvas = TestRecordingCanvas();
  _Walker(canvas).paintChild(root, Offset.zero);
  final found = <String>[];
  for (final call in canvas.invocations) {
    final name = call.invocation.memberName;
    final paint = call.invocation.positionalArguments
        .whereType<Paint>()
        .firstOrNull;
    final where = RegExp(r'package:midnight_village/[^ )]+')
        .allMatches(call.stackToString())
        .map((m) => m.group(0)!.replaceFirst('package:midnight_village/', ''))
        .take(2)
        .join(' < ');
    if (_lineCalls.contains(name)) {
      found.add('${_name(name)} at $where');
    } else if (_shapeCalls.contains(name) &&
        paint != null &&
        paint.style == PaintingStyle.stroke) {
      found.add('${_name(name)} stroked at $where');
    }
  }
  void text(RenderObject node) {
    if (node is RenderDrawn) return;
    if (node is RenderParagraph) {
      node.text.visitChildren((span) {
        final d = span.style?.decoration;
        if (d != null && d != TextDecoration.none) found.add('text $d');
        return true;
      });
      final d = node.text.style?.decoration;
      if (d != null && d != TextDecoration.none) found.add('text $d');
    }
    node.visitChildren(text);
  }

  text(root);
  return found;
}

String _name(Symbol s) => s.toString().replaceAll(RegExp(r'Symbol\("|"\)'), '');

class _Walker extends TestRecordingPaintingContext {
  _Walker(super.canvas);

  @override
  void paintChild(RenderObject child, Offset offset) {
    if (child is RenderDrawn) return;
    super.paintChild(child, offset);
  }

  // flutter_test's recorder returns null here and a colour filter (a dimmed
  // card) would throw: paint the child as if unfiltered.
  @override
  ColorFilterLayer pushColorFilter(
    Offset offset,
    ColorFilter colorFilter,
    PaintingContextCallback painter, {
    ColorFilterLayer? oldLayer,
  }) {
    painter(this, offset);
    return oldLayer ?? ColorFilterLayer();
  }
}

Future<List<String>> _strokes(
  WidgetTester tester,
  Widget child, {
  Dress dress = Dress.paper,
  GroundKind ground = GroundKind.night,
}) async {
  final key = GlobalKey();
  await pumpSkinned(
    tester,
    DressScope(
      dress: dress,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: RepaintBoundary(key: key, child: child),
      ),
    ),
    ground: ground,
  );
  await tester.pump(const Duration(milliseconds: 200));
  return strokesIn(key.currentContext!.findRenderObject()!);
}

void main() {
  group('no stroke on paper', () {
    for (final ground in [GroundKind.night, GroundKind.day]) {
      for (final (i, sample) in partsCatalogue.indexed) {
        testWidgets(
          '${sample.entry} (${sample.state.name} #$i) on ${ground.name}',
          (tester) async {
            tester.view.physicalSize = const Size(800, 1400);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final strokes = await _strokes(
              tester,
              Material(
                type: MaterialType.transparency,
                child: sampleOf(sample),
              ),
              ground: ground,
            );
            expect(
              strokes,
              isEmpty,
              reason:
                  '${sample.entry} paints a stroke on paper: put it in the '
                  'paper table (dress_style.dart) or, if it is a drawing, a Drawn',
            );
          },
        );
      }
    }

    testWidgets('the test sees a stroke where there is one (plain dress)', (
      tester,
    ) async {
      final strokes = await _strokes(
        tester,
        SecondaryButton(label: 'Outlined', onPressed: () {}),
        dress: Dress.plain,
      );
      expect(strokes, isNotEmpty);
    });

    testWidgets('and sees the ways a component could draw one', (tester) async {
      Future<List<String>> of(Widget w) => _strokes(tester, w);
      expect(
        await of(
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        isNotEmpty,
        reason: 'a rounded border',
      );
      expect(
        await of(
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(border: Border.all(color: Colors.white)),
          ),
        ),
        isNotEmpty,
        reason: 'a square border',
      );
      expect(
        await of(
          Container(
            width: 40,
            height: 40,
            decoration: const ShapeDecoration(
              shape: StadiumBorder(side: BorderSide(color: Colors.white)),
            ),
          ),
        ),
        isNotEmpty,
        reason: 'a shape with a visible side',
      );
      expect(
        await of(
          const Text(
            'Leave',
            style: TextStyle(decoration: TextDecoration.underline),
          ),
        ),
        isNotEmpty,
        reason: 'an underline',
      );
      expect(
        await of(OutlinedButton(onPressed: () {}, child: const Text('Raw'))),
        isNotEmpty,
        reason: 'a Material outlined button',
      );
      expect(
        await of(
          const InputDecorator(
            decoration: InputDecoration(border: OutlineInputBorder()),
          ),
        ),
        isNotEmpty,
        reason: 'an input border',
      );
    });

    testWidgets('a drawing inside a Drawn is allowed, its neighbours are not', (
      tester,
    ) async {
      final line = CustomPaint(painter: _Line(), size: const Size(20, 20));
      expect(
        await _strokes(tester, Drawn(DrawnKind.qrCode, child: line)),
        isEmpty,
      );
      expect(await _strokes(tester, line), isNotEmpty);
    });

    test('the allow-list is the named drawings and no more', () {
      expect(DrawnKind.values.map((k) => k.name).toSet(), {
        'qrCode',
        'scanner',
      });
    });
  });

  group('the inventory', () {
    final files = [
      for (final f in Directory('lib/design_system/primitives').listSync())
        if (f is File && f.path.endsWith('.dart'))
          'primitives/${f.uri.pathSegments.last}',
    ];

    test('every primitive file is a listed component or says why not', () {
      final listed = {for (final e in inventory) e.file};
      final unlisted = [
        for (final f in files)
          if (!listed.contains(f) && !notAComponent.containsKey(f)) f,
      ];
      expect(
        unlisted,
        isEmpty,
        reason:
            'add it to `inventory` (dress_inventory.dart) with its plain and '
            'paper look, or to `notAComponent` with a reason',
      );
      final gone = [
        for (final f in {...listed, ...notAComponent.keys})
          if (!File('lib/design_system/$f').existsSync()) f,
      ];
      expect(gone, isEmpty, reason: 'listed, but there is no such file');
      expect(
        [
          for (final f in notAComponent.keys)
            if (listed.contains(f)) f,
        ],
        isEmpty,
        reason: 'a file is a component or it is not',
      );
    });

    test('every entry declares both dresses and has samples to look at', () {
      final sampled = {for (final s in partsCatalogue) s.entry};
      for (final e in inventory) {
        expect(e.plain.trim(), isNotEmpty, reason: '${e.name}: plain look');
        expect(e.paper.trim(), isNotEmpty, reason: '${e.name}: paper look');
        expect(sampled, contains(e.name), reason: '${e.name}: no sample');
      }
      expect(
        sampled.difference({for (final e in inventory) e.name}),
        isEmpty,
        reason: 'a sample for no inventory entry',
      );
      expect(
        {for (final e in inventory) e.name}.length,
        inventory.length,
        reason: 'a name twice',
      );
    });

    test('every paper kind has both dresses in the one table, and its '
        'component draws from it', () {
      expect(DressStyle.parts.keys.toSet(), PaperPart.values.toSet());
      for (final part in PaperPart.values) {
        expect(DressStyle.parts[part]!.plain, isNotEmpty);
        expect(DressStyle.of(part, Dress.plain), isNull);
        expect(DressStyle.of(part, Dress.paper), isNotNull);
      }
      for (final e in inventory.where((e) => e.part != null)) {
        final source = File('lib/design_system/${e.file}').readAsStringSync();
        expect(
          source,
          contains('PaperPart.${e.part!.name}'),
          reason: '${e.name} says it is ${e.part} but draws something else',
        );
      }
    });

    test('the README lists every component in its table', () {
      final readme = File('lib/design_system/README.md').readAsStringSync();
      for (final e in inventory) {
        expect(
          readme,
          contains('| ${e.name} |'),
          reason: '${e.name} is not in the README\'s inventory table',
        );
      }
    });
  });

  group('screens build from the kit', () {
    final raw = RegExp(
      r'\b(OutlinedButton|TextButton|ElevatedButton|FilledButton|IconButton|'
      r'ActionChip|ChoiceChip|FilterChip|InputChip|Chip|Divider|'
      r'VerticalDivider|InputDecoration|OutlineInputBorder|'
      r'UnderlineInputBorder|SegmentedButton|Checkbox|Radio|Switch|ListTile|'
      r'Card|AlertDialog|SnackBar|ShapeDecoration)\s*[(.]|'
      r'\bBorder(Side)?\s*[(.]|\bborder\s*:|PaintingStyle\.stroke|'
      r'TextDecoration\.underline',
    );

    List<String> scan(Map<String, String> sources) => [
      for (final MapEntry(key: path, value: source) in sources.entries)
        if (!path.startsWith('lib/features/debug/'))
          for (final (n, line) in source.split('\n').indexed)
            if (!line.trimLeft().startsWith('//') && raw.hasMatch(line))
              '$path:${n + 1}: ${line.trim()}',
    ];

    test('no screen draws its own button, chip, divider or border', () {
      final sources = {
        for (final f in Directory('lib/features').listSync(recursive: true))
          if (f is File && f.path.endsWith('.dart'))
            f.path: f.readAsStringSync(),
      };
      expect(sources, isNotEmpty);
      expect(
        scan(sources),
        isEmpty,
        reason:
            'a screen asks a primitive (`lib/design_system/primitives/`) '
            'for it; a primitive has its paper look in dress_style.dart',
      );
    });

    test('the scan catches what it is for', () {
      for (final bad in [
        'OutlinedButton(onPressed: f, child: c)',
        'IconButton(icon: i, onPressed: f)',
        'const Divider(height: 8)',
        'border: Border.all(color: c),',
        'decoration: BoxDecoration(border: b)',
        'InputDecoration(hint: h)',
        'style: TextStyle(decoration: TextDecoration.underline)',
        'BorderSide(color: c)',
      ]) {
        expect(scan({'lib/features/x.dart': bad}), isNotEmpty, reason: bad);
      }
      expect(
        scan({'lib/features/x.dart': 'PrimaryButton(label: l, onPressed: f)'}),
        isEmpty,
      );
    });
  });

  test(
    'a paper component keeps its touch target and is no smaller than 48',
    () {
      expect(SecondaryButton.height, greaterThanOrEqualTo(48));
      expect(ButtonSize.regular.primaryHeight, greaterThanOrEqualTo(48));
    },
  );
}

class _Line extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) => canvas.drawLine(
    Offset.zero,
    Offset(size.width, size.height),
    Paint()..style = PaintingStyle.stroke,
  );

  @override
  bool shouldRepaint(_Line old) => false;
}
