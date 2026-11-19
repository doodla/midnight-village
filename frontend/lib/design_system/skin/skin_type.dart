import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// The type roles. Each is a complete style but for colour, which comes from
/// the ground the text sits on. Sizes stay inside the brief's scale: headings
/// 26 to 36, timers 64 to 84, labels 12, body 15 to 17, plus the few in-between
/// sizes the mocks use for names, buttons and small print.
///
/// [label] and [micro] are set in capitals: `SectionLabel` uppercases its
/// text; anything else using them must too.
@immutable
class SkinType {
  const SkinType({
    required this.display,
    required this.headline,
    required this.title,
    required this.heading,
    required this.name,
    required this.nameSmall,
    required this.buttonLabel,
    required this.timer,
    required this.timerSmall,
    required this.bodyLarge,
    required this.body,
    required this.action,
    required this.small,
    required this.caption,
    required this.tag,
    required this.badge,
    required this.label,
    required this.micro,
  });

  /// The biggest heading on a screen ("Cleo's card", a dead player's role).
  final TextStyle display;

  /// A screen title ("Tonight's deck").
  final TextStyle headline;

  /// A prompt or a sheet title; names in the vote.
  final TextStyle title;

  /// Short headings inside a screen ("My night") and pace values.
  final TextStyle heading;

  /// A player's name in a row.
  final TextStyle name;

  /// A player's name under a card.
  final TextStyle nameSmall;

  /// The primary button's label.
  final TextStyle buttonLabel;

  /// The large countdown (talk, vote).
  final TextStyle timer;

  /// The countdown beside a picture (night).
  final TextStyle timerSmall;

  /// A paragraph read with care (what a role does).
  final TextStyle bodyLarge;

  /// Ordinary text.
  final TextStyle body;

  /// Secondary button labels and links.
  final TextStyle action;

  /// Meta lines, progress counts.
  final TextStyle small;

  /// Hints and footnotes.
  final TextStyle caption;

  /// Team tags and chips.
  final TextStyle tag;

  /// Numbers in count badges; role names under deck cards.
  final TextStyle badge;

  /// Section labels, in capitals and tracked.
  final TextStyle label;

  /// The smallest capitals (pace field names).
  final TextStyle micro;
}
