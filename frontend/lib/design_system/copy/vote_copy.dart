part of 'copy.dart';

/// 09 Vote.
abstract final class VoteCopy {
  /// The only question in the app.
  static const headline = 'Who dies today?';
  static const pickName = 'Pick a name';
  static const lockIn = Template('Lock in {name}');
  static const locked = 'Locked';
  static const progress = Template('{d} of {n} locked');
}
