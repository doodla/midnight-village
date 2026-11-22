import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The web scanner's fallback decoder is the app's own file: pinned, with its
// licence, and the scanner is pointed at it, so no third-party request is made
// (tool/zxing_wasm.sh makes and checks web/zxing/).

const _wasmSum =
    '5003fb4b88c4fbd1fd518a2fd8c8ad365c519e183a08c03a322dddfea3cea84e';

void main() {
  test('the decoder is served from web/zxing with its licence', () {
    for (final file in [
      'zxing-wasm-reader.js',
      'zxing_reader.wasm',
      'LICENSE-zxing-wasm.txt',
    ]) {
      expect(File('web/zxing/$file').existsSync(), isTrue, reason: file);
    }
    expect(
      File('web/zxing/LICENSE-zxing-wasm.txt').readAsStringSync(),
      contains('MIT License'),
    );
  });

  test('the script looks for its .wasm beside itself, not on a CDN', () {
    final script = File('web/zxing/zxing-wasm-reader.js').readAsStringSync();
    expect(script, contains('setZXingModuleOverrides'));
    expect(script.trimRight(), endsWith('})();'));
    // The override is the last thing the file does.
    final tail = script.substring(script.lastIndexOf('/* Midnight Village'));
    expect(tail, contains('document.currentScript'));
    expect(tail, contains('new URL(file, here)'));
    expect(tail, isNot(contains('jsdelivr')));
  });

  test('the .wasm is the pinned file (needs sha256sum)', () {
    final ProcessResult result;
    try {
      result = Process.runSync('sha256sum', ['web/zxing/zxing_reader.wasm']);
    } on ProcessException {
      markTestSkipped('sha256sum is not installed here');
      return;
    }
    expect('${result.stdout}', startsWith(_wasmSum));
    expect(
      File('tool/zxing_wasm.sh').readAsStringSync(),
      contains('SUM_WASM="$_wasmSum"'),
    );
  });

  test('the web scanner is pointed at it', () {
    final scanner = File(
      'lib/features/lobby/presentation/scan/code_scanner.dart',
    ).readAsStringSync();
    expect(scanner, contains('setBarcodeLibraryScriptUrl'));
    final web = File(
      'lib/features/lobby/presentation/scan/own_decoder_web.dart',
    ).readAsStringSync();
    expect(web, contains("resolve('zxing/zxing-wasm-reader.js')"));
    // Resolved against the page's base, so /join/<code> finds it too.
    expect(web, contains('baseURI'));
  });
}
