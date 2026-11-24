part of 'copy.dart';

/// 01 Join.
abstract final class JoinCopy {
  /// The hero line (not a word: copy rule 1).
  static const title = Words._('Midnight Village');
  static const nameHint = Words._('Your name');

  /// Outlined and of equal weight; locked until a name is typed.
  static const startTable = Words._('Start a table');
  static const joinTable = Words._('Join a table');

  /// "Join a table" opened: the code and an amber "Join" in its place.
  static const codeHint = Words._('Code');
  static const join = Words._('Join');

  static const online = Template('{n} at tables');
  static const lastWon = Words._('You won last game');
  static const lastLost = Words._('You lost last game');

  /// Only in an Android browser, at the foot: a quiet link to the app's file.
  static const getApp = Words._('Get the app');
}
