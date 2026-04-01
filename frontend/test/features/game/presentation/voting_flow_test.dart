import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/api/authenticated_client.dart';
import 'package:midnight_village/design_system/components/game/vote_submission.dart';
import 'package:midnight_village/features/auth/presentation/auth_notifier.dart';
import 'package:midnight_village/features/game/data/game_service.dart';
import 'package:midnight_village/features/game/domain/game_session_state.dart';
import 'package:midnight_village/features/game/domain/voting_state.dart';
import 'package:midnight_village/features/game/presentation/game_container_screen.dart';
import 'package:midnight_village/features/game/presentation/game_notifier.dart';

import '../../../design_system/test_helpers/pump_with_tokens.dart';
import '../../../helpers/mock_http_client.dart';
import '../../../helpers/mock_websocket.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Default state for voting phase tests.
GameSessionState _votingState({
  bool hasVoted = false,
  VoteProgress voteProgress = const VoteProgress(),
  VoteRevealData? voteRevealData,
}) => GameSessionState(
  gameId: 'test-game-id',
  phase: 'voting',
  yourRole: const YourRole(originalRole: 'seer', hasActed: false),
  hasVoted: hasVoted,
  players: const [
    GamePlayer(playerId: 1, displayName: 'Alice'),
    GamePlayer(playerId: 2, displayName: 'Bob'),
    GamePlayer(playerId: 3, displayName: 'Charlie'),
  ],
  voteProgress: voteProgress,
  voteRevealData: voteRevealData,
);

/// A mock GameNotifier that allows tracking of method calls.
class _MockVotingNotifier extends GameNotifier {
  _MockVotingNotifier(this._state);

  final AsyncValue<GameSessionState> _state;

  /// Records the targetPlayerId passed to submitVote.
  int? lastVoteTarget;

  @override
  Future<GameSessionState> build(String gameId) async {
    state = _state;
    return _state.value ??
        GameSessionState(
          gameId: gameId,
          phase: 'voting',
          yourRole: const YourRole(originalRole: 'seer', hasActed: false),
          players: const [],
        );
  }

  @override
  Future<void> submitVote(int targetPlayerId) async {
    lastVoteTarget = targetPlayerId;
    // Optimistically mark as voted in state.
    final current = state.value;
    if (current != null) {
      state = AsyncData(
        current.copyWith(
          hasVoted: true,
          voteProgress: current.voteProgress.copyWith(currentPlayerVoted: true),
        ),
      );
    }
  }
}

void main() {
  group('Voting phase — VoteSubmission wiring', () {
    testWidgets('renders VoteSubmission widget in voting phase', (
      tester,
    ) async {
      final mockNotifier = _MockVotingNotifier(AsyncData(_votingState()));

      await tester.pumpWithTokens(
        const GameContainerScreen(gameId: 'test-game-id'),
        overrides: [
          gameProvider('test-game-id').overrideWith(() => mockNotifier),
        ],
      );

      expect(find.byType(VoteSubmission), findsOneWidget);
    });

    testWidgets('VoteSubmission shows all players', (tester) async {
      final mockNotifier = _MockVotingNotifier(AsyncData(_votingState()));

      await tester.pumpWithTokens(
        const GameContainerScreen(gameId: 'test-game-id'),
        overrides: [
          gameProvider('test-game-id').overrideWith(() => mockNotifier),
        ],
      );

      // Alice, Bob, and Charlie should appear as vote targets.
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Charlie'), findsOneWidget);
    });

    testWidgets(
      'tapping player and confirming calls submitVote with player id',
      (tester) async {
        final mockNotifier = _MockVotingNotifier(AsyncData(_votingState()));

        await tester.pumpWithTokens(
          const GameContainerScreen(gameId: 'test-game-id'),
          overrides: [
            gameProvider('test-game-id').overrideWith(() => mockNotifier),
          ],
        );

        // Select a player by tapping their name.
        await tester.tap(find.text('Alice'));
        await tester.pumpAndSettle();

        // Confirm the vote.
        await tester.tap(find.text('Lock in your vote'));
        await tester.pumpAndSettle();

        expect(mockNotifier.lastVoteTarget, 1); // Alice's playerId is 1.
      },
    );

    testWidgets('shows locked state after voting', (tester) async {
      final mockNotifier = _MockVotingNotifier(
        AsyncData(_votingState(hasVoted: true)),
      );

      await tester.pumpWithTokens(
        const GameContainerScreen(gameId: 'test-game-id'),
        overrides: [
          gameProvider('test-game-id').overrideWith(() => mockNotifier),
        ],
      );

      // Locked state shows "Vote submitted" confirmation.
      expect(find.text('Vote submitted'), findsOneWidget);
    });
  });

  group('Voting phase — vote progress display', () {
    testWidgets('shows vote progress count "X of Y voted"', (tester) async {
      final mockNotifier = _MockVotingNotifier(
        AsyncData(
          _votingState(
            voteProgress: const VoteProgress(playerVoted: {1: true, 2: true}),
          ),
        ),
      );

      await tester.pumpWithTokens(
        const GameContainerScreen(gameId: 'test-game-id'),
        overrides: [
          gameProvider('test-game-id').overrideWith(() => mockNotifier),
        ],
      );

      // 2 of 3 players have voted.
      expect(find.text('2 of 3 voted'), findsOneWidget);
    });

    testWidgets('shows 0 voted when no one has voted yet', (tester) async {
      final mockNotifier = _MockVotingNotifier(AsyncData(_votingState()));

      await tester.pumpWithTokens(
        const GameContainerScreen(gameId: 'test-game-id'),
        overrides: [
          gameProvider('test-game-id').overrideWith(() => mockNotifier),
        ],
      );

      expect(find.text('0 of 3 voted'), findsOneWidget);
    });
  });

  group('Vote reveal flow — intermediate tally', () {
    testWidgets('shows intermediate tally when voteRevealData is present', (
      tester,
    ) async {
      final voteReveal = VoteRevealData(
        votes: {'1': 2, '2': 3, '3': null},
        tally: {'2': 1, '3': 2},
      );

      final mockNotifier = _MockVotingNotifier(
        AsyncData(_votingState(voteRevealData: voteReveal)),
      );

      await tester.pumpWithTokens(
        const GameContainerScreen(gameId: 'test-game-id'),
        overrides: [
          gameProvider('test-game-id').overrideWith(() => mockNotifier),
        ],
      );

      // Should show "Votes" heading in the intermediate tally.
      expect(find.text('Votes'), findsOneWidget);
    });

    testWidgets('displays voter-to-target pairs in intermediate tally', (
      tester,
    ) async {
      final voteReveal = VoteRevealData(
        votes: {'1': 2, '2': 3},
        tally: {'2': 1, '3': 1},
      );

      final mockNotifier = _MockVotingNotifier(
        AsyncData(_votingState(voteRevealData: voteReveal)),
      );

      await tester.pumpWithTokens(
        const GameContainerScreen(gameId: 'test-game-id'),
        overrides: [
          gameProvider('test-game-id').overrideWith(() => mockNotifier),
        ],
      );

      // Alice (1) voted for Bob (2).
      expect(find.text('Alice voted for Bob'), findsOneWidget);
      // Bob (2) voted for Charlie (3).
      expect(find.text('Bob voted for Charlie'), findsOneWidget);
    });

    testWidgets('abstaining players show "Abstained" in tally', (tester) async {
      final voteReveal = VoteRevealData(votes: {'3': null}, tally: {});

      final mockNotifier = _MockVotingNotifier(
        AsyncData(_votingState(voteRevealData: voteReveal)),
      );

      await tester.pumpWithTokens(
        const GameContainerScreen(gameId: 'test-game-id'),
        overrides: [
          gameProvider('test-game-id').overrideWith(() => mockNotifier),
        ],
      );

      // Charlie (3) abstained.
      expect(find.text('Charlie abstained'), findsOneWidget);
    });

    testWidgets(
      'does not show VoteReveal widget while in voting phase (no elimination data)',
      (tester) async {
        // VoteRevealData is present but phase is still 'voting' — no elimination data.
        final voteReveal = VoteRevealData(votes: {'1': 2}, tally: {'2': 1});

        final mockNotifier = _MockVotingNotifier(
          AsyncData(_votingState(voteRevealData: voteReveal)),
        );

        await tester.pumpWithTokens(
          const GameContainerScreen(gameId: 'test-game-id'),
          overrides: [
            gameProvider('test-game-id').overrideWith(() => mockNotifier),
          ],
        );

        // VoteReveal widget (which shows "No one was eliminated!") must NOT be shown.
        // We check that the elimination section is absent.
        expect(find.text('No one was eliminated!'), findsNothing);
      },
    );
  });

  group('Vote reveal — 5-second REST fallback timeout', () {
    /// Default voting-phase JSON for the timeout test.
    Map<String, dynamic> votingPhaseJsonForTimeout() => {
      'game_id': 'test-game-id',
      'phase': 'voting',
      'current_wave': 0,
      'deadline': null,
      'your_role': {'original_role': 'seer', 'has_acted': false},
      'has_voted': false,
      'players': [
        {'player_id': 1, 'display_name': 'Alice'},
        {'player_id': 2, 'display_name': 'Bob'},
      ],
      'roles_in_game': [],
    };

    // Flutter widget tests run inside a fakeAsync zone, so tester.pump()
    // advances fake time. This lets us fire the 5-second Timer in
    // _handleVoteReveal without a real wall-clock delay.
    testWidgets(
      '5-second fallback transitions to results phase when game_results is missed',
      (tester) async {
        final http = MockHttpClient();
        final ws = MockWebSocketChannel();

        http
            .when(method: 'GET', path: '/onuw/games/test-game-id/me/')
            .thenReturn(
              Response(
                requestOptions: RequestOptions(
                  path: '/onuw/games/test-game-id/me/',
                ),
                statusCode: 200,
                data: votingPhaseJsonForTimeout(),
              ),
            );

        // Register the results endpoint that the fallback will call.
        http
            .when(method: 'GET', path: '/onuw/games/test-game-id/results/')
            .thenReturn(
              Response(
                requestOptions: RequestOptions(
                  path: '/onuw/games/test-game-id/results/',
                ),
                statusCode: 200,
                data: {
                  'winning_teams': ['village'],
                  'players': [],
                },
              ),
            );

        final client = AuthenticatedClient.forTesting(dio: http.dio);

        await tester.pumpWithTokens(
          const GameContainerScreen(gameId: 'test-game-id'),
          overrides: [
            authenticatedClientProvider.overrideWithValue(client),
            gameServiceProvider.overrideWithValue(GameService(client: client)),
            gameWebSocketStreamProvider.overrideWith(
              (ref, gameId) => ws.stream,
            ),
          ],
        );

        // Wait for the initial voting phase to load.
        await tester.pumpAndSettle();
        expect(find.text('0 of 2 voted'), findsOneWidget);

        // Inject vote_reveal — this starts the 5-second timeout inside
        // GameNotifier._handleVoteReveal.
        ws.addServerEvent(
          jsonEncode({
            'type': 'vote_reveal',
            'votes': {'1': 2},
          }),
        );
        await tester.pump();

        // Intermediate tally is now visible.
        expect(find.text('Votes'), findsOneWidget);

        // Advance time by 5 seconds. tester.pump() advances Flutter's fake
        // clock, firing any pending Timers — including the 5-second fallback.
        await tester.pump(const Duration(seconds: 5));

        // Allow the async _fetchResultsFallback chain to complete.
        await tester.pumpAndSettle();

        // The GameContainerScreen shows the results placeholder when phase
        // transitions to 'results'. 'Results' appears in the PhaseIndicator.
        expect(find.text('Results'), findsWidgets);
      },
    );
  });

  group('Voting phase — vote_submitted WS event integration', () {
    /// Default voting-phase JSON returned by the mock /me/ endpoint.
    Map<String, dynamic> votingPhaseJson() => {
      'game_id': 'test-game-id',
      'phase': 'voting',
      'current_wave': 0,
      'deadline': null,
      'your_role': {'original_role': 'seer', 'has_acted': false},
      'has_voted': false,
      'players': [
        {'player_id': 1, 'display_name': 'Alice'},
        {'player_id': 2, 'display_name': 'Bob'},
        {'player_id': 3, 'display_name': 'Charlie'},
      ],
      'roles_in_game': [],
    };

    testWidgets(
      'vote progress counter increments when vote_submitted WS event is received',
      (tester) async {
        final http = MockHttpClient();
        final ws = MockWebSocketChannel();

        http
            .when(method: 'GET', path: '/onuw/games/test-game-id/me/')
            .thenReturn(
              Response(
                requestOptions: RequestOptions(
                  path: '/onuw/games/test-game-id/me/',
                ),
                statusCode: 200,
                data: votingPhaseJson(),
              ),
            );

        final client = AuthenticatedClient.forTesting(dio: http.dio);

        await tester.pumpWithTokens(
          const GameContainerScreen(gameId: 'test-game-id'),
          overrides: [
            authenticatedClientProvider.overrideWithValue(client),
            gameServiceProvider.overrideWithValue(GameService(client: client)),
            gameWebSocketStreamProvider.overrideWith(
              (ref, gameId) => ws.stream,
            ),
          ],
        );

        // Wait for initial state to load — shows "0 of 3 voted".
        await tester.pumpAndSettle();
        expect(find.text('0 of 3 voted'), findsOneWidget);

        // Inject vote_submitted event for player 1.
        ws.addServerEvent(
          jsonEncode({'type': 'vote_submitted', 'player_id': 1}),
        );
        await tester.pump();

        // Counter must increment to 1 of 3.
        expect(find.text('1 of 3 voted'), findsOneWidget);

        // Inject a second vote_submitted event for player 2.
        ws.addServerEvent(
          jsonEncode({'type': 'vote_submitted', 'player_id': 2}),
        );
        await tester.pump();

        // Counter must increment to 2 of 3.
        expect(find.text('2 of 3 voted'), findsOneWidget);
      },
    );
  });
}
