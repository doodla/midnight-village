import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicences();
  runApp(const ProviderScope(child: App()));
}

/// The bundled fonts and their OFL licence texts (assets/fonts/).
const _fontLicences = [
  ('Gloock', 'assets/fonts/gloock/OFL.txt'),
  ('Figtree', 'assets/fonts/figtree/OFL.txt'),
];

/// Lists the bundled fonts' licences on the app's licences page, as the SIL
/// Open Font License requires when the fonts ship with the app.
void registerFontLicences() {
  LicenseRegistry.addLicense(() async* {
    for (final (family, asset) in _fontLicences) {
      yield LicenseEntryWithLineBreaks([
        family,
      ], await rootBundle.loadString(asset));
    }
  });
}
