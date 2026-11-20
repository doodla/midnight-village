import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/night/night_pick.dart';
import 'package:midnight_village/design_system/night/pick_rule.dart';

// The phone compares picks with the prompt's shapes and nothing else
// (first-time play spec, section 8).

const _ben = PlayerPick(2);
const _cleo = PlayerPick(3);
const _left = CenterPick(0);
const _right = CenterPick(2);
const _you = SelfPick();

const _seer = PickRule(
  shapes: {PickShape.self, PickShape.onePlayer, PickShape.twoCenter},
  players: {2, 3},
  centers: {0, 1, 2},
);
const _troublemaker = PickRule(
  shapes: {PickShape.self, PickShape.twoPlayers},
  players: {2, 3},
);
const _drunk = PickRule(shapes: {PickShape.oneCenter}, centers: {0, 1, 2});

List<NightPick> _taps(PickRule rule, List<NightPick> taps) =>
    taps.fold(const [], rule.tap);

void main() {
  test('a whole shape fits; its start and a mix do not', () {
    expect(_seer.fits([_cleo]), isTrue);
    expect(_seer.fits([_left, _right]), isTrue);
    expect(_seer.fits([_you]), isTrue);
    expect(_seer.fits([_left]), isFalse);
    expect(_seer.fits([_cleo, _left]), isFalse);
    expect(_troublemaker.fits([_ben, _cleo]), isTrue);
    expect(_troublemaker.fits([_ben]), isFalse);
  });

  test('only the cards the prompt names can be picked', () {
    expect(_seer.canPick(const PlayerPick(9)), isFalse);
    expect(_drunk.canPick(_cleo), isFalse);
    expect(_drunk.canPick(_you), isFalse);
    expect(_troublemaker.canPick(_left), isFalse);
    expect(_drunk.canPick(_right), isTrue);
  });

  test('nothing to choose: any one card, "You" included', () {
    const rule = PickRule.anyCard();
    for (final pick in [_you, _cleo, _left]) {
      expect(rule.canPick(pick), isTrue);
      expect(rule.fits([pick]), isTrue);
    }
    expect(_taps(rule, [_cleo, _left]), [_left]);
  });

  test('a tap keeps the picks a shape or its start', () {
    expect(_taps(_seer, [_left, _right]), [_left, _right]);
    expect(_taps(_seer, [_left, _right, CenterPick(1)]), [
      _right,
      const CenterPick(1),
    ]);
    expect(_taps(_seer, [_left, _cleo]), [_cleo]);
    expect(_taps(_seer, [_cleo, _left]), [_left]);
    expect(_taps(_troublemaker, [_ben, _cleo]), [_ben, _cleo]);
    expect(_taps(_troublemaker, [_ben, _you]), [_you]);
  });

  test('a picked card tapped again is unpicked; one that cannot be '
      'picked changes nothing', () {
    expect(_taps(_seer, [_left, _right, _left]), [_right]);
    expect(_taps(_drunk, [_left, _cleo]), [_left]);
  });
}
