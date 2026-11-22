import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The Android release: signed with the public key, opening table links in the
// app, and never built without the web app's address. (A real build is checked
// by `flutter build apk`, which this machine's CI does not run: these read the
// files that make it.)

String _read(String path) => File(path).readAsStringSync();

void main() {
  final gradle = _read('android/app/build.gradle.kts');
  final manifest = _read('android/app/src/main/AndroidManifest.xml');
  final props = {
    for (final line in _read('android/release-key/key.properties').split('\n'))
      if (line.contains('='))
        line.split('=').first: line.substring(line.indexOf('=') + 1),
  };

  group('signing', () {
    test('a release build is signed with the committed key, not the debug '
        'key', () {
      expect(gradle, contains('signingConfigs.getByName("release")'));
      expect(gradle, isNot(contains('signingConfigs.getByName("debug")')));
      expect(
        File('android/release-key/${props['storeFile']}').existsSync(),
        isTrue,
      );
    });

    test('the key is public, and says so beside it', () {
      final readme = _read('android/release-key/README.md');
      expect(readme, contains('PUBLIC'));
      expect(readme, contains('22 November 2026'));
      expect(readme.toLowerCase(), contains('before any store release'));
      expect(readme, contains('uninstalls once'));
    });

    test('the folder is not ignored (it is committed on purpose)', () {
      final ignore = _read('android/.gitignore');
      expect(ignore, contains('!release-key/key.properties'));
      expect(ignore, contains('!release-key/*.jks'));
    });
  });

  group('App Links', () {
    test('the app id is the one on phones', () {
      expect(
        gradle,
        contains('applicationId = "com.midnightvillage.midnight_village"'),
      );
    });

    test('table links open the app: VIEW, BROWSABLE, verified, /join/ on the '
        "build's public host", () {
      expect(manifest, contains('android:autoVerify="true"'));
      expect(manifest, contains('android.intent.action.VIEW'));
      expect(manifest, contains('android.intent.category.BROWSABLE'));
      expect(manifest, contains('android:scheme="https"'));
      expect(manifest, contains(r'android:host="${publicHost}"'));
      expect(manifest, contains('android:pathPrefix="/join/"'));
      // The host is the build's PUBLIC_ORIGIN, never a guess written here.
      expect(gradle, contains('manifestPlaceholders["publicHost"]'));
      expect(manifest, isNot(contains('vercel.app')));
    });

    test('the web app serves assetlinks.json for this app and this key', () {
      final links =
          jsonDecode(_read('web/.well-known/assetlinks.json')) as List;
      final target = (links.single as Map)['target'] as Map;
      expect(target['namespace'], 'android_app');
      expect(target['package_name'], 'com.midnightvillage.midnight_village');
      expect(
        (links.single as Map)['relation'],
        contains('delegate_permission/common.handle_all_urls'),
      );
      expect(target['sha256_cert_fingerprints'], hasLength(1));
    });

    test("assetlinks.json carries the committed key's SHA-256 "
        '(needs keytool)', () {
      final links =
          jsonDecode(_read('web/.well-known/assetlinks.json')) as List;
      final fingerprint =
          (((links.single as Map)['target'] as Map)['sha256_cert_fingerprints']
                  as List)
              .single;
      final ProcessResult listed;
      try {
        listed = Process.runSync('keytool', [
          '-list',
          '-v',
          '-keystore',
          'android/release-key/${props['storeFile']}',
          '-storepass',
          props['storePassword']!,
          '-alias',
          props['keyAlias']!,
        ]);
      } on ProcessException {
        markTestSkipped('keytool is not installed here');
        return;
      }
      expect(listed.exitCode, 0, reason: '${listed.stderr}');
      expect(
        RegExp('SHA256: ([0-9A-F:]+)').firstMatch('${listed.stdout}')!.group(1),
        fingerprint,
      );
    });

    test('the web host serves it as JSON, past the app rewrite', () {
      final vercel = jsonDecode(_read('vercel.json')) as Map;
      final headers = (vercel['headers'] as List).cast<Map>();
      expect(
        headers.any(
          (h) =>
              h['source'] == '/.well-known/assetlinks.json' &&
              (h['headers'] as List).any(
                (x) =>
                    x['key'] == 'Content-Type' &&
                    x['value'] == 'application/json',
              ),
        ),
        isTrue,
      );
      // /join/<code> reaches the app through the one rewrite to index.html.
      expect(vercel['rewrites'], [
        {'source': '/(.*)', 'destination': '/index.html'},
      ]);
    });
  });

  group('a release build needs the public origin', () {
    ProcessResult run(Map<String, String> env) => Process.runSync(
      'bash',
      ['tool/build_android.sh'],
      environment: {'CHECK_ONLY': '1', ...env},
      includeParentEnvironment: false,
    );

    test(
      'the build script stops without PUBLIC_ORIGIN, saying what to pass',
      () {
        final result = run({'API_ORIGIN': 'https://api.example'});
        expect(result.exitCode, isNot(0));
        expect('${result.stderr}', contains('PUBLIC_ORIGIN'));
        expect('${result.stderr}', contains('https://'));
      },
    );

    test('and without API_ORIGIN', () {
      final result = run({'PUBLIC_ORIGIN': 'https://app.example'});
      expect(result.exitCode, isNot(0));
      expect('${result.stderr}', contains('API_ORIGIN'));
    });

    test('and with an origin Android would not verify', () {
      final result = run({
        'API_ORIGIN': 'https://api.example',
        'PUBLIC_ORIGIN': 'http://app.example',
      });
      expect(result.exitCode, isNot(0));
      expect('${result.stderr}', contains('https'));
    });

    test('and with an origin that has a path, a query or a fragment (the '
        "manifest's /join/ prefix would not match the app's own links)", () {
      for (final origin in [
        'https://app.example/play',
        'https://app.example/play/',
        'https://app.example/?x=1',
        'https://app.example/#top',
      ]) {
        final result = run({
          'API_ORIGIN': 'https://api.example',
          'PUBLIC_ORIGIN': origin,
        });
        expect(result.exitCode, isNot(0), reason: origin);
        expect('${result.stderr}', contains('PUBLIC_ORIGIN'), reason: origin);
      }
    });

    test('and goes on with both (a trailing slash is still an origin)', () {
      final result = run({
        'API_ORIGIN': 'https://api.example',
        'PUBLIC_ORIGIN': 'https://app.example/',
      });
      expect(result.exitCode, 0, reason: '${result.stderr}');
    });

    test('and goes on with both', () {
      final result = run({
        'API_ORIGIN': 'https://api.example',
        'PUBLIC_ORIGIN': 'https://app.example',
      });
      expect(result.exitCode, 0, reason: '${result.stderr}');
    });

    test('gradle stops a release task with no https PUBLIC_ORIGIN, in words, '
        'and a debug build is untouched', () {
      expect(gradle, contains('it.name.contains("Release")'));
      expect(gradle, contains('--dart-define=PUBLIC_ORIGIN=https://'));
      expect(gradle, contains('throw GradleException'));
      expect(gradle, contains('rawPath'));
      expect(
        File('tool/build_android.sh').readAsStringSync(),
        contains('--split-per-abi'),
      );
      // Only a release task throws: the check is the one `releasing` guards.
      expect(gradle, contains('if (releasing && publicHost == null)'));
    });
  });
}
