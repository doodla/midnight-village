import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/debug/debug_models.dart';
import 'package:midnight_village/core/debug/debug_providers.dart';
import 'package:midnight_village/core/debug/debug_table_controller.dart';
import 'package:midnight_village/design_system/skin/skin_choice.dart';
import 'package:midnight_village/design_system/skin/skin_id.dart';
import 'package:midnight_village/features/debug/presentation/debug_toolbar_screen.dart';
import 'package:midnight_village/design_system/skin/skin.dart';
import 'package:midnight_village/design_system/skin_loader.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockController extends Mock implements DebugTableController {}

/// Decoding the new skin's art needs real I/O, which the test clock never
/// waits for; the switch's waiting for it is tested in skin_choice_test.dart.
class _ReadyLoader extends SkinLoader {
  @override
  Future<void> prepare(Skin skin) async {}
}

const _table = DebugTable(
  gameId: 'g1',
  lobbyCode: 'ABCD',
  players: [
    DebugPlayer(
      userId: 1,
      displayName: 'Alice',
      accessToken: 'a',
      refreshToken: 'ar',
      role: 'Werewolf',
      isHost: true,
    ),
    DebugPlayer(
      userId: 2,
      displayName: 'Bob',
      accessToken: 'b',
      refreshToken: 'br',
      role: 'Seer',
      isHost: false,
    ),
  ],
);

void main() {
  // The toolbar runs WITHOUT a backend: the controller is mocked. These tests
  // exercise the table-setup → perspective-switcher flow and the dev gate.
  late _MockController controller;

  setUpAll(() {
    registerFallbackValue(_table.players.first);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    controller = _MockController();
    when(() => controller.isManuallyDisconnected(any())).thenReturn(false);
  });

  Widget buildApp() => ProviderScope(
    overrides: [
      debugTableControllerProvider.overrideWithValue(controller),
      skinLoaderProvider.overrideWithValue(_ReadyLoader()),
    ],
    child: const MaterialApp(home: DebugToolbarScreen()),
  );

  testWidgets('renders table setup with player-count + presets', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());

    expect(find.text('Table Setup'), findsOneWidget);
    expect(find.byKey(const Key('debug-player-count')), findsOneWidget);
    // 5-player presets from RoleConfig (Base-Game-Only) are shown.
    expect(find.text('Starter'), findsOneWidget);
  });

  testWidgets(
    'creating a table reveals the perspective switcher with true roles',
    (tester) async {
      when(
        () => controller.createTable(
          playerNames: any(named: 'playerNames'),
          roleCounts: any(named: 'roleCounts'),
          playerRolesByName: any(named: 'playerRolesByName'),
          centerCards: any(named: 'centerCards'),
        ),
      ).thenAnswer((_) async => _table);

      await tester.pumpWidget(buildApp());

      // Select a preset (enables Create Table) then create.
      await tester.tap(find.text('Starter'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('debug-create-table')));
      await tester.pumpAndSettle();

      // Perspective switcher lists players with their true (debug-only) roles.
      expect(find.text('Perspective'), findsOneWidget);
      expect(find.textContaining('Alice'), findsWidgets);
      expect(find.textContaining('Werewolf'), findsWidgets);
      expect(find.byKey(const Key('debug-switch-2')), findsOneWidget);
    },
  );

  testWidgets('tapping Become switches perspective via the controller', (
    tester,
  ) async {
    when(
      () => controller.createTable(
        playerNames: any(named: 'playerNames'),
        roleCounts: any(named: 'roleCounts'),
        playerRolesByName: any(named: 'playerRolesByName'),
        centerCards: any(named: 'centerCards'),
      ),
    ).thenAnswer((_) async => _table);
    when(() => controller.switchTo(any())).thenAnswer((_) async {});

    await tester.pumpWidget(buildApp());
    await tester.tap(find.text('Starter'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('debug-create-table')));
    await tester.pumpAndSettle();

    final switchBtn = find.byKey(const Key('debug-switch-2'));
    await tester.ensureVisible(switchBtn);
    await tester.pumpAndSettle();
    await tester.tap(switchBtn);
    await tester.pumpAndSettle();

    final captured = verify(() => controller.switchTo(captureAny())).captured;
    expect((captured.single as DebugPlayer).userId, 2);
  });

  testWidgets('god panel refresh reads the oracle', (tester) async {
    when(
      () => controller.createTable(
        playerNames: any(named: 'playerNames'),
        roleCounts: any(named: 'roleCounts'),
        playerRolesByName: any(named: 'playerRolesByName'),
        centerCards: any(named: 'centerCards'),
      ),
    ).thenAnswer((_) async => _table);
    when(() => controller.oracle()).thenThrow(Exception('no backend'));

    await tester.pumpWidget(buildApp());
    await tester.tap(find.text('Starter'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('debug-create-table')));
    await tester.pumpAndSettle();

    final refreshBtn = find.byKey(const Key('debug-refresh-oracle'));
    await tester.ensureVisible(refreshBtn);
    await tester.pumpAndSettle();
    await tester.tap(refreshBtn);
    await tester.pumpAndSettle();

    verify(() => controller.oracle()).called(1);
  });

  testWidgets('the skin toggle switches the look and remembers it', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DebugToolbarScreen)),
    );
    expect(container.read(skinChoiceProvider), SkinId.shadowPaper);

    await tester.ensureVisible(find.text('Night print'));
    await tester.tap(find.text('Night print'));
    await tester.pumpAndSettle();

    expect(container.read(skinChoiceProvider), SkinId.nightPrint);
    expect(
      (await SharedPreferences.getInstance()).getString('skin'),
      SkinId.nightPrint.name,
    );
  });
}
