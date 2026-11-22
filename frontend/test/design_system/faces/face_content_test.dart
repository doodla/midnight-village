import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/copy/role_text.dart';
import 'package:midnight_village/design_system/faces/face_content.dart';
import 'package:midnight_village/design_system/faces/night_report.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/night/choose_prompt.dart';

import '../../helpers/sheet/sheet_data.dart';

// The faces read from what the server recorded (contract_samples/): every
// prompt, every talk.

const _game7Prompts = [
  'me_choose_prompt_seer',
  'me_choose_prompt_robber',
  'me_choose_prompt_troublemaker',
  'me_choose_prompt_villager',
  'me_choose_prompt_werewolf_lone',
];
const _game8Prompts = [
  'me_choose_prompt_drunk',
  'me_choose_prompt_insomniac',
  'me_choose_prompt_mason',
  'me_choose_prompt_minion',
  'me_choose_prompt_werewolf_pack',
];
const _game7Talks = [
  'me_discussion_choose_seer',
  'me_discussion_choose_robber',
  'me_discussion_choose_villager',
  'me_discussion_choose_werewolf_lone',
];
const _game8Talks = [
  'me_discussion_choose_doppelganger',
  'me_discussion_choose_drunk',
  'me_discussion_choose_insomniac',
  'me_discussion_choose_mason',
  'me_discussion_choose_minion',
  'me_discussion_choose_werewolf_pack',
];

FaceContent _you(String name) {
  final me = recordedMe(name);
  return NightReport.fromMe(me).you(ChoosePrompt.fromMe(me));
}

FaceContent _myNight(String name) =>
    NightReport.fromMe(recordedMe(name)).myNight;

List<String> _lines(FacePage page) => page.lines;

void main() {
  group('every phone has the same number of pages at the same beat', () {
    test('04: one page, the whole card, for every role', () {
      expect(
        {
          for (final role in RoleId.values)
            FaceContent.roleText(role).pages.length,
        },
        {1},
      );
    });

    test('06: one page without a window 1, two in window 2 after one', () {
      expect({for (final name in _game7Prompts) _you(name).pages.length}, {1});
      expect({for (final name in _game8Prompts) _you(name).pages.length}, {2});
    });

    test('08: the result, window 1 when it ran, then the dealt card', () {
      expect(
        {for (final name in _game7Talks) _myNight(name).pages.length},
        {2},
      );
      expect(
        {for (final name in _game8Talks) _myNight(name).pages.length},
        {3},
      );
      final seer = _myNight('me_discussion_choose_seer');
      expect(_lines(seer.pages.first), ["Cleo's card was: Werewolf."]);
      expect(_lines(seer.pages.last), ['Dealt: Seer']);
    });
  });

  test('each prompt kind the server sends has its own instruction', () {
    expect(_lines(_you('me_choose_prompt_seer').pages.first), [NightCopy.seer]);
    expect(_lines(_you('me_choose_prompt_villager').pages.first), [
      NightCopy.noChoice,
    ]);
    expect(_lines(_you('me_choose_prompt_werewolf_lone').pages.first), [
      NightCopy.loneWerewolf,
    ]);
    expect(_lines(_you('me_choose_prompt_doppelganger_look').pages.first), [
      NightCopy.doppelgangerLook,
    ]);
    // A kind the server adds later is a plain board, never a throw.
    final unknown = NightPrompt.fromKind('not_a_kind');
    expect(unknown.title, NightCopy.chooseNone);
    expect(unknown.go.fill({'cards': 'Cleo'}), 'Choose Cleo');
    expect(unknown.pass, NightCopy.skip);
  });

  test('every prompt kind has its button words, so none can crash a board: '
      '"Choose {cards}" and "Skip" where nothing better is said', () {
    for (final prompt in NightPrompt.values) {
      expect(
        prompt.go.fill({'cards': 'Cleo'}),
        allOf(contains('Cleo'), isNot(contains('{'))),
        reason: prompt.kind,
      );
      expect(prompt.pass, isNotEmpty, reason: prompt.kind);
    }
    final fallback = NightPrompt.fromKind('none');
    expect(fallback.go.fill({'cards': 'Cleo'}), 'Choose Cleo');
    expect(fallback.pass, 'Skip');
    expect(
      NightPrompt.fromKind('not_a_kind').go.fill({'cards': 'a'}),
      isNotEmpty,
    );
  });

  test("the Doppelganger's held line and her title agree: a player's role", () {
    final prompt = NightPrompt.fromKind('doppelganger_look');
    expect(prompt.instruction, "Copy 1 player's role.");
    expect(prompt.title, "Copy a player's role");
  });

  test("the Doppelganger's follow-up shows whom she copied and what her "
      'copy may do', () {
    final face = _you('me_choose_doppelganger_followup');
    expect(face.pages.single.name, 'Seer');
    expect(_lines(face.pages.single), ['You copied Ben.', NightCopy.seer]);
  });

  test('a Doppelganger who copied a role with nothing to do in window 1 sees '
      'her copy at once', () {
    // No recorded game has this; the follow-up sample, with the values the
    // server sends for such a copy.
    final me = recordedMe('me_choose_doppelganger_followup');
    final prompt = me['action_prompt'] as Map;
    prompt['kind'] = 'none';
    prompt['shapes'] = [
      {'any': 1},
    ];
    prompt['role_acting_as'] = 'Villager';
    ((me['night_results'] as List).first
            as Map)['revealed_info']['copied_role'] =
        'Villager';
    final face = NightReport.fromMe(me).you(ChoosePrompt.fromMe(me));
    expect(face.pages.single.name, 'Villager');
    expect(_lines(face.pages.single), ['You copied Ben.', NightCopy.noChoice]);
  });

  test('the results fill their lines with names, cards and roles', () {
    String result(String name) => _lines(_myNight(name).pages.first).join(' ');
    expect(result('me_discussion_choose_robber'), "You took Ana's card: Seer.");
    expect(
      result('me_discussion_choose_werewolf_lone'),
      'Only you. Left was: Werewolf.',
    );
    expect(result('me_discussion_choose_villager'), NightCopy.slept);
    // Chose, and nothing picked meant anything: the server says so.
    expect(
      result('me_discussion_choose_seer_nothing_chosen'),
      SawCopy.didNothing,
    );
    expect(result('me_discussion_choose_drunk'), 'You took Middle, unseen.');
    expect(
      result('me_discussion_choose_minion'),
      'Werewolves were: Cleo, Ida.',
    );
    expect(result('me_discussion_choose_mason'), 'Masons were: Fin.');
    expect(
      result('me_discussion_choose_insomniac'),
      'Your card now: Insomniac.',
    );
    expect(
      result('me_discussion_choose_werewolf_pack'),
      'Werewolves were: Ida.',
    );
    final doppelganger = _myNight('me_discussion_choose_doppelganger');
    expect(_lines(doppelganger.pages[1]), [
      'You copied Ben.',
      'Left was: Villager. Middle was: Villager.',
    ]);
  });

  test('the talk opens My night only where the night told something: a '
      'result, or the copy; never "You slept." or "You did nothing."', () {
    bool tells(String name) =>
        NightReport.fromMe(recordedMe(name)).tellsSomething;
    for (final name in [
      'me_discussion_choose_seer',
      'me_discussion_choose_robber',
      'me_discussion_choose_drunk',
      'me_discussion_choose_minion',
      'me_discussion_choose_mason',
      'me_discussion_choose_insomniac',
      'me_discussion_choose_werewolf_lone',
      'me_discussion_choose_doppelganger',
    ]) {
      expect(tells(name), isTrue, reason: name);
    }
    for (final name in [
      'me_discussion_choose_villager',
      'me_discussion_choose_seer_nothing_chosen',
    ]) {
      expect(tells(name), isFalse, reason: name);
    }
  });

  test('every line is a fact of the night: nothing says "now" but the '
      "Insomniac's, who looks last", () {
    for (final name in _game7Talks.followedBy(_game8Talks)) {
      for (final page in _myNight(name).pages) {
        for (final line in page.lines) {
          if (line.contains('now')) {
            expect(name, 'me_discussion_choose_insomniac', reason: line);
          }
        }
      }
    }
  });

  test('the portrait is the card seen, or the moon when nothing was', () {
    final seer = _myNight('me_discussion_choose_seer').pages.first;
    expect(seer.portrait, const RoleFacePortrait(RoleId.werewolf));
    for (final name in [
      'me_discussion_choose_villager',
      'me_discussion_choose_drunk',
    ]) {
      expect(_myNight(name).pages.first.portrait, isA<MoonFacePortrait>());
    }
  });

  test('a result the app does not know is a broken payload', () {
    final me = recordedMe('me_discussion_choose_seer');
    ((me['night_results'] as List).first as Map)['action_type'] = 'unknown';
    expect(() => NightReport.fromMe(me), throwsA(isA<FormatException>()));
  });

  test('the role text face is the role text, in its order', () {
    final face = FaceContent.roleText(RoleId.minion);
    final text = RoleText.of(RoleId.minion);
    expect(face.pages.single.name, 'Minion');
    expect(face.pages.single.tag, 'Werewolf');
    expect(face.pages.single.lines, [
      text.lines[1],
      text.lines[2],
      RoleCopy.shared,
    ]);
  });
}
