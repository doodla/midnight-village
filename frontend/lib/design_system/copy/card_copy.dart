part of 'copy.dart';

/// 04 Your card.
abstract final class CardCopy {
  static const headline = Words._('Your card');
  static const ready = Words._('Ready');

  /// "Ready" before this phone has held its card: says what unlocks it (23
  /// November 2026: a locked main button's label says why; a button is 3
  /// words at most).
  static const readyLocked = Words._('Look first');
}
