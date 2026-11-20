import 'package:flutter/foundation.dart';

import '../models/role.dart';
import '../night/choose_prompt.dart';
import 'face_content.dart';

/// What `/me/` tells this phone about its night, as the faces that show it:
/// the dealt card (04), "You" at night, My night at the talk. Read from the
/// server's payload, nothing decided here.
@immutable
class NightReport {
  const NightReport._({required this.dealt, this.windowOne, this.saw});

  /// A `/me/` from the look stage on: `your_role`, `roles_in_game` and
  /// `night_results`.
  factory NightReport.fromMe(Map<String, dynamic> me) {
    final role = me['your_role'] as Map<String, dynamic>;
    final results = (me['night_results'] as List).cast<Map<String, dynamic>>();
    List<Map<String, dynamic>> wave(int n) => [
      for (final entry in results)
        if (entry['wave'] == n) entry,
    ];
    // Window 1 runs, and every phone has its page, when the deck holds the
    // Doppelganger (spec section 3), whoever holds her.
    final windowOneRan = (me['roles_in_game'] as List).any(
      (entry) => serverRole((entry as Map)['role']) == RoleId.doppelganger,
    );
    final second = wave(2);
    return NightReport._(
      dealt: serverRole(role['original_role']),
      windowOne: windowOneRan ? WindowOneResult.fromEntries(wave(1)) : null,
      saw: second.isEmpty ? null : NightResult.fromEntry(second.first),
    );
  }

  final RoleId dealt;

  /// Window 1's page, when it ran.
  final WindowOneResult? windowOne;

  /// What window 2 told this phone; null when it told it nothing.
  final NightResult? saw;

  /// 04: the card dealt.
  FaceContent get card => FaceContent.roleText(dealt);

  /// "You" on the board for [prompt]: once the Doppelganger's look is back,
  /// for the rest of window 1, whom she copied and what her copy may do
  /// (nothing, for a role that acts later or not at all); else the prompt,
  /// and window 1's page in window 2.
  FaceContent you(ChoosePrompt prompt) => switch (windowOne) {
    final CopiedResult look when prompt.window == 1 => FaceContent.copied(
      look,
      prompt.kind,
    ),
    _ => FaceContent.nightYou(
      dealt: dealt,
      prompt: prompt.kind,
      windowOne: prompt.window == 2 ? windowOne : null,
    ),
  };

  /// 08's My night.
  FaceContent get myNight => FaceContent.myNight(
    dealt: dealt,
    windowOne: windowOne,
    saw: saw ?? SleptResult.none,
  );
}
