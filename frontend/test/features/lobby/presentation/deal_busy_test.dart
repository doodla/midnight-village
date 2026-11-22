import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/features/game/domain/screen_table.dart';
import 'package:midnight_village/features/game/presentation/shell/table_shell.dart';
import 'package:midnight_village/features/game/presentation/table_screen.dart';
import 'package:midnight_village/features/lobby/presentation/at_table_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/live_game_setup.dart' show recordedMe;
import '../../../helpers/mock_http_client.dart';
import '../../../helpers/table_setup.dart';

// The deal is a tap that leads to another screen: Deal is busy in the frame
// of the tap and is not live again until the next screen is named (by the
// dealt game's `/me/`, which is where the host sits: `AtTableScreen`),
// not just until the deal's answer (the gap the audit found: Deal tappable
// again between the answer and the dusk).

void main() {
  testWidgets('Deal stays busy past the deal\'s answer until the next screen '
      'is named; one request, never two', (tester) async {
    final setup = await TableSetup.pump(
      tester,
      lobby: v2Lobby('detail_auto_deck_5'),
      viewer: 'Ana',
      timesOut: false,
    );
    final started = ContractSamples.map('http/game/started_with_look');
    setup.http.answer(
      'POST',
      '/onuw/lobbies/${setup.code}/start/',
      started,
      status: 201,
    );
    setup.answerGame(recordedMe('me_look_stage'));
    final start = '/onuw/lobbies/${setup.code}/start/';
    int starts() => setup.count('POST', start);

    // The next screen comes from the dealt game's own /me/ (its answer is
    // where the host sits: `/me/table/` is not asked), and it is slow: held.
    final mePath = '/onuw/games/${started['game_id']}/me/';
    final me = setup.http.hold(method: 'GET', path: mePath);

    PrimaryButton deal() =>
        tester.widget<PrimaryButton>(find.byType(PrimaryButton).last);
    await tester.tap(find.byType(PrimaryButton).last);
    await tester.pump();
    expect(deal().busy, isTrue, reason: 'busy in the frame of the tap');
    await setup.settle(tester);
    expect(starts(), 1);

    // The answer is in, the next screen is not named: still busy, and a
    // tap sends nothing.
    expect(find.byType(AtTableScreen), findsOneWidget);
    expect(deal().busy, isTrue);
    await tester.tap(find.byType(PrimaryButton).last);
    await setup.settle(tester);
    expect(starts(), 1);

    setup.http.stopHolding(method: 'GET', path: mePath);
    me.releaseAll();
    await setup.settle(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TableShell)),
    );
    expect(
      container.read(tableScreenProvider).value?.screen,
      isNot(AppScreen.table),
    );
    expect(find.text(BannerCopy.notSent), findsNothing);
    await setup.close(tester);
  });
}
