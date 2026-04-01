import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/components/game/center_cards.dart';
import 'package:midnight_village/design_system/components/game/night_action_prompt.dart';
import 'package:midnight_village/features/game/domain/game_session_state.dart';
import 'package:midnight_village/features/game/domain/night_state.dart';
import 'package:midnight_village/features/game/presentation/game_container_screen.dart';
import 'package:midnight_village/features/game/presentation/game_notifier.dart';

import '../../../design_system/test_helpers/pump_with_tokens.dart';

/// Creates a GameSessionState with the given phase and nightSubView.
GameSessionState _makeState({
  String phase = 'night',
  NightSubView nightSubView = NightSubView.waiting,
  ActionPrompt? actionPrompt,
  ActionResult? lastActionResult,
}) => GameSessionState(
  gameId: 'test-game-id',
  phase: phase,
  yourRole: const YourRole(originalRole: 'seer', hasActed: false),
  players: const [
    GamePlayer(playerId: 1, displayName: 'Alice'),
    GamePlayer(playerId: 2, displayName: 'Bob'),
  ],
  nightSubView: nightSubView,
  actionPrompt: actionPrompt,
  lastActionResult: lastActionResult,
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

    testWidgets('shows night waiting view for NightSubView.waiting', (
      tester,
    ) async {
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

      // NightWaitingView renders "The village sleeps…"
      expect(find.text('The village sleeps\u2026'), findsOneWidget);
    });

    testWidgets('shows seer choice view for NightSubView.seerChoice', (
      tester,
    ) async {
      final state = _makeState(
        phase: 'night',
        nightSubView: NightSubView.seerChoice,
        actionPrompt: const ActionPrompt(
          roleActingAs: 'Seer',
          actionTypes: ['peek_player', 'peek_center'],
          validTargets: {},
          wave: 1,
        ),
      );
      await tester.pumpWithTokens(
        const GameContainerScreen(gameId: 'test-game-id'),
        overrides: [
          gameProvider(
            'test-game-id',
          ).overrideWith(() => _MockGameNotifier(AsyncData(state))),
        ],
      );

      // SeerChoiceView renders two choice buttons.
      expect(find.text('Look at a player\'s card'), findsOneWidget);
      expect(find.text('Look at two center cards'), findsOneWidget);
    });

    testWidgets('shows NightActionPrompt for NightSubView.actionPrompt', (
      tester,
    ) async {
      final state = _makeState(
        phase: 'night',
        nightSubView: NightSubView.actionPrompt,
        actionPrompt: const ActionPrompt(
          roleActingAs: 'Seer',
          actionTypes: ['peek_player'],
          validTargets: {},
          wave: 1,
        ),
      );
      await tester.pumpWithTokens(
        const GameContainerScreen(gameId: 'test-game-id'),
        overrides: [
          gameProvider(
            'test-game-id',
          ).overrideWith(() => _MockGameNotifier(AsyncData(state))),
        ],
      );

      expect(find.byType(NightActionPrompt), findsOneWidget);
    });

    testWidgets('shows action result view for NightSubView.actionResult', (
      tester,
    ) async {
      final state = _makeState(
        phase: 'night',
        nightSubView: NightSubView.actionResult,
        lastActionResult: const ActionResult(
          wave: 1,
          revealedInfo: {'action_type': 'swap_with_center', 'card_index': 2},
        ),
      );
      await tester.pumpWithTokens(
        const GameContainerScreen(gameId: 'test-game-id'),
        overrides: [
          gameProvider(
            'test-game-id',
          ).overrideWith(() => _MockGameNotifier(AsyncData(state))),
        ],
      );

      // NightResultView for swap_with_center shows confirmation text.
      expect(find.textContaining('center card'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows lone werewolf view for NightSubView.loneWerewolfPeek', (
      tester,
    ) async {
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

      // LoneWerewolfPeekView renders CenterCards.
      expect(find.byType(CenterCards), findsOneWidget);
    });

    testWidgets('shows role reveal view for NightSubView.roleReveal', (
      tester,
    ) async {
      final state = _makeState(
        phase: 'night',
        nightSubView: NightSubView.roleReveal,
      );
      await tester.pumpWithTokens(
        const GameContainerScreen(gameId: 'test-game-id'),
        overrides: [
          gameProvider(
            'test-game-id',
          ).overrideWith(() => _MockGameNotifier(AsyncData(state))),
        ],
      );

      // RoleRevealView renders "You are the" text.
      expect(find.text('You are the'), findsOneWidget);
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

    testWidgets('shows results phase placeholder', (tester) async {
      final state = _makeState(phase: 'results');
      await tester.pumpWithTokens(
        const GameContainerScreen(gameId: 'test-game-id'),
        overrides: [
          gameProvider(
            'test-game-id',
          ).overrideWith(() => _MockGameNotifier(AsyncData(state))),
        ],
      );

      // "Results" appears twice: once in the PhaseIndicator label
      // and once as the placeholder view text.
      expect(find.text('Results'), findsNWidgets(2));
    });

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

    testWidgets(
      'falls back to waiting view when actionPrompt missing for seerChoice',
      (tester) async {
        final state = _makeState(
          phase: 'night',
          nightSubView: NightSubView.seerChoice,
          // No actionPrompt provided — should fall back to waiting view.
        );
        await tester.pumpWithTokens(
          const GameContainerScreen(gameId: 'test-game-id'),
          overrides: [
            gameProvider(
              'test-game-id',
            ).overrideWith(() => _MockGameNotifier(AsyncData(state))),
          ],
        );

        expect(find.text('The village sleeps\u2026'), findsOneWidget);
      },
    );
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
