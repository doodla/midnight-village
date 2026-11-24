// The screen gallery: renders entries of the screen catalogue from the real
// widgets to PNG, next to their mocks. Run it with `just screens` (see
// frontend/CLAUDE.md); it is not part of `just test`.
//
// The catalogue is rendered in [screenShards] parts, one test file each
// (`screens_1of4_test.dart` ...), so `flutter test` can render them side by
// side: one screen takes two to four seconds and there are over two hundred.
// Every buildable entry is in exactly one part (`screens_shards_test.dart`
// proves it). `just screens` clears the output before the run and prints each
// part's summary after it.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'screen_catalogue.dart';
import 'screen_gallery.dart';

/// How many parts the catalogue is rendered in: one `screens_<n>of4_test.dart`
/// file per part.
const screenShards = 4;

/// `--dart-define=SCREENS_WIDTH=360` renders at another phone width.
const _width = int.fromEnvironment('SCREENS_WIDTH', defaultValue: 390);

/// `--dart-define=SCREENS_STRICT=true` fails each screen with findings.
const _strict = bool.fromEnvironment('SCREENS_STRICT');

/// The entries part [shard] (1 to [screenShards]) renders: every
/// [screenShards]th buildable entry, so the parts take about as long as each
/// other, and the entries that are not built yet (listed once, in part 1).
List<ScreenEntry> entriesOfShard(int shard) {
  final buildable = screenCatalogue.where((e) => e.build != null).toList();
  return [
    for (var i = 0; i < buildable.length; i++)
      if (i % screenShards == shard - 1) buildable[i],
    if (shard == 1) ...screenCatalogue.where((e) => e.build == null),
  ];
}

/// The `main` of part [shard]'s test file.
void runScreens(int shard) {
  final entries = entriesOfShard(shard);
  final results = <String, ScreenResult>{};

  tearDownAll(() {
    final summary = summarize(
      results,
      width: _width,
      strict: _strict,
      entries: entries,
    );
    File('${outputDir(_width)}/summary-${shard}of$screenShards.txt')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('$summary\n');
  });

  for (final entry in entries.where((e) => e.build != null)) {
    testWidgets(entry.id, (tester) async {
      final capture = await captureScreen(
        tester,
        entry.build!,
        width: _width,
        playerScreen: entry.playerScreen,
        frames: entry.frames,
        textScale: entry.textScale,
      );
      results[entry.id] = saveScreen(entry, capture, width: _width);
      // A screen that cannot be built always fails the run.
      if (capture.failure case final failure?) fail(failure);
      if (_strict) expect(capture.findings, isEmpty, reason: entry.id);
    });
  }
}
