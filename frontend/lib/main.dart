import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app.dart';
import 'core/web/start_done_stub.dart'
    if (dart.library.js_interop) 'core/web/start_done_web.dart';
import 'design_system/skin/card_back.dart';
import 'design_system/skin/ground.dart';
import 'design_system/skin/skin_id.dart';
import 'design_system/skin/system_bars.dart';
import 'design_system/skin_loader.dart';
import 'design_system/teach/learned_store.dart';
import 'features/game/presentation/table_screen.dart';
import 'features/lobby/presentation/last_seat.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // A table's link is `<origin>/join/<code>`, with no `#` (nothing changes on
  // other platforms). The web host serves the app for it (`vercel.json`).
  usePathUrlStrategy();
  // The screens run under the status and navigation bars, as the launch
  // screen does (android/app/src/main/res/values/styles.xml); each screen
  // sets the bars' icons for its ground (`systemBarsOver`).
  unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
  SystemChrome.setSystemUIOverlayStyle(
    systemBarsOver(SkinId.fallback.skin.ground(GroundKind.night)),
  );
  registerFontLicences();
  // The cues this device has learned, before the first frame, so it is right.
  await restoreLearned();
  // Whether this phone had gone on from the count, so a restart lands there.
  await restoreLocalSteps();
  runApp(const ProviderScope(child: App()));
  // 01's picture first, then the art secrets show, decoded long before the
  // first card is dealt. The card back of the game this device was last in
  // is decoded with them, so a restart in a game has it before the table is
  // even named. Then, on the web, the page may install what serves the next
  // visits from the cache.
  unawaited(
    SkinLoader()
        .prepare(
          SkinId.fallback.skin,
          back: CardBack.forGame(LastSeat.openingGame),
        )
        .whenComplete(webStartDone),
  );
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
