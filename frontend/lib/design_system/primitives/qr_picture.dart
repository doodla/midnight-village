import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

import '../skin/skin.dart';

/// A QR code for [data] (02: the link that joins the table), drawn square in
/// the ink of the ground it sits on, with the quiet zone a reader needs. It
/// takes the width it is given, up to [side]. Its meaning is spoken through
/// [semanticLabel]; the modules are not read out.
class QrPicture extends StatelessWidget {
  const QrPicture({
    super.key,
    required this.data,
    this.side = defaultSide,
    this.semanticLabel,
  });

  final String data;
  final double side;
  final String? semanticLabel;

  /// Big enough to scan across a table.
  static const defaultSide = 168.0;

  /// The light border round the code, in modules (the standard asks for 4;
  /// the paper it sits on gives the rest).
  static const quietModules = 2;

  @override
  Widget build(BuildContext context) {
    final image = QrImage(
      QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.M),
    );
    return Semantics(
      image: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.hasBoundedWidth
              ? side.clamp(0.0, constraints.maxWidth)
              : side;
          return SizedBox.square(
            dimension: width,
            child: CustomPaint(
              painter: _QrPainter(image, ink: context.ground.text),
            ),
          );
        },
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.image, {required this.ink});

  final QrImage image;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final count = image.moduleCount + 2 * QrPicture.quietModules;
    // Whole device pixels per module would leave a ragged edge at odd sizes;
    // a module is a fraction of the side, the squares slightly overlapped so
    // no hairline shows between them.
    final module = size.width / count;
    final paint = Paint()
      ..color = ink
      ..isAntiAlias = false;
    for (var row = 0; row < image.moduleCount; row++) {
      for (var col = 0; col < image.moduleCount; col++) {
        if (!image.isDark(row, col)) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            (col + QrPicture.quietModules) * module,
            (row + QrPicture.quietModules) * module,
            module + 0.5,
            module + 0.5,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) => old.image != image || old.ink != ink;
}
