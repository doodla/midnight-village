// Deliberately bad copy, for copy_budget_test.dart to prove its rules fail:
// each line here breaks one rule of first-time-play.md section 1. Never
// import this from lib/.

abstract final class BadCopy {
  /// Rule 9: a sentence of 10 words.
  static const longSentence = 'You must now look at the card you were dealt.';

  /// Rule 9: a "!".
  static const shout = 'Ready!';

  /// Rule 9: a second question.
  static const question = 'Are you ready?';

  /// Rule 9: banned text from the mocks.
  static const banned = 'Waiting for Dev';

  /// Rule 6: a gesture explained.
  static const gesture = 'Tap a card';

  /// Rule 3: a headline of 6 words.
  static const headline = 'The whole village goes to sleep';

  /// Rule 4: a button of 4 words.
  static const button = 'I know my role';

  /// Rule 1: a banner of 7 words with its button.
  static const banner = 'We could not send your vote.';
  static const bannerButton = 'Retry';

  /// Rule 1: a spoken label of 10 words.
  static const spoken = 'Your card is hidden, press and hold to show it';
}
