import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../logging/app_logger.dart';
import 'other_tab_writes.dart';

/// The session's two tokens as this app holds them.
typedef HeldTokens = ({String? access, String? refresh});

/// The session's JWT tokens: kept in memory, and in the platform's secure
/// storage (Keychain on iOS, EncryptedSharedPreferences on Android, WebCrypto
/// over localStorage on the web) so they outlive the app.
///
/// Storage is read once, on the first read of a token (the saved session
/// read back at start), and written through on every change: from then on
/// every reader (a request's `Authorization`, the socket's connect, a
/// refresh) gets the value in memory, and [held] gives it without waiting,
/// so a tap's request leaves the phone in the tap's own task. (On the web a
/// read of secure storage is WebCrypto, whose answers come in later tasks,
/// behind the app's frames: a request that waited for it left 0.4 to 1.6 s
/// after the finger.)
///
/// A change made here is in memory at once (a token a refresh rotated is the
/// next one sent) and then in storage; a write that fails leaves memory to
/// be read again from storage, so the two never disagree for long.
///
/// Two tabs of one browser share one saved session, as they always have: a
/// change another tab writes ([otherTabWrites]: the browser's `storage`
/// event) is read back into this tab's memory, and until that read is done
/// this tab sends what it held. A change in this tab wins over a read back
/// that was under way.
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage, Stream<void>? otherTabWrites})
    : _storage = storage ?? const FlutterSecureStorage() {
    _otherTab = (otherTabWrites ?? secureStorageWritesInOtherTabs()).listen(
      (_) => _readBack(),
    );
  }

  final FlutterSecureStorage _storage;
  late final StreamSubscription<void> _otherTab;

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  /// The tokens in memory; null until storage has been read.
  HeldTokens? _held;

  /// The read of storage under way.
  Future<HeldTokens>? _reading;

  /// Moves on with every change made here and every read back started, so
  /// a read that began before it does not overwrite it.
  var _version = 0;

  /// The tokens, without waiting: null only before storage has been read
  /// once (then [accessToken] and [refreshToken] read it).
  HeldTokens? get held => _held;

  Future<String?> get accessToken async => (await _tokens()).access;

  Future<String?> get refreshToken async => (await _tokens()).refresh;

  /// True when both tokens are present and non-empty: a complete pair for
  /// the refresh flow (an access token alone is not a session).
  Future<bool> get hasTokens async {
    final tokens = await _tokens();
    return (tokens.access?.isNotEmpty ?? false) &&
        (tokens.refresh?.isNotEmpty ?? false);
  }

  Future<HeldTokens> _tokens() {
    final held = _held;
    if (held != null) return Future.value(held);
    return _reading ??= _read();
  }

  /// Reads storage into memory (unless a change made here meanwhile is
  /// newer). A failed read is tried again by the next reader.
  Future<HeldTokens> _read() async {
    final version = _version;
    try {
      final values = await Future.wait([
        _storage.read(key: _accessTokenKey),
        _storage.read(key: _refreshTokenKey),
      ]);
      final read = (access: values[0], refresh: values[1]);
      if (version == _version) {
        _held = read;
        logger.d(
          'TokenStorage: read from storage (access '
          '${read.access != null ? "present" : "absent"}, refresh '
          '${read.refresh != null ? "present" : "absent"})',
        );
      }
      return _held ?? read;
    } finally {
      _reading = null;
    }
  }

  /// Another tab changed the saved session: read it back.
  void _readBack() {
    if (_held == null && _reading != null) return;
    _version++;
    _reading = _read();
    unawaited(
      _reading!.then<void>(
        (_) {},
        onError: (Object e) =>
            logger.w('TokenStorage: reading another tab\'s change failed: $e'),
      ),
    );
  }

  /// Memory no longer says what storage holds: read it again when asked.
  void _forget() {
    _version++;
    _held = null;
    _reading = null;
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    logger.d('TokenStorage.saveTokens');
    _version++;
    _held = (access: accessToken, refresh: refreshToken);
    try {
      await _storage.write(key: _accessTokenKey, value: accessToken);
    } catch (e, stack) {
      logger.e('Failed to save access token', error: e, stackTrace: stack);
      _forget();
      rethrow;
    }
    try {
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    } catch (e) {
      _forget();
      // Rollback the first write, but don't mask the original error
      try {
        await _storage.delete(key: _accessTokenKey);
      } catch (rollbackError) {
        logger.w('Rollback failed during saveTokens: $rollbackError');
      }
      rethrow;
    }
  }

  Future<void> deleteTokens() async {
    _version++;
    _held = (access: null, refresh: null);
    try {
      await Future.wait([
        _storage.delete(key: _accessTokenKey),
        _storage.delete(key: _refreshTokenKey),
      ]);
    } catch (_) {
      _forget();
      rethrow;
    }
    logger.d('TokenStorage.deleteTokens completed');
  }

  /// Stops reading other tabs' changes (a test's storage, thrown away).
  Future<void> dispose() => _otherTab.cancel();
}
