import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/features/game/presentation/game_container_screen.dart';
import 'package:midnight_village/features/game/presentation/shell/table_shell.dart';

import '../../../helpers/contract/server_json.dart';
import '../../../helpers/game_state_factory.dart';
import '../../../helpers/mock_http_client.dart';
import '../../../helpers/shell_setup.dart';

/// The game route ([GameEntry]) decides by the game's `/me/`: a `stage` is
/// night protocol 2 and the rebuilt shell; none is protocol 1 and the old
/// screen; a server that cannot be reached is "One moment" until it answers;
/// a server that refuses is the old screen's own error path, never an
/// endless "One moment".
void main() {
  testWidgets('a protocol-2 game opens the rebuilt shell', (tester) async {
    final s = await ShellSetup.pump(
      tester,
      recordedMe('me_look_stage'),
      entry: true,
    );
    await s.settle(tester);
    expect(find.byType(TableShell), findsOneWidget);
    expect(find.byType(GameContainerScreen), findsNothing);
    await s.close(tester);
  });

  testWidgets('a protocol-1 game keeps the old game screen', (tester) async {
    final me = GameMeJsonBuilder()
        .withGameId('00000000-0000-0000-0000-000000000001')
        .build();
    final s = await ShellSetup.pump(tester, me, entry: true, userId: 1);
    s.http.answer(
      'GET',
      '/onuw/games/${s.gameId}/players/',
      serverPlayerList(),
    );
    await s.settle(tester);
    expect(find.byType(GameContainerScreen), findsOneWidget);
    expect(find.byType(TableShell), findsNothing);
    await s.close(tester);
  });

  testWidgets('no answer: "One moment", fetched again until it answers', (
    tester,
  ) async {
    final me = recordedMe('me_look_stage');
    final s = await ShellSetup.pump(
      tester,
      me,
      entry: true,
      before: (s) => s.failMe(),
    );
    await s.settle(tester);
    expect(find.text(BannerCopy.offline), findsOneWidget);
    expect(find.byType(TableShell), findsNothing);
    expect(find.byType(GameContainerScreen), findsNothing);

    s.answerMe(me);
    await tester.pump(const Duration(seconds: 1));
    await s.settle(tester);
    expect(find.byType(TableShell), findsOneWidget);
    await s.close(tester);
  });

  testWidgets('refused (the game is gone): the old screen, which says so '
      'and goes home', (tester) async {
    final me = recordedMe('me_look_stage');
    final s = await ShellSetup.pump(
      tester,
      me,
      entry: true,
      before: (s) => s.refuseMe(),
    );
    await s.settle(tester);
    await s.settle(tester);
    expect(find.text(BannerCopy.offline), findsNothing);
    expect(find.byKey(ShellSetup.home), findsOneWidget);
    await s.close(tester);
  });
}
