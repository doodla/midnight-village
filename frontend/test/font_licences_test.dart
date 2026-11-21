import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/main.dart';

void main() {
  test('the bundled fonts are listed with their OFL licence', () async {
    addTearDown(LicenseRegistry.reset);
    registerFontLicences();

    final licences = await LicenseRegistry.licenses.toList();

    const holders = {
      'Gloock': 'The Gloock Project Authors',
      'Figtree': 'The Figtree Project Authors',
    };
    for (final MapEntry(key: family, value: holder) in holders.entries) {
      final entry = licences.singleWhere((l) => l.packages.contains(family));
      final text = entry.paragraphs.map((p) => p.text).join('\n');
      expect(text, contains('SIL Open Font License, Version 1.1'));
      expect(text, contains(holder), reason: family);
    }
  });
}
