// The talk's deck shows its portraits (the owner, 28 November 2026: "The
// images are all gone dude"). Every `/me/` the server recorded in the talk,
// whatever its deck, on every phone of the sweep from 360 x 780 up (the
// owner's Pixel in Chrome, 411.43 x 784, among them) at the phone's own text
// size: every pile has its portrait, and none is left alone on a row of its
// own. The words alone are for a short phone
// or large text, never for a deck whose words are wider than four to a row.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/countdown.dart';
import 'package:midnight_village/design_system/primitives/deck_pile.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';
import 'package:midnight_village/features/game/domain/game_me.dart';
import 'package:midnight_village/features/game/presentation/shell/talk_screen.dart';

import '../../../helpers/component_sheet.dart' show learnedOverrides;
import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/pump_skinned.dart';
import '../../../helpers/screen_sweep.dart' show sizeLabel, sweepSizes;

List<String> get _talks => [
  for (final sample in ContractSamples.index)
    if (sample.path == '/onuw/games/{game_id}/me/' &&
        ContractSamples.map(sample.name)['phase'] == 'discussion')
      sample.name,
];

void main() {
  final phones = [
    for (final size in sweepSizes)
      if (size.height >= 780) size,
  ];

  test('the recorded talks hold decks of six, eight and more piles', () {
    final piles = {
      for (final name in _talks)
        (ContractSamples.map(name)['roles_in_game'] as List).length,
    };
    expect(piles, containsAll([5, 6, 7, 8, 9]));
  });

  for (final name in _talks) {
    testWidgets('every pile of $name has its portrait, none alone on its '
        'row', (tester) async {
      final me = GameMe.fromJson(ContractSamples.map(name));
      for (final size in phones) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await pumpSkinned(
          tester,
          ProviderScope(
            overrides: learnedOverrides({...Cue.values}),
            child: TalkView(me: me, clock: Countdown.held(192), onReady: () {}),
          ),
        );
        await tester.pumpAndSettle();
        final piles = tester.widgetList<DeckPile>(find.byType(DeckPile));
        expect(piles, hasLength(me.deck.length));
        for (final pile in piles) {
          expect(
            pile.nameOnly,
            isFalse,
            reason:
                '$name on a phone ${sizeLabel(size)}: ${pile.label} is '
                'drawn as its words alone, no portrait',
          );
        }
        final rows = <double, int>{};
        for (final e in find.byType(DeckPile).evaluate()) {
          final top = (e.renderObject! as RenderBox).localToGlobal(Offset.zero);
          rows.update(top.dy.roundToDouble(), (n) => n + 1, ifAbsent: () => 1);
        }
        expect(
          rows.values.where((n) => n == 1),
          me.deck.length < 2 ? anything : isEmpty,
          reason:
              '$name on a phone ${sizeLabel(size)}: a pile is alone on its '
              'row (${rows.values.join(', ')} to a row)',
        );
      }
    });
  }
}
