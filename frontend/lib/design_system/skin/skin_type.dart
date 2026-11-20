import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// The type roles. Each is a complete style but for colour, which comes from
/// the ground the text sits on.
///
/// The brief's scale (design brief section 4, "Type scale"): headings 26 to
/// 36, timers 64 to 84 (a compact one 34), counts 28, labels 12 in capitals,
/// body 15 to 17, and names, buttons and small print 11 to 24. Nothing larger
/// but one hero line per screen, which follows its mock: [heroTitle] (Join),
/// [heroCode] (the table code), [heroRole] (your card), [heroVerdict] (who
/// dies) and [heroWinner] (who won). `test/design_system/skin/
/// skin_contract_test.dart` holds every skin to it.
///
/// [label] and [micro] are set in capitals: `SectionLabel` uppercases its
/// text; anything else using them must too.
@immutable
class SkinType {
  const SkinType({
    required this.heroTitle,
    required this.heroCode,
    required this.heroRole,
    required this.heroVerdict,
    required this.heroWinner,
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
    required this.timerCompact,
    required this.bodyLarge,
    required this.lede,
    required this.body,
    required this.action,
    required this.code,
    required this.small,
    required this.smallStrong,
    required this.caption,
    required this.tag,
    required this.badge,
    required this.label,
    required this.micro,
  });

  /// Hero: the app's name on Join (S01).
  final TextStyle heroTitle;

  /// Hero: the table code, read aloud across the table (S02).
  final TextStyle heroCode;

  /// Hero: the role name on your card (S04).
  final TextStyle heroRole;

  /// Hero: who dies ("Dev dies.", S10).
  final TextStyle heroVerdict;

  /// Hero: who won ("The Werewolf wins", S11).
  final TextStyle heroWinner;

  /// The biggest ordinary heading ("Cleo's card", the dead player's role).
  final TextStyle display;

  /// A screen's title under a picture or band ("The village sleeps", "Who
  /// dies today?").
  final TextStyle screenTitle;

  /// A screen title at the top ("Tonight's deck"), a sheet's role name.
  final TextStyle headline;

  /// A prompt; names in the vote; the role beside "Your turn".
  final TextStyle title;

  /// The number of votes at the end of a count row.
  final TextStyle tally;

  /// Short headings inside a screen ("My night"), pace values, names in the
  /// count.
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

  /// The countdown beside the candle (S05).
  final TextStyle timerSmall;

  /// The countdown in a screen's corner (S06).
  final TextStyle timerCompact;

  /// A paragraph read with care (what a role does).
  final TextStyle bodyLarge;

  /// The line under the app's name (S01).
  final TextStyle lede;

  /// Ordinary text.
  final TextStyle body;

  /// Secondary button labels and links.
  final TextStyle action;

  /// A code typed or read letter by letter (the table code field, S01).
  final TextStyle code;

  /// Meta lines, plain progress counts.
  final TextStyle small;

  /// Progress counts beside tokens, chips, pills.
  final TextStyle smallStrong;

  /// Hints and footnotes.
  final TextStyle caption;

  /// Team tags; a unit beside a number ("s").
  final TextStyle tag;

  /// Numbers in small count badges; role names under deck cards.
  final TextStyle badge;

  /// Section labels, in capitals and tracked.
  final TextStyle label;

  /// The smallest capitals (pace field names).
  final TextStyle micro;

  /// Every role by name, for the contract test and the type specimen.
  Map<String, TextStyle> get roles => {
    'heroTitle': heroTitle,
    'heroCode': heroCode,
    'heroRole': heroRole,
    'heroVerdict': heroVerdict,
    'heroWinner': heroWinner,
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
    'timerCompact': timerCompact,
    'bodyLarge': bodyLarge,
    'lede': lede,
    'body': body,
    'action': action,
    'code': code,
    'small': small,
    'smallStrong': smallStrong,
    'caption': caption,
    'tag': tag,
    'badge': badge,
    'label': label,
    'micro': micro,
  };
}
