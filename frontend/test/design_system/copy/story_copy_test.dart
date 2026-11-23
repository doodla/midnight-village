import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';

// What happened's lines (docs/specs/frontend/end-board.md, section 8): one
// function, `StoryCopy.line`, says every step, leading with the role that
// acted and ending with what came of it. Every form, as the owner reads it.

void main() {
  String line(
    StoryAct act, {
    String role = '',
    List<String> names = const [],
    String other = '',
    String third = '',
    String seen = '',
    bool same = false,
  }) => StoryCopy.line(
    act,
    role: role,
    name: 'Ana',
    names: names,
    other: other,
    third: third,
    seen: seen,
    same: same,
  );

  test('every form', () {
    expect(line(StoryAct.dealt), 'The cards as dealt.');
    expect(
      line(StoryAct.werewolves, names: ['Cleo', 'Esme']),
      'Werewolves Cleo and Esme meet.',
    );
    expect(
      line(StoryAct.werewolves, names: ['Cleo', 'Esme', 'Rosa Maria']),
      'Werewolves Cleo, Esme and Rosa Maria meet.',
    );
    expect(
      line(StoryAct.masons, names: ['Esme', 'Fin']),
      'Masons Esme and Fin meet.',
    );
    expect(line(StoryAct.alone, role: 'Mason'), 'Mason Ana is alone.');
    expect(
      line(StoryAct.peeksMiddle, role: StoryCopy.loneWerewolf),
      'Lone Werewolf Ana peeks at a middle card.',
    );
    expect(
      line(StoryAct.minion, role: 'Minion', names: ['Cleo']),
      'Minion Ana sees the Werewolves.',
    );
    expect(
      line(StoryAct.minion, role: 'Minion'),
      'Minion Ana sees no Werewolves.',
    );
    expect(
      line(StoryAct.seesPlayer, role: 'Seer', other: 'Cleo', seen: 'Werewolf'),
      'Seer Ana sees Cleo: Werewolf.',
    );
    expect(
      line(StoryAct.seesMiddle, role: 'Seer'),
      'Seer Ana peeks at two middle cards.',
    );
    expect(
      line(StoryAct.takes, role: 'Robber', other: 'Dev'),
      "Robber Ana takes Dev's card.",
    );
    expect(
      line(StoryAct.swaps, role: 'Troublemaker', other: 'Ben', third: 'Cleo'),
      'Troublemaker Ana swaps Ben and Cleo.',
    );
    expect(
      line(StoryAct.swapsMiddle, role: 'Drunk'),
      'Drunk Ana swaps with a middle card.',
    );
    expect(
      line(StoryAct.wakes, role: 'Insomniac', seen: 'Insomniac', same: true),
      'Insomniac Ana wakes: still Insomniac.',
    );
    expect(
      line(StoryAct.wakes, role: 'Insomniac', seen: 'Seer'),
      'Insomniac Ana wakes: now the Seer.',
    );
    expect(
      line(StoryAct.copies, role: 'Doppelganger', other: 'Ben', seen: 'Seer'),
      'Doppelganger Ana copies Ben: now a Seer.',
    );
    expect(
      line(
        StoryAct.copies,
        role: 'Doppelganger',
        other: 'Ben',
        seen: 'Insomniac',
      ),
      'Doppelganger Ana copies Ben: now an Insomniac.',
    );
    // A Doppelganger's follow-up, in the same forms.
    expect(
      line(StoryAct.seesMiddle, role: 'Doppelganger'),
      'Doppelganger Ana peeks at two middle cards.',
    );
  });
}
