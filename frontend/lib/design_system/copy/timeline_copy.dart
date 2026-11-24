part of 'copy.dart';

/// 11's timeline rows, each after a "{role}:" prefix (a Doppelganger's
/// follow-up: "Doppelganger · {copied}:").
abstract final class TimelineCopy {
  static const prefix = Template('{role}:');
  static const followUpPrefix = Template('Doppelganger · {copied}:');
  static const copies = Template('{a} copies {b}.');
  static const seeEachOther = Template('{names} see each other.');
  static const wakesAlone = Template('{name} wakes alone.');
  static const minionSees = Template('{a} sees {names}.');
  static const minionSeesNone = Template('{a} sees no Werewolf.');
  static const seerPlayer = Template("{a} sees {b}'s card.");
  static const seerCenter = Template('{a} sees {pos1}, {pos2}.');
  static const loneWerewolf = Template('{a} sees {pos}.');
  static const robber = Template("{a} takes {b}'s card.");
  static const troublemaker = Template('{a} swaps {b} and {c}.');
  static const drunk = Template('{a} takes {pos}.');
  static const insomniac = Template('{a} sees own card.');
  static const skip = Template('{a} does nothing.');
}
