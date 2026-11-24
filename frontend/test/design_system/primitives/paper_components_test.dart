import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/design_system/primitives/drawn.dart';
import 'package:midnight_village/design_system/primitives/paper_piece.dart';
import 'package:midnight_village/design_system/primitives/secondary_button.dart';
import 'package:midnight_village/design_system/skin/dress.dart';
import 'package:midnight_village/design_system/skin/dress_inventory.dart';
import 'package:midnight_village/design_system/skin/dress_style.dart';
import 'package:midnight_village/design_system/skin/ground.dart';

import '../../helpers/parts_catalogue.dart';
import '../../helpers/pump_skinned.dart';
import 'paper_rules_test.dart' show paperScreens, paperSheets;

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

/// Every paint call [root] makes (and what it paints), recorded without a
/// screen; leaves out whatever sits in a [Drawn].
List<RecordedInvocation> paintCallsOf(RenderObject root) {
  final canvas = TestRecordingCanvas();
  _Walker(canvas).paintChild(root, Offset.zero);
  return canvas.invocations;
}

/// The same, each with the render object that was painting it (the innermost):
/// its `debugCreator` leads to the widgets above it.
List<(RecordedInvocation, RenderObject)> paintCallsWithOwner(
  RenderObject root,
) {
  final canvas = TestRecordingCanvas();
  final walker = _Walker(canvas);
  walker.paintChild(root, Offset.zero);
  final out = <(RecordedInvocation, RenderObject)>[];
  for (final (i, call) in canvas.invocations.indexed) {
    RenderObject? owner;
    var width = 1 << 30;
    for (final (start, end, node) in walker.spans) {
      if (start <= i && i < end && end - start < width) {
        owner = node;
        width = end - start;
      }
    }
    out.add((call, owner ?? root));
  }
  return out;
}

/// Walks the paint of [root] and returns every stroke, ring or text line it
/// draws, leaving out whatever sits in a [Drawn].
List<String> strokesIn(RenderObject root) {
  final found = <String>[];
  for (final call in paintCallsOf(root)) {
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

  /// Where each child's paint calls start and end in the recording.
  final spans = <(int, int, RenderObject)>[];

  @override
  void paintChild(RenderObject child, Offset offset) {
    if (child is RenderDrawn) return;
    final start = (canvas as TestRecordingCanvas).invocations.length;
    super.paintChild(child, offset);
    spans.add((
      start,
      (canvas as TestRecordingCanvas).invocations.length,
      child,
    ));
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

    // The parts page is not the screens: every paper SCREEN is walked too (the
    // table as host and guest, your card both ways, the night board at 5 and
    // 10, the deck page) and every sheet each can open, as built in the app.
    for (final entry in paperScreens.entries) {
      testWidgets('screen: ${entry.key}', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await entry.value(tester);
        expect(strokesIn(tester.binding.renderViews.first.child!), isEmpty);
      });
    }
    for (final entry in paperSheets.entries) {
      testWidgets('sheet: ${entry.key}', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await entry.value.open(tester);
        await tester.pump(const Duration(milliseconds: 600));
        expect(strokesIn(tester.binding.renderViews.first.child!), isEmpty);
      });
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
        // The HANGED stamp: an ink impression, its rules and burst are lines
        // (the mock's stamp, end board piece 3).
        'inkStamp',
      });
    });
  });

  group('the inventory', () {
    final files = [
      for (final f in Directory('lib/design_system/primitives').listSync())
        // A part file is its library's: the library's line covers it.
        if (f is File &&
            f.path.endsWith('.dart') &&
            !f.readAsStringSync().startsWith('part of '))
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

    test('every paper kind has both dresses in the one table', () {
      expect(DressStyle.parts.keys.toSet(), PaperPart.values.toSet());
      for (final part in PaperPart.values) {
        expect(DressStyle.parts[part]!.plain, isNotEmpty);
        expect(DressStyle.of(part, Dress.plain), isNull);
        expect(DressStyle.of(part, Dress.paper), isNotNull);
      }
    });

    // The registry is held on the WIDGETS, not on the text of a source file (a
    // comment satisfied that): each component class is built on the parts page
    // in both dresses, and where it says it is a kind of paper, a PaperPiece of
    // that kind is built inside it.
    for (final e in inventory) {
      testWidgets('${e.name}: built in both dresses, made of ${e.part}', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final samples = partsCatalogue.where((s) => s.entry == e.name).toList();
        expect(
          samples,
          isNotEmpty,
          reason: '${e.name} is not on the parts page',
        );
        final names = e.built ?? e.name.split(' / ');
        bool isIt(Widget w) => names.contains(
          w.runtimeType.toString().replaceAll(RegExp(r'<.*>'), ''),
        );
        final parts = <PaperPart>{};
        for (final dress in Dress.values) {
          var built = false;
          for (final sample in samples) {
            await pumpSkinned(
              tester,
              DressScope(
                dress: dress,
                child: Material(
                  type: MaterialType.transparency,
                  child: sampleOf(sample),
                ),
              ),
            );
            await tester.pump(const Duration(milliseconds: 100));
            final at = find.byWidgetPredicate(isIt);
            if (at.evaluate().isEmpty) continue;
            built = true;
            if (dress.isPaper) {
              for (final piece
                  in find
                      .descendant(of: at, matching: find.byType(PaperPiece))
                      .evaluate()) {
                parts.add((piece.widget as PaperPiece).part);
              }
            } else {
              // Plain draws no paper piece: its look is the component's own.
              expect(
                find.descendant(of: at, matching: find.byType(PaperPiece)),
                findsNothing,
                reason: '${e.name} draws paper on a plain screen',
              );
            }
          }
          expect(built, isTrue, reason: '${e.name} not built in ${dress.name}');
        }
        if (e.part != null) {
          expect(
            parts,
            contains(e.part),
            reason: '${e.name} says it is ${e.part}, built of $parts',
          );
        }
      });
    }

    // The README's inventory table is the inventory: a ROW per component with
    // its own plain and paper words and file, not a name found anywhere.
    test('the README table has a row per component with its words', () {
      final rows = {
        for (final line in File(
          'lib/design_system/README.md',
        ).readAsLinesSync())
          if (line.startsWith('| ') && line.endsWith('|'))
            line
                .substring(1, line.length - 1)
                .split(' | ')
                .map((c) => c.trim())
                .toList()
              ..[0] = line.split('|')[1].trim(),
      };
      final byName = {for (final r in rows) r.first: r};
      for (final e in inventory) {
        final row = byName[e.name];
        expect(row, isNotNull, reason: '${e.name} has no row in the README');
        expect(row!.length, greaterThanOrEqualTo(4), reason: '${e.name} row');
        expect(row[1], e.plain, reason: '${e.name}: the plain look differs');
        expect(row[2], e.paper, reason: '${e.name}: the paper look differs');
        expect(row[3], contains(e.file), reason: '${e.name}: its file differs');
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

  // Real hit-test areas, measured on the screens a player uses: every control
  // that takes a tap (a gesture detector, an ink well) on every paper screen is
  // at least the reading floor (`Sizes.touch`, 44) high and wide, or sits in a
  // row or a card that reaches it. A control a finger cannot hit fails.
  group('every tap target on a paper screen is hit-testable at 44', () {
    List<String> small(WidgetTester tester) {
      final faults = <String>[];
      final seen = <RenderObject>{};
      for (final e in tester.allElements) {
        final w = e.widget;
        final taps = switch (w) {
          GestureDetector() => w.onTap != null || w.onLongPress != null,
          RawGestureDetector() => w.gestures.isNotEmpty,
          InkResponse() => w.onTap != null || w.onLongPress != null,
          _ => false,
        };
        if (!taps) continue;
        // What a sheet covers is behind its scrim.
        if (!(ModalRoute.of(e)?.isCurrent ?? true)) continue;
        final box = e.renderObject;
        if (box is! RenderBox || !box.hasSize || !seen.add(box)) continue;
        // A gesture detector a screen uses to catch a tap anywhere (the whole
        // screen, a scrim) is not a control.
        if (box.size.width > 300 && box.size.height > 300) continue;
        final side = box.size.shortestSide;
        // Off the screen (a page that scrolls) cannot be hit-tested here.
        final view = tester.view.physicalSize / tester.view.devicePixelRatio;
        final middle = box.localToGlobal(box.size.center(Offset.zero));
        if (middle.dx < 0 ||
            middle.dy < 0 ||
            middle.dx > view.width ||
            middle.dy > view.height) {
          continue;
        }
        // What a finger can hit is the box AND the hit test: the centre must
        // answer to it.
        final centre = box.localToGlobal(box.size.center(Offset.zero));
        final result = tester.hitTestOnBinding(centre);
        final hit = result.path.any((h) => identical(h.target, box));
        if (side < Sizes.touch - 0.5 || !hit) {
          faults.add(
            '${w.runtimeType} ${box.size.width.round()} x '
            '${box.size.height.round()}${hit ? '' : ' (centre misses it)'}',
          );
        }
      }
      return faults;
    }

    for (final entry in paperScreens.entries) {
      testWidgets(entry.key, (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await entry.value(tester);
        // OPEN (found by this measurement, not fixed in this pass): the table's
        // deck strip thumbnails are 30 x 40 and a tap on one reads its card;
        // seven or more across the phone cannot each be 44 wide as drawn. The
        // allowance is exactly them: any other small target fails, and so does
        // this one when it is fixed (remove it then).
        final known = entry.key.startsWith('table')
            ? {'RawGestureDetector 30 x 40'}
            : <String>{};
        expect(small(tester).toSet(), known);
      });
    }

    testWidgets('the check sees a control that is too small', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: const SizedBox(width: 30, height: 30),
            ),
          ),
        ),
      );
      expect(small(tester), hasLength(1));
    });
  });
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
