part of 'copy.dart';

/// 01's scan action and the scanner it opens (01b). The action is a glyph and
/// the viewfinder has no words: these are what a screen reader says, and the
/// one calm line (with its way out) when the camera cannot be used.
abstract final class ScanCopy {
  /// Spoken only: 01's scan glyph.
  static const scan = Words._('Scan the code');

  /// Spoken only: what the viewfinder is doing, and its two glyphs.
  static const looking = Words._("Looking for the table's code");
  static const back = Words._('Back');
  static const light = Words._('Light');

  /// The camera cannot be used (refused, none, or a page that may not): one
  /// line, and "Type the code" takes the player back to the code field.
  static const cameraOff = Words._('The camera is off.');
  static const typeCode = Words._('Type the code');
}
