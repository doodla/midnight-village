import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// The type roles. Each is a complete style but for colour, which comes from
/// the ground the text sits on.
///
/// The brief's scale (design brief section 4, "Type scale", as amended by the
/// first-time play spec): headings 26 to 36, timers 64 to 84 (a compact one
/// 34), counts 28, anything a player reads to act 16 to 24 (body 16 to 17),
/// and captions under cards and tokens 14. No capitals tracked as labels.
/// Nothing larger but one hero line per screen, which follows its mock:
/// [heroTitle] (Join), [heroCode] (the table code), [heroVerdict] (who dies)
/// [heroWinner] (who won) and [heroRole] (the role on a held face). `test/design_system/skin/
/// skin_contract_test.dart` holds every skin to it, and the screen gallery
/// fails a player screen whose text is drawn below the floor.
@immutable
class SkinType {
  const SkinType({
    required this.heroTitle,
    required this.heroCode,
    required this.heroVerdict,
    required this.heroWinner,
    required this.heroRole,
    required this.display,
    required this.screenTitle,
    required this.headline,
    required this.title,
    required this.tally,
    required this.heading,
    required this.name,
    required this.nameSmall,
    required this.buttonLabelLarge,
    required this.buttonLabel,
    required this.buttonLabelSmall,
    required this.timer,
    required this.timerVote,
    required this.timerSmall,
    required this.bodyLarge,
    required this.bodyStrong,
    required this.lede,
    required this.body,
    required this.action,
    required this.code,
    required this.cue,
    required this.caption,
    required this.tag,
    required this.badge,
  });

  /// Hero: the app's name on Join (S01).
  final TextStyle heroTitle;

  /// Hero: the table code, read aloud across the table (S02).
  final TextStyle heroCode;

  /// Hero: who dies ("Dev dies.", S10).
  final TextStyle heroVerdict;

  /// Hero: who won ("The village wins", S11).
  final TextStyle heroWinner;

  /// Hero: the role's name on a held face (S04's "Seer"): seeing your card
  /// is the screen's moment.
  final TextStyle heroRole;

  /// The biggest ordinary heading (the dead player's role).
  final TextStyle display;

  /// A screen's title under a picture or band ("The village sleeps", "Who
  /// dies today?").
  final TextStyle screenTitle;

  /// A screen title at the top ("Tonight's deck"), a sheet's role name.
  final TextStyle headline;

  /// Names in the vote.
  final TextStyle title;

  /// The number of votes at the end of a count row.
  final TextStyle tally;

  /// Short headings inside a screen ("My night"), pace values, names in the
  /// count, a role's name on a held face.
  final TextStyle heading;

  /// A player's name in a row.
  final TextStyle name;

  /// A player's name under a card.
  final TextStyle nameSmall;

  /// The primary button's label at its three sizes.
  final TextStyle buttonLabelLarge;
  final TextStyle buttonLabel;
  final TextStyle buttonLabelSmall;

  /// The talk's large countdown (S08).
  final TextStyle timer;

  /// The vote's countdown in its band (S09).
  final TextStyle timerVote;

  /// The countdown beside the candle (S05, S06).
  final TextStyle timerSmall;

  /// A paragraph read with care (what a role does, on the role sheet).
  final TextStyle bodyLarge;

  /// [bodyLarge] bold: the word that leads a line ("At night:") and a count
  /// read from across the table ("2 of 6 ready").
  final TextStyle bodyStrong;

  /// The lines under the app's name (S01).
  final TextStyle lede;

  /// Ordinary text: anything a player reads to act, a held face's lines.
  final TextStyle body;

  /// Secondary button labels, chips and links.
  final TextStyle action;

  /// A code typed or read letter by letter (the table code field, S01).
  final TextStyle code;

  /// The teach-once cue's one word, "Hold" (20, in the hold ring).
  final TextStyle cue;

  /// Captions under cards and tokens ("Left", "Now").
  final TextStyle caption;

  /// Team tags.
  final TextStyle tag;

  /// Numbers in count badges; role names under deck cards.
  final TextStyle badge;

  /// Every role by name, for the contract test and the type specimen.
  Map<String, TextStyle> get roles => {
    'heroTitle': heroTitle,
    'heroCode': heroCode,
    'heroVerdict': heroVerdict,
    'heroWinner': heroWinner,
    'heroRole': heroRole,
    'display': display,
    'screenTitle': screenTitle,
    'headline': headline,
    'title': title,
    'tally': tally,
    'heading': heading,
    'name': name,
    'nameSmall': nameSmall,
    'buttonLabelLarge': buttonLabelLarge,
    'buttonLabel': buttonLabel,
    'buttonLabelSmall': buttonLabelSmall,
    'timer': timer,
    'timerVote': timerVote,
    'timerSmall': timerSmall,
    'bodyLarge': bodyLarge,
    'bodyStrong': bodyStrong,
    'lede': lede,
    'body': body,
    'action': action,
    'code': code,
    'cue': cue,
    'caption': caption,
    'tag': tag,
    'badge': badge,
  };
}
