import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/design_system/primitives/fit_line.dart';
import 'package:midnight_village/design_system/skin/skin_id.dart';

// A fit sets a role smaller to fit its room, but never under the label floor
// (12): a chip or a tag stays at its token and the words wrap, or the line
// overflows where the gallery and the sweeps see it, rather than shrinking
// out of sight (the picture critic found tags drawn at about 9 to 10).

Future<double> _drawnSize(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Center(child: SizedBox(width: 60, child: child)),
    ),
  );
  return tester
      .widget<RichText>(find.byType(RichText).first)
      .text
      .style!
      .fontSize!;
}

void main() {
  final type = SkinId.fallback.skin.typography;

  testWidgets('FitWords never sets a label under 12, in a room too narrow', (
    tester,
  ) async {
    final size = await _drawnSize(
      tester,
      FitWords('Werewolf team', style: type.tag, maxLines: 1),
    );
    expect(size, ReadingFloor.caption);
  });

  testWidgets('FitWords sets a name smaller to fit, but not under 12', (
    tester,
  ) async {
    final size = await _drawnSize(
      tester,
      FitWords('Troublemaker', style: type.name),
    );
    expect(size, lessThan(type.name.fontSize!));
    expect(size, greaterThanOrEqualTo(ReadingFloor.caption));
  });

  testWidgets('FitLine never sets a label under 12, in a room too narrow', (
    tester,
  ) async {
    final size = await _drawnSize(
      tester,
      FitLine('Practice player', style: type.tag),
    );
    expect(size, ReadingFloor.caption);
    tester.takeException();
  });

  testWidgets('FitLine sets a larger line smaller to fit, not under 12', (
    tester,
  ) async {
    final size = await _drawnSize(
      tester,
      FitLine('Doppelganger', style: type.heroTitle),
    );
    expect(size, lessThan(type.heroTitle.fontSize!));
    expect(size, greaterThanOrEqualTo(ReadingFloor.caption));
  });
}
