"""
End-to-end integration test for the ONUW night phase.

Tests a complete 5-player game flow through the night phase using the
HTTP API, verifying DB state, /me/ responses, and hidden information
isolation.

Players: Werewolf, Werewolf, Seer, Robber, Villager
Center:  Drunk, Insomniac, Troublemaker

Night flow:
  Wave 2: Werewolves see each other
  Wave 3: Seer peeks a werewolf, Robber swaps with a werewolf
  No wave 4 actors -> transition to discussion
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


class TestNightPhaseE2E:
    """Full night phase end-to-end flow with 5 players."""

    def _setup_game(self):
        """
        Create a game with deterministic role assignments.

        Returns (game, users_by_role) where users_by_role maps
        role name -> User object.
        """
        # Create 5 users
        host = User.objects.create_user(username="e2e_host", password="pass")
        p1 = User.objects.create_user(username="e2e_p1", password="pass")
        p2 = User.objects.create_user(username="e2e_p2", password="pass")
        p3 = User.objects.create_user(username="e2e_p3", password="pass")
        p4 = User.objects.create_user(username="e2e_p4", password="pass")
        all_users = [host, p1, p2, p3, p4]

        role_config = {
            "Werewolf": 2,
            "Seer": 1,
            "Robber": 1,
            "Villager": 1,
            "Drunk": 1,
            "Insomniac": 1,
            "Troublemaker": 1,
        }

        # Create lobby
        lobby = Lobby.objects.create(
            host=host,
            game_type="onuw",
            max_players=10,
            settings={"roles": role_config},
        )
        for user in all_users:
            LobbyMember.objects.create(lobby=lobby, user=user, is_ready=True)
        lobby.status = Lobby.Status.IN_GAME
        lobby.save()

        # Assign specific roles deterministically
        # We use assign_roles with a specific seed to get deterministic results,
        # then override to get the exact roles we want for testing.
        game = Game.objects.create(
            lobby=lobby,
            phase=Phase.NIGHT,
            random_seed=42,
            settings=lobby.settings,
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
        )

        # Assign roles explicitly for the test scenario
        role_assignments = {
            host: "Werewolf",
            p1: "Werewolf",
            p2: "Seer",
            p3: "Robber",
            p4: "Villager",
        }

        users_by_role = {}
        for user, role in role_assignments.items():
            PlayerRole.objects.create(
                game=game,
                user=user,
                original_role=role,
                current_role=role,
            )
            users_by_role[role] = users_by_role.get(role, [])
            users_by_role[role].append(user)

        return game, users_by_role, host

    def test_full_night_phase_flow(self, db):
        """
        Complete night phase:
        1. Create game with 5 players
        2. Initialize night phase (find first wave)
        3. Wave 2: Werewolves submit see_team
        4. Wave 3: Seer peeks, Robber swaps
        5. No more waves -> discussion
        6. Verify final state and /me/ responses
        """
        game, users_by_role, _host = self._setup_game()

        ww1 = users_by_role["Werewolf"][0]
        ww2 = users_by_role["Werewolf"][1]
        seer = users_by_role["Seer"][0]
        robber = users_by_role["Robber"][0]
        villager = users_by_role["Villager"][0]

        all_players = [ww1, ww2, seer, robber, villager]

        # Initialize night phase
        with _patch_channels():
            from apps.onuw.services import start_night_phase

            start_night_phase(game)

        # ── Step 1: Verify initial state ──────────────────────────────
        game.refresh_from_db()
        assert game.phase == Phase.NIGHT
        # First active wave should be 2 (Werewolves)
        assert game.current_wave == 2

        # ── Step 2: Wave 2 -- Werewolves see each other ───────────────
        action_url = reverse("onuw:night-action", kwargs={"game_id": str(game.id)})

        with _patch_channels():
            # Werewolf 1 submits
            client = APIClient()
            client.force_authenticate(user=ww1)
            response = client.post(
                action_url,
                {"action_type": "see_team", "targets": {}},
                format="json",
            )
            # pyrefly: ignore [missing-attribute]
            assert response.status_code == status.HTTP_200_OK

            # Werewolf 2 submits -- should auto-advance
            client.force_authenticate(user=ww2)
            response = client.post(
                action_url,
                {"action_type": "see_team", "targets": {}},
                format="json",
            )
            # pyrefly: ignore [missing-attribute]
            assert response.status_code == status.HTTP_200_OK

        # Wave should have advanced to 3
        game.refresh_from_db()
        assert game.current_wave == 3

        # Verify werewolf results
        pr_ww1 = PlayerRole.objects.get(game=game, user=ww1)
        assert "wave_2_result" in pr_ww1.night_action_data
        assert ww2.id in pr_ww1.night_action_data["wave_2_result"]["werewolves"]

        pr_ww2 = PlayerRole.objects.get(game=game, user=ww2)
        assert "wave_2_result" in pr_ww2.night_action_data
        assert ww1.id in pr_ww2.night_action_data["wave_2_result"]["werewolves"]

        # ── Step 3: Wave 3 -- Seer peeks, Robber swaps ───────────────
        with _patch_channels():
            # Seer peeks at Werewolf 1
            client.force_authenticate(user=seer)
            response = client.post(
                action_url,
                {
                    "action_type": "peek_player",
                    "targets": {"player_id": ww1.id},
                },
                format="json",
            )
            # pyrefly: ignore [missing-attribute]
            assert response.status_code == status.HTTP_200_OK

            # Robber swaps with Werewolf 1
            client.force_authenticate(user=robber)
            response = client.post(
                action_url,
                {
                    "action_type": "swap_with_player",
                    "targets": {"player_id": ww1.id},
                },
                format="json",
            )
            # pyrefly: ignore [missing-attribute]
            assert response.status_code == status.HTTP_200_OK

        # ── Step 4: Verify transition to discussion ───────────────────
        game.refresh_from_db()
        assert game.phase == Phase.DISCUSSION
        assert game.current_wave == 0

        # ── Step 5: Verify final roles ────────────────────────────────
        # Wave 3 canonical order: Seer -> Robber -> Troublemaker -> Drunk
        # Seer peeks ww1 -> sees Werewolf (before Robber swap)
        # Robber swaps with ww1 -> Robber gets Werewolf, ww1 gets Robber
        # Final: ww1=Robber, ww2=Werewolf, seer=Seer, robber=Werewolf, villager=Villager

        pr_ww1 = PlayerRole.objects.get(game=game, user=ww1)
        assert pr_ww1.current_role == "Robber"

        pr_ww2 = PlayerRole.objects.get(game=game, user=ww2)
        assert pr_ww2.current_role == "Werewolf"

        pr_seer = PlayerRole.objects.get(game=game, user=seer)
        assert pr_seer.current_role == "Seer"

        pr_robber = PlayerRole.objects.get(game=game, user=robber)
        assert pr_robber.current_role == "Werewolf"

        pr_villager = PlayerRole.objects.get(game=game, user=villager)
        assert pr_villager.current_role == "Villager"

        # ── Step 6: Verify Seer's peek result ─────────────────────────
        pr_seer.refresh_from_db()
        assert "wave_3_result" in pr_seer.night_action_data
        assert pr_seer.night_action_data["wave_3_result"]["peeked_role"] == "Werewolf"

        # ── Step 7: Verify Robber's swap result ───────────────────────
        pr_robber.refresh_from_db()
        assert "wave_3_result" in pr_robber.night_action_data
        assert pr_robber.night_action_data["wave_3_result"]["new_role"] == "Werewolf"

        # ── Step 8: Verify /me/ endpoint for each player ──────────────
        me_url = reverse("onuw:game-me", kwargs={"game_id": str(game.id)})

        # Check each player sees their own data (current_role hidden before results)
        for player_user in all_players:
            client.force_authenticate(user=player_user)
            response = client.get(me_url)
            assert response.status_code == status.HTTP_200_OK
            assert response.data["phase"] == "discussion"
            assert "original_role" in response.data["your_role"]
            assert "current_role" not in response.data["your_role"]

        # ── Step 9: Verify hidden information isolation ───────────────
        # Each player's /me/ should ONLY contain their own role info
        responses_by_player = {}
        for player_user in all_players:
            client.force_authenticate(user=player_user)
            response = client.get(me_url)
            # pyrefly: ignore [missing-attribute]
            responses_by_player[player_user.id] = response.data

        # night_action_data should NOT be exposed during discussion phase
        # (it contains internal engine state; results are delivered via WebSocket)
        for player_id, resp in responses_by_player.items():
            assert "night_action_data" not in resp["your_role"], (
                f"Player {player_id} should not see night_action_data during discussion"
            )

        # No player response should contain center_cards
        for resp in responses_by_player.values():
            assert "center_cards" not in resp

    def test_night_actions_log_recorded(self, db):
        """Verify the game's night_actions_log contains all actions."""
        game, users_by_role, _host = self._setup_game()

        ww1 = users_by_role["Werewolf"][0]
        ww2 = users_by_role["Werewolf"][1]
        seer = users_by_role["Seer"][0]
        robber = users_by_role["Robber"][0]

        action_url = reverse("onuw:night-action", kwargs={"game_id": str(game.id)})

        with _patch_channels():
            from apps.onuw.services import start_night_phase

            start_night_phase(game)

            # Wave 2
            client = APIClient()
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

            # Wave 3
            client.force_authenticate(user=seer)
            client.post(
                action_url,
                {
                    "action_type": "peek_player",
                    "targets": {"player_id": ww1.id},
                },
                format="json",
            )
            client.force_authenticate(user=robber)
            client.post(
                action_url,
                {
                    "action_type": "swap_with_player",
                    "targets": {"player_id": ww1.id},
                },
                format="json",
            )

        game.refresh_from_db()
        log = game.night_actions_log

        # Should have 4 entries: 2 werewolves + seer + robber
        assert len(log) == 4

        # Wave 2 entries
        wave_2_entries = [e for e in log if e["wave"] == 2]
        assert len(wave_2_entries) == 2
        assert all(e["action_type"] == "see_team" for e in wave_2_entries)

        # Wave 3 entries
        wave_3_entries = [e for e in log if e["wave"] == 3]
        assert len(wave_3_entries) == 2
        wave_3_types = {e["action_type"] for e in wave_3_entries}
        assert "peek_player" in wave_3_types
        assert "swap_with_player" in wave_3_types
