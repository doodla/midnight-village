/// Something that smells like a stale build: a picture the page answered
/// with HTML, an API call it answered with a page, a file that will not
/// decode. The places that notice say so here ([report]); `NewBuild`, when
/// the app runs, looks at `/commit.txt` once more because of it. With nothing
/// listening (tests, an installed app) it does nothing.
class StaleSmell {
  StaleSmell._();

  static void Function()? _listener;

  /// [onSmell] hears every report until the returned function is called.
  static void Function() listen(void Function() onSmell) {
    _listener = onSmell;
    return () {
      if (_listener == onSmell) _listener = null;
    };
  }

  static void report() => _listener?.call();
}
