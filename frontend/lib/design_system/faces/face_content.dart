import 'package:flutter/foundation.dart';

import '../../core/logging/app_logger.dart';
import '../copy/copy.dart';
import '../copy/role_text.dart';
import '../models/role.dart';

// What a held face says (first-time play spec, sections 3, 7 and 8): pages
// of a portrait and a few lines, read from what the server sends (see
// night_report.dart). Hidden information: the page count of a face depends
// only on the moment (window 1 ran or not), never on the role.

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
    this.team,
    this.rules,
  });

  final FacePortrait portrait;

  /// A role's name over the lines (not a word: copy rule 1).
  final String? name;

  /// A role's tag beside its name.
  final String? tag;

  /// The team the tag is coloured for (`TagChip.team`).
  final TeamId? team;
  final List<String> lines;

  /// A role's text, drawn as its rows (`RoleRules`) in place of [lines]
  /// (which carry the same words, for a screen reader).
  final RoleText? rules;

  /// Everything on the page, in reading order: what is read aloud when the
  /// player asks for it.
  String get spoken => [?name, ?tag, ...lines].join('. ');
}

/// A center card by its index: "Left", "Middle", "Right".
String centerName(int index) => NightCopy.center[index];

/// Several names as one gap ("Ana, Ben").
String nameList(Iterable<String> names) => names.join(', ');

/// The role named [name] by the server; anything else is a broken payload.
RoleId serverRole(Object? name) =>
    RoleId.fromServer(name as String) ??
    (throw FormatException('Not a role', name));

/// What a night prompt asks of this phone, by the prompt's `kind`, one to
/// one: what its "You" face says, the board's title, and the words of its
/// button (what will happen with the picks; what passing is for this role).
enum NightPrompt {
  noChoice(
    'none',
    NightCopy.noChoice,
    CommonCopy.nightTitle,
    go: NightCopy.choose,
    pass: NightCopy.skip,
  ),
  seer(
    'seer',
    NightCopy.seer,
    NightCopy.seerTitle,
    go: NightCopy.see,
    pass: NightCopy.skip,
    seats: NightCopy.seerSeats,
    strip: NightCopy.seerCenter,
  ),
  robber(
    'robber',
    NightCopy.robber,
    NightCopy.robberTitle,
    go: NightCopy.swapWith,
    pass: NightCopy.keep,
  ),
  troublemaker(
    'troublemaker',
    NightCopy.troublemaker,
    NightCopy.troublemakerTitle,
    go: NightCopy.swap,
    pass: NightCopy.skip,
  ),
  drunk(
    'drunk',
    NightCopy.drunk,
    NightCopy.drunkTitle,
    go: NightCopy.swapWith,
    pass: NightCopy.chooseForMe,
  ),
  loneWerewolf(
    'lone_werewolf',
    NightCopy.loneWerewolf,
    NightCopy.loneWerewolfTitle,
    go: NightCopy.see,
    pass: NightCopy.skip,
  ),
  doppelgangerLook(
    'doppelganger_look',
    NightCopy.doppelgangerLook,
    NightCopy.doppelgangerTitle,
    go: NightCopy.copyCard,
    pass: NightCopy.skip,
  ),

  /// A kind this app does not know (the server added one): a plain board
  /// that still lets the player pick a card or skip, never a crash in a
  /// player's hand mid-game. The picks it takes are the prompt's `shapes`.
  generic(
    'generic',
    NightCopy.chooseNone,
    NightCopy.chooseNone,
    go: NightCopy.choose,
    pass: NightCopy.skip,
  );

  const NightPrompt(
    this.kind,
    this.instruction,
    this.title, {
    required this.go,
    required this.pass,
    this.seats,
    this.strip,
  });

  /// The server's name for it.
  final String kind;
  final String instruction;

  /// The board's headline: the role's night line in a few words for a
  /// phone with a choice; "The village sleeps" for a sleeper.
  final String title;

  /// The button once the picks are whole: what will happen to them ("See
  /// {cards}", "Swap with {cards}"); a sleeper has no button, and carries
  /// the plain "Choose {cards}" so no kind is ever without one.
  final Template go;

  /// The button with "You" alone picked: what passing is, for this role.
  final Words pass;

  /// The words this board adds above its seats and on the table's strip in
  /// place of "Center", with a rule saying "or" between them (the Seer's,
  /// who may pick from either: the owner chose it, 22 November 2026); null
  /// for every other prompt, whose board keeps the room empty.
  final String? seats;
  final String? strip;

  /// The prompt of [kind]; a kind this app does not know is the plain
  /// [generic] board, logged (a player is never thrown out mid-game for
  /// a role the server added).
  static NightPrompt fromKind(String kind) {
    final known = values.where((prompt) => prompt.kind == kind).firstOrNull;
    if (known != null) return known;
    logger.w('Unknown night prompt kind "$kind": showing the generic board');
    return generic;
  }
}

/// What a phone was told when a window closed (one `night_results` entry):
/// one row of the spec's "07 faces" table, a page of My night.
sealed class NightResult {
  const NightResult();

  /// One entry of `/me/`'s `night_results`.
  factory NightResult.fromEntry(Map<String, dynamic> entry) {
    final info = entry['revealed_info'] as Map<String, dynamic>;
    List<String> names() => (info['teammate_names'] as List).cast<String>();
    return switch (entry['action_type']) {
      'peek_player' => SeerPlayerResult._(
        name: info['target_name'] as String,
        role: serverRole(info['role']),
      ),
      'peek_center' => SeerCenterResult._([
        for (final (i, role) in (info['roles'] as List).indexed)
          ((info['center_indices'] as List)[i] as int, serverRole(role)),
      ]),
      // Chose, and nothing picked meant anything for the role (the server
      // lists the viewer's own skip, marked `nothing_chosen`).
      'skip' => const DidNothingResult._(),
      'swap_with_player' => RobbedResult._(
        name: info['target_name'] as String,
        role: serverRole(info['new_role']),
      ),
      'insomniac' => NewCardResult._(serverRole(info['current_role'])),
      'swap_others' => SwappedResult._(
        info['player1_name'] as String,
        info['player2_name'] as String,
      ),
      'swap_with_center' => DrunkResult._(info['card_index'] as int),
      'see_team' => switch (serverRole(info['role_acting_as'])) {
        RoleId.minion => MinionResult._(names()),
        RoleId.mason => MasonsResult._(names()),
        _ when names().isEmpty => LoneWerewolfResult._(
          switch (info['center_card']) {
            {'index': final int index, 'role': final role} => (
              index,
              serverRole(role),
            ),
            _ => null,
          },
        ),
        _ => WerewolvesResult._(names()),
      },
      final type => throw FormatException('Unknown night result', type),
    };
  }

  FacePortrait get portrait;
  List<String> get lines;

  FacePage get page => FacePage(portrait: portrait, lines: lines);
}

/// The Seer looked at a player's card.
final class SeerPlayerResult extends NightResult {
  const SeerPlayerResult._({required this.name, required this.role});

  final String name;
  final RoleId role;

  @override
  FacePortrait get portrait => RoleFacePortrait(role);

  @override
  List<String> get lines => [
    SawCopy.seerPlayer.fill({'name': name, 'role': role.displayName}),
  ];
}

/// The Seer looked at two center cards, each named by its place
/// (`center_indices`, in the order of `roles`); the portrait is the first.
final class SeerCenterResult extends NightResult {
  const SeerCenterResult._(this.cards);

  final List<(int index, RoleId role)> cards;

  @override
  FacePortrait get portrait => RoleFacePortrait(cards.first.$2);

  @override
  List<String> get lines => [
    SawCopy.seerCenter.fill({
      'pos1': centerName(cards.first.$1),
      'role1': cards.first.$2.displayName,
      'pos2': centerName(cards.last.$1),
      'role2': cards.last.$2.displayName,
    }),
  ];
}

/// The player chose, and nothing they picked meant anything for the role.
final class DidNothingResult extends NightResult {
  const DidNothingResult._();

  @override
  FacePortrait get portrait => const MoonFacePortrait();

  @override
  List<String> get lines => const [SawCopy.didNothing];
}

/// The Robber took a player's card and looked at it.
final class RobbedResult extends NightResult {
  const RobbedResult._({required this.name, required this.role});

  final String name;
  final RoleId role;

  @override
  FacePortrait get portrait => RoleFacePortrait(role);

  @override
  List<String> get lines => [
    SawCopy.robbed.fill({'name': name, 'role': role.displayName}),
  ];
}

/// The Insomniac's card at the end of the night (no card moves after her).
final class NewCardResult extends NightResult {
  const NewCardResult._(this.role);

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
  const SwappedResult._(this.a, this.b);

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
  const DrunkResult._(this.center);

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
  const WerewolvesResult._(this.names);

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
  const LoneWerewolfResult._(this.look);

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
  const MinionResult._(this.names);

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
  const MasonsResult._(this.names);

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

/// Nothing came back: no choice, a choice of nothing, or a timeout.
final class SleptResult extends NightResult {
  const SleptResult._();

  /// The page for a window that told this phone nothing.
  static const none = SleptResult._();

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

  /// Window 1's `night_results` entries for this phone (wave 1): her look
  /// (a `peek_player` naming `copied_role`), then her follow-up's; none for
  /// everyone else.
  factory WindowOneResult.fromEntries(List<Map<String, dynamic>> entries) {
    if (entries.isEmpty) return const WindowOneSlept._();
    // Her look held no other player: she copied nothing.
    if (entries.first['action_type'] == 'skip') {
      return const WindowOneDidNothing._();
    }
    final look = entries.first['revealed_info'] as Map<String, dynamic>;
    return CopiedResult._(
      name: look['target_name'] as String,
      role: serverRole(look['copied_role']),
      followUp: entries.length > 1 ? NightResult.fromEntry(entries[1]) : null,
    );
  }

  FacePage get page;
}

final class CopiedResult extends WindowOneResult {
  const CopiedResult._({required this.name, required this.role, this.followUp});

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
  const WindowOneSlept._();

  @override
  FacePage get page => SleptResult.none.page;
}

/// The Doppelganger's look held no other player: she copied nothing.
final class WindowOneDidNothing extends WindowOneResult {
  const WindowOneDidNothing._();

  @override
  FacePage get page => const DidNothingResult._().page;
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
        team: text.team,
        lines: text.lines.skip(1).toList(),
        rules: text,
      ),
    ]);
  }

  /// "You" on the night board: the dealt role's name and what the prompt
  /// asks; in window 2, after a window 1, what window 1 told this phone on a
  /// second page (every phone has one).
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
  /// copied, the copied role's portrait, and what her follow-up prompt asks.
  factory FaceContent.copied(CopiedResult look, NightPrompt followUp) =>
      FaceContent([
        FacePage(
          portrait: RoleFacePortrait(look.role),
          name: look.role.displayName,
          lines: [
            NightCopy.copied.fill({'name': look.name}),
            followUp.instruction,
          ],
        ),
      ]);

  /// 08's My night: what window 2 told this phone first (the page most
  /// wanted), window 1's page when it ran, then the dealt card; the same
  /// count on every phone.
  factory FaceContent.myNight({
    required RoleId dealt,
    WindowOneResult? windowOne,
    required NightResult saw,
  }) => FaceContent([
    saw.page,
    ?windowOne?.page,
    FacePage(
      portrait: RoleFacePortrait(dealt),
      lines: [
        TalkCopy.dealt.fill({'role': dealt.displayName}),
      ],
    ),
  ]);
}
