import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/copy/role_text.dart';
import 'package:midnight_village/design_system/faces/face_content.dart';
import 'package:midnight_village/design_system/models/role.dart';

/// Every result a window can end with, one of each kind.
const _results = <NightResult>[
  SeerPlayerResult(name: 'Cleo', role: RoleId.werewolf),
  SeerCenterResult((0, RoleId.drunk), (2, RoleId.tanner)),
  NewCardResult(RoleId.robber),
  SwappedResult('Ana', 'Ben'),
  DrunkResult(1),
  WerewolvesResult(['Ana', 'Ben']),
  LoneWerewolfResult(),
  LoneWerewolfResult((2, RoleId.seer)),
  MinionResult(['Ana']),
  MinionResult([]),
  MasonsResult(['Ana']),
  MasonsResult([]),
  DidNothingResult(),
  SleptResult(),
];

final _windowOnes = <WindowOneResult>[
  const WindowOneSlept(),
  for (final role in RoleId.values) CopiedResult(name: 'Cleo', role: role),
  const CopiedResult(
    name: 'Cleo',
    role: RoleId.drunk,
    followUp: DrunkResult(0),
  ),
];

void main() {
  group('every phone has the same number of pages at the same beat', () {
    test('04: two pages for every role', () {
      expect(
        {
          for (final role in RoleId.values)
            FaceContent.roleText(role).pages.length,
        },
        {2},
      );
    });

    test('06: one page in window 1, before and after a copy; two in window 2 '
        'after a window 1', () {
      expect(
        {
          for (final role in RoleId.values)
            for (final prompt in NightPrompt.values)
              FaceContent.nightYou(dealt: role, prompt: prompt).pages.length,
          for (final role in RoleId.values)
            FaceContent.copied(name: 'Cleo', role: role).pages.length,
        },
        {1},
      );
      expect(
        {
          for (final role in RoleId.values)
            for (final windowOne in _windowOnes)
              FaceContent.nightYou(
                dealt: role,
                prompt: NightPrompt.noChoice,
                windowOne: windowOne,
              ).pages.length,
        },
        {2},
      );
    });

    test('07: one page, whatever was seen', () {
      expect({for (final r in _results) FaceContent.saw(r).pages.length}, {1});
    });

    test('08: dealt and seen, with window 1 between when it ran', () {
      int pages(WindowOneResult? windowOne, NightResult saw) =>
          FaceContent.myNight(
            dealt: RoleId.seer,
            windowOne: windowOne,
            saw: saw,
          ).pages.length;
      expect({for (final r in _results) pages(null, r)}, {2});
      expect(
        {
          for (final w in _windowOnes)
            for (final r in _results) pages(w, r),
        },
        {3},
      );
    });
  });

  test('every page has at most two lines', () {
    final pages = [
      for (final role in RoleId.values) ...[
        ...FaceContent.roleText(role).pages,
        ...FaceContent.copied(name: 'Cleo', role: role).pages,
      ],
      for (final w in _windowOnes) w.page,
      for (final r in _results) r.page,
    ];
    expect(pages.where((p) => p.lines.length > FacePage.maxLines), isEmpty);
  });

  test('the role text face is the role text, in its order', () {
    final face = FaceContent.roleText(RoleId.minion);
    final text = RoleText.of(RoleId.minion);
    expect(face.pages.first.name, 'Minion');
    expect(face.pages.first.tag, 'Werewolf');
    expect(
      [...face.pages.first.lines, ...face.pages.last.lines],
      [text.lines[1], text.lines[2], RoleCopy.shared],
    );
  });

  test('the 07 faces fill their lines with names, cards and roles', () {
    expect(
      const SeerCenterResult((0, RoleId.drunk), (2, RoleId.tanner)).lines,
      ['Left: Drunk. Right: Tanner.'],
    );
    expect(const SwappedResult('Ana', 'Ben').lines, [
      'You swapped Ana and Ben.',
    ]);
    expect(const DrunkResult(1).lines, ['Middle is yours. Unseen.']);
    expect(const LoneWerewolfResult((2, RoleId.seer)).lines, [
      'Only you.',
      'Right: Seer.',
    ]);
    expect(const MinionResult([]).lines, ['No Werewolves.']);
    expect(const MasonsResult(['Ana', 'Ben']).lines, ['Masons: Ana, Ben.']);
  });

  test('the portrait is the card seen, or the moon when nothing was', () {
    expect(
      const SeerCenterResult((0, RoleId.drunk), (2, RoleId.tanner)).portrait,
      const RoleFacePortrait(RoleId.drunk),
    );
    for (final blind in const [
      SwappedResult('Ana', 'Ben'),
      DrunkResult(0),
      DidNothingResult(),
      SleptResult(),
    ]) {
      expect(blind.portrait, isA<MoonFacePortrait>());
    }
  });

  test('a copy shows the copied role and its window-1 instruction', () {
    final page = FaceContent.copied(
      name: 'Cleo',
      role: RoleId.robber,
    ).pages.single;
    expect(page.portrait, const RoleFacePortrait(RoleId.robber));
    expect(page.lines, ['You copied Cleo.', NightCopy.robber]);
    expect(
      FaceContent.copied(
        name: 'Cleo',
        role: RoleId.werewolf,
      ).pages.single.lines.last,
      NightCopy.noChoice,
      reason: 'a copied Werewolf acts in window 2, not at once',
    );
  });
}
