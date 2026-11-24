part of 'copy.dart';

/// 08 Talk.
abstract final class TalkCopy {
  static const headline = Words._('The village wakes');
  static const myNight = Words._('My night');
  static const readyToVote = Words._('Ready to vote');

  /// My night's first page.
  static const dealt = Template('Dealt: {role}');

  /// Tonight's deck on 08: a role with more than one
  /// card in it ("3 Villagers").
  static const deckCount = Template('{n} {roles}');
}
