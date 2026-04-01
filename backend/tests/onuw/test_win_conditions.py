"""
Unit tests for ONUW win condition evaluation.

Tests the pure-Python win conditions engine (no Django dependencies).
"""

import pytest

from apps.onuw.engine.win_conditions import (
    GameResult,
    evaluate_winner,
    get_effective_team,
)

pytestmark = pytest.mark.unit


class TestGetEffectiveTeam:
    """Tests for get_effective_team function."""

    def test_werewolf_is_werewolf_team(self):
        team = get_effective_team(1, {1: "Werewolf"}, {})
        assert team == "werewolf"

    def test_minion_is_werewolf_team(self):
        team = get_effective_team(1, {1: "Minion"}, {})
        assert team == "werewolf"

    def test_villager_is_village_team(self):
        team = get_effective_team(1, {1: "Villager"}, {})
        assert team == "village"

    def test_seer_is_village_team(self):
        team = get_effective_team(1, {1: "Seer"}, {})
        assert team == "village"

    def test_tanner_is_neutral(self):
        team = get_effective_team(1, {1: "Tanner"}, {})
        assert team == "neutral"

    def test_doppelganger_as_werewolf(self):
        """Doppelganger who copied Werewolf is on werewolf team."""
        team = get_effective_team(1, {1: "Doppelganger"}, {1: "Werewolf"})
        assert team == "werewolf"

    def test_doppelganger_as_seer(self):
        """Doppelganger who copied Seer is on village team."""
        team = get_effective_team(1, {1: "Doppelganger"}, {1: "Seer"})
        assert team == "village"

    def test_doppelganger_as_tanner(self):
        """Doppelganger who copied Tanner is neutral."""
        team = get_effective_team(1, {1: "Doppelganger"}, {1: "Tanner"})
        assert team == "neutral"

    def test_swapped_to_doppelganger_card_is_village(self):
        """A non-original player swapped to Doppelganger card is village team."""
        # Player 2 was originally Villager but got swapped to Doppelganger card.
        # They have no entry in doppelganger_copied.
        team = get_effective_team(2, {2: "Doppelganger"}, {})
        assert team == "village"

    def test_doppelganger_as_minion(self):
        """Doppelganger who copied Minion is on werewolf team."""
        team = get_effective_team(1, {1: "Doppelganger"}, {1: "Minion"})
        assert team == "werewolf"


class TestEvaluateWinner:
    """Tests for evaluate_winner function."""

    def test_village_wins_when_werewolf_eliminated(self):
        """Village wins when a Werewolf is eliminated."""
        eliminated = [1]
        player_roles = {
            1: "Werewolf",
            2: "Seer",
            3: "Villager",
            4: "Robber",
            5: "Werewolf",
        }
        result = evaluate_winner(eliminated, player_roles)
        assert result.winning_teams == ["village"]
        assert result.eliminated_players == [1]
        assert result.player_outcomes[2] == "win"  # Seer
        assert result.player_outcomes[3] == "win"  # Villager
        assert result.player_outcomes[4] == "win"  # Robber
        assert result.player_outcomes[1] == "lose"  # Werewolf
        assert result.player_outcomes[5] == "lose"  # Werewolf

    def test_werewolves_win_when_no_werewolf_eliminated(self):
        """Werewolves win when no Werewolf is eliminated."""
        eliminated = [2]  # Seer eliminated, not Werewolf
        player_roles = {
            1: "Werewolf",
            2: "Seer",
            3: "Villager",
        }
        result = evaluate_winner(eliminated, player_roles)
        assert result.winning_teams == ["werewolf"]
        assert result.player_outcomes[1] == "win"  # Werewolf
        assert result.player_outcomes[2] == "lose"  # Seer
        assert result.player_outcomes[3] == "lose"  # Villager

    def test_tanner_wins_when_tanner_eliminated(self):
        """Tanner wins when eliminated. WW team blocked by Tanner death."""
        eliminated = [3]
        player_roles = {
            1: "Werewolf",
            2: "Seer",
            3: "Tanner",
        }
        result = evaluate_winner(eliminated, player_roles)
        assert "tanner" in result.winning_teams
        # WW team does NOT win (Tanner death blocks)
        assert "werewolf" not in result.winning_teams
        assert result.player_outcomes[3] == "win"  # Tanner
        assert result.player_outcomes[1] == "lose"  # Werewolf
        assert result.player_outcomes[2] == "lose"  # Seer

    def test_tanner_and_werewolf_both_die(self):
        """When both Tanner and Werewolf are eliminated, both Tanner and Village win."""
        eliminated = [1, 3]  # Werewolf and Tanner both eliminated
        player_roles = {
            1: "Werewolf",
            2: "Seer",
            3: "Tanner",
        }
        result = evaluate_winner(eliminated, player_roles)
        assert "tanner" in result.winning_teams
        assert "village" in result.winning_teams
        assert result.player_outcomes[3] == "win"  # Tanner
        assert result.player_outcomes[2] == "win"  # Seer (village wins)
        assert result.player_outcomes[1] == "lose"  # Werewolf

    def test_no_werewolf_game_village_wins_no_elimination(self):
        """In a game with no werewolves, village wins if no one is eliminated."""
        eliminated: list[int] = []
        player_roles = {
            1: "Seer",
            2: "Villager",
            3: "Robber",
        }
        result = evaluate_winner(eliminated, player_roles)
        assert result.winning_teams == ["village"]
        assert result.player_outcomes[1] == "win"
        assert result.player_outcomes[2] == "win"
        assert result.player_outcomes[3] == "win"

    def test_no_werewolf_game_nobody_wins_if_someone_eliminated(self):
        """In a no-werewolf game, if someone is eliminated, nobody wins."""
        eliminated = [2]
        player_roles = {
            1: "Seer",
            2: "Villager",
            3: "Robber",
        }
        result = evaluate_winner(eliminated, player_roles)
        assert result.winning_teams == []
        assert all(v == "lose" for v in result.player_outcomes.values())

    def test_minion_wins_with_werewolf_team(self):
        """Minion wins when werewolves win."""
        eliminated = [2]  # Village eliminated, not werewolf
        player_roles = {
            1: "Werewolf",
            2: "Seer",
            3: "Minion",
        }
        result = evaluate_winner(eliminated, player_roles)
        assert result.winning_teams == ["werewolf"]
        assert result.player_outcomes[1] == "win"  # Werewolf
        assert result.player_outcomes[3] == "win"  # Minion
        assert result.player_outcomes[2] == "lose"  # Seer

    def test_hunter_chain_triggers_village_win(self):
        """
        Hunter is eliminated, chain kills a werewolf. But this test
        is about evaluate_winner receiving the already-processed
        elimination list (apply_hunter is called before).
        """
        # apply_hunter already added werewolf to eliminated
        eliminated = [4, 1]  # Hunter and Werewolf both eliminated
        player_roles = {
            1: "Werewolf",
            2: "Seer",
            3: "Villager",
            4: "Hunter",
        }
        result = evaluate_winner(eliminated, player_roles)
        assert result.winning_teams == ["village"]
        assert result.player_outcomes[2] == "win"  # Seer
        assert result.player_outcomes[3] == "win"  # Villager
        assert result.player_outcomes[4] == "win"  # Hunter

    def test_swapped_player_uses_current_role_for_team(self):
        """
        After swaps, team is determined by current_role.
        Originally Robber, but swapped to Werewolf card -> werewolf team.
        """
        eliminated = [2]  # Originally Robber, now holding Werewolf card
        player_roles = {
            1: "Robber",  # Originally Werewolf, now holding Robber card
            2: "Werewolf",  # Originally Robber, now holding Werewolf card
            3: "Villager",
        }
        result = evaluate_winner(eliminated, player_roles)
        # A werewolf was eliminated -> village wins
        assert result.winning_teams == ["village"]
        # Player 1 (current Robber) is village team
        assert result.player_outcomes[1] == "win"
        assert result.player_outcomes[3] == "win"
        # Player 2 (current Werewolf) loses
        assert result.player_outcomes[2] == "lose"

    def test_doppelganger_as_werewolf_on_werewolf_team(self):
        """Doppelganger who copied Werewolf counts as werewolf for win conditions."""
        eliminated: list[int] = []
        player_roles = {
            1: "Doppelganger",  # Copied Werewolf
            2: "Seer",
            3: "Villager",
        }
        doppelganger_copied = {1: "Werewolf"}
        result = evaluate_winner(eliminated, player_roles, doppelganger_copied)
        # Werewolf exists but wasn't eliminated -> werewolves win
        assert result.winning_teams == ["werewolf"]
        assert result.player_outcomes[1] == "win"  # Doppelganger-as-Werewolf
        assert result.player_outcomes[2] == "lose"
        assert result.player_outcomes[3] == "lose"  # Villager loses

    def test_doppelganger_werewolf_eliminated(self):
        """Doppelganger-as-Werewolf eliminated -> village wins."""
        eliminated = [1]
        player_roles = {
            1: "Doppelganger",  # Copied Werewolf
            2: "Seer",
            3: "Villager",
        }
        doppelganger_copied = {1: "Werewolf"}
        result = evaluate_winner(eliminated, player_roles, doppelganger_copied)
        assert result.winning_teams == ["village"]
        assert result.player_outcomes[2] == "win"
        assert result.player_outcomes[3] == "win"

    def test_no_elimination_with_werewolves(self):
        """No one eliminated but werewolves exist -> werewolves win."""
        player_roles = {
            1: "Werewolf",
            2: "Seer",
            3: "Villager",
        }
        result = evaluate_winner([], player_roles)
        assert result.winning_teams == ["werewolf"]

    def test_tanner_in_no_werewolf_game_eliminated(self):
        """In a no-werewolf game, Tanner eliminated -> Tanner wins."""
        eliminated = [3]
        player_roles = {
            1: "Seer",
            2: "Villager",
            3: "Tanner",
        }
        result = evaluate_winner(eliminated, player_roles)
        assert "tanner" in result.winning_teams
        assert "village" not in result.winning_teams  # someone died, village loses
        assert result.player_outcomes[3] == "win"
        assert result.player_outcomes[1] == "lose"
        assert result.player_outcomes[2] == "lose"

    def test_tanner_loses_when_not_eliminated(self):
        """Tanner loses if not eliminated, even in village win."""
        eliminated = [1]
        player_roles = {
            1: "Werewolf",
            2: "Seer",
            3: "Tanner",
        }
        result = evaluate_winner(eliminated, player_roles)
        assert result.winning_teams == ["village"]
        assert result.player_outcomes[3] == "lose"  # Tanner did not die

    def test_no_werewolf_game_village_wins_tanner_loses(self):
        """In no-werewolf game with no elimination, Tanner loses."""
        player_roles = {
            1: "Seer",
            2: "Villager",
            3: "Tanner",
        }
        result = evaluate_winner([], player_roles)
        assert result.winning_teams == ["village"]
        assert result.player_outcomes[3] == "lose"  # Tanner did not die
        assert result.player_outcomes[1] == "win"

    def test_drunk_swaps_into_werewolf_from_center_werewolf_wins(self):
        """Spec Example 4: Drunk swaps with Werewolf from center.

        Drunk unknowingly becomes Werewolf. If not eliminated, Werewolf team wins.
        After night swap: player 1 holds Werewolf (from center), player 2 holds Seer.
        Village kills the Seer (wrong person), so no Werewolf eliminated.
        """
        eliminated = [2]  # Village kills the Seer (wrong person)
        player_roles = {1: "Werewolf", 2: "Seer", 3: "Villager", 4: "Robber"}
        result = evaluate_winner(eliminated, player_roles)
        assert result.winning_teams == ["werewolf"]
        assert result.player_outcomes[1] == "win"  # Drunk-turned-Werewolf wins
        assert result.player_outcomes[2] == "lose"  # Seer eliminated, loses
        assert result.player_outcomes[3] == "lose"  # Villager loses
        assert result.player_outcomes[4] == "lose"  # Robber loses

    def test_doppelganger_as_werewolf_swapped_away_no_werewolves_in_play(self):
        """When Doppelganger-as-Werewolf is swapped to a non-Doppelganger card,
        and no real Werewolf cards are held by players, the game should use
        the 'no werewolves in play' branch — not the 'werewolves exist' branch.

        Bug: werewolf_role_players included the original Doppelganger based on
        doppelganger_copied even after their card was swapped away.
        """
        # Doppelganger (1) copied Werewolf, then Robber (2) stole the Doppelganger card.
        # After swap: player 1 holds Robber, player 2 holds Doppelganger-that-copied-Werewolf.
        eliminated: list[int] = []
        player_roles = {
            1: "Robber",  # was Doppelganger, now holds Robber card
            2: "Doppelganger",  # was Robber, now holds Doppelganger card
            3: "Villager",
        }
        doppelganger_copied = {1: "Werewolf"}  # player 1 originally copied Werewolf
        result = evaluate_winner(eliminated, player_roles, doppelganger_copied)

        # Player 2 now holds the Doppelganger card that copied Werewolf.
        # This means a werewolf IS in play (player 2). No one was eliminated,
        # so the werewolf team should win.
        assert "werewolf" in result.winning_teams
        # Player 2 holds the werewolf-team card — they should win.
        assert result.player_outcomes[2] == "win"
        # Player 1 holds the Robber card — village team, should lose.
        assert result.player_outcomes[1] == "lose"

    def test_doppelganger_card_holder_inherits_copied_team(self):
        """A player who receives the Doppelganger card via swap inherits the
        copied role's team. The copied role is a property of the CARD, not
        the original player.

        Spec: 'Any player holding the Doppelganger card has the copied role
        as their effective role.'
        """
        # Troublemaker swapped Doppelganger (1) and Villager (3).
        # Doppelganger originally copied Werewolf.
        player_roles = {
            1: "Villager",  # was Doppelganger, now holds Villager card
            2: "Seer",
            3: "Doppelganger",  # was Villager, now holds Doppelganger card
        }
        doppelganger_copied = {1: "Werewolf"}
        # Player 3 now holds the werewolf-team card.
        team = get_effective_team(3, player_roles, doppelganger_copied)
        assert team == "werewolf"

    def test_doppelganger_swapped_away_original_is_new_team(self):
        """The original Doppelganger who was swapped away uses their new card's team."""
        # Doppelganger (1) copied Werewolf, Robber (2) stole the Doppelganger card.
        player_roles = {
            1: "Robber",  # was Doppelganger, now holds Robber card
            2: "Doppelganger",  # was Robber, now holds Doppelganger card
        }
        doppelganger_copied = {1: "Werewolf"}
        # Player 1 holds Robber card = village team.
        team = get_effective_team(1, player_roles, doppelganger_copied)
        assert team == "village"

    def test_doppelganger_card_eliminated_counts_as_copied_role(self):
        """If the player holding the Doppelganger-that-copied-Werewolf card
        is eliminated, it counts as eliminating a werewolf."""
        # After swap: player 2 holds the Doppelganger card (copied Werewolf).
        eliminated = [2]
        player_roles = {
            1: "Robber",
            2: "Doppelganger",
            3: "Villager",
        }
        doppelganger_copied = {1: "Werewolf"}
        result = evaluate_winner(eliminated, player_roles, doppelganger_copied)

        # A "werewolf" was eliminated (player 2 holds the werewolf-team card).
        assert "village" in result.winning_teams
        assert "werewolf" not in result.winning_teams

    def test_result_is_frozen_dataclass(self):
        """GameResult is immutable."""
        result = evaluate_winner([], {1: "Seer", 2: "Villager"})
        assert isinstance(result, GameResult)
        with pytest.raises(AttributeError):
            result.winning_teams = ["werewolf"]  # type: ignore[misc]
