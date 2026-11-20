import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../test/helpers/test_fonts.dart';
import '../test/helpers/truncated_text.dart';
import 'reading_floor.dart';
import 'screen_catalogue.dart';

/// Phone height of the mocks, in logical pixels.
const screenHeight = 844.0;
const _pixelRatio = 2.0;
const _mocksDir = '../docs/design/mocks';

/// Frames drawn after an entry's build: 1 s in all, long enough for the screen
/// transitions and the role reveal (0.8 s), short of the reveal moving on by
/// itself (4 s). An animation needs frames to run, not one jump of the clock.
const _settleFrames = 10;
const _frameTime = Duration(milliseconds: 100);

/// What rendering one screen produced, before anything is written.
class ScreenCapture {
  ScreenCapture({required this.findings, this.png, this.failure});

  /// The screen as PNG bytes; null when it could not be built or captured.
  final Uint8List? png;

  /// Layout overflows and exceptions reported while it was on screen.
  final List<String> findings;

  /// Why there is no picture: the builder or the capture threw.
  final String? failure;
}

/// What the gallery wrote for one catalogue entry.
class ScreenResult {
  ScreenResult(this.capture, this.png);

  final ScreenCapture capture;

  /// The PNG written, or null when there is none.
  final String? png;
}

/// Where the PNGs for [width] go: `build/screens/` for the mocks' width,
/// `build/screens/w<width>/` for any other.
String outputDir(int width) =>
    width == 390 ? 'build/screens' : 'build/screens/w$width';

/// Removes the previous run's images for [width], so a renamed or removed
/// entry leaves nothing behind.
void clearOutput(int width) {
  final dir = Directory(outputDir(width));
  if (!dir.existsSync()) return;
  for (final file in dir.listSync()) {
    if (file is File && file.path.endsWith('.png')) file.deleteSync();
  }
  final compare = Directory('${dir.path}/compare');
  if (compare.existsSync()) compare.deleteSync(recursive: true);
}

/// Builds a screen with [build] at [width] x [screenHeight] and captures it.
/// Overflows and exceptions reported while it is on screen are collected, not
/// thrown, so one broken screen does not hide the others; a [build] (or the
/// capture) that throws gives no picture and a [ScreenCapture.failure]. On a
/// [playerScreen], text drawn below the reading floor is a finding too
/// (reading_floor.dart).
Future<ScreenCapture> captureScreen(
  WidgetTester tester,
  Future<void> Function(WidgetTester tester) build, {
  required int width,
  bool playerScreen = false,
}) async {
  tester.view.physicalSize = Size(
    width * _pixelRatio,
    screenHeight * _pixelRatio,
  );
  tester.view.devicePixelRatio = _pixelRatio;
  addTearDown(tester.view.reset);
  // The "DEBUG" ribbon is not part of the screen.
  WidgetsApp.debugAllowBannerOverride = false;
  addTearDown(() => WidgetsApp.debugAllowBannerOverride = true);

  final findings = <String>{};
  final reportError = FlutterError.onError;
  FlutterError.onError = (details) => findings.add(_describe(details));
  addTearDown(() => FlutterError.onError = reportError);

  // The old theme's fonts cannot load here (see test_fonts.dart), so every
  // pump happens inside quietRetiredFonts. The body must not throw: a future
  // failing inside that zone never reaches an await outside it, so each error
  // comes back as a value.
  final (png, failure) = await quietRetiredFonts(() async {
    try {
      await build(tester);
      for (var i = 0; i < _settleFrames; i++) {
        await tester.pump(_frameTime);
      }
      findings.addAll([
        for (final cut in truncatedText(tester)) 'cut short: $cut',
      ]);
      if (playerScreen) findings.addAll(readingFloorBreaches(tester));
    } catch (error, stack) {
      return (null, 'BUILD FAILED: ${_describeError(error, stack)}');
    }
    try {
      await _precacheImages(tester);
      return (await _capturePng(tester), null);
    } catch (error, stack) {
      return (null, 'CAPTURE FAILED: ${_describeError(error, stack)}');
    }
  });
  // Given back before the caller's expectations run: a test that fails with
  // the handler still replaced never ends.
  FlutterError.onError = reportError;
  return ScreenCapture(png: png, findings: findings.toList(), failure: failure);
}

/// Writes [capture] for [entry] (and, when the entry has a mock, the
/// side-by-side comparison). A capture without a picture writes nothing.
ScreenResult saveScreen(
  ScreenEntry entry,
  ScreenCapture capture, {
  required int width,
}) {
  final png = capture.png;
  if (png == null) return ScreenResult(capture, null);
  final dir = outputDir(width);
  final file = File('$dir/${entry.id}.png')
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(png);
  if (entry.mock case final mock?) {
    _writeComparison(
      mock: File('$_mocksDir/$mock'),
      app: png,
      to: File('$dir/compare/${entry.id}.png'),
    );
  }
  return ScreenResult(capture, file.path);
}

String _describeError(Object error, StackTrace stack) =>
    _describe(FlutterErrorDetails(exception: error, stack: stack));

/// One line: what happened, and where in lib/ when the report says.
String _describe(FlutterErrorDetails details) {
  final what = details.exceptionAsString().split('\n').first.trim();
  final where = RegExp(
    r'(?:package:midnight_village/|/frontend/lib/)([\w/]+\.dart:\d+)',
  ).firstMatch('$details\n${details.stack ?? ''}');
  return where == null ? what : '$what  (lib/${where.group(1)})';
}

/// Image providers load on real I/O, which the test clock never waits for:
/// load every image on screen for real, then draw again.
Future<void> _precacheImages(WidgetTester tester) async {
  final images = [
    for (final element in find.byType(Image).evaluate())
      ((element.widget as Image).image, element),
    for (final element in find.byType(DecoratedBox).evaluate())
      if ((element.widget as DecoratedBox).decoration case BoxDecoration(
        image: final image?,
      ))
        (image.image, element),
  ];
  if (images.isEmpty) return;
  await tester.runAsync(
    () => Future.wait([
      for (final (provider, context) in images)
        precacheImage(provider, context),
    ]),
  );
  await tester.pump();
}

/// The whole screen, overlays included, as PNG bytes at [_pixelRatio].
Future<Uint8List> _capturePng(WidgetTester tester) async {
  // toImage only completes outside the fake test clock.
  final png = await tester.runAsync(() async {
    final image = await captureImage(tester.binding.rootElement!);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return bytes!.buffer.asUint8List();
  });
  return png!;
}

/// The mock on the left, scaled to the app's height, and the app on the right.
void _writeComparison({
  required File mock,
  required Uint8List app,
  required File to,
}) {
  const gap = 24;
  final appImage = img.decodePng(app)!;
  final mockImage = img.copyResize(
    img.decodePng(mock.readAsBytesSync())!,
    height: appImage.height,
    interpolation: img.Interpolation.cubic,
  );
  final canvas = img.Image(
    width: mockImage.width + gap + appImage.width,
    height: appImage.height,
  )..clear(img.ColorRgb8(128, 128, 128));
  img.compositeImage(canvas, mockImage);
  img.compositeImage(canvas, appImage, dstX: mockImage.width + gap);
  to
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(img.encodePng(canvas));
}

/// The table printed at the end of a run: one line per entry, its findings
/// indented under it, then the totals.
String summarize(
  Map<String, ScreenResult> results, {
  required int width,
  required bool strict,
}) {
  final out = StringBuffer()
    ..writeln(
      'Screens at ${width}x${screenHeight.toInt()} '
      '(${strict ? 'strict' : 'findings reported, not failed'})',
    )
    ..writeln(
      'Fonts: Gloock, Figtree and the icons are the real ones; text in the '
      'old theme\'s fonts is drawn in Figtree stand-ins until the old look is '
      'removed (test/helpers/test_fonts.dart).',
    );
  final idWidth = screenCatalogue
      .map((e) => e.id.length)
      .reduce((a, b) => a > b ? a : b);
  var withFindings = 0;
  var notBuilt = 0;
  var failed = 0;
  for (final entry in screenCatalogue) {
    final id = entry.id.padRight(idWidth);
    final result = results[entry.id];
    if (entry.notBuilt case final why?) {
      notBuilt++;
      out.writeln('  $id  NOT BUILT: $why (mock ${entry.mock})');
      continue;
    }
    if (result == null) {
      failed++;
      out.writeln('  $id  DID NOT RENDER (see the test output above)');
      continue;
    }
    final capture = result.capture;
    if (capture.failure case final failure?) {
      failed++;
      out.writeln('  $id  $failure');
    } else {
      final status = capture.findings.isEmpty
          ? 'ok'
          : '${capture.findings.length} finding(s)';
      out.writeln('  $id  ${result.png}  $status');
    }
    if (capture.findings.isNotEmpty) withFindings++;
    for (final finding in capture.findings) {
      out.writeln('  ${' ' * idWidth}    ! $finding');
    }
  }
  final rendered = results.values.where((r) => r.png != null).length;
  out
    ..writeln(
      '$rendered rendered, $withFindings with findings, $notBuilt not built'
      '${failed > 0 ? ', $failed FAILED' : ''}.',
    )
    ..write('Side by side with the mocks: ${outputDir(width)}/compare/');
  return out.toString();
}
