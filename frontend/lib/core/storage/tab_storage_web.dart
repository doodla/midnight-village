import 'package:web/web.dart' as web;

import 'tab_storage.dart';

/// The browser's `sessionStorage`; a browser that refuses it (blocked
/// storage throws) leaves this tab with memory only.
TabStorage openTabStorage() => _SessionTabStorage();

class _SessionTabStorage implements TabStorage {
  final _memory = MemoryTabStorage();

  @override
  String? read(String key) {
    try {
      return web.window.sessionStorage.getItem(key) ?? _memory.read(key);
    } catch (_) {
      return _memory.read(key);
    }
  }

  @override
  void write(String key, String value) {
    _memory.write(key, value);
    try {
      web.window.sessionStorage.setItem(key, value);
    } catch (_) {
      // Memory still holds it for this page's life.
    }
  }

  @override
  void remove(String key) {
    _memory.remove(key);
    try {
      web.window.sessionStorage.removeItem(key);
    } catch (_) {}
  }
}
