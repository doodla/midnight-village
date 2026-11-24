import 'package:midnight_village/design_system/models/role.dart';

// The copy rules of docs/specs/frontend/first-time-play.md, section 1, as
// functions over a line of copy. copy_budget_test.dart applies them to every
// line of lib/design_system/copy/copy.dart and to every screen state.

/// What a line is on screen; each kind has its own rules.
enum Shown {
  /// The one headline of a screen state: 5 words at most.
  headline,

  /// A button: 1 to 3 words.
  button,

  /// Any other text, hints and captions included.
  text,

  /// The teach-once cue's word.
  cue,

  /// Text on a held face: counted with the screen under it.
  face,
}

/// One line as a screen state shows it.
typedef Line = ({Shown kind, String text});

Line headline(Object text) => (kind: Shown.headline, text: '$text');
Line button(Object text) => (kind: Shown.button, text: '$text');
Line text(Object text) => (kind: Shown.text, text: '$text');
Line cue(Object text) => (kind: Shown.cue, text: '$text');
Line face(Object text) => (kind: Shown.face, text: '$text');

/// Rule 1: names that are not words. The 12 role names, their plurals and
/// the app's name.
final _exemptNames = {
  for (final role in RoleId.values) ...[
    role.displayName,
    role == RoleId.werewolf ? 'Werewolves' : '${role.displayName}s',
  ],
};
const _appName = 'Midnight Village';

/// Unit symbols, read with their number as one thing ("14 s"): not words
/// right after a number or a gap, as digits are not.
const _units = {'s', 'min'};
final _number = RegExp(r'^(\d+|\{\w+\})$');

final _letter = RegExp(r'\p{L}', unicode: true);
final _gap = RegExp(r'\{\w+\}');
final _edgePunctuation = RegExp(r"^[^\p{L}\d{]+|[^\p{L}\d}]+$", unicode: true);

/// The words of [line] as rule 1 counts them: split on whitespace, a word is
/// a piece with a letter in it, and gaps (`{name}`), the role names and
/// their plurals, "Midnight Village", digits, unit symbols and glyphs are
/// not words.
List<String> words(String line) {
  final pieces = line.replaceAll(_appName, ' ').split(RegExp(r'\s+'));
  bool unit(int i) =>
      _units.contains(pieces[i]) && i > 0 && _number.hasMatch(pieces[i - 1]);
  return [
    for (final (i, piece) in pieces.indexed)
      if (_letter.hasMatch(piece) &&
          !_gap.hasMatch(piece) &&
          !unit(i) &&
          !_exemptNames.contains(piece.replaceAll(_edgePunctuation, '')))
        piece,
  ];
}

int wordCount(String line) => words(line).length;

/// [line]'s sentences: split after ".", "?" or "!" (and a ":" that ends a
/// label is part of its sentence).
List<String> sentences(String line) => [
  for (final s in line.split(RegExp(r'(?<=[.?!])\s+')))
    if (s.trim().isNotEmpty) s.trim(),
];

/// Rule 9: the text the mocks used, and words a player should never meet.
const banned = [
  'Holding.',
  'Let go',
  'Tap the cards while you wait',
  'Waiting for',
  'reconnect',
  'Your turn',
  'Do nothing tonight',
  'Night one',
  'Tap to add or remove',
  'Hold a card to read',
  'Each column is a player',
  'The red line',
  'untouched',
  'held the',
  'Good with',
  'Acts at night',
  'Double',
  'Change',
  'x2',
  'of 8 cards',
  'seconds to choose',
  'seconds of night',
  'left to talk',
  'Accused',
  'Voted by',
  'In the deck tonight',
  'Host · You',
  'I know my card',
  "I'm ready to vote",
  'One table. One night.',
  'connection',
  'server',
  'error',
  'loading',
  'sync',
  'please',
  'Are you sure',
  'you can',
];

/// Rule 9: the one question.
const onlyQuestion = 'Who dies today?';

/// Rule 6: gestures are never explained in text. The cue's one word is an
/// exception, and so are the lines in [gestureKept].
final _gesture = RegExp(
  r'\b(tap|taps|tapping|tapped|press|pressing|swipe|drag|hold|holding|'
  r'double[- ]tap)\b',
  caseSensitive: false,
);

/// Lines that name a gesture and stay, each by a decision in the spec. None
/// since a sleeper is no longer told to tap a card (section 8).
const gestureKept = <String>{};

/// Budgets that are not a screen's.
const headlineMax = 5;
const buttonMax = 3;
const sentenceMax = 8;
const bannerMax = 6;
const spokenMax = 8;

/// What is wrong with [line] wherever it is shown: rule 9 (sentence length,
/// "!", the one question, the banned list) and rule 6 (gestures).
List<String> lineViolations(String line, {bool isCue = false}) => [
  for (final s in sentences(line))
    if (wordCount(s) > sentenceMax)
      '"$s" is a sentence of ${wordCount(s)} words (at most $sentenceMax)',
  if (line.contains('!')) '"$line" has a "!"',
  if (line.contains('?') && line != onlyQuestion)
    '"$line" asks a question; the only one is "$onlyQuestion"',
  for (final phrase in banned)
    if (_contains(line, phrase)) '"$line" uses the banned "$phrase"',
  if (!isCue && !gestureKept.contains(line) && _gesture.hasMatch(line))
    '"$line" explains a gesture ("${_gesture.firstMatch(line)![0]}")',
];

/// Whether [line] contains [phrase] as whole words, in any case.
bool _contains(String line, String phrase) {
  final edge = RegExp(r'^\w').hasMatch(phrase) ? r'\b' : '';
  final end = RegExp(r'\w$').hasMatch(phrase) ? r'\b' : '';
  return RegExp(
    '$edge${RegExp.escape(phrase)}$end',
    caseSensitive: false,
  ).hasMatch(line);
}

/// What is wrong with one screen state, [lines] being everything visible at
/// once: rules 3 (one headline of at most 5 words) and 4 (buttons of 1 to 3
/// words). How many words a screen has in all is not a number here: a change
/// that adds words says so and why (rule 2, `tool/words_added.py`).
List<String> stateViolations(List<Line> lines) {
  final headlines = lines.where((l) => l.kind == Shown.headline).toList();
  return [
    if (headlines.length > 1)
      '${headlines.length} headlines: ${headlines.map((l) => l.text)}',
    for (final h in headlines)
      if (wordCount(h.text) > headlineMax)
        'headline "${h.text}" is ${wordCount(h.text)} words',
    for (final b in lines.where((l) => l.kind == Shown.button))
      if (wordCount(b.text) < 1 || wordCount(b.text) > buttonMax)
        'button "${b.text}" is ${wordCount(b.text)} words (1 to $buttonMax)',
  ];
}

/// Rule 1: a banner and its button share a budget of 6 words.
List<String> bannerViolations(String banner, {String? button}) {
  final total = wordCount(banner) + (button == null ? 0 : wordCount(button));
  return [
    if (total > bannerMax)
      'banner "$banner"${button == null ? '' : ' + "$button"'} is $total '
          'words (at most $bannerMax)',
  ];
}

/// Rule 1: a screen reader's label is 8 words at most.
List<String> spokenViolations(String label) => [
  if (wordCount(label) > spokenMax)
    'spoken "$label" is ${wordCount(label)} words (at most $spokenMax)',
];
