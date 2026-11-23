import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/paper_card.dart';
import 'package:midnight_village/design_system/primitives/sheet_scaffold.dart';
import 'package:midnight_village/design_system/primitives/screen_frame.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/ground_scope.dart';
import 'package:midnight_village/design_system/skin/skin.dart';
import 'package:midnight_village/design_system/skin/skin_theme.dart';

import '../../helpers/pump_skinned.dart';

/// Records the ground its context reads.
class _Probe extends StatelessWidget {
  const _Probe(this.onRead);

  final void Function(Ground ground, GroundKind kind) onRead;

  @override
  Widget build(BuildContext context) {
    onRead(context.ground, GroundScope.of(context));
    return const SizedBox();
  }
}

void main() {
  final skin = skinsUnderTest.values.first;

  Future<(Ground, GroundKind)> read(
    WidgetTester tester,
    Widget Function(Widget probe) wrap,
  ) async {
    late Ground ground;
    late GroundKind kind;
    await tester.pumpWidget(
      MaterialApp(
        theme: skinTheme(skin),
        home: wrap(_Probe((g, k) => (ground, kind) = (g, k))),
      ),
    );
    return (ground, kind);
  }

  testWidgets('asking for the ground with none declared is a mistake', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: skinTheme(skin), home: _Probe((_, _) {})),
    );
    expect(
      tester.takeException(),
      isA<AssertionError>().having(
        (e) => '$e',
        'message',
        contains('No GroundScope above this widget'),
      ),
    );
  });

  testWidgets('a scope sets the ground for everything below it', (
    tester,
  ) async {
    final (ground, kind) = await read(
      tester,
      (probe) => GroundScope(ground: GroundKind.day, child: probe),
    );
    expect(kind, GroundKind.day);
    expect(ground, same(skin.day));
  });

  testWidgets('a paper card puts its content on paper, on any ground', (
    tester,
  ) async {
    final (ground, kind) = await read(
      tester,
      (probe) => GroundScope(
        ground: GroundKind.day,
        child: PaperCard(child: probe),
      ),
    );
    expect(kind, GroundKind.paper);
    expect(ground.text, skin.paper.text);
  });

  Future<GroundKind> openFromDay(
    WidgetTester tester,
    Future<void> Function(BuildContext context, WidgetBuilder probe) open,
  ) async {
    late GroundKind inside;
    await pumpSkinned(
      tester,
      ground: GroundKind.day,
      ScreenFrame(
        ground: GroundKind.day,
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                open(context, (_) => _Probe((_, kind) => inside = kind)),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return inside;
  }

  testWidgets('a sheet opened from a day screen is day-grounded', (
    tester,
  ) async {
    final kind = await openFromDay(
      tester,
      (context, probe) => showSkinSheet<void>(context, builder: probe),
    );
    expect(kind, GroundKind.day);
  });

  testWidgets('a dialog opened from a day screen is day-grounded', (
    tester,
  ) async {
    final kind = await openFromDay(
      tester,
      (context, probe) => showSkinDialog<void>(context, builder: probe),
    );
    expect(kind, GroundKind.day);
  });

  testWidgets('even a plain Material dialog carries the ground it was opened '
      'on', (tester) async {
    final kind = await openFromDay(
      tester,
      (context, probe) => showDialog<void>(context: context, builder: probe),
    );
    expect(kind, GroundKind.day);
  });

  testWidgets('the sheet\'s own content is on paper, its edge lit by the '
      'ground it covers', (tester) async {
    late GroundKind body;
    late Color edge;
    await pumpSkinned(
      tester,
      ground: GroundKind.day,
      ScreenFrame(
        ground: GroundKind.day,
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showSkinSheet<void>(
              context,
              builder: (context) {
                edge = context.ground.selection;
                return SheetScaffold(child: _Probe((_, kind) => body = kind));
              },
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(body, GroundKind.paper);
    expect(edge, skin.day.selection);
  });
}
