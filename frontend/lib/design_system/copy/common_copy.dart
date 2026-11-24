part of 'copy.dart';

/// Words shared by several screens.
abstract final class CommonCopy {
  /// The teach-once cue's one word (copy rule 6).
  static const hold = Words._('Hold');

  /// A gate button after the player is ready (04, 08).
  static const readyDone = Words._('Ready ✓');

  /// Back to the start (02 guest, 11 guest).
  static const leave = Words._('Leave');

  /// How many are ready, under 04's card and on 08 (playtest: a bare
  /// "1 of 5" on 04 read as cards, not players).
  static const progress = Template('{d} of {n} ready');

  /// Night and dawn share the title (05, 06).
  static const nightTitle = Words._('The village sleeps');

  /// A clock under a minute (05, 06, 08, 09, the deck's lengths): a bare
  /// "14" was not read as seconds (cold read on the real screens). From a
  /// minute it is "4:12", which reads as a clock.
  static const seconds = Template('{n} s');
}
