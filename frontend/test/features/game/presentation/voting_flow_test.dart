import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/components/game/vote_submission.dart';
import 'package:midnight_village/features/game/domain/game_session_state.dart';
import 'package:midnight_village/features/game/domain/voting_state.dart';
import 'package:midnight_village/features/game/presentation/game_container_screen.dart';
import 'package:midnight_village/features/game/presentation/game_notifier.dart';

import '../../../design_system/test_helpers/pump_with_tokens.dart';

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
}
