/// Which night a game runs, as its `/me/` says: a `/me/` with a `stage` key
/// is night protocol 2 (the rebuilt screens), one without is protocol 1 (the
/// old screens). Fixed for the life of a game.
enum NightProtocol {
  one,
  two;

  /// Read from a `/me/` body.
  static NightProtocol of(Map<String, dynamic> me) =>
      me.containsKey('stage') ? two : one;
}
