import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/main.dart';

void main() {
  test('the bundled fonts are listed with their OFL licence', () async {
    addTearDown(LicenseRegistry.reset);
    registerFontLicences();

    final licences = await LicenseRegistry.licenses.toList();

    for (final family in ['Gloock', 'Figtree']) {
      final entry = licences.singleWhere((l) => l.packages.contains(family));
      final text = entry.paragraphs.map((p) => p.text).join('\n');
      expect(text, contains('SIL Open Font License, Version 1.1'));
      expect(text, contains('The $family Project Authors'));
    }
  });
}
