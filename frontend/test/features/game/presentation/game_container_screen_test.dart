import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/game/domain/game_session_state.dart';
import 'package:midnight_village/features/game/domain/night_state.dart';
import 'package:midnight_village/features/game/presentation/game_container_screen.dart';
import 'package:midnight_village/features/game/presentation/game_notifier.dart';

import '../../../design_system/test_helpers/pump_with_tokens.dart';

/// Creates a GameSessionState with the given phase and nightSubView.
GameSessionState _makeState({
  String phase = 'night',
  NightSubView nightSubView = NightSubView.waiting,
}) => GameSessionState(
  gameId: 'test-game-id',
  phase: phase,
  yourRole: const YourRole(originalRole: 'seer', hasActed: false),
  players: const [
    GamePlayer(playerId: 1, displayName: 'Alice'),
    GamePlayer(playerId: 2, displayName: 'Bob'),
  ],
  nightSubView: nightSubView,
);

void main() {
  group('GameContainerScreen', () {
    testWidgets('shows loading state', (tester) async {
      await tester.pumpWithTokens(
        const GameContainerScreen(gameId: 'test-game-id'),
        overrides: [
          gameProvider(
            'test-game-id',
          ).overrideWith(() => _MockGameNotifier(const AsyncLoading())),
        ],
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error state with retry button', (tester) async {
      await tester.pumpWithTokens(
        const GameContainerScreen(gameId: 'test-game-id'),
        overrides: [
          gameProvider('test-game-id').overrideWith(
            () => _MockGameNotifier(
              AsyncError(Exception('test'), StackTrace.current),
            ),
          ),
        ],
      );

      expect(find.text('Failed to load game'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('shows night waiting placeholder', (tester) async {
      final state = _makeState(
        phase: 'night',
        nightSubView: NightSubView.waiting,
      );
      await tester.pumpWithTokens(
        const GameContainerScreen(gameId: 'test-game-id'),
        overrides: [
          gameProvider(
            'test-game-id',
          ).overrideWith(() => _MockGameNotifier(AsyncData(state))),
        ],
      );

      expect(find.text('Night Waiting'), findsOneWidget);
    });

    testWidgets('shows seer choice placeholder', (tester) async {
      final state = _makeState(
        phase: 'night',
        nightSubView: NightSubView.seerChoice,
      );
      await tester.pumpWithTokens(
        const GameContainerScreen(gameId: 'test-game-id'),
        overrides: [
          gameProvider(
            'test-game-id',
          ).overrideWith(() => _MockGameNotifier(AsyncData(state))),
        ],
      );

      expect(find.text('Seer Choice'), findsOneWidget);
    });

    testWidgets('shows night action placeholder', (tester) async {
      final state = _makeState(
        phase: 'night',
        nightSubView: NightSubView.actionPrompt,
      );
      await tester.pumpWithTokens(
        const GameContainerScreen(gameId: 'test-game-id'),
        overrides: [
          gameProvider(
            'test-game-id',
          ).overrideWith(() => _MockGameNotifier(AsyncData(state))),
        ],
      );

      expect(find.text('Night Action'), findsOneWidget);
    });

    testWidgets('shows action result placeholder', (tester) async {
      final state = _makeState(
        phase: 'night',
        nightSubView: NightSubView.actionResult,
      );
      await tester.pumpWithTokens(
        const GameContainerScreen(gameId: 'test-game-id'),
        overrides: [
          gameProvider(
            'test-game-id',
          ).overrideWith(() => _MockGameNotifier(AsyncData(state))),
        ],
      );

      expect(find.text('Action Result'), findsOneWidget);
    });

    testWidgets('shows lone werewolf peek placeholder', (tester) async {
      final state = _makeState(
        phase: 'night',
        nightSubView: NightSubView.loneWerewolfPeek,
      );
      await tester.pumpWithTokens(
        const GameContainerScreen(gameId: 'test-game-id'),
        overrides: [
          gameProvider(
            'test-game-id',
          ).overrideWith(() => _MockGameNotifier(AsyncData(state))),
        ],
      );

      expect(find.text('Lone Werewolf Peek'), findsOneWidget);
    });

    testWidgets('shows discussion phase placeholder', (tester) async {
      final state = _makeState(phase: 'discussion');
      await tester.pumpWithTokens(
        const GameContainerScreen(gameId: 'test-game-id'),
        overrides: [
          gameProvider(
            'test-game-id',
          ).overrideWith(() => _MockGameNotifier(AsyncData(state))),
        ],
      );

      expect(find.text('Discussion Phase'), findsOneWidget);
    });

    testWidgets('shows voting phase placeholder', (tester) async {
      final state = _makeState(phase: 'voting');
      await tester.pumpWithTokens(
        const GameContainerScreen(gameId: 'test-game-id'),
        overrides: [
          gameProvider(
            'test-game-id',
          ).overrideWith(() => _MockGameNotifier(AsyncData(state))),
        ],
      );

      expect(find.text('Voting Phase'), findsOneWidget);
    });

    testWidgets(
      'shows "Loading results..." when results is null in results phase',
      (tester) async {
        final state = _makeState(phase: 'results');
        await tester.pumpWithTokens(
          const GameContainerScreen(gameId: 'test-game-id'),
          overrides: [
            gameProvider(
              'test-game-id',
            ).overrideWith(() => _MockGameNotifier(AsyncData(state))),
          ],
        );

        // PhaseIndicator still shows 'Results' label.
        expect(find.text('Results'), findsOneWidget);
        // Placeholder shown while waiting for results data.
        expect(find.text('Loading results...'), findsOneWidget);
      },
    );

    testWidgets('shows PhaseIndicator when in data state', (tester) async {
      final state = _makeState(phase: 'discussion');
      await tester.pumpWithTokens(
        const GameContainerScreen(gameId: 'test-game-id'),
        overrides: [
          gameProvider(
            'test-game-id',
          ).overrideWith(() => _MockGameNotifier(AsyncData(state))),
        ],
      );

      // PhaseIndicator renders abbreviated phase names.
      expect(find.text('Disc.'), findsOneWidget);
      expect(find.text('Night'), findsOneWidget);
    });
  });
}

/// A mock GameNotifier that returns a fixed state.
class _MockGameNotifier extends GameNotifier {
  _MockGameNotifier(this._initialState);

  final AsyncValue<GameSessionState> _initialState;

  @override
  Future<GameSessionState> build(String gameId) async {
    state = _initialState;
    return _initialState.value ??
        GameSessionState(
          gameId: gameId,
          phase: 'night',
          yourRole: const YourRole(originalRole: 'seer', hasActed: false),
          players: const [],
        );
  }
}
