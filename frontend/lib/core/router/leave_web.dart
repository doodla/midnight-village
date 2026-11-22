import 'dart:js_interop';

@JS('history.go')
external void _historyGo(int delta);

/// Leaves the app on the web: two entries back, past the app's one entry
/// and the entry of the page it was opened at (the engine's single-entry
/// history keeps the app's entry over that one), to the page before. Where
/// there is no page before (the app opened in a fresh tab) nothing happens
/// and the app keeps its history: Back still works. The engine's own exit
/// is never used: where it cannot leave, it takes the app's history down
/// with it and Back stops working.
void leaveWebPage() => _historyGo(-2);
