"""
Full end-to-end integration tests for ONUW: lobby to results.

Tests the complete game lifecycle from lobby creation through night phase,
discussion, voting, and final results with win condition verification.
"""

from unittest.mock import patch

from django.urls import reverse

import pytest
from rest_framework import status
from rest_framework.test import APIClient

from apps.core.models import Lobby, LobbyMember, User
from apps.onuw.models import Game, Phase, PlayerRole

pytestmark = pytest.mark.integration


def _patch_channels():
    """Mock out channel layer so WebSocket sends are no-ops during tests."""
    return patch("apps.onuw.services.get_channel_layer", return_value=None)


class TestCompleteGameVillageWins:
    """
    Full game: lobby -> night -> discussion -> voting -> results.
    Village wins by eliminating a Werewolf.

    Players: 5 guests
    Roles: Werewolf x2, Seer, Robber, Villager + center: Drunk, Insomniac, Troublemaker

    Night flow:
      Wave 2: Werewolves see each other
      Wave 3: Seer peeks at Werewolf (learns role), Robber swaps with Villager
      No wave 4 -> discussion
    Discussion: host ends discussion -> voting
    Voting: all vote for a Werewolf -> auto-reveal -> results
    Result: Village wins
    """

    def _setup_game(self):
        """
        Create a lobby with 5 players, start game with explicit role
        assignments, and return all the handles needed for testing.
        """
        # Create 5 users
        host = User.objects.create_user(
            username="e2e_full_host", password="pass", display_name="Host"
        )
        p1 = User.objects.create_user(
            username="e2e_full_p1", password="pass", display_name="Player1"
        )
        p2 = User.objects.create_user(
            username="e2e_full_p2", password="pass", display_name="Player2"
        )
        p3 = User.objects.create_user(
            username="e2e_full_p3", password="pass", display_name="Player3"
        )
        p4 = User.objects.create_user(
            username="e2e_full_p4", password="pass", display_name="Player4"
        )

        role_config = {
            "Werewolf": 2,
            "Seer": 1,
            "Robber": 1,
            "Villager": 1,
            "Drunk": 1,
            "Insomniac": 1,
            "Troublemaker": 1,
        }

        lobby = Lobby.objects.create(
            host=host,
            game_type="onuw",
            max_players=10,
            settings={"roles": role_config},
        )
        for user in [host, p1, p2, p3, p4]:
            LobbyMember.objects.create(lobby=lobby, user=user, is_ready=True)
        lobby.status = Lobby.Status.IN_GAME
        lobby.save()

        # Create game with explicit role assignments for determinism
        game = Game.objects.create(
            lobby=lobby,
            phase=Phase.NIGHT,
            random_seed=42,
            settings=lobby.settings,
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
        )

        # Explicit assignments:
        # host=Werewolf, p1=Werewolf, p2=Seer, p3=Robber, p4=Villager
        role_assignments = {
            host: "Werewolf",
            p1: "Werewolf",
            p2: "Seer",
            p3: "Robber",
            p4: "Villager",
        }
        for user, role in role_assignments.items():
            PlayerRole.objects.create(
                game=game, user=user, original_role=role, current_role=role
            )

        users = {"host": host, "p1": p1, "p2": p2, "p3": p3, "p4": p4}
        return game, users, host, lobby

    def test_complete_game_village_wins(self, db):
        """
        Complete game flow where village eliminates a werewolf.

        1. Create game with known roles
        2. Night: Werewolves see each other, Seer peeks werewolf, Robber swaps
        3. Discussion -> Voting
        4. All vote for host (Werewolf) -> auto-reveal -> results
        5. Verify winning_team="village"
        6. GET /results/ -> verify full data
        """
        game, users, host, _lobby = self._setup_game()
        client = APIClient()

        action_url = reverse("onuw:night-action", kwargs={"game_id": str(game.id)})
        end_discussion_url = reverse(
            "onuw:end-discussion", kwargs={"game_id": str(game.id)}
        )
        vote_url = reverse("onuw:vote", kwargs={"game_id": str(game.id)})
        results_url = reverse("onuw:results", kwargs={"game_id": str(game.id)})

        ww1 = users["host"]
        ww2 = users["p1"]
        seer = users["p2"]
        robber = users["p3"]
        villager = users["p4"]

        with _patch_channels():
            # ── Initialize night phase ─────────────────────────────────────
            from apps.onuw.services import start_night_phase

            start_night_phase(game)

            game.refresh_from_db()
            assert game.phase == Phase.NIGHT
            assert game.current_wave == 2  # First active wave: Werewolves

            # ── Wave 2: Werewolves see each other ──────────────────────────
            client.force_authenticate(user=ww1)
            response = client.post(
                action_url,
                {"action_type": "see_team", "targets": {}},
                format="json",
            )
            assert response.status_code == status.HTTP_200_OK  # type: ignore[union-attr]

            client.force_authenticate(user=ww2)
            response = client.post(
                action_url,
                {"action_type": "see_team", "targets": {}},
                format="json",
            )
            assert response.status_code == status.HTTP_200_OK  # type: ignore[union-attr]

            # Should auto-advance to wave 3
            game.refresh_from_db()
            assert game.current_wave == 3

            # Verify werewolves saw each other
            pr_ww1 = PlayerRole.objects.get(game=game, user=ww1)
            # pyrefly: ignore [missing-attribute]
            assert ww2.id in pr_ww1.night_action_data["wave_2_result"]["werewolves"]

            # ── Wave 3: Seer peeks, Robber swaps ──────────────────────────
            # Seer peeks at ww1 (host) -> learns they are Werewolf
            client.force_authenticate(user=seer)
            response = client.post(
                action_url,
                {
                    "action_type": "peek_player",
                    # pyrefly: ignore [missing-attribute]
                    "targets": {"player_id": ww1.id},
                },
                format="json",
            )
            assert response.status_code == status.HTTP_200_OK  # type: ignore[union-attr]

            # Robber swaps with villager (not werewolf)
            client.force_authenticate(user=robber)
            response = client.post(
                action_url,
                {
                    "action_type": "swap_with_player",
                    # pyrefly: ignore [missing-attribute]
                    "targets": {"player_id": villager.id},
                },
                format="json",
            )
            assert response.status_code == status.HTTP_200_OK  # type: ignore[union-attr]

            # No wave 4 actors -> should transition to discussion
            game.refresh_from_db()
            assert game.phase == Phase.DISCUSSION

            # Verify Seer's peek result
            pr_seer = PlayerRole.objects.get(game=game, user=seer)
            assert (
                pr_seer.night_action_data["wave_3_result"]["peeked_role"] == "Werewolf"
            )

            # Verify roles after Robber swap
            # Robber swapped with Villager: Robber gets Villager, Villager gets Robber
            pr_robber = PlayerRole.objects.get(game=game, user=robber)
            assert pr_robber.current_role == "Villager"
            pr_villager = PlayerRole.objects.get(game=game, user=villager)
            assert pr_villager.current_role == "Robber"

            # ── Discussion -> Voting ───────────────────────────────────────
            client.force_authenticate(user=host)
            response = client.post(end_discussion_url)
            assert response.status_code == status.HTTP_200_OK  # type: ignore[union-attr]

            game.refresh_from_db()
            assert game.phase == Phase.VOTING

            # ── Voting: All vote for host (Werewolf) ───────────────────────
            # Seer knows host is Werewolf, convinces everyone to vote host
            for user in [ww1, ww2, seer, robber, villager]:
                client.force_authenticate(user=user)
                response = client.post(
                    vote_url,
                    # pyrefly: ignore [missing-attribute]
                    {"target_player_id": ww1.id},
                    format="json",
                )
                assert response.status_code == status.HTTP_200_OK  # type: ignore[union-attr]

            # After all 5 votes, auto-reveal should trigger
            game.refresh_from_db()
            assert game.phase == Phase.RESULTS

            # ── Verify results ─────────────────────────────────────────────
            assert game.results["winning_team"] == "village"
            # pyrefly: ignore [missing-attribute]
            assert ww1.id in game.results["eliminated_players"]

            # Verify player outcomes
            outcomes = game.results["player_outcomes"]
            # Village team players win
            # pyrefly: ignore [missing-attribute]
            assert outcomes[str(seer.id)] == "win"
            # pyrefly: ignore [missing-attribute]
            assert outcomes[str(robber.id)] == "win"  # Currently Villager
            # pyrefly: ignore [missing-attribute]
            assert outcomes[str(villager.id)] == "win"  # Currently Robber
            # Werewolf team loses
            # pyrefly: ignore [missing-attribute]
            assert outcomes[str(ww1.id)] == "lose"
            # pyrefly: ignore [missing-attribute]
            assert outcomes[str(ww2.id)] == "lose"

            # ── GET /results/ ──────────────────────────────────────────────
            client.force_authenticate(user=seer)
            response = client.get(results_url)
            assert response.status_code == status.HTTP_200_OK  # type: ignore[union-attr]

            data = response.data  # type: ignore[union-attr]
            assert data["winning_team"] == "village"
            assert len(data["players"]) == 5
            assert len(data["eliminated_players"]) >= 1
            assert data["center_cards"]["final"] == [
                "Drunk",
                "Insomniac",
                "Troublemaker",
            ]

            # Verify all players are listed with correct roles
            players_by_id = {p["player_id"]: p for p in data["players"]}
            # pyrefly: ignore [missing-attribute]
            assert players_by_id[ww1.id]["original_role"] == "Werewolf"
            # pyrefly: ignore [missing-attribute]
            assert players_by_id[ww1.id]["final_role"] == "Werewolf"
            # pyrefly: ignore [missing-attribute]
            assert players_by_id[seer.id]["original_role"] == "Seer"
            # pyrefly: ignore [missing-attribute]
            assert players_by_id[seer.id]["final_role"] == "Seer"
            # pyrefly: ignore [missing-attribute]
            assert players_by_id[robber.id]["original_role"] == "Robber"
            # pyrefly: ignore [missing-attribute]
            assert players_by_id[robber.id]["final_role"] == "Villager"  # Swapped

            # Night actions log should be present
            assert len(data["night_actions_log"]) > 0


class TestCompleteGameWerewolvesWin:
    """
    Full game where village votes wrong and werewolves win.

    Same setup as village win, but village votes for Villager instead
    of Werewolf. Werewolves win because no werewolf is eliminated.
    """

    def _setup_game(self):
        """Create game with 5 players, same as village wins setup."""
        host = User.objects.create_user(
            username="e2e_ww_host", password="pass", display_name="Host"
        )
        p1 = User.objects.create_user(
            username="e2e_ww_p1", password="pass", display_name="Player1"
        )
        p2 = User.objects.create_user(
            username="e2e_ww_p2", password="pass", display_name="Player2"
        )
        p3 = User.objects.create_user(
            username="e2e_ww_p3", password="pass", display_name="Player3"
        )
        p4 = User.objects.create_user(
            username="e2e_ww_p4", password="pass", display_name="Player4"
        )

        role_config = {
            "Werewolf": 2,
            "Seer": 1,
            "Robber": 1,
            "Villager": 1,
            "Drunk": 1,
            "Insomniac": 1,
            "Troublemaker": 1,
        }

        lobby = Lobby.objects.create(
            host=host,
            game_type="onuw",
            max_players=10,
            settings={"roles": role_config},
        )
        for user in [host, p1, p2, p3, p4]:
            LobbyMember.objects.create(lobby=lobby, user=user, is_ready=True)
        lobby.status = Lobby.Status.IN_GAME
        lobby.save()

        game = Game.objects.create(
            lobby=lobby,
            phase=Phase.NIGHT,
            random_seed=42,
            settings=lobby.settings,
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
        )

        # host=Werewolf, p1=Werewolf, p2=Seer, p3=Robber, p4=Villager
        role_assignments = {
            host: "Werewolf",
            p1: "Werewolf",
            p2: "Seer",
            p3: "Robber",
            p4: "Villager",
        }
        for user, role in role_assignments.items():
            PlayerRole.objects.create(
                game=game, user=user, original_role=role, current_role=role
            )

        users = {"host": host, "p1": p1, "p2": p2, "p3": p3, "p4": p4}
        return game, users, host

    def test_complete_game_werewolves_win(self, db):
        """
        Village votes for non-werewolf. Werewolves win.

        1. Night phase: werewolves see each other, seer peeks, robber swaps
        2. Discussion -> Voting
        3. All vote for p4 (Villager) -> werewolves win
        """
        game, users, host = self._setup_game()
        client = APIClient()

        action_url = reverse("onuw:night-action", kwargs={"game_id": str(game.id)})
        end_discussion_url = reverse(
            "onuw:end-discussion", kwargs={"game_id": str(game.id)}
        )
        vote_url = reverse("onuw:vote", kwargs={"game_id": str(game.id)})
        results_url = reverse("onuw:results", kwargs={"game_id": str(game.id)})

        ww1 = users["host"]
        ww2 = users["p1"]
        seer = users["p2"]
        robber = users["p3"]
        villager = users["p4"]

        with _patch_channels():
            from apps.onuw.services import start_night_phase

            start_night_phase(game)

            # ── Wave 2: Werewolves ─────────────────────────────────────────
            client.force_authenticate(user=ww1)
            client.post(
                action_url,
                {"action_type": "see_team", "targets": {}},
                format="json",
            )
            client.force_authenticate(user=ww2)
            client.post(
                action_url,
                {"action_type": "see_team", "targets": {}},
                format="json",
            )

            # ── Wave 3: Seer + Robber ──────────────────────────────────────
            client.force_authenticate(user=seer)
            client.post(
                action_url,
                {
                    "action_type": "peek_player",
                    # pyrefly: ignore [missing-attribute]
                    "targets": {"player_id": ww1.id},
                },
                format="json",
            )
            client.force_authenticate(user=robber)
            client.post(
                action_url,
                {
                    "action_type": "swap_with_player",
                    # pyrefly: ignore [missing-attribute]
                    "targets": {"player_id": villager.id},
                },
                format="json",
            )

            game.refresh_from_db()
            assert game.phase == Phase.DISCUSSION

            # ── Discussion -> Voting ───────────────────────────────────────
            client.force_authenticate(user=host)
            client.post(end_discussion_url)

            game.refresh_from_db()
            assert game.phase == Phase.VOTING

            # ── Voting: All vote for villager (NOT a werewolf) ─────────────
            for user in [ww1, ww2, seer, robber, villager]:
                client.force_authenticate(user=user)
                client.post(
                    vote_url,
                    # pyrefly: ignore [missing-attribute]
                    {"target_player_id": villager.id},
                    format="json",
                )

            game.refresh_from_db()
            assert game.phase == Phase.RESULTS

            # ── Verify werewolves win ──────────────────────────────────────
            assert game.results["winning_team"] == "werewolf"
            # pyrefly: ignore [missing-attribute]
            assert villager.id in game.results["eliminated_players"]

            # Werewolf team wins
            outcomes = game.results["player_outcomes"]
            # pyrefly: ignore [missing-attribute]
            assert outcomes[str(ww1.id)] == "win"
            # pyrefly: ignore [missing-attribute]
            assert outcomes[str(ww2.id)] == "win"
            # Village team loses
            # pyrefly: ignore [missing-attribute]
            assert outcomes[str(seer.id)] == "lose"
            # pyrefly: ignore [missing-attribute]
            assert outcomes[str(robber.id)] == "lose"
            # pyrefly: ignore [missing-attribute]
            assert outcomes[str(villager.id)] == "lose"

            # ── GET /results/ ──────────────────────────────────────────────
            client.force_authenticate(user=seer)
            response = client.get(results_url)
            assert response.status_code == status.HTTP_200_OK  # type: ignore[union-attr]
            assert response.data["winning_team"] == "werewolf"  # type: ignore[union-attr]


class TestCompleteGameTannerWins:
    """
    Full game where village votes for Tanner. Tanner wins.

    Roles: Werewolf x2, Tanner, Seer, Villager + center: Drunk, Insomniac, Troublemaker
    """

    def _setup_game(self):
        """Create game with Tanner in roles."""
        host = User.objects.create_user(
            username="e2e_tan_host", password="pass", display_name="Host"
        )
        p1 = User.objects.create_user(
            username="e2e_tan_p1", password="pass", display_name="Player1"
        )
        p2 = User.objects.create_user(
            username="e2e_tan_p2", password="pass", display_name="Player2"
        )
        p3 = User.objects.create_user(
            username="e2e_tan_p3", password="pass", display_name="Player3"
        )
        p4 = User.objects.create_user(
            username="e2e_tan_p4", password="pass", display_name="Player4"
        )

        role_config = {
            "Werewolf": 2,
            "Tanner": 1,
            "Seer": 1,
            "Villager": 1,
            "Drunk": 1,
            "Insomniac": 1,
            "Troublemaker": 1,
        }

        lobby = Lobby.objects.create(
            host=host,
            game_type="onuw",
            max_players=10,
            settings={"roles": role_config},
        )
        for user in [host, p1, p2, p3, p4]:
            LobbyMember.objects.create(lobby=lobby, user=user, is_ready=True)
        lobby.status = Lobby.Status.IN_GAME
        lobby.save()

        game = Game.objects.create(
            lobby=lobby,
            phase=Phase.NIGHT,
            random_seed=42,
            settings=lobby.settings,
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
        )

        # host=Werewolf, p1=Werewolf, p2=Seer, p3=Tanner, p4=Villager
        role_assignments = {
            host: "Werewolf",
            p1: "Werewolf",
            p2: "Seer",
            p3: "Tanner",
            p4: "Villager",
        }
        for user, role in role_assignments.items():
            PlayerRole.objects.create(
                game=game, user=user, original_role=role, current_role=role
            )

        users = {"host": host, "p1": p1, "p2": p2, "p3": p3, "p4": p4}
        return game, users, host

    def test_complete_game_tanner_wins(self, db):
        """
        Village votes for Tanner (mistaking them for werewolf).
        Tanner wins.

        1. Night phase: Werewolves see each other, Seer peeks
        2. Discussion -> Voting
        3. All vote for p3 (Tanner) -> Tanner wins!
        """
        game, users, host = self._setup_game()
        client = APIClient()

        action_url = reverse("onuw:night-action", kwargs={"game_id": str(game.id)})
        end_discussion_url = reverse(
            "onuw:end-discussion", kwargs={"game_id": str(game.id)}
        )
        vote_url = reverse("onuw:vote", kwargs={"game_id": str(game.id)})
        results_url = reverse("onuw:results", kwargs={"game_id": str(game.id)})

        ww1 = users["host"]
        ww2 = users["p1"]
        seer = users["p2"]
        tanner = users["p3"]
        villager = users["p4"]

        with _patch_channels():
            from apps.onuw.services import start_night_phase

            start_night_phase(game)

            # ── Wave 2: Werewolves see each other ──────────────────────────
            client.force_authenticate(user=ww1)
            client.post(
                action_url,
                {"action_type": "see_team", "targets": {}},
                format="json",
            )
            client.force_authenticate(user=ww2)
            client.post(
                action_url,
                {"action_type": "see_team", "targets": {}},
                format="json",
            )

            # ── Wave 3: Seer peeks ─────────────────────────────────────────
            # Seer should act in wave 3
            game.refresh_from_db()
            assert game.current_wave == 3

            client.force_authenticate(user=seer)
            client.post(
                action_url,
                {
                    "action_type": "peek_player",
                    # pyrefly: ignore [missing-attribute]
                    "targets": {"player_id": tanner.id},
                },
                format="json",
            )

            # No more wave 3 actors (Robber not in game) -> discussion
            game.refresh_from_db()
            assert game.phase == Phase.DISCUSSION

            # ── Discussion -> Voting ───────────────────────────────────────
            client.force_authenticate(user=host)
            client.post(end_discussion_url)

            game.refresh_from_db()
            assert game.phase == Phase.VOTING

            # ── Voting: All vote for Tanner ────────────────────────────────
            for user in [ww1, ww2, seer, tanner, villager]:
                client.force_authenticate(user=user)
                client.post(
                    vote_url,
                    # pyrefly: ignore [missing-attribute]
                    {"target_player_id": tanner.id},
                    format="json",
                )

            game.refresh_from_db()
            assert game.phase == Phase.RESULTS

            # ── Verify Tanner wins ─────────────────────────────────────────
            assert game.results["winning_team"] == "tanner"
            # pyrefly: ignore [missing-attribute]
            assert tanner.id in game.results["eliminated_players"]

            # Only Tanner wins
            outcomes = game.results["player_outcomes"]
            # pyrefly: ignore [missing-attribute]
            assert outcomes[str(tanner.id)] == "win"
            # Everyone else loses
            # pyrefly: ignore [missing-attribute]
            assert outcomes[str(ww1.id)] == "lose"
            # pyrefly: ignore [missing-attribute]
            assert outcomes[str(ww2.id)] == "lose"
            # pyrefly: ignore [missing-attribute]
            assert outcomes[str(seer.id)] == "lose"
            # pyrefly: ignore [missing-attribute]
            assert outcomes[str(villager.id)] == "lose"

            # ── GET /results/ ──────────────────────────────────────────────
            client.force_authenticate(user=seer)
            response = client.get(results_url)
            assert response.status_code == status.HTTP_200_OK  # type: ignore[union-attr]
            assert response.data["winning_team"] == "tanner"  # type: ignore[union-attr]

            # Verify eliminated player details
            eliminated = response.data["eliminated_players"]  # type: ignore[union-attr]
            assert len(eliminated) == 1
            # pyrefly: ignore [missing-attribute]
            assert eliminated[0]["player_id"] == tanner.id
            assert eliminated[0]["role"] == "Tanner"
