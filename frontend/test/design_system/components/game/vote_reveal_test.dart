import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/components/game/vote_reveal.dart';
import 'package:midnight_village/design_system/models/game_result.dart';
import 'package:midnight_village/design_system/tokens/app_tokens_provider.dart';
import 'package:midnight_village/design_system/tokens/theme_bridge.dart';

import '../../../design_system/test_helpers/test_theme.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

const _testTheme = TestThemeTokens();

Future<void> _pump(
  WidgetTester tester, {
  required List<VoteResult> votes,
  required Map<String, int> tally,
  List<String> eliminatedPlayerIds = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [activeThemeProvider.overrideWithValue(_testTheme)],
      child: MaterialApp(
        theme: generateThemeData(_testTheme),
        home: Scaffold(
          body: VoteReveal(
            votes: votes,
            tally: tally,
            eliminatedPlayerIds: eliminatedPlayerIds,
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

const _voteAliceBob = VoteResult(
  voterId: 'p1',
  voterName: 'Alice',
  targetId: 'p2',
  targetName: 'Bob',
);

const _voteBobBob = VoteResult(
  voterId: 'p3',
  voterName: 'Carol',
  targetId: 'p2',
  targetName: 'Bob',
);

const _voteCarolAlice = VoteResult(
  voterId: 'p2',
  voterName: 'Bob',
  targetId: 'p1',
  targetName: 'Alice',
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // Vote list: individual votes are displayed
  // -------------------------------------------------------------------------

  testWidgets('displays all individual votes', (tester) async {
    await _pump(
      tester,
      votes: [_voteAliceBob, _voteBobBob, _voteCarolAlice],
      tally: {'p2': 2, 'p1': 1},
    );

    expect(find.text('Alice voted for Bob'), findsOneWidget);
    expect(find.text('Carol voted for Bob'), findsOneWidget);
    expect(find.text('Bob voted for Alice'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // Tally: entries appear in descending order by vote count
  // -------------------------------------------------------------------------

  testWidgets('tally entries are shown (both players visible)', (tester) async {
    await _pump(
      tester,
      votes: [_voteAliceBob, _voteBobBob, _voteCarolAlice],
      tally: {'p2': 2, 'p1': 1},
    );

    // Both count values must appear.
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // Tally: most-voted player uses primary token color
  // -------------------------------------------------------------------------

  testWidgets('most-voted player name uses primary token color', (
    tester,
  ) async {
    await _pump(
      tester,
      votes: [_voteAliceBob, _voteBobBob, _voteCarolAlice],
      tally: {'p2': 2, 'p1': 1},
    );

    // TestColorTokens.primary = Color(0xFF00FF00)
    final primaryColorTextFinder = find.byWidgetPredicate((widget) {
      if (widget is! Text) return false;
      final data = widget.data ?? '';
      if (!data.contains('Bob')) return false;
      return widget.style?.color == const Color(0xFF00FF00);
    });

    expect(
      primaryColorTextFinder,
      findsWidgets,
      reason: 'Most-voted player "Bob" must appear in primary token color',
    );
  });

  // -------------------------------------------------------------------------
  // Elimination: eliminated player shown in error color
  // -------------------------------------------------------------------------

  testWidgets('elimination shows eliminated player in error color', (
    tester,
  ) async {
    await _pump(
      tester,
      votes: [_voteAliceBob, _voteBobBob],
      tally: {'p2': 2},
      eliminatedPlayerIds: ['p2'],
    );

    // TestColorTokens.error = Color(0xFFFF0000)
    final eliminatedFinder = find.byWidgetPredicate((widget) {
      if (widget is! Text) return false;
      final data = widget.data ?? '';
      return data.contains('Eliminated') &&
          data.contains('Bob') &&
          widget.style?.color == const Color(0xFFFF0000);
    });

    expect(
      eliminatedFinder,
      findsOneWidget,
      reason:
          'Elimination text must include player name and use error token color',
    );
  });

  // -------------------------------------------------------------------------
  // Elimination: "No one was eliminated!" when empty
  // -------------------------------------------------------------------------

  testWidgets(
    '"No one was eliminated!" shown when eliminatedPlayerIds is empty',
    (tester) async {
      await _pump(
        tester,
        votes: [_voteAliceBob],
        tally: {'p2': 1},
        eliminatedPlayerIds: [],
      );

      expect(find.text('No one was eliminated!'), findsOneWidget);
    },
  );

  // -------------------------------------------------------------------------
  // Elimination: "No one was eliminated!" NOT shown when someone is eliminated
  // -------------------------------------------------------------------------

  testWidgets('"No one was eliminated!" absent when a player is eliminated', (
    tester,
  ) async {
    await _pump(
      tester,
      votes: [_voteAliceBob],
      tally: {'p2': 1},
      eliminatedPlayerIds: ['p2'],
    );

    expect(find.text('No one was eliminated!'), findsNothing);
  });

  // -------------------------------------------------------------------------
  // Empty votes list renders without error
  // -------------------------------------------------------------------------

  testWidgets('renders correctly with no votes', (tester) async {
    await _pump(tester, votes: [], tally: {}, eliminatedPlayerIds: []);

    expect(find.text('No one was eliminated!'), findsOneWidget);
  });
}
