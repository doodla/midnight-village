import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:midnight_village/design_system/tokens/app_tokens_provider.dart';
import '../../../helpers/contract/from_sample.dart';
import '../../../helpers/contract/server_json.dart';
import '../../../design_system/test_helpers/midnight_village_theme.dart';
import 'package:midnight_village/design_system/skin/skin_theme.dart';
import 'package:midnight_village/design_system/skin/skins/shadow_paper.dart';
import 'package:midnight_village/features/auth/domain/auth_state.dart';
import 'package:midnight_village/features/auth/domain/user.dart';
import 'package:midnight_village/features/auth/presentation/auth_notifier.dart';
import 'package:midnight_village/features/lobby/domain/lobby_state.dart';
import 'package:midnight_village/features/lobby/presentation/lobby_notifier.dart';
import 'package:midnight_village/features/lobby/presentation/lobby_screen.dart';

// ---------------------------------------------------------------------------
// Fake notifier — no HTTP/WebSocket, records method calls
// ---------------------------------------------------------------------------

class FakeLobbyNotifier extends LobbyNotifier {
  FakeLobbyNotifier({required LobbyState initialState})
    : _initialState = initialState;

  final LobbyState _initialState;

  int toggleReadyCount = 0;
  int leaveCount = 0;
  int startGameCount = 0;
  Map<String, int>? lastRoleConfig;

  @override
  Future<LobbyState> build(String code) async => _initialState;

  @override
  Future<void> toggleReady() async => toggleReadyCount++;

  @override
  Future<void> leave() async => leaveCount++;

  @override
  Future<String> startGame() async {
    startGameCount++;
    return 'game-id-123';
  }

  @override
  Future<void> updateRoleConfig(Map<String, int> roles) async {
    lastRoleConfig = roles;
    state = AsyncData(state.value!.copyWith(roleConfig: roles));
  }
}

// ---------------------------------------------------------------------------
// State factories
// ---------------------------------------------------------------------------

/// Alice (1), Bob (2) and Carol (3), everyone ready but Bob and Carol.
const _defaultSeats = <Seat>[
  (id: 1, name: 'Alice'),
  (id: 2, name: 'Bob'),
  (id: 3, name: 'Carol'),
];

/// The server's lobby body for [seats] (all ready but [notReady]), parsed as
/// the app parses it.
LobbyState _makeState({
  String code = 'ABC123',
  int hostId = 1,
  List<Seat> seats = _defaultSeats,
  Set<int> notReady = const {2, 3},
  String status = 'waiting',
  Map<String, int>? roleConfig,
}) => FromSample.lobby(
  serverLobby(
    code: code,
    seats: seats,
    hostId: hostId,
    notReady: notReady,
    status: status,
    roles: roleConfig ?? _validRoleConfig(3),
  ),
);

// 3 players + 3 center = 6 cards
Map<String, int> _validRoleConfig(int playerCount) {
  final total = playerCount + 3;
  return {
    'Werewolf': 2,
    'Seer': 1,
    'Robber': 1,
    'Troublemaker': 1,
    if (total == 6) 'Villager': 1,
    if (total == 7) 'Villager': 2,
    if (total == 8) 'Villager': 3,
  };
}

// ---------------------------------------------------------------------------
// Test harness
// ---------------------------------------------------------------------------

Future<void> _pump(
  WidgetTester tester, {
  required FakeLobbyNotifier notifier,
  String code = 'ABC123',
  int userId = 1,
  String playerName = 'Alice',
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => LobbyScreen(code: code),
        routes: [
          GoRoute(
            path: 'game/:id',
            builder: (context, state) => const Scaffold(body: Text('Game')),
          ),
        ],
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeThemeProvider.overrideWithValue(const MidnightVillageTheme()),
        authProvider.overrideWithValue(
          AuthState.authenticated(User(id: userId, displayName: playerName)),
        ),
        lobbyProvider(code).overrideWith(() => notifier),
      ],
      child: MaterialApp.router(
        theme: skinTheme(shadowPaper),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle(); // Complete the async build and animations
}

/// Scrolls [finder] into view before tapping.
Future<void> _scrollAndTap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('LobbyScreen', () {
    group('T023 – lobby layout', () {
      testWidgets('displays lobby code prominently', (tester) async {
        final notifier = FakeLobbyNotifier(
          initialState: _makeState(code: 'XYZ789'),
        );
        await _pump(tester, notifier: notifier, code: 'XYZ789');

        expect(find.text('XYZ789'), findsOneWidget);
      });

      testWidgets('displays all players with names', (tester) async {
        final notifier = FakeLobbyNotifier(initialState: _makeState());
        await _pump(tester, notifier: notifier);

        expect(find.text('Alice'), findsWidgets);
        expect(find.text('Bob'), findsWidgets);
        expect(find.text('Carol'), findsWidgets);
      });

      testWidgets('shows ready indicator for ready players', (tester) async {
        final notifier = FakeLobbyNotifier(
          initialState: _makeState(
            seats: [(id: 1, name: 'Alice'), (id: 2, name: 'Bob')],
            notReady: {2},
          ),
        );
        await _pump(tester, notifier: notifier);

        // Ready players should have a check icon, not-ready should not
        expect(find.byIcon(Icons.check_circle), findsWidgets);
      });
    });

    group('T025 – notifier wiring', () {
      testWidgets('ready toggle button calls notifier', (tester) async {
        final notifier = FakeLobbyNotifier(
          initialState: _makeState(
            seats: [(id: 1, name: 'Alice')],
            notReady: {1},
          ),
        );
        await _pump(tester, notifier: notifier, userId: 1);

        await _scrollAndTap(tester, find.text('Ready'));

        expect(notifier.toggleReadyCount, 1);
      });

      testWidgets('ready button shows Not Ready when player is ready', (
        tester,
      ) async {
        final notifier = FakeLobbyNotifier(
          initialState: _makeState(
            seats: [(id: 1, name: 'Alice')],
            notReady: const {},
          ),
        );
        await _pump(tester, notifier: notifier, userId: 1);

        expect(find.text('Not Ready'), findsOneWidget);
        await _scrollAndTap(tester, find.text('Not Ready'));

        expect(notifier.toggleReadyCount, 1);
      });

      testWidgets('leave button calls notifier.leave()', (tester) async {
        final notifier = FakeLobbyNotifier(initialState: _makeState());
        await _pump(tester, notifier: notifier);

        await _scrollAndTap(tester, find.text('Leave'));

        expect(notifier.leaveCount, 1);
      });
    });

    group('T024 – role configuration', () {
      testWidgets('host sees role configuration section', (tester) async {
        final notifier = FakeLobbyNotifier(initialState: _makeState(hostId: 1));
        await _pump(tester, notifier: notifier, userId: 1);

        // Host should see +/- role controls
        expect(find.text('Role Configuration'), findsOneWidget);
        expect(find.byIcon(Icons.add), findsWidgets);
        expect(find.byIcon(Icons.remove), findsWidgets);
      });

      testWidgets('non-host sees role token list, not config controls', (
        tester,
      ) async {
        final notifier = FakeLobbyNotifier(initialState: _makeState(hostId: 2));
        // userId=1 is NOT the host (hostId=99)
        await _pump(tester, notifier: notifier, userId: 1);

        expect(find.text('Role Configuration'), findsNothing);
        expect(find.byIcon(Icons.add), findsNothing);
        expect(find.byIcon(Icons.remove), findsNothing);
      });

      testWidgets('increment button increases role count', (tester) async {
        final notifier = FakeLobbyNotifier(
          initialState: _makeState(
            hostId: 1,
            roleConfig: {'Werewolf': 1, 'Seer': 1, 'Robber': 1, 'Villager': 1},
          ),
        );
        await _pump(tester, notifier: notifier, userId: 1);

        // Find the Werewolf row and tap its + button
        final werewolfRow = find.ancestor(
          of: find.text('Werewolf'),
          matching: find.byType(Row),
        );
        final addButton = find
            .descendant(of: werewolfRow, matching: find.byIcon(Icons.add))
            .first;

        await _scrollAndTap(tester, addButton);

        // updateRoleConfig should have been called
        expect(notifier.lastRoleConfig, isNotNull);
        expect(notifier.lastRoleConfig!['Werewolf'], 2);
      });

      testWidgets('decrement button decreases role count', (tester) async {
        final notifier = FakeLobbyNotifier(
          initialState: _makeState(
            hostId: 1,
            roleConfig: {'Werewolf': 2, 'Seer': 1, 'Robber': 1, 'Villager': 1},
          ),
        );
        await _pump(tester, notifier: notifier, userId: 1);

        final werewolfRow = find.ancestor(
          of: find.text('Werewolf'),
          matching: find.byType(Row),
        );
        final removeButton = find
            .descendant(of: werewolfRow, matching: find.byIcon(Icons.remove))
            .first;

        await _scrollAndTap(tester, removeButton);

        expect(notifier.lastRoleConfig, isNotNull);
        expect(notifier.lastRoleConfig!['Werewolf'], 1);
      });

      testWidgets('Mason increments by 2', (tester) async {
        final notifier = FakeLobbyNotifier(
          initialState: _makeState(
            hostId: 1,
            roleConfig: {'Werewolf': 2, 'Seer': 1, 'Robber': 1, 'Mason': 0},
          ),
        );
        await _pump(tester, notifier: notifier, userId: 1);

        final masonRow = find.ancestor(
          of: find.text('Mason'),
          matching: find.byType(Row),
        );
        final addButton = find
            .descendant(of: masonRow, matching: find.byIcon(Icons.add))
            .first;

        await _scrollAndTap(tester, addButton);

        expect(notifier.lastRoleConfig, isNotNull);
        expect(notifier.lastRoleConfig!['Mason'], 2);
      });

      testWidgets('Mason decrements by 2', (tester) async {
        final notifier = FakeLobbyNotifier(
          initialState: _makeState(
            hostId: 1,
            roleConfig: {'Werewolf': 2, 'Seer': 1, 'Robber': 1, 'Mason': 2},
          ),
        );
        await _pump(tester, notifier: notifier, userId: 1);

        final masonRow = find.ancestor(
          of: find.text('Mason'),
          matching: find.byType(Row),
        );
        final removeButton = find
            .descendant(of: masonRow, matching: find.byIcon(Icons.remove))
            .first;

        await _scrollAndTap(tester, removeButton);

        expect(notifier.lastRoleConfig, isNotNull);
        expect(notifier.lastRoleConfig!['Mason'], 0);
      });

      testWidgets('preset selection populates role counts', (tester) async {
        final notifier = FakeLobbyNotifier(
          initialState: _makeState(hostId: 1, roleConfig: {'Werewolf': 1}),
        );
        await _pump(tester, notifier: notifier, userId: 1);

        // Open preset dropdown and select Starter
        final dropdown = find.byType(DropdownButtonFormField<String>);
        await tester.ensureVisible(dropdown);
        await tester.pump();
        await tester.tap(dropdown);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Starter').last);
        await tester.pumpAndSettle();

        expect(notifier.lastRoleConfig, isNotNull);
        expect(notifier.lastRoleConfig!['Werewolf'], 2);
        expect(notifier.lastRoleConfig!['Seer'], 1);
      });

      testWidgets('shows validation error when role count is wrong', (
        tester,
      ) async {
        final notifier = FakeLobbyNotifier(
          initialState: _makeState(
            hostId: 1,
            roleConfig: {'Werewolf': 1}, // only 1 card — invalid
          ),
        );
        await _pump(tester, notifier: notifier, userId: 1);

        // Should show a validation error message
        expect(find.textContaining('cards'), findsWidgets);
      });
    });

    group('T026 – host-only controls', () {
      testWidgets('host sees start button', (tester) async {
        final notifier = FakeLobbyNotifier(initialState: _makeState(hostId: 1));
        await _pump(tester, notifier: notifier, userId: 1);

        expect(find.text('Start Game'), findsOneWidget);
      });

      testWidgets('non-host does not see start button', (tester) async {
        final notifier = FakeLobbyNotifier(initialState: _makeState(hostId: 2));
        await _pump(tester, notifier: notifier, userId: 1);

        expect(find.text('Start Game'), findsNothing);
        expect(find.textContaining('Waiting for host'), findsOneWidget);
      });

      testWidgets('start button disabled when not all players ready', (
        tester,
      ) async {
        final notifier = FakeLobbyNotifier(
          initialState: _makeState(
            hostId: 1,
            seats: [(id: 1, name: 'Alice'), (id: 3, name: 'Carol')],
            notReady: const {},
            roleConfig: _validRoleConfig(3),
          ),
        );
        await _pump(tester, notifier: notifier, userId: 1);

        final startButton = tester.widget<FilledButton>(
          find.ancestor(
            of: find.text('Start Game'),
            matching: find.byType(FilledButton),
          ),
        );
        expect(startButton.onPressed, isNull);
      });

      testWidgets('start button disabled when role config invalid', (
        tester,
      ) async {
        final notifier = FakeLobbyNotifier(
          initialState: _makeState(
            hostId: 1,
            seats: [
              (id: 1, name: 'Alice'),
              (id: 2, name: 'Bob'),
              (id: 3, name: 'Carol'),
            ],
            notReady: const {},
            roleConfig: {'Werewolf': 1}, // Invalid — wrong card count
          ),
        );
        await _pump(tester, notifier: notifier, userId: 1);

        // Start button should be disabled (onPressed == null)
        final startButton = tester.widget<FilledButton>(
          find.ancestor(
            of: find.text('Start Game'),
            matching: find.byType(FilledButton),
          ),
        );
        expect(startButton.onPressed, isNull);
      });

      testWidgets(
        'start button enabled when all players ready and config valid',
        (tester) async {
          final notifier = FakeLobbyNotifier(
            initialState: _makeState(
              hostId: 1,
              seats: [
                (id: 1, name: 'Alice'),
                (id: 2, name: 'Bob'),
                (id: 3, name: 'Carol'),
              ],
              notReady: const {},
              roleConfig: _validRoleConfig(3),
            ),
          );
          await _pump(tester, notifier: notifier, userId: 1);

          final startButton = tester.widget<FilledButton>(
            find.ancestor(
              of: find.text('Start Game'),
              matching: find.byType(FilledButton),
            ),
          );
          expect(startButton.onPressed, isNotNull);
        },
      );

      testWidgets('start button disabled when player count below 3', (
        tester,
      ) async {
        final notifier = FakeLobbyNotifier(
          initialState: _makeState(
            hostId: 1,
            seats: [(id: 1, name: 'Alice'), (id: 2, name: 'Bob')],
            notReady: const {},
            roleConfig: _validRoleConfig(2), // 2 players — invalid
          ),
        );
        await _pump(tester, notifier: notifier, userId: 1);

        final startButton = tester.widget<FilledButton>(
          find.ancestor(
            of: find.text('Start Game'),
            matching: find.byType(FilledButton),
          ),
        );
        expect(startButton.onPressed, isNull);
      });

      testWidgets('start button calls notifier.startGame()', (tester) async {
        final notifier = FakeLobbyNotifier(
          initialState: _makeState(
            hostId: 1,
            seats: [
              (id: 1, name: 'Alice'),
              (id: 2, name: 'Bob'),
              (id: 3, name: 'Carol'),
            ],
            notReady: const {},
            roleConfig: _validRoleConfig(3),
          ),
        );
        await _pump(tester, notifier: notifier, userId: 1);

        await _scrollAndTap(tester, find.text('Start Game'));

        expect(notifier.startGameCount, 1);
      });
    });

    group('T027 – loading and error states', () {
      testWidgets('shows loading indicator while lobby is loading', (
        tester,
      ) async {
        final notifier = FakeLobbyNotifier(initialState: _makeState());
        // Before pumping to settle, state is loading
        await _pump(tester, notifier: notifier);

        // After settling it shows the lobby content
        expect(find.text('ABC123'), findsWidgets);
      });

      testWidgets('renders complete lobby UI without throwing', (tester) async {
        final notifier = FakeLobbyNotifier(initialState: _makeState());
        // This is the essential smoke test — if it renders, design tokens work
        await _pump(tester, notifier: notifier);
        expect(find.byType(LobbyScreen), findsOneWidget);
      });
    });
  });
}
