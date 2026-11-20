import 'package:flutter/foundation.dart';

import '../copy/copy.dart';
import '../copy/role_text.dart';
import '../models/role.dart';

// What a held face says (first-time play spec, sections 3 and 8): pages of a
// portrait and a few lines, built from plain data the server gives. Hidden
// information: the page count of a face depends only on the moment (window 1
// ran or not), never on the role.

/// What fills a face's portrait slot.
sealed class FacePortrait {
  const FacePortrait();
}

/// A role's portrait.
final class RoleFacePortrait extends FacePortrait {
  const RoleFacePortrait(this.role);

  final RoleId role;

  @override
  bool operator ==(Object other) =>
      other is RoleFacePortrait && other.role == role;

  @override
  int get hashCode => role.hashCode;
}

/// The moon: nothing seen, or a blind swap.
final class MoonFacePortrait extends FacePortrait {
  const MoonFacePortrait();
}

/// One page of a face.
@immutable
class FacePage {
  const FacePage({
    required this.portrait,
    required this.lines,
    this.name,
    this.tag,
  });

  final FacePortrait portrait;

  /// A role's name over the lines (not a word: copy rule 1).
  final String? name;

  /// A role's tag beside its name.
  final String? tag;
  final List<String> lines;

  /// Everything on the page, in reading order: what is read aloud when the
  /// player asks for it.
  String get spoken => [?name, ?tag, ...lines].join('. ');
}

/// A center card by its index: "Left", "Middle", "Right".
String centerName(int index) => NightCopy.center[index];

/// Several names as one gap ("Ana, Ben").
String nameList(Iterable<String> names) => names.join(', ');

/// The prompt the server gives a phone for one night window: what its "You"
/// face asks for.
enum NightPrompt {
  noChoice(NightCopy.noChoice),
  seer(NightCopy.seer),
  robber(NightCopy.robber),
  troublemaker(NightCopy.troublemaker),
  drunk(NightCopy.drunk),
  loneWerewolf(NightCopy.loneWerewolf),
  doppelgangerLook(NightCopy.doppelgangerLook);

  const NightPrompt(this.instruction);

  final String instruction;

  /// A copied role's window-1 follow-up: the four that act at once; every
  /// other copied role acts later or not at all.
  static NightPrompt windowOneFor(RoleId copied) => switch (copied) {
    RoleId.seer => seer,
    RoleId.robber => robber,
    RoleId.troublemaker => troublemaker,
    RoleId.drunk => drunk,
    _ => noChoice,
  };
}

/// What a phone was told when a window closed: one row of the "07 faces"
/// table, a page of My night.
sealed class NightResult {
  const NightResult();

  FacePortrait get portrait;
  List<String> get lines;

  FacePage get page => FacePage(portrait: portrait, lines: lines);
}

/// The Seer looked at a player's card.
final class SeerPlayerResult extends NightResult {
  const SeerPlayerResult({required this.name, required this.role});

  final String name;
  final RoleId role;

  @override
  FacePortrait get portrait => RoleFacePortrait(role);

  @override
  List<String> get lines => [
    SawCopy.seerPlayer.fill({'name': name, 'role': role.displayName}),
  ];
}

/// The Seer looked at two center cards; the portrait is the first.
final class SeerCenterResult extends NightResult {
  const SeerCenterResult(this.first, this.second);

  final (int index, RoleId role) first;
  final (int index, RoleId role) second;

  @override
  FacePortrait get portrait => RoleFacePortrait(first.$2);

  @override
  List<String> get lines => [
    SawCopy.seerCenter.fill({
      'pos1': centerName(first.$1),
      'role1': first.$2.displayName,
      'pos2': centerName(second.$1),
      'role2': second.$2.displayName,
    }),
  ];
}

/// The Robber's or the Insomniac's card now.
final class NewCardResult extends NightResult {
  const NewCardResult(this.role);

  final RoleId role;

  @override
  FacePortrait get portrait => RoleFacePortrait(role);

  @override
  List<String> get lines => [
    SawCopy.newCard.fill({'role': role.displayName}),
  ];
}

/// The Troublemaker swapped two players.
final class SwappedResult extends NightResult {
  const SwappedResult(this.a, this.b);

  final String a;
  final String b;

  @override
  FacePortrait get portrait => const MoonFacePortrait();

  @override
  List<String> get lines => [
    SawCopy.swapped.fill({'a': a, 'b': b}),
  ];
}

/// The Drunk took a center card, chosen or by the server's seeded swap.
final class DrunkResult extends NightResult {
  const DrunkResult(this.center);

  final int center;

  @override
  FacePortrait get portrait => const MoonFacePortrait();

  @override
  List<String> get lines => [
    SawCopy.drunk.fill({'pos': centerName(center)}),
  ];
}

/// The Werewolves saw each other.
final class WerewolvesResult extends NightResult {
  const WerewolvesResult(this.names);

  final List<String> names;

  @override
  FacePortrait get portrait => const RoleFacePortrait(RoleId.werewolf);

  @override
  List<String> get lines => [
    SawCopy.werewolves.fill({'names': nameList(names)}),
  ];
}

/// A lone Werewolf, with the center card it looked at, if it did.
final class LoneWerewolfResult extends NightResult {
  const LoneWerewolfResult([this.look]);

  final (int index, RoleId role)? look;

  @override
  FacePortrait get portrait => const RoleFacePortrait(RoleId.werewolf);

  @override
  List<String> get lines => [
    SawCopy.onlyYou,
    if (look case (final index, final role))
      SawCopy.centerLook.fill({
        'pos': centerName(index),
        'role': role.displayName,
      }),
  ];
}

/// The Minion saw the Werewolves, or that there are none.
final class MinionResult extends NightResult {
  const MinionResult(this.names);

  final List<String> names;

  @override
  FacePortrait get portrait => const RoleFacePortrait(RoleId.minion);

  @override
  List<String> get lines => [
    names.isEmpty
        ? SawCopy.noWerewolves
        : SawCopy.werewolves.fill({'names': nameList(names)}),
  ];
}

/// The Masons saw each other, or a lone Mason saw nobody.
final class MasonsResult extends NightResult {
  const MasonsResult(this.names);

  /// The other Masons; empty for a lone Mason.
  final List<String> names;

  @override
  FacePortrait get portrait => const RoleFacePortrait(RoleId.mason);

  @override
  List<String> get lines => [
    names.isEmpty
        ? SawCopy.onlyYou
        : SawCopy.masons.fill({'names': nameList(names)}),
  ];
}

/// The player chose, but no pick was a valid action for their role.
final class DidNothingResult extends NightResult {
  const DidNothingResult();

  @override
  FacePortrait get portrait => const MoonFacePortrait();

  @override
  List<String> get lines => const [SawCopy.didNothing];
}

/// No choice, or the window timed out.
final class SleptResult extends NightResult {
  const SleptResult();

  @override
  FacePortrait get portrait => const MoonFacePortrait();

  @override
  List<String> get lines => const [NightCopy.slept];
}

/// What a phone learned in window 1: the Doppelganger's copy (and her
/// follow-up's result, when the copied role acts at once); everyone else
/// slept.
sealed class WindowOneResult {
  const WindowOneResult();

  FacePage get page;
}

final class CopiedResult extends WindowOneResult {
  const CopiedResult({required this.name, required this.role, this.followUp});

  final String name;
  final RoleId role;

  /// A one-line result: window 1's follow-ups are the Seer's, the Robber's,
  /// the Troublemaker's and the Drunk's.
  final NightResult? followUp;

  @override
  FacePage get page => FacePage(
    portrait: RoleFacePortrait(role),
    lines: [
      NightCopy.copied.fill({'name': name}),
      ...?followUp?.lines,
    ],
  );
}

final class WindowOneSlept extends WindowOneResult {
  const WindowOneSlept();

  @override
  FacePage get page => const SleptResult().page;
}

/// A held face's pages, in the order holds show them.
@immutable
class FaceContent {
  const FaceContent(this.pages) : assert(pages.length > 0);

  final List<FacePage> pages;

  /// 04: the whole role card on one page (the role sheet's words).
  factory FaceContent.roleText(RoleId role) {
    final text = RoleText.of(role);
    return FaceContent([
      FacePage(
        portrait: RoleFacePortrait(role),
        name: role.displayName,
        tag: text.tag,
        lines: text.lines.skip(1).toList(),
      ),
    ]);
  }

  /// "You" on the night board: the dealt role's name and this window's
  /// instruction; in window 2, after a window 1, what window 1 told this
  /// phone on a second page (every phone has one).
  factory FaceContent.nightYou({
    required RoleId dealt,
    required NightPrompt prompt,
    WindowOneResult? windowOne,
  }) => FaceContent([
    FacePage(
      portrait: RoleFacePortrait(dealt),
      name: dealt.displayName,
      lines: [prompt.instruction],
    ),
    ?windowOne?.page,
  ]);

  /// "You" in window 1 once the Doppelganger's look has come back: whom she
  /// copied, the copied role's portrait, and its window-1 instruction.
  factory FaceContent.copied({required String name, required RoleId role}) =>
      FaceContent([
        FacePage(
          portrait: RoleFacePortrait(role),
          name: role.displayName,
          lines: [
            NightCopy.copied.fill({'name': name}),
            NightPrompt.windowOneFor(role).instruction,
          ],
        ),
      ]);

  /// 08's My night: the dealt card, window 1's page when it ran, and what
  /// window 2 told this phone; the same count on every phone.
  factory FaceContent.myNight({
    required RoleId dealt,
    WindowOneResult? windowOne,
    required NightResult saw,
  }) => FaceContent([
    FacePage(
      portrait: RoleFacePortrait(dealt),
      lines: [
        TalkCopy.dealt.fill({'role': dealt.displayName}),
      ],
    ),
    ?windowOne?.page,
    saw.page,
  ]);
}
