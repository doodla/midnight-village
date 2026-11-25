import 'other_tab_writes_stub.dart'
    if (dart.library.js_interop) 'other_tab_writes_web.dart'
    as platform;

/// The prefix the web's secure storage gives its keys in localStorage
/// (`WebOptions.publicKey`'s default): its values and its own key.
const secureStoragePrefix = 'FlutterSecureStorage';

/// An event each time another tab of this browser changes what the secure
/// storage holds (the browser's `storage` event, which a tab never gets for
/// its own writes). Off the web there are no other tabs: it never fires.
Stream<void> secureStorageWritesInOtherTabs() =>
    platform.secureStorageWritesInOtherTabs(secureStoragePrefix);
