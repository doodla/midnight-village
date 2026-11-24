import '../../../helpers/finger.dart';
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
// of the tap and is never live again before the next screen (the gap the
// audit found: Deal tappable again between the answer and the dusk). The
// deal's answer is where the host sits (`SeatSeed`): the answer itself names
// the next screen, so there is no gap left to wait in.

void main() {
  testWidgets('Deal stays busy until its answer, which names the next screen '
      'itself; one request, never two', (tester) async {
    final setup = await TableSetup.pump(
      tester,
      lobby: v2Lobby('detail_auto_deck_5'),
      viewer: 'Ana',
      timesOut: false,
    );
    final started = ContractSamples.map('http/game/started_with_look');
    final start = '/onuw/lobbies/${setup.code}/start/';
    setup.http.answer('POST', start, started, status: 201);
    setup.answerGame(recordedMe('me_look_stage'));
    int starts() => setup.count('POST', start);

    // The deal's answer is slow.
    final answer = setup.http.hold(method: 'POST', path: start);

    PrimaryButton deal() =>
        tester.widget<PrimaryButton>(find.byType(PrimaryButton).last);
    await pressLikeAFinger(tester, find.byType(PrimaryButton).last);
    await tester.pump();
    expect(deal().busy, isTrue, reason: 'busy in the frame of the tap');
    await tester.pump(const Duration(milliseconds: 40));
    expect(starts(), 1);

    // No answer yet: still busy, and a tap sends nothing.
    expect(find.byType(AtTableScreen), findsOneWidget);
    expect(deal().busy, isTrue);
    await pressLikeAFinger(tester, find.byType(PrimaryButton).last);
    await tester.pump(const Duration(milliseconds: 40));
    expect(starts(), 1);

    setup.http.stopHolding(method: 'POST', path: start);
    final atAnswer = setup.http.requests.length;
    answer.releaseAll();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TableShell)),
    );
    AppScreen? screen() => container.read(tableScreenProvider).value?.screen;
    // Frames only, no time passing (02's slow poll never comes due): the
    // answer alone moves the screen.
    for (var i = 0; i < 50 && screen() == AppScreen.table; i++) {
      expect(deal().busy, isTrue, reason: 'never live again before the dusk');
      await tester.pump(Duration.zero);
    }
    expect(screen(), isNot(AppScreen.table));
    await setup.settle(tester);
    expect(find.text(BannerCopy.notSent), findsNothing);
    expect(starts(), 1);
    // Where the host sits is the answer: never read after it.
    expect(
      setup.http.requests.skip(atAnswer).map((r) => r.path),
      isNot(contains('/me/table/')),
    );
    await setup.close(tester);
  });
}
