import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/debug/debug_models.dart';
import 'package:midnight_village/core/debug/debug_providers.dart';
import 'package:midnight_village/core/debug/debug_table_controller.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';
import 'package:midnight_village/features/debug/presentation/debug_toolbar_screen.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockController extends Mock implements DebugTableController {}

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
    overrides: [debugTableControllerProvider.overrideWithValue(controller)],
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
          protocolTwo: any(named: 'protocolTwo'),
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

  testWidgets('a table is protocol 2 (v2) unless the switch is turned off', (
    tester,
  ) async {
    when(
      () => controller.createTable(
        playerNames: any(named: 'playerNames'),
        roleCounts: any(named: 'roleCounts'),
        playerRolesByName: any(named: 'playerRolesByName'),
        centerCards: any(named: 'centerCards'),
        protocolTwo: any(named: 'protocolTwo'),
      ),
    ).thenAnswer((_) async => _table);

    await tester.pumpWidget(buildApp());
    await tester.tap(find.text('Starter'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('debug-create-table')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('debug-protocol-two')));
    await tester.tap(find.byKey(const Key('debug-protocol-two')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('debug-create-table')));
    await tester.tap(find.byKey(const Key('debug-create-table')));
    await tester.pumpAndSettle();

    final made = verify(
      () => controller.createTable(
        playerNames: any(named: 'playerNames'),
        roleCounts: any(named: 'roleCounts'),
        playerRolesByName: any(named: 'playerRolesByName'),
        centerCards: any(named: 'centerCards'),
        protocolTwo: captureAny(named: 'protocolTwo'),
      ),
    ).captured;
    expect(made, [true, false]);
  });

  testWidgets('tapping Become switches perspective via the controller', (
    tester,
  ) async {
    when(
      () => controller.createTable(
        playerNames: any(named: 'playerNames'),
        roleCounts: any(named: 'roleCounts'),
        playerRolesByName: any(named: 'playerRolesByName'),
        centerCards: any(named: 'centerCards'),
        protocolTwo: any(named: 'protocolTwo'),
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
        protocolTwo: any(named: 'protocolTwo'),
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

  testWidgets('"Reset learned cues" makes this device a newcomer again', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DebugToolbarScreen)),
    );
    await container.read(learnedCuesProvider.notifier).learn(Cue.hold);
    expect(container.read(learnedCuesProvider), {Cue.hold});

    final reset = find.byKey(const Key('debug-forget-cues'));
    await tester.ensureVisible(reset);
    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(container.read(learnedCuesProvider), isEmpty);
  });
}
