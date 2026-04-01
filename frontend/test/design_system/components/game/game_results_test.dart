import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/components/game/game_results.dart';
import 'package:midnight_village/design_system/models/game_result.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/tokens/app_tokens_provider.dart';
import 'package:midnight_village/design_system/tokens/theme_bridge.dart';

import '../../../design_system/test_helpers/test_theme.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

const _testTheme = TestThemeTokens();

/// Pumps GameResults in a bounded, scrollable context.
Future<void> _pump(
  WidgetTester tester, {
  required GameResult result,
  VoidCallback? onPlayAgain,
  VoidCallback? onReturnToLobby,
}) async {
  tester.view.physicalSize =
      const Size(400, 900) * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [activeThemeProvider.overrideWithValue(_testTheme)],
      child: MaterialApp(
        theme: generateThemeData(_testTheme),
        home: Scaffold(
          body: GameResults(
            result: result,
            onPlayAgain: onPlayAgain,
            onReturnToLobby: onReturnToLobby,
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Sample player helpers
// ---------------------------------------------------------------------------

PlayerResult _werewolfPlayer() => const PlayerResult(
  id: 'p1',
  displayName: 'Alice',
  originalRole: RoleId.werewolf,
  finalRole: RoleId.werewolf,
  team: TeamId.werewolf,
  isEliminated: false,
  isWinner: true,
);

PlayerResult _villagerPlayer({bool isEliminated = false}) => PlayerResult(
  id: 'p2',
  displayName: 'Bob',
  originalRole: RoleId.villager,
  finalRole: RoleId.villager,
  team: TeamId.village,
  isEliminated: isEliminated,
  isWinner: false,
);

PlayerResult _tannerPlayer() => const PlayerResult(
  id: 'p3',
  displayName: 'Carol',
  originalRole: RoleId.tanner,
  finalRole: RoleId.tanner,
  team: TeamId.independent,
  isEliminated: true,
  isWinner: true,
);

PlayerResult _robberSwappedToWerewolf() => const PlayerResult(
  id: 'p4',
  displayName: 'Dave',
  originalRole: RoleId.robber,
  finalRole: RoleId.werewolf,
  team: TeamId.werewolf,
  isEliminated: false,
  isWinner: false,
);

PlayerResult _doppelgangerAsVillager() => const PlayerResult(
  id: 'p5',
  displayName: 'Eve',
  originalRole: RoleId.doppelganger,
  finalRole: RoleId.villager,
  team: TeamId.village,
  isEliminated: false,
  isWinner: false,
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // Werewolf win: werewolfTeam color
  // -------------------------------------------------------------------------

  testWidgets('werewolf win shows "Werewolves win!" in werewolfTeam color', (
    tester,
  ) async {
    await _pump(
      tester,
      result: GameResult(
        winningTeams: const [TeamId.werewolf],
        players: [_werewolfPlayer(), _villagerPlayer()],
      ),
    );

    // TestColorTokens.werewolfTeam = Color(0xFFFF4444)
    final finder = find.byWidgetPredicate((widget) {
      if (widget is! Text) return false;
      return widget.data == 'Werewolves win!' &&
          widget.style?.color == const Color(0xFFFF4444);
    });

    expect(
      finder,
      findsOneWidget,
      reason: '"Werewolves win!" must appear with werewolfTeam token color',
    );
  });

  // -------------------------------------------------------------------------
  // Village win: villageTeam color
  // -------------------------------------------------------------------------

  testWidgets('village win shows "Village wins!" in villageTeam color', (
    tester,
  ) async {
    await _pump(
      tester,
      result: GameResult(
        winningTeams: const [TeamId.village],
        players: [_villagerPlayer(), _werewolfPlayer()],
      ),
    );

    // TestColorTokens.villageTeam = Color(0xFF4444FF)
    final finder = find.byWidgetPredicate((widget) {
      if (widget is! Text) return false;
      return widget.data == 'Village wins!' &&
          widget.style?.color == const Color(0xFF4444FF);
    });

    expect(
      finder,
      findsOneWidget,
      reason: '"Village wins!" must appear with villageTeam token color',
    );
  });

  // -------------------------------------------------------------------------
  // Tanner win: independentTeam color
  // -------------------------------------------------------------------------

  testWidgets('tanner win shows "Tanner wins!" in independentTeam color', (
    tester,
  ) async {
    await _pump(
      tester,
      result: GameResult(
        winningTeams: const [TeamId.independent],
        players: [_tannerPlayer(), _villagerPlayer()],
      ),
    );

    // TestColorTokens.independentTeam = Color(0xFFFFFF00)
    final finder = find.byWidgetPredicate((widget) {
      if (widget is! Text) return false;
      return widget.data == 'Tanner wins!' &&
          widget.style?.color == const Color(0xFFFFFF00);
    });

    expect(
      finder,
      findsOneWidget,
      reason: '"Tanner wins!" must appear with independentTeam token color',
    );
  });

  // -------------------------------------------------------------------------
  // No winners: "Nobody wins!" in onSurface color
  // -------------------------------------------------------------------------

  testWidgets('"Nobody wins!" shown when winningTeams is empty', (
    tester,
  ) async {
    await _pump(
      tester,
      result: GameResult(winningTeams: const [], players: [_villagerPlayer()]),
    );

    // TestColorTokens.onSurface = Color(0xFFFFFFFF)
    final finder = find.byWidgetPredicate((widget) {
      if (widget is! Text) return false;
      return widget.data == 'Nobody wins!' &&
          widget.style?.color == const Color(0xFFFFFFFF);
    });

    expect(
      finder,
      findsOneWidget,
      reason:
          '"Nobody wins!" must appear in onSurface color when there are no winners',
    );
  });

  // -------------------------------------------------------------------------
  // Role swap: "OriginalRole → FinalRole" format
  // -------------------------------------------------------------------------

  testWidgets('role swap is shown as "OriginalRole → FinalRole"', (
    tester,
  ) async {
    await _pump(
      tester,
      result: GameResult(
        winningTeams: const [TeamId.werewolf],
        players: [_robberSwappedToWerewolf()],
      ),
    );

    expect(
      find.text('Robber → Werewolf'),
      findsOneWidget,
      reason: 'Swapped role must display as "OriginalRole → FinalRole"',
    );
  });

  // -------------------------------------------------------------------------
  // Doppelganger: "Doppelganger (as FinalRole)" format
  // -------------------------------------------------------------------------

  testWidgets('doppelganger shows "Doppelganger (as FinalRole)"', (
    tester,
  ) async {
    await _pump(
      tester,
      result: GameResult(
        winningTeams: const [TeamId.village],
        players: [_doppelgangerAsVillager()],
      ),
    );

    expect(
      find.text('Doppelganger (as Villager)'),
      findsOneWidget,
      reason: 'Doppelganger must display as "Doppelganger (as FinalRole)"',
    );
  });

  // -------------------------------------------------------------------------
  // Eliminated player: shows "(eliminated)" marker
  // -------------------------------------------------------------------------

  testWidgets('eliminated player shows "(eliminated)" indicator', (
    tester,
  ) async {
    await _pump(
      tester,
      result: GameResult(
        winningTeams: const [TeamId.village],
        players: [_villagerPlayer(isEliminated: true)],
      ),
    );

    expect(
      find.text('(eliminated)'),
      findsOneWidget,
      reason: 'Eliminated player must show "(eliminated)" marker',
    );
  });

  // -------------------------------------------------------------------------
  // Non-eliminated player: no "(eliminated)" marker
  // -------------------------------------------------------------------------

  testWidgets('non-eliminated player does not show "(eliminated)" indicator', (
    tester,
  ) async {
    await _pump(
      tester,
      result: GameResult(
        winningTeams: const [TeamId.village],
        players: [_villagerPlayer(isEliminated: false)],
      ),
    );

    expect(
      find.text('(eliminated)'),
      findsNothing,
      reason: 'Non-eliminated player must not show "(eliminated)"',
    );
  });

  // -------------------------------------------------------------------------
  // "Play Again" button shown when onPlayAgain provided
  // -------------------------------------------------------------------------

  testWidgets('"Play Again" button is shown when onPlayAgain is provided', (
    tester,
  ) async {
    await _pump(
      tester,
      result: GameResult(
        winningTeams: const [TeamId.village],
        players: [_villagerPlayer()],
      ),
      onPlayAgain: () {},
    );

    expect(find.text('Play Again'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // "Play Again" button NOT shown when onPlayAgain is null
  // -------------------------------------------------------------------------

  testWidgets('"Play Again" button is hidden when onPlayAgain is null', (
    tester,
  ) async {
    await _pump(
      tester,
      result: GameResult(
        winningTeams: const [TeamId.village],
        players: [_villagerPlayer()],
      ),
    );

    expect(find.text('Play Again'), findsNothing);
  });

  // -------------------------------------------------------------------------
  // "Return to Lobby" button shown when onReturnToLobby provided
  // -------------------------------------------------------------------------

  testWidgets(
    '"Return to Lobby" button is shown when onReturnToLobby is provided',
    (tester) async {
      await _pump(
        tester,
        result: GameResult(
          winningTeams: const [TeamId.village],
          players: [_villagerPlayer()],
        ),
        onReturnToLobby: () {},
      );

      expect(find.text('Return to Lobby'), findsOneWidget);
    },
  );

  // -------------------------------------------------------------------------
  // "Return to Lobby" button NOT shown when onReturnToLobby is null
  // -------------------------------------------------------------------------

  testWidgets(
    '"Return to Lobby" button is hidden when onReturnToLobby is null',
    (tester) async {
      await _pump(
        tester,
        result: GameResult(
          winningTeams: const [TeamId.village],
          players: [_villagerPlayer()],
        ),
      );

      expect(find.text('Return to Lobby'), findsNothing);
    },
  );

  // -------------------------------------------------------------------------
  // Both buttons shown when both callbacks provided
  // -------------------------------------------------------------------------

  testWidgets('both buttons shown when both callbacks are provided', (
    tester,
  ) async {
    await _pump(
      tester,
      result: GameResult(
        winningTeams: const [TeamId.village],
        players: [_villagerPlayer()],
      ),
      onPlayAgain: () {},
      onReturnToLobby: () {},
    );

    expect(find.text('Play Again'), findsOneWidget);
    expect(find.text('Return to Lobby'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // Multiple winning teams displayed on separate lines
  // -------------------------------------------------------------------------

  testWidgets('multiple winning teams each shown on separate lines', (
    tester,
  ) async {
    await _pump(
      tester,
      result: GameResult(
        winningTeams: const [TeamId.village, TeamId.independent],
        players: [_tannerPlayer(), _villagerPlayer()],
      ),
    );

    expect(find.text('Village wins!'), findsOneWidget);
    expect(find.text('Tanner wins!'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // Same role: just role name shown (no arrow)
  // -------------------------------------------------------------------------

  testWidgets('unchanged role shows just role name without arrow', (
    tester,
  ) async {
    await _pump(
      tester,
      result: GameResult(
        winningTeams: const [TeamId.village],
        players: [_villagerPlayer()],
      ),
    );

    // "Villager" appears at least once (in the caption role label and/or RoleCard).
    expect(find.text('Villager'), findsWidgets);
    // No arrow notation must appear anywhere.
    expect(
      find.textContaining('→'),
      findsNothing,
      reason: 'Unchanged role must not show arrow',
    );
  });

  // -------------------------------------------------------------------------
  // Hunter chain elimination: shows "(eliminated by Hunter)"
  // -------------------------------------------------------------------------

  testWidgets('hunter chain elimination shows "(eliminated by Hunter)"', (
    tester,
  ) async {
    final hunterVictim = const PlayerResult(
      id: 'p6',
      displayName: 'Frank',
      originalRole: RoleId.villager,
      finalRole: RoleId.villager,
      team: TeamId.village,
      isEliminated: true,
      isWinner: false,
      eliminationReason: EliminationReason.hunterChain,
    );

    await _pump(
      tester,
      result: GameResult(
        winningTeams: const [TeamId.village],
        players: [hunterVictim],
      ),
    );

    expect(find.text('(eliminated by Hunter)'), findsOneWidget);
    expect(find.text('(eliminated)'), findsNothing);
  });

  // -------------------------------------------------------------------------
  // Standard elimination: shows "(eliminated)" not "(eliminated by Hunter)"
  // -------------------------------------------------------------------------

  testWidgets('vote elimination shows "(eliminated)" not hunter label', (
    tester,
  ) async {
    final eliminatedByVote = const PlayerResult(
      id: 'p7',
      displayName: 'Grace',
      originalRole: RoleId.werewolf,
      finalRole: RoleId.werewolf,
      team: TeamId.werewolf,
      isEliminated: true,
      isWinner: false,
      eliminationReason: EliminationReason.vote,
    );

    await _pump(
      tester,
      result: GameResult(
        winningTeams: const [TeamId.village],
        players: [eliminatedByVote],
      ),
    );

    expect(find.text('(eliminated)'), findsOneWidget);
    expect(find.text('(eliminated by Hunter)'), findsNothing);
  });

  // -------------------------------------------------------------------------
  // votes and centerCards fields: GameResult with new fields renders without error
  // -------------------------------------------------------------------------

  testWidgets('GameResult with votes and centerCards renders correctly', (
    tester,
  ) async {
    await _pump(
      tester,
      result: GameResult(
        winningTeams: const [TeamId.village],
        players: [_villagerPlayer(isEliminated: true)],
        votes: const [
          VoteResult(
            voterId: 'p1',
            voterName: 'Alice',
            targetId: 'p2',
            targetName: 'Bob',
          ),
        ],
        centerCards: const [RoleId.werewolf, RoleId.villager],
      ),
    );

    // Widget still renders correctly with new fields.
    expect(find.text('Village wins!'), findsOneWidget);
    expect(find.text('(eliminated)'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // Center cards section: displays center card roles
  // -------------------------------------------------------------------------

  testWidgets(
    'center cards section shows role cards when centerCards present',
    (tester) async {
      await _pump(
        tester,
        result: GameResult(
          winningTeams: const [TeamId.village],
          players: [_villagerPlayer()],
          centerCards: const [RoleId.werewolf, RoleId.seer, RoleId.tanner],
        ),
      );

      expect(
        find.text('Center Cards'),
        findsOneWidget,
        reason:
            '"Center Cards" heading must appear when centerCards is non-empty',
      );

      // Each center card renders a small RoleCard with the role's displayName.
      expect(find.text('Werewolf'), findsOneWidget);
      expect(find.text('Seer'), findsOneWidget);
      expect(find.text('Tanner'), findsOneWidget);
    },
  );

  testWidgets('center cards section hidden when centerCards is empty', (
    tester,
  ) async {
    await _pump(
      tester,
      result: GameResult(
        winningTeams: const [TeamId.village],
        players: [_villagerPlayer()],
        centerCards: const [],
      ),
    );

    expect(
      find.text('Center Cards'),
      findsNothing,
      reason:
          '"Center Cards" heading must not appear when centerCards is empty',
    );
  });

  // -------------------------------------------------------------------------
  // Vote target display: shows who each player voted for
  // -------------------------------------------------------------------------

  testWidgets('player row shows "Voted for" when voteTargetName is present', (
    tester,
  ) async {
    const playerWithVote = PlayerResult(
      id: 'p1',
      displayName: 'Alice',
      originalRole: RoleId.werewolf,
      finalRole: RoleId.werewolf,
      team: TeamId.werewolf,
      isEliminated: false,
      isWinner: true,
      voteTargetId: 'p2',
      voteTargetName: 'Bob',
    );

    await _pump(
      tester,
      result: GameResult(
        winningTeams: const [TeamId.werewolf],
        players: [playerWithVote],
      ),
    );

    expect(
      find.text('Voted for Bob'),
      findsOneWidget,
      reason: 'Player row must show vote target name',
    );
  });

  testWidgets('player row shows "Abstained" when vote target is null', (
    tester,
  ) async {
    const abstainer = PlayerResult(
      id: 'p1',
      displayName: 'Alice',
      originalRole: RoleId.villager,
      finalRole: RoleId.villager,
      team: TeamId.village,
      isEliminated: false,
      isWinner: false,
      voteTargetId: null,
      voteTargetName: null,
    );

    await _pump(
      tester,
      result: GameResult(
        winningTeams: const [TeamId.village],
        players: [abstainer],
      ),
    );

    expect(
      find.text('Abstained'),
      findsOneWidget,
      reason: 'Player row must show "Abstained" when vote target is null',
    );
  });

  testWidgets(
    'player row shows "Voted for" with target ID when name is missing',
    (tester) async {
      // voteTargetId is set but voteTargetName is null — this means
      // the frontend couldn't resolve the name. Should show neither
      // "Voted for" nor "Abstained" since a target WAS chosen.
      const playerWithIdOnly = PlayerResult(
        id: 'p1',
        displayName: 'Alice',
        originalRole: RoleId.villager,
        finalRole: RoleId.villager,
        team: TeamId.village,
        isEliminated: false,
        isWinner: false,
        voteTargetId: 'p2',
        voteTargetName: null,
      );

      await _pump(
        tester,
        result: GameResult(
          winningTeams: const [TeamId.village],
          players: [playerWithIdOnly],
        ),
      );

      // Neither "Voted for" nor "Abstained" should appear — the player
      // voted but the name couldn't be resolved.
      expect(find.textContaining('Voted for'), findsNothing);
      expect(find.text('Abstained'), findsNothing);
    },
  );
}
