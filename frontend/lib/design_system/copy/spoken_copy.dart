part of 'copy.dart';

/// What a screen reader says (8 words at most; not in the budgets).
abstract final class SpokenCopy {
  /// A face before it is shown.
  static const hidden = Template('{target}, hidden. Activate to show.');

  /// A button whose action is on its way, or a screen waiting for its
  /// answer.
  static const working = 'Working';

  /// The vote's button before a name is picked.
  static const pickFirst = 'Pick a name first';

  /// 03's steppers' glyphs and the grid card's minus.
  static const lower = 'Lower';
  static const higher = 'Higher';
  static const takeOut = Template('Take one {role} out');
}
