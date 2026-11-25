import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/still.dart';

/// A Still draws exactly what its inside draws: the same pixels, a
/// half-clear fill, a mask and an opacity included.
void main() {
  Future<List<int>> pixels(WidgetTester tester, Widget inside) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: key,
            child: ColoredBox(
              color: const Color(0xFF203040),
              child: SizedBox(width: 40, height: 40, child: inside),
            ),
          ),
        ),
      ),
    );
    final box =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await tester.runAsync(() async {
      final i = await box.toImage();
      final data = await i.toByteData(format: ui.ImageByteFormat.rawRgba);
      i.dispose();
      return data!.buffer.asUint8List().toList();
    });
    return image!;
  }

  final cases = <String, (Widget, Widget)>{
    'a half-clear fill': (
      const ColoredBox(color: Color(0x80FFC080)),
      const Still(child: ColoredBox(color: Color(0x80FFC080))),
    ),
    'an opacity': (
      const Opacity(opacity: 0.4, child: ColoredBox(color: Color(0xFFFFC080))),
      const Still(opacity: 0.4, child: ColoredBox(color: Color(0xFFFFC080))),
    ),
    'a mask': (
      ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (r) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF000000), Color(0x00000000)],
        ).createShader(r),
        child: const ColoredBox(color: Color(0xFFFFC080)),
      ),
      Still(
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (r) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF000000), Color(0x00000000)],
          ).createShader(r),
          child: const ColoredBox(color: Color(0xFFFFC080)),
        ),
      ),
    ),
  };
  for (final MapEntry(key: name, value: (plain, still)) in cases.entries) {
    testWidgets('$name: the same pixels', (tester) async {
      final a = await pixels(tester, plain);
      final b = await pixels(tester, still);
      var worst = 0;
      for (var i = 0; i < a.length; i++) {
        final d = (a[i] - b[i]).abs();
        if (d > worst) worst = d;
      }
      expect(worst, lessThanOrEqualTo(1), reason: 'largest channel change');
    });
  }
}
