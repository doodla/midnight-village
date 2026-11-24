part of 'copy.dart';

/// 09 Vote.
abstract final class VoteCopy {
  /// The only question in the app.
  static const headline = Words._('Who dies today?');
  static const pickName = Words._('Pick a name');
  static const lockIn = Template('Lock in {name}');
  static const locked = Words._('Locked');
  static const progress = Template('{d} of {n} locked');
}
