import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/paper_card.dart';
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

  testWidgets('outside any scope the ground is night', (tester) async {
    final (ground, kind) = await read(tester, (probe) => probe);
    expect(kind, GroundKind.night);
    expect(ground, same(skin.night));
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
}
