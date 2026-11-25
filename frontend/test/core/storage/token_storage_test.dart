import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/storage/token_storage.dart';
import 'package:mocktail/mocktail.dart';

/// The platform's secure storage, as a map: counts its reads, and can be
/// made to fail a write or to hold its answers.
class _Device extends Mock implements FlutterSecureStorage {
  _Device([Map<String, String>? saved]) {
    if (saved != null) values.addAll(saved);
    when(() => read(key: any(named: 'key'))).thenAnswer((i) async {
      reads++;
      // What storage held when asked, answered when [hold] lets it.
      final value = values[i.namedArguments[#key] as String];
      final held = hold;
      if (held != null) await held.future;
      return value;
    });
    when(
      () => write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((i) async {
      final key = i.namedArguments[#key] as String;
      if (failWrites.contains(key)) throw StateError('storage full');
      values[key] = i.namedArguments[#value] as String;
    });
    when(() => delete(key: any(named: 'key'))).thenAnswer((i) async {
      values.remove(i.namedArguments[#key]);
    });
  }

  final values = <String, String>{};
  final failWrites = <String>{};
  var reads = 0;

  /// While set, reads answer only when it completes.
  Completer<void>? hold;
}

const _saved = {'access_token': 'access-1', 'refresh_token': 'refresh-1'};

void main() {
  group('TokenStorage', () {
    test('reads storage once; then every reader gets memory', () async {
      final device = _Device(_saved);
      final tokens = TokenStorage(storage: device);

      expect(tokens.held, isNull);
      expect(await tokens.hasTokens, isTrue);
      expect(await tokens.accessToken, 'access-1');
      expect(await tokens.refreshToken, 'refresh-1');
      expect(tokens.held, (access: 'access-1', refresh: 'refresh-1'));
      expect(device.reads, 2, reason: 'one read of each key, at start');
    });

    test('readers at start share the one read', () async {
      final device = _Device(_saved)..hold = Completer<void>();
      final tokens = TokenStorage(storage: device);

      final a = tokens.accessToken;
      final b = tokens.refreshToken;
      final c = tokens.hasTokens;
      device.hold!.complete();
      device.hold = null;

      expect(await a, 'access-1');
      expect(await b, 'refresh-1');
      expect(await c, isTrue);
      expect(device.reads, 2);
    });

    test('nothing saved: held says so (no tokens, no wait)', () async {
      final tokens = TokenStorage(storage: _Device());

      expect(await tokens.hasTokens, isFalse);
      expect(tokens.held, (access: null, refresh: null));
    });

    test('an empty token is no session', () async {
      final tokens = TokenStorage(
        storage: _Device({'access_token': '', 'refresh_token': 'refresh-1'}),
      );

      expect(await tokens.hasTokens, isFalse);
    });

    test('a save is in memory at once, before storage has it', () async {
      final device = _Device(_saved);
      final tokens = TokenStorage(storage: device);
      await tokens.accessToken;

      final saving = tokens.saveTokens(
        accessToken: 'access-2',
        refreshToken: 'refresh-2',
      );
      // A refresh's rotated token is the next one sent.
      expect(tokens.held, (access: 'access-2', refresh: 'refresh-2'));
      await saving;

      expect(device.values, {
        'access_token': 'access-2',
        'refresh_token': 'refresh-2',
      });
      expect(device.reads, 2, reason: 'a save is not read back');
    });

    test('a save before any read needs no read', () async {
      final device = _Device();
      final tokens = TokenStorage(storage: device);

      await tokens.saveTokens(accessToken: 'a', refreshToken: 'r');

      expect(await tokens.accessToken, 'a');
      expect(device.reads, 0);
    });

    test('a save wins over a read that was under way', () async {
      final device = _Device(_saved)..hold = Completer<void>();
      final tokens = TokenStorage(storage: device);

      final reading = tokens.accessToken;
      await tokens.saveTokens(accessToken: 'new', refreshToken: 'newer');
      device.hold!.complete();

      expect(await reading, 'new');
      expect(tokens.held, (access: 'new', refresh: 'newer'));
    });

    test('a failed first write leaves memory to be read again', () async {
      final device = _Device(_saved)..failWrites.add('access_token');
      final tokens = TokenStorage(storage: device);
      await tokens.accessToken;

      await expectLater(
        tokens.saveTokens(accessToken: 'a', refreshToken: 'r'),
        throwsStateError,
      );

      expect(tokens.held, isNull);
      expect(await tokens.accessToken, 'access-1');
      verifyNever(() => device.write(key: 'refresh_token', value: 'r'));
    });

    test('a failed second write rolls the first back, memory too', () async {
      final device = _Device(_saved)..failWrites.add('refresh_token');
      final tokens = TokenStorage(storage: device);

      await expectLater(
        tokens.saveTokens(accessToken: 'a', refreshToken: 'r'),
        throwsStateError,
      );

      verify(() => device.delete(key: 'access_token')).called(1);
      expect(await tokens.accessToken, isNull);
      expect(await tokens.refreshToken, 'refresh-1');
      expect(await tokens.hasTokens, isFalse);
    });

    test('delete: gone from memory at once and from storage', () async {
      final device = _Device(_saved);
      final tokens = TokenStorage(storage: device);
      await tokens.accessToken;

      final deleting = tokens.deleteTokens();
      expect(tokens.held, (access: null, refresh: null));
      await deleting;

      expect(device.values, isEmpty);
      expect(await tokens.hasTokens, isFalse);
    });

    test('a failed read is tried again by the next reader', () async {
      final device = _Device(_saved);
      var fail = true;
      when(() => device.read(key: any(named: 'key'))).thenAnswer((i) async {
        if (fail) throw StateError('locked');
        return device.values[i.namedArguments[#key]];
      });
      final tokens = TokenStorage(storage: device);

      await expectLater(tokens.accessToken, throwsStateError);
      fail = false;

      expect(await tokens.accessToken, 'access-1');
    });

    group('another tab', () {
      test('its change is read back into memory', () async {
        final device = _Device(_saved);
        final otherTab = StreamController<void>();
        final tokens = TokenStorage(
          storage: device,
          otherTabWrites: otherTab.stream,
        );
        await tokens.accessToken;

        // The other tab made a new guest: storage holds its tokens.
        device.values
          ..['access_token'] = 'theirs'
          ..['refresh_token'] = 'their-refresh';
        otherTab.add(null);
        // Until the read back is done, this tab sends what it held.
        await Future<void>.delayed(Duration.zero);
        await pumpEventQueue();

        expect(tokens.held, (access: 'theirs', refresh: 'their-refresh'));
        await tokens.dispose();
      });

      test('a change made here meanwhile wins over the read back', () async {
        final device = _Device(_saved);
        final otherTab = StreamController<void>();
        final tokens = TokenStorage(
          storage: device,
          otherTabWrites: otherTab.stream,
        );
        await tokens.accessToken;

        device.hold = Completer<void>();
        otherTab.add(null);
        await pumpEventQueue();
        // Held while the read back waits.
        expect(tokens.held, (access: 'access-1', refresh: 'refresh-1'));
        await tokens.saveTokens(accessToken: 'mine', refreshToken: 'mine-r');
        device.hold!.complete();
        await pumpEventQueue();

        expect(tokens.held, (access: 'mine', refresh: 'mine-r'));
        await tokens.dispose();
      });
    });
  });
}
