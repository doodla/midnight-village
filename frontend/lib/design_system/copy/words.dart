part of 'copy.dart';

/// Words a player reads. Only this library makes one, so a part that asks for
/// [Words] (a button's label) can only be given a line of copy, or a line of
/// copy with its gaps filled ([Template.fill]): a sentence written in a
/// screen does not compile. It is a [String] wherever one is read.
extension type const Words._(String text) implements String {
  /// For a test of a part, which has no line of copy of its own.
  @visibleForTesting
  const Words.forTest(String text) : this._(text);
}
