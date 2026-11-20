import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'design_system/skin/skin_id.dart';
import 'design_system/skin_loader.dart';
import 'design_system/teach/learned_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicences();
  // The cues this device has learned, before the first frame, so it is right.
  await restoreLearned();
  runApp(const ProviderScope(child: App()));
  // The art secrets show, decoded long before the first card is dealt.
  unawaited(SkinLoader().prepare(SkinId.fallback.skin));
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
