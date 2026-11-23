import 'tab_storage_stub.dart'
    if (dart.library.js_interop) 'tab_storage_web.dart'
    as open;

/// Small things kept for THIS tab only and for as long as it lives, across
/// the page's own reload (the browser's `sessionStorage`): which build this
/// tab last reloaded for (`NewBuild`), and what 01's form held when the page
/// was reloaded for a newer build, so a reload loses nothing typed. Never
/// shared with another tab, never kept after the tab is closed. Off the web
/// (and where the browser refuses storage) it is plain memory: nothing is
/// kept past the app's own life, and nothing throws.
abstract interface class TabStorage {
  String? read(String key);
  void write(String key, String value);
  void remove(String key);
}

/// Memory only: tests, the installed app, and a browser that refuses storage.
class MemoryTabStorage implements TabStorage {
  final _values = <String, String>{};

  @override
  String? read(String key) => _values[key];

  @override
  void write(String key, String value) => _values[key] = value;

  @override
  void remove(String key) => _values.remove(key);
}

/// The tab's storage for the platform this runs on.
TabStorage openTabStorage() => open.openTabStorage();
