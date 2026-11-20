import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../faces/face_content.dart';
import 'pick_rule.dart';

/// This phone's turn on the night board, read from `/me/` during a night
/// window: the stage to name, what the prompt asks, what it lets
/// the phone pick, and which choose of the stage this is.
///
/// This is THE parsed night prompt: the app's `/me/` model (`GameMe`) holds
/// one of these, the board draws from it, and the choose request is built
/// from it (`ChooseRequest.of`). There is no second parser of `action_prompt`.
@immutable
class ChoosePrompt {
  const ChoosePrompt._({
    required this.stage,
    required this.window,
    required this.kind,
    required this.rule,
    required this.chosen,
    required this.choosesLeft,
    required this.maxChooses,
    required this.maxPicks,
  });

  /// `/me/` with an `action_prompt`. Strict: every key the server always
  /// sends is read, and a prompt that is not a `choose` prompt
  /// is a broken payload here.
  factory ChoosePrompt.fromMe(Map<String, dynamic> me) {
    final prompt = me['action_prompt'] as Map<String, dynamic>;
    final types = (prompt['action_types'] as List).cast<String>();
    if (types.length != 1 || types.single != 'choose') {
      throw FormatException('Not a choose prompt', types);
    }
    return ChoosePrompt._(
      stage: me['stage'] as String,
      window: prompt['window'] as int,
      kind: NightPrompt.fromKind(prompt['kind'] as String),
      rule: PickRule.fromPrompt(prompt),
      chosen: prompt['chosen'] as int,
      choosesLeft: prompt['chooses_left'] as int,
      maxChooses: prompt['max_chooses'] as int,
      maxPicks: prompt['max_picks'] as int,
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

  /// How many chooses this phone should still send in this stage, as the
  /// server says (`chooses_left`): 1 for every phone's turn, and 1 again for
  /// the Doppelganger's follow-up when her copied role acts in window 1. The
  /// phone infers nothing from the prompt's `kind`.
  final int choosesLeft;

  /// How many chooses the server takes from this phone in this stage (2 in
  /// window 1 from anyone). Never a reason to offer a second: [choosesLeft]
  /// is.
  final int maxChooses;

  /// The most picks one choose carries.
  final int maxPicks;

  /// Which choose of the stage the board is on: the server's count while one
  /// is left to send ([chosen]), else the last one sent. It changes only when
  /// the server arms a new turn (the Doppelganger's follow-up), never when a
  /// turn is used, so the board re-arms exactly then.
  int get turn => choosesLeft > 0 ? chosen : math.max(0, chosen - 1);

  /// The server has this turn's choose (a phone that restarted, or chose on
  /// another screen): the board starts at "Chosen".
  bool get used => choosesLeft == 0;

  /// This prompt as it is once this phone has sent this turn's choose: what
  /// the app shows from the tap on, until a `/me/` fetched after the answer
  /// says what the server holds.
  ChoosePrompt get afterChoose => used
      ? this
      : ChoosePrompt._(
          stage: stage,
          window: window,
          kind: kind,
          rule: rule,
          chosen: chosen + 1,
          choosesLeft: 0,
          maxChooses: maxChooses,
          maxPicks: maxPicks,
        );
}
