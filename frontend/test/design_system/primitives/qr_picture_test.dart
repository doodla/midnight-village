import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/design_system/primitives/qr_picture.dart';
import 'package:qr/qr.dart';

import '../../helpers/pump_skinned.dart';

// The QR code 02 shows paints its modules, not an empty box, at the least
// size 02 gives it. It paints plain rectangles on a canvas (no image, no
// platform view), the one path every renderer draws, the web's included.

void main() {
  testWidgets('the QR code paints its dark modules where the code has them, '
      'at its scannable least', (tester) async {
    const link = 'https://midnight.example/join/V9YC2J';
    final key = GlobalKey();
    await pumpSkinned(
      tester,
      RepaintBoundary(
        key: key,
        child: const QrPicture(data: link, side: Sizes.qrScannable),
      ),
    );

    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final bytes = (await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return (image.width, data!);
    }))!;
    final (width, data) = bytes;

    final code = QrImage(
      QrCode.fromData(data: link, errorCorrectLevel: QrErrorCorrectLevel.M),
    );
    final count = code.moduleCount + 2 * QrPicture.quietModules;
    final module = width / count;
    double brightness(int row, int col) {
      // The middle of the module.
      final x = ((col + QrPicture.quietModules + 0.5) * module).floor();
      final y = ((row + QrPicture.quietModules + 0.5) * module).floor();
      final i = (y * width + x) * 4;
      return (data.getUint8(i) + data.getUint8(i + 1) + data.getUint8(i + 2)) /
          3;
    }

    // Every module drawn where the code says, the light ones left clear:
    // the ink (the ground's text) differs from the paper.
    var dark = 0;
    final darkSeen = <double>{}, lightSeen = <double>{};
    for (var row = 0; row < code.moduleCount; row++) {
      for (var col = 0; col < code.moduleCount; col++) {
        final b = brightness(row, col);
        if (code.isDark(row, col)) {
          dark++;
          darkSeen.add(b);
        } else {
          lightSeen.add(b);
        }
      }
    }
    expect(dark, greaterThan(code.moduleCount * code.moduleCount ~/ 4));
    expect(darkSeen, hasLength(1), reason: 'every dark module the same ink');
    expect(
      lightSeen.contains(darkSeen.single),
      isFalse,
      reason: 'no light module painted',
    );
  });
}
