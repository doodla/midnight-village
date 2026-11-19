// Golden Diff Report Tool
//
// Processes Flutter golden test failure artifacts to produce:
// - Pixel-diff overlay images (magenta for changed pixels, dimmed for unchanged)
// - A self-contained HTML comparison report with base64-encoded thumbnails
//
// Usage:
//   dart run tool/golden_diff_report.dart [failuresDir [outputDir]] [--open]
//
// Flutter golden test failures are written to the `failures/` subdirectory of
// the comparator's basedir. The default scan path is `test/design_system/failures/`,
// matching the comparator set up in test/flutter_test_config.dart.
//
// Failure artifact naming convention (LocalFileComparator):
//   {key}_masterImage.png  – baseline (expected)
//   {key}_testImage.png    – actual render from failing test
//   {key}_isolatedDiff.png – Flutter's own diff (ignored; we generate our own)
//   {key}_maskedDiff.png   – Flutter's own masked diff (ignored)
//
// This tool only reads *_testImage.png + *_masterImage.png pairs and writes
// *_diff.png overlays plus golden_diff_report.html into outputDir.

import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

class FailurePair {
  const FailurePair({
    required this.testName,
    required this.masterFile,
    required this.testFile,
  });

  final String testName;
  final File masterFile;
  final File testFile;
}

class DiffResult {
  const DiffResult({
    required this.testName,
    required this.changedPixels,
    required this.totalPixels,
    required this.baselineBase64,
    required this.actualBase64,
    required this.diffBase64,
    this.errorMessage,
  });

  final String testName;
  final int changedPixels;
  final int totalPixels;
  final String baselineBase64;
  final String actualBase64;
  final String diffBase64;
  final String? errorMessage;

  double get changePercent =>
      totalPixels > 0 ? changedPixels / totalPixels * 100 : 0;
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

void main(List<String> args) {
  final positional = args.where((a) => !a.startsWith('--')).toList();
  final openAfter = args.contains('--open');

  final failuresDir = positional.isNotEmpty
      ? positional[0]
      : 'test/design_system/failures';
  final outputDir =
      positional.length > 1 ? positional[1] : 'test/golden_diff_report';

  final failures = scanForFailures(failuresDir);
  if (failures.isEmpty) {
    stdout.writeln('No golden test failures found in $failuresDir');
    exit(0);
  }

  stdout.writeln(
    'Found ${failures.length} golden test failure(s) in $failuresDir',
  );

  final results = <DiffResult>[];
  for (final pair in failures) {
    stdout.write('  Processing ${pair.testName}... ');
    final result = processPair(pair, outputDir);
    results.add(result);
    if (result.errorMessage != null) {
      stdout.writeln('ERROR: ${result.errorMessage}');
    } else {
      stdout.writeln('${result.changedPixels} pixel(s) changed '
          '(${result.changePercent.toStringAsFixed(2)}%)');
    }
  }

  generateReport(results, outputDir);
  final reportPath = '$outputDir/golden_diff_report.html';
  stdout.writeln('\nReport generated: $reportPath');

  if (openAfter) {
    Process.run('open', [reportPath]);
  }
}

// ---------------------------------------------------------------------------
// Scan for failure pairs
// ---------------------------------------------------------------------------

/// Scans [dir] for `*_testImage.png` files, then looks for a matching
/// `*_masterImage.png` in the same directory.
List<FailurePair> scanForFailures(String dirPath) {
  final dir = Directory(dirPath);
  if (!dir.existsSync()) {
    return [];
  }

  final pairs = <FailurePair>[];

  for (final entity in dir.listSync()) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.last;
    if (!name.endsWith('_testImage.png')) continue;

    final key = name.substring(0, name.length - '_testImage.png'.length);
    final masterFile = File('$dirPath/${key}_masterImage.png');
    if (!masterFile.existsSync()) {
      stderr.writeln(
        'Warning: found $name but no ${key}_masterImage.png – skipping',
      );
      continue;
    }

    pairs.add(FailurePair(
      testName: key.replaceAll('_', ' '),
      masterFile: masterFile,
      testFile: entity,
    ));
  }

  return pairs;
}

// ---------------------------------------------------------------------------
// Pixel diff processing
// ---------------------------------------------------------------------------

/// Reads [pair], generates a magenta diff overlay, saves it to [outputDir],
/// and returns a [DiffResult] with base64-encoded image data.
DiffResult processPair(FailurePair pair, String outputDir) {
  Directory(outputDir).createSync(recursive: true);

  try {
    final masterBytes = pair.masterFile.readAsBytesSync();
    final testBytes = pair.testFile.readAsBytesSync();

    final masterImage = img.decodeImage(masterBytes);
    final testImage = img.decodeImage(testBytes);

    if (masterImage == null) {
      return _errorResult(pair, 'Failed to decode master image');
    }
    if (testImage == null) {
      return _errorResult(pair, 'Failed to decode test image');
    }

    final diffImage = generateDiffOverlay(masterImage, testImage);
    final changedPixels = countChangedPixels(masterImage, testImage);
    final totalPixels = masterImage.width * masterImage.height;

    // Save diff image alongside the source files.
    final keyRaw = pair.masterFile.uri.pathSegments.last
        .replaceAll('_masterImage.png', '');
    final diffPath = '$outputDir/${keyRaw}_diff.png';
    File(diffPath).writeAsBytesSync(img.encodePng(diffImage));

    return DiffResult(
      testName: pair.testName,
      changedPixels: changedPixels,
      totalPixels: totalPixels,
      baselineBase64: base64Encode(masterBytes),
      actualBase64: base64Encode(testBytes),
      diffBase64: base64Encode(img.encodePng(diffImage)),
    );
  } on Exception catch (e) {
    return _errorResult(pair, e.toString());
  }
}

DiffResult _errorResult(FailurePair pair, String message) => DiffResult(
      testName: pair.testName,
      changedPixels: 0,
      totalPixels: 0,
      baselineBase64: '',
      actualBase64: '',
      diffBase64: '',
      errorMessage: message,
    );

// ---------------------------------------------------------------------------
// Diff overlay generation (T028)
// ---------------------------------------------------------------------------

/// Returns a new image where:
/// - Unchanged pixels are dimmed to 50% brightness.
/// - Changed pixels are highlighted in solid magenta (255, 0, 255).
///
/// If the images have different sizes, the overlay is cropped to the
/// intersection; pixels outside the smaller dimension are always marked
/// as changed (magenta).
img.Image generateDiffOverlay(img.Image baseline, img.Image actual) {
  final width =
      baseline.width > actual.width ? baseline.width : actual.width;
  final height =
      baseline.height > actual.height ? baseline.height : actual.height;

  final diff = img.Image(width: width, height: height);

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final inBaseline = x < baseline.width && y < baseline.height;
      final inActual = x < actual.width && y < actual.height;

      if (!inBaseline || !inActual) {
        // Pixel exists in only one image – mark as changed.
        diff.setPixel(x, y, img.ColorRgba8(255, 0, 255, 255));
        continue;
      }

      final basePixel = baseline.getPixel(x, y);
      final actualPixel = actual.getPixel(x, y);

      final same = basePixel.r == actualPixel.r &&
          basePixel.g == actualPixel.g &&
          basePixel.b == actualPixel.b &&
          basePixel.a == actualPixel.a;

      if (same) {
        // Unchanged: dim to ~50% brightness.
        diff.setPixel(
          x,
          y,
          img.ColorRgba8(
            (basePixel.r / 2).round(),
            (basePixel.g / 2).round(),
            (basePixel.b / 2).round(),
            128,
          ),
        );
      } else {
        // Changed: solid magenta.
        diff.setPixel(x, y, img.ColorRgba8(255, 0, 255, 255));
      }
    }
  }

  return diff;
}

/// Counts the number of pixels that differ between [baseline] and [actual].
/// Pixels outside the intersection of the two images count as changed.
int countChangedPixels(img.Image baseline, img.Image actual) {
  if (baseline.width != actual.width || baseline.height != actual.height) {
    // Size mismatch: count everything outside the intersection as changed.
    final intersectW =
        baseline.width < actual.width ? baseline.width : actual.width;
    final intersectH =
        baseline.height < actual.height ? baseline.height : actual.height;
    final outsideCount = (baseline.width * baseline.height) -
        (intersectW * intersectH) +
        (actual.width * actual.height) -
        (intersectW * intersectH);

    var changed = outsideCount;
    for (var y = 0; y < intersectH; y++) {
      for (var x = 0; x < intersectW; x++) {
        final bp = baseline.getPixel(x, y);
        final ap = actual.getPixel(x, y);
        if (bp.r != ap.r || bp.g != ap.g || bp.b != ap.b || bp.a != ap.a) {
          changed++;
        }
      }
    }
    return changed;
  }

  var changed = 0;
  for (var y = 0; y < baseline.height; y++) {
    for (var x = 0; x < baseline.width; x++) {
      final bp = baseline.getPixel(x, y);
      final ap = actual.getPixel(x, y);
      if (bp.r != ap.r || bp.g != ap.g || bp.b != ap.b || bp.a != ap.a) {
        changed++;
      }
    }
  }
  return changed;
}

// ---------------------------------------------------------------------------
// HTML report generation (T029)
// ---------------------------------------------------------------------------

/// Writes a self-contained HTML report to [outputDir]/golden_diff_report.html.
/// All images are base64-encoded inline so the file is portable (no external
/// file references) and suitable as a CI artifact.
void generateReport(List<DiffResult> results, String outputDir) {
  final timestamp = DateTime.now().toIso8601String();
  final failureCount = results.length;
  final errorCount = results.where((r) => r.errorMessage != null).length;

  final buffer = StringBuffer();
  buffer.writeln('<!DOCTYPE html>');
  buffer.writeln('<html lang="en">');
  buffer.writeln('<head>');
  buffer.writeln('<meta charset="UTF-8">');
  buffer.writeln(
    '<meta name="viewport" content="width=device-width, initial-scale=1.0">',
  );
  buffer.writeln('<title>Golden Diff Report</title>');
  buffer.writeln('<style>');
  buffer.writeln(_css());
  buffer.writeln('</style>');
  buffer.writeln('</head>');
  buffer.writeln('<body>');

  // Header
  buffer.writeln('<div class="header">');
  buffer.writeln('<h1>Golden Test Diff Report</h1>');
  buffer.writeln('<div class="meta">');
  buffer.writeln('<span class="badge failure">$failureCount failure(s)</span>');
  if (errorCount > 0) {
    buffer.writeln('<span class="badge error">$errorCount error(s)</span>');
  }
  buffer.writeln('<span class="timestamp">Generated: $timestamp</span>');
  buffer.writeln('</div>');
  buffer.writeln('</div>');

  // Summary table
  buffer.writeln('<table class="summary">');
  buffer.writeln('<thead>');
  buffer.writeln(
    '<tr><th>Test</th><th>Changed Pixels</th><th>% Changed</th><th>Status</th></tr>',
  );
  buffer.writeln('</thead>');
  buffer.writeln('<tbody>');
  for (final result in results) {
    final status =
        result.errorMessage != null ? 'ERROR' : '${result.changedPixels} px';
    final pct = result.errorMessage != null
        ? '—'
        : '${result.changePercent.toStringAsFixed(2)}%';
    final rowClass = result.errorMessage != null ? 'row-error' : 'row-fail';
    buffer.writeln('<tr class="$rowClass">');
    buffer.writeln('<td><a href="#${_anchor(result.testName)}">'
        '${_escape(result.testName)}</a></td>');
    buffer.writeln('<td>$status</td>');
    buffer.writeln('<td>$pct</td>');
    buffer.writeln('<td>${result.errorMessage != null ? "Error" : "Mismatch"}'
        '</td>');
    buffer.writeln('</tr>');
  }
  buffer.writeln('</tbody>');
  buffer.writeln('</table>');

  // Per-failure sections
  for (final result in results) {
    final anchor = _anchor(result.testName);
    buffer.writeln('<div class="failure-section" id="$anchor">');
    buffer.writeln('<h2>${_escape(result.testName)}</h2>');

    if (result.errorMessage != null) {
      buffer.writeln('<p class="error-msg">Error: '
          '${_escape(result.errorMessage!)}</p>');
      buffer.writeln('</div>');
      continue;
    }

    buffer.writeln('<p class="stats">'
        '${result.changedPixels} pixel(s) changed '
        '(${result.changePercent.toStringAsFixed(2)}% of '
        '${result.totalPixels} total)</p>');

    buffer.writeln('<div class="comparison">');
    _writeImagePanel(buffer, result.baselineBase64, 'Baseline (expected)');
    _writeImagePanel(buffer, result.actualBase64, 'Actual (test output)');
    _writeImagePanel(
      buffer,
      result.diffBase64,
      'Diff (magenta = changed)',
    );
    buffer.writeln('</div>');

    buffer.writeln('</div>');
  }

  buffer.writeln('</body>');
  buffer.writeln('</html>');

  Directory(outputDir).createSync(recursive: true);
  File('$outputDir/golden_diff_report.html')
      .writeAsStringSync(buffer.toString());
}

void _writeImagePanel(StringBuffer buf, String base64Data, String label) {
  buf.writeln('<div class="image-panel">');
  buf.writeln('<p class="image-label">$label</p>');
  if (base64Data.isEmpty) {
    buf.writeln('<p class="no-image">Image unavailable</p>');
  } else {
    // Clicking the thumbnail opens the full-size image.
    buf.writeln(
      '<a href="data:image/png;base64,$base64Data" target="_blank">',
    );
    buf.writeln(
      '<img src="data:image/png;base64,$base64Data" '
      'alt="$label" class="thumbnail">',
    );
    buf.writeln('</a>');
    buf.writeln('<p class="hint">Click to expand</p>');
  }
  buf.writeln('</div>');
}

String _anchor(String testName) =>
    testName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-');

String _escape(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

// ---------------------------------------------------------------------------
// Inline CSS
// ---------------------------------------------------------------------------

String _css() => '''
  * { box-sizing: border-box; margin: 0; padding: 0; }

  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    background: #1a1a2e;
    color: #e0e0e0;
    padding: 24px;
    line-height: 1.5;
  }

  .header {
    margin-bottom: 32px;
  }

  h1 {
    font-size: 28px;
    color: #ffffff;
    margin-bottom: 8px;
  }

  h2 {
    font-size: 20px;
    color: #c0a0ff;
    margin-bottom: 8px;
  }

  .meta {
    display: flex;
    align-items: center;
    gap: 12px;
    flex-wrap: wrap;
  }

  .badge {
    padding: 4px 10px;
    border-radius: 12px;
    font-size: 13px;
    font-weight: 600;
  }

  .badge.failure { background: #8b0000; color: #ffcccc; }
  .badge.error   { background: #5a3000; color: #ffddaa; }

  .timestamp {
    font-size: 13px;
    color: #888;
  }

  .summary {
    width: 100%;
    border-collapse: collapse;
    margin-bottom: 40px;
    font-size: 14px;
  }

  .summary th {
    background: #16213e;
    padding: 10px 14px;
    text-align: left;
    color: #aaa;
    border-bottom: 1px solid #333;
  }

  .summary td {
    padding: 10px 14px;
    border-bottom: 1px solid #2a2a3e;
  }

  .summary tr:hover td { background: #1e1e3a; }

  .summary a { color: #9090ff; text-decoration: none; }
  .summary a:hover { text-decoration: underline; }

  .row-error td { color: #ffaa66; }

  .failure-section {
    background: #16213e;
    border: 1px solid #2a2a4a;
    border-radius: 8px;
    padding: 24px;
    margin-bottom: 32px;
  }

  .stats {
    font-size: 13px;
    color: #aaa;
    margin-bottom: 16px;
  }

  .error-msg {
    color: #ffaa66;
    font-size: 14px;
  }

  .comparison {
    display: flex;
    gap: 16px;
    flex-wrap: wrap;
  }

  .image-panel {
    flex: 1 1 200px;
    min-width: 160px;
  }

  .image-label {
    font-size: 12px;
    color: #888;
    margin-bottom: 8px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .thumbnail {
    width: 100%;
    height: auto;
    display: block;
    border: 1px solid #333;
    border-radius: 4px;
    cursor: pointer;
    transition: opacity 0.15s;
  }

  .thumbnail:hover { opacity: 0.85; }

  .hint {
    font-size: 11px;
    color: #666;
    margin-top: 4px;
    text-align: center;
  }

  .no-image {
    font-size: 13px;
    color: #666;
    padding: 16px 0;
  }
''';
