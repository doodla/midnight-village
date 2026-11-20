import 'package:flutter/foundation.dart';

import '../faces/face_content.dart';
import 'pick_rule.dart';

/// This phone's turn on the night board, read from `/me/` during a night
/// window (protocol 2): the stage to name, what the prompt asks, what it lets
/// the phone pick, and which choose of the stage this is.
@immutable
class ChoosePrompt {
  const ChoosePrompt._({
    required this.stage,
    required this.window,
    required this.kind,
    required this.rule,
    required this.chosen,
  });

  /// `/me/` with an `action_prompt`.
  factory ChoosePrompt.fromMe(Map<String, dynamic> me) {
    final prompt = me['action_prompt'] as Map<String, dynamic>;
    return ChoosePrompt._(
      stage: me['stage'] as String,
      window: prompt['window'] as int,
      kind: NightPrompt.fromKind(prompt['kind'] as String),
      rule: PickRule.fromPrompt(prompt),
      chosen: prompt['chosen'] as int,
    );
  }

  /// The server's opaque name for this stage, sent back with the picks.
  final String stage;

  /// 1 (the Doppelganger's window) or 2.
  final int window;

  /// What the prompt asks (its `kind`).
  final NightPrompt kind;
  final PickRule rule;

  /// How many chooses the server has from this phone in this stage.
  final int chosen;

  /// Which choose of the stage this is: 1 only for the Doppelganger's
  /// follow-up, which the server marks by giving window 1 a prompt that is
  /// neither her look nor "nothing to do"; 0 otherwise. The board re-arms
  /// when it changes, so no other phone ever gets a second choose, whatever
  /// `max_chooses` says.
  int get turn =>
      window == 1 &&
          kind != NightPrompt.doppelgangerLook &&
          kind != NightPrompt.noChoice
      ? 1
      : 0;

  /// The server already has this turn's choose (a phone that restarted, or
  /// chose on another screen): the board starts at "Chosen".
  bool get used => chosen > turn;
}
