import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/config/env.dart';

const _server = 'https://api.example.test';
const _page = 'https://app.example.test';

void main() {
  group('the REST base (Env.apiUrlFor)', () {
    test('the web build with API_SAME_ORIGIN calls its own page origin', () {
      expect(
        Env.apiUrlFor(
          web: true,
          sameOrigin: true,
          serverOrigin: _server,
          pageOrigin: _page,
        ),
        '$_page/api',
      );
    });

    test('the web build without the define calls the server, as before', () {
      expect(
        Env.apiUrlFor(
          web: true,
          sameOrigin: false,
          serverOrigin: _server,
          pageOrigin: _page,
        ),
        '$_server/api',
      );
    });

    test('Android ignores the define and calls the server', () {
      for (final sameOrigin in [true, false]) {
        expect(
          Env.apiUrlFor(
            web: false,
            sameOrigin: sameOrigin,
            serverOrigin: _server,
            pageOrigin: '',
          ),
          '$_server/api',
        );
      }
    });
  });

  test('the suite (dev, not web, no define) talks to the local server', () {
    expect(Env.apiUrl, 'http://localhost:8000/api');
    expect(Env.wsBaseUrl, 'ws://localhost:8000');
  });

  test('only the Vercel web build passes API_SAME_ORIGIN', () {
    const define = '--dart-define=API_SAME_ORIGIN=true';
    expect(
      File('tool/vercel_build.sh').readAsStringSync(),
      contains(define),
      reason: 'the web build on Vercel calls the API through its own origin',
    );
    expect(
      File('tool/build_android.sh').readAsStringSync(),
      isNot(contains('API_SAME_ORIGIN')),
      reason: 'Android has no page origin: it calls API_ORIGIN',
    );
    expect(
      File('tool/vercel_build.sh').readAsStringSync(),
      contains(r'--dart-define="API_ORIGIN=$API_ORIGIN"'),
      reason: 'the sockets still go to API_ORIGIN',
    );
  });

  test('vercel.json sends /api/ to the server before the app catch-all', () {
    final vercel =
        jsonDecode(File('vercel.json').readAsStringSync())
            as Map<String, dynamic>;
    final rewrites = (vercel['rewrites'] as List).cast<Map>();
    expect(rewrites.first, {
      'source': '/api/:path*',
      'destination': 'https://midnight-village-anthelion.vercel.app/api/:path*',
    });
    expect(rewrites.last['source'], '/(.*)');
    // Nothing the API answers (signed-in answers) is cached by Vercel.
    final headers = (vercel['headers'] as List).cast<Map>();
    expect(
      headers.any(
        (h) =>
            h['source'] == '/api/:path*' &&
            (h['headers'] as List).any(
              (x) =>
                  x['key'] == 'x-vercel-enable-rewrite-caching' &&
                  x['value'] == '0',
            ),
      ),
      isTrue,
    );
  });
}
