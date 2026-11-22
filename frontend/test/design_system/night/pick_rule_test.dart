import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/night/night_pick.dart';
import 'package:midnight_village/design_system/night/pick_rule.dart';

import '../../helpers/contract/contract_samples.dart';
import '../../helpers/sheet/sheet_data.dart';

// The phone compares picks with the prompt's shapes and nothing else
// (first-time play spec, section 8), read from every prompt the server
// recorded.

/// Every recorded prompt.
final _prompts = [
  for (final info in ContractSamples.index)
    if (info.name.startsWith('http/game/me_choose_prompt_') ||
        info.name == 'http/game/me_choose_doppelganger_followup')
      info.name.substring('http/game/'.length),
];

PickRule _rule(String sample) => PickRule.fromPrompt(
  recordedMe(sample)['action_prompt'] as Map<String, dynamic>,
);

List<NightPick> _taps(PickRule rule, List<NightPick> taps) =>
    taps.fold(const [], rule.tap);

const _you = SelfPick();
const _left = CenterPick(0);
const _middle = CenterPick(1);
const _right = CenterPick(2);

void main() {
  test('every recorded prompt parses', () {
    expect(_prompts, hasLength(greaterThanOrEqualTo(12)));
    for (final sample in _prompts) {
      expect(() => _rule(sample), returnsNormally, reason: sample);
    }
  });

  test('"You" alone is a choice for every prompt, the Drunk and the '
      "Doppelganger's look included", () {
    for (final sample in _prompts) {
      final rule = _rule(sample);
      expect(rule.canPick(_you), isTrue, reason: sample);
      expect(rule.fits([_you]), isTrue, reason: sample);
    }
  });

  test("the Seer's shapes: a player, or two center cards", () {
    final rule = _rule('me_choose_prompt_seer');
    expect(rule.fits([PlayerPick(cleo.id)]), isTrue);
    expect(rule.fits([_left, _right]), isTrue);
    expect(rule.fits([_left]), isFalse);
    expect(rule.fits([PlayerPick(cleo.id), _left]), isFalse);
    expect(rule.canPick(PlayerPick(ana.id)), isFalse, reason: 'her own seat');
  });

  test("the Troublemaker's: two other players", () {
    final rule = _rule('me_choose_prompt_troublemaker');
    expect(rule.fits([PlayerPick(ana.id), PlayerPick(ben.id)]), isTrue);
    expect(rule.fits([PlayerPick(ana.id)]), isFalse);
    expect(rule.canPick(_left), isFalse);
  });

  test("the Drunk's: one center card; no player's card", () {
    final me = recordedMe('me_choose_prompt_drunk');
    final rule = _rule('me_choose_prompt_drunk');
    final other = NightSeat.seatsOf(
      me,
    ).map((s) => s.id).firstWhere((id) => id != selfIn(me));
    expect(rule.canPick(PlayerPick(other)), isFalse);
    expect(rule.fits([_middle]), isTrue);
  });

  test('nothing to choose: any one card', () {
    final rule = _rule('me_choose_prompt_villager');
    for (final pick in [_you, PlayerPick(ben.id), _left]) {
      expect(rule.fits([pick]), isTrue, reason: '$pick');
    }
    expect(_taps(rule, [PlayerPick(ben.id), _left]), [_left]);
  });

  test('a tap keeps the picks "You", a shape or its start', () {
    final seer = _rule('me_choose_prompt_seer');
    expect(_taps(seer, [_left, _right]), [_left, _right]);
    expect(_taps(seer, [_left, _right, _middle]), [_right, _middle]);
    expect(_taps(seer, [_left, PlayerPick(cleo.id)]), [PlayerPick(cleo.id)]);
    expect(_taps(seer, [PlayerPick(cleo.id), _you]), [_you]);
    expect(_taps(seer, [_you, _left]), [_left]);
  });

  test('a picked card tapped again is unpicked; one that cannot be picked '
      'changes nothing', () {
    final seer = _rule('me_choose_prompt_seer');
    expect(_taps(seer, [_left, _right, _left]), [_right]);
    final drunk = _rule('me_choose_prompt_drunk');
    final me = recordedMe('me_choose_prompt_drunk');
    final other = NightSeat.seatsOf(
      me,
    ).map((s) => s.id).firstWhere((id) => id != selfIn(me));
    expect(_taps(drunk, [_left, PlayerPick(other)]), [_left]);
  });

  group('a card that cannot join the pick is dimmed', () {
    final seer = _rule('me_choose_prompt_seer');
    final cleoPick = PlayerPick(cleo.id);

    test("the Seer's: nothing at first; one player, everything else; one "
        'center card, the players and no other center card', () {
      for (final card in [cleoPick, PlayerPick(ben.id), _left, _middle]) {
        expect(seer.dims(card, const []), isFalse);
      }
      expect(seer.dims(PlayerPick(ben.id), [cleoPick]), isTrue);
      expect(seer.dims(_left, [cleoPick]), isTrue);
      expect(seer.dims(PlayerPick(ben.id), [_left]), isTrue);
      expect(seer.dims(_middle, [_left]), isFalse);
      expect(seer.dims(_right, [_left]), isFalse);
      expect(seer.dims(_middle, [_left, _right]), isTrue);
    });

    test('nothing dims before the first pick, for any recorded prompt: the '
        'board shows no role until the first tap', () {
      for (final sample in _prompts) {
        final rule = _rule(sample);
        for (final card in [cleoPick, _left, _middle, _right]) {
          expect(rule.dims(card, const []), isFalse, reason: sample);
          expect(rule.dims(card, [_you]), isFalse, reason: sample);
        }
      }
    });

    test('"You" is never dimmed, a card picked is not, and "You" alone '
        'leaves the pick empty', () {
      expect(seer.dims(_you, [cleoPick]), isFalse);
      expect(seer.dims(cleoPick, [cleoPick]), isFalse);
      expect(seer.dims(_left, [_you]), isFalse);
      final robber = _rule('me_choose_prompt_robber');
      expect(robber.dims(_left, [_you]), isFalse);
      expect(robber.dims(_left, [cleoPick]), isTrue);
    });

    test("a sleeper's shape is any one card: nothing dims", () {
      final sleeper = _rule('me_choose_prompt_villager');
      for (final card in [cleoPick, _left, _right]) {
        expect(sleeper.dims(card, const []), isFalse);
      }
    });

    test('it is exactly the cards a tap would replace the pick with, not '
        'add to, for every recorded prompt', () {
      for (final sample in _prompts) {
        final rule = _rule(sample);
        final players = {
          for (final id in rule.players) PlayerPick(id),
          cleoPick,
        };
        final cards = [...players, _left, _middle, _right];
        // Every pick a player can be in the middle of: none, one card, two.
        final singles = [
          for (final card in cards)
            if (rule.canPick(card)) [card],
        ];
        final pairs = [
          for (final one in singles)
            for (final card in cards) rule.tap(one, card),
        ].where((picks) => picks.length == 2);
        for (final picks in [const <NightPick>[], ...singles, ...pairs]) {
          for (final card in cards) {
            if (picks.contains(card) || !rule.canPick(card)) continue;
            final after = rule.tap(picks, card);
            final adds = picks.every(after.contains) && after.contains(card);
            expect(
              rule.dims(card, picks),
              !adds,
              reason: '$sample: $card after $picks',
            );
          }
        }
      }
    });
  });

  test('a shape the app does not know is left out, and a prompt left with '
      'none takes any one card: no crash in a player\'s hand', () {
    final prompt =
        recordedMe('me_choose_prompt_seer')['action_prompt']
            as Map<String, dynamic>;
    (prompt['shapes'] as List).first = {'tokens': 1};
    final rule = PickRule.fromPrompt(prompt);
    // Her {"center": 2} stays; the unknown one is gone.
    expect(rule.fits([_left, _right]), isTrue);
    expect(rule.fits([PlayerPick(cleo.id)]), isFalse);
    (prompt['shapes'] as List)
      ..clear()
      ..add({'tokens': 1});
    final plain = PickRule.fromPrompt(prompt);
    expect(plain.fits([PlayerPick(cleo.id)]), isTrue);
    expect(plain.fits([_left]), isTrue);
  });
}
