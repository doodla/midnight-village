import 'package:web/web.dart' as web;

/// localStorage changed in another tab under [prefix] (or was cleared).
Stream<void> secureStorageWritesInOtherTabs(String prefix) =>
    web.EventStreamProviders.storageEvent.forTarget(web.window).where((event) {
      final key = event.key;
      return key == null || key.startsWith(prefix);
    });
