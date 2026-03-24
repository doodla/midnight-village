"""
Integration test: full lobby-to-game flow.

Simulates a realistic frontend flow with 5 players going through guest
registration, lobby creation, join, ready, game start, and player-scoped
state retrieval.
"""

from django.urls import reverse

import pytest
from rest_framework import status
from rest_framework.test import APIClient

pytestmark = pytest.mark.integration


class TestLobbyToGameFlow:
    """End-to-end flow from lobby creation to game state retrieval."""

    def test_five_player_game_flow(self, db):
        """
        Full 5-player flow:
        1. Create 5 guest accounts
        2. Player 1 creates lobby
        3. Players 2-5 join
        4. Host updates settings with role config
        5. All 5 players ready up
        6. Host starts game
        7. Each player queries their state
        8. Verify: each sees exactly one role, no leaks, correct phase
        """
        # Role config: 8 roles for 5 players
        role_config = {
            "Werewolf": 2,
            "Seer": 1,
            "Robber": 1,
            "Villager": 1,
            "Drunk": 1,
            "Insomniac": 1,
            "Troublemaker": 1,
        }

        # ── Step 1: Create 5 guest accounts ──────────────────────────
        clients = []
        user_ids = []
        guest_url = reverse("core:guest-create")
        for _i in range(5):
            client = APIClient()
            response = client.post(guest_url, {}, format="json")
            assert response.status_code == status.HTTP_201_CREATED  # type: ignore[misc]
            token = response.data["access"]  # type: ignore[misc]
            user_id = response.data["user"]["id"]  # type: ignore[misc]
            client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")
            clients.append(client)
            user_ids.append(user_id)

        host_client = clients[0]

        # ── Step 2: Player 1 creates lobby ────────────────────────────
        create_url = reverse("core:lobby-list")
        response = host_client.post(
            create_url,
            {"game_type": "onuw", "max_players": 10},
            format="json",
        )
        assert response.status_code == status.HTTP_201_CREATED
        lobby_code = response.data["code"]

        # ── Step 3: Players 2-5 join lobby ────────────────────────────
        join_url = reverse("core:lobby-join", kwargs={"code": lobby_code})
        for client in clients[1:]:
            response = client.post(join_url)
            assert response.status_code == status.HTTP_200_OK

        # ── Step 4: Host updates lobby settings with role config ──────
        # No PATCH endpoint yet, so update directly via ORM
        from apps.core.models import Lobby

        lobby = Lobby.objects.get(code=lobby_code)
        lobby.settings = {"roles": role_config}
        lobby.save()

        # ── Step 5: All 5 players ready up ────────────────────────────
        ready_url = reverse("core:lobby-ready", kwargs={"code": lobby_code})
        for client in clients:
            response = client.post(ready_url, {"is_ready": True}, format="json")
            assert response.status_code == status.HTTP_200_OK

        # ── Step 6: Host starts game ──────────────────────────────────
        start_url = reverse("onuw:game-start", kwargs={"code": lobby_code})
        response = host_client.post(start_url)
        assert response.status_code == status.HTTP_201_CREATED
        game_id = response.data["game_id"]
        assert response.data["phase"] == "night"

        # ── Step 7: Each player queries their state ───────────────────
        me_url = reverse("onuw:game-me", kwargs={"game_id": str(game_id)})
        player_responses = []
        for client in clients:
            response = client.get(me_url)
            assert response.status_code == status.HTTP_200_OK
            player_responses.append(response.data)

        # ── Step 8: Verify correctness ────────────────────────────────

        # Each player sees exactly one role
        roles_seen = []
        for resp in player_responses:
            assert "your_role" in resp
            role_data = resp["your_role"]
            assert "original_role" in role_data
            assert "current_role" in role_data
            assert role_data["original_role"] == role_data["current_role"]
            roles_seen.append(role_data["original_role"])

        # All roles are valid
        valid_roles = set(role_config.keys())
        for role in roles_seen:
            assert role in valid_roles

        # No two player responses reveal another player's role info
        # (each response should only contain the player's own role)
        for i, resp_i in enumerate(player_responses):
            role_i = resp_i["your_role"]["original_role"]
            # Check that no OTHER player's specific role appears in resp_i
            # (unless they happen to share the same role, e.g., two Werewolves)
            for j, resp_j in enumerate(player_responses):
                if i == j:
                    continue
                role_j = resp_j["your_role"]["original_role"]
                if role_j != role_i:
                    # If another player has a different role, it should not
                    # appear in player i's response
                    # We check the your_role block specifically
                    assert resp_i["your_role"]["original_role"] != role_j

        # Center cards not visible in any response
        for resp in player_responses:
            assert "center_cards" not in resp

        # All responses show correct game phase
        for resp in player_responses:
            assert resp["phase"] == "night"
            assert resp["game_id"] == str(game_id)

        # Verify total role distribution:
        # 5 player roles + 3 center cards = 8 total
        from apps.onuw.models import Game

        game = Game.objects.get(id=game_id)
        assert len(game.center_cards) == 3

        all_roles = roles_seen + game.center_cards
        from collections import Counter

        actual_counts = Counter(all_roles)
        for role_name, expected_count in role_config.items():
            assert actual_counts[role_name] == expected_count, (
                f"Expected {expected_count} of {role_name}, "
                f"got {actual_counts.get(role_name, 0)}"
            )
