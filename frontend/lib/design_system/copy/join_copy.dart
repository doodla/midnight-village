part of 'copy.dart';

/// 01 Join.
abstract final class JoinCopy {
  /// The hero line (not a word: copy rule 1).
  static const title = 'Midnight Village';
  static const nameHint = 'Your name';

  /// Outlined and of equal weight; locked until a name is typed.
  static const startTable = 'Start a table';
  static const joinTable = 'Join a table';

  /// "Join a table" opened: the code and an amber "Join" in its place.
  static const codeHint = 'Code';
  static const join = 'Join';

  static const online = Template('{n} at tables');
  static const lastWon = 'You won last game';
  static const lastLost = 'You lost last game';

  /// Only in an Android browser, at the foot: a quiet link to the app's file.
  static const getApp = 'Get the app';
}
