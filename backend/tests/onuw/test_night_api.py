"""
Integration tests for the ONUW Night Phase API endpoints.

Tests the NightActionView and WaveAdvanceView with various scenarios.
"""

from unittest.mock import patch

from django.urls import reverse

import pytest
from rest_framework import status

from apps.core.models import Lobby, LobbyMember, User
from apps.onuw.models import Game, Phase, PlayerRole

pytestmark = pytest.mark.integration


def _create_game(
    players_roles: dict[str, str],
    center_cards: list[str],
    phase: str = Phase.NIGHT,
    current_wave: int = 2,
    host_username: str = "host_na",
):
    """
    Create a game with specific role assignments.

    Args:
        players_roles: Mapping of username -> role name.
        center_cards: List of 3 center card role names.
        phase: Game phase.
        current_wave: Current wave number.
        host_username: Username for the host (first player).

    Returns:
        (game, users_dict) where users_dict maps username -> User.
    """
    usernames = list(players_roles.keys())
    users = {}
    for uname in usernames:
        users[uname] = User.objects.create_user(username=uname, password="pass")

    host = users[usernames[0]]
    lobby = Lobby.objects.create(
        host=host,
        game_type="onuw",
        max_players=10,
        settings={"roles": {}},
    )
    for user in users.values():
        LobbyMember.objects.create(lobby=lobby, user=user, is_ready=True)
    lobby.status = Lobby.Status.IN_GAME
    lobby.save()

    game = Game.objects.create(
        lobby=lobby,
        phase=phase,
        current_wave=current_wave,
        random_seed=42,
        settings=lobby.settings,
        center_cards=center_cards,
    )

    for uname, role in players_roles.items():
        PlayerRole.objects.create(
            game=game,
            user=users[uname],
            original_role=role,
            current_role=role,
        )

    return game, users


def _action_url(game_id):
    return reverse("onuw:night-action", kwargs={"game_id": str(game_id)})


def _advance_url(game_id):
    return reverse("onuw:wave-advance", kwargs={"game_id": str(game_id)})


def _patch_channels():
    """Context manager to mock out channel layer so WebSocket sends are no-ops."""
    return patch("apps.onuw.services.get_channel_layer", return_value=None)


class TestNightActionSubmission:
    """Tests for POST /api/onuw/games/<game_id>/action/."""

    def test_seer_can_submit_peek_player_action(self, api_client, db):
        """Seer can submit a peek_player action targeting another player."""
        game, users = _create_game(
            {
                "host_seer": "Seer",
                "p1_ww": "Werewolf",
                "p2_rob": "Robber",
                "p3_vill": "Villager",
                "p4_drunk": "Drunk",
            },
            center_cards=["Troublemaker", "Insomniac", "Villager"],
            current_wave=3,
        )

        seer_user = users["host_seer"]
        target_user = users["p1_ww"]
        api_client.force_authenticate(user=seer_user)

        with _patch_channels():
            response = api_client.post(
                _action_url(game.id),
                {
                    "action_type": "peek_player",
                    "targets": {"player_id": target_user.id},
                },
                format="json",
            )

        assert response.status_code == status.HTTP_200_OK
        assert response.data["status"] == "submitted"

        # Verify DB state
        pr = PlayerRole.objects.get(game=game, user=seer_user)
        assert pr.has_acted is True
        assert pr.night_action_data["action_type"] == "peek_player"
        assert pr.night_action_data["role_acting_as"] == "Seer"

    def test_wrong_action_type_rejected(self, api_client, db):
        """Submitting an action type not allowed for the role returns 400."""
        game, users = _create_game(
            {
                "host_seer2": "Seer",
                "p1_ww2": "Werewolf",
                "p2_rob2": "Robber",
                "p3_vill2": "Villager",
                "p4_drunk2": "Drunk",
            },
            center_cards=["Troublemaker", "Insomniac", "Villager"],
            current_wave=3,
        )

        seer_user = users["host_seer2"]
        target_user = users["p1_ww2"]
        api_client.force_authenticate(user=seer_user)

        with _patch_channels():
            response = api_client.post(
                _action_url(game.id),
                {
                    "action_type": "swap_with_player",
                    "targets": {"player_id": target_user.id},
                },
                format="json",
            )

        assert response.status_code == status.HTTP_400_BAD_REQUEST

    def test_player_cannot_submit_in_wrong_wave(self, api_client, db):
        """A Werewolf cannot submit in wave 3 (they act in wave 2)."""
        game, users = _create_game(
            {
                "host_ww3": "Werewolf",
                "p1_seer3": "Seer",
                "p2_rob3": "Robber",
                "p3_vill3": "Villager",
                "p4_drunk3": "Drunk",
            },
            center_cards=["Troublemaker", "Insomniac", "Villager"],
            current_wave=3,
        )

        ww_user = users["host_ww3"]
        api_client.force_authenticate(user=ww_user)

        with _patch_channels():
            response = api_client.post(
                _action_url(game.id),
                {
                    "action_type": "see_team",
                    "targets": {},
                },
                format="json",
            )

        assert response.status_code == status.HTTP_400_BAD_REQUEST

    def test_player_cannot_submit_twice_same_wave(self, api_client, db):
        """A player cannot submit twice in the same wave."""
        game, users = _create_game(
            {
                "host_seer4": "Seer",
                "p1_ww4": "Werewolf",
                "p2_rob4": "Robber",
                "p3_vill4": "Villager",
                "p4_drunk4": "Drunk",
            },
            center_cards=["Troublemaker", "Insomniac", "Villager"],
            current_wave=3,
        )

        seer_user = users["host_seer4"]
        target_user = users["p1_ww4"]
        api_client.force_authenticate(user=seer_user)

        with _patch_channels():
            # First submission
            response = api_client.post(
                _action_url(game.id),
                {
                    "action_type": "peek_player",
                    "targets": {"player_id": target_user.id},
                },
                format="json",
            )
            assert response.status_code == status.HTTP_200_OK

            # Second submission should fail
            response = api_client.post(
                _action_url(game.id),
                {
                    "action_type": "peek_player",
                    "targets": {"player_id": target_user.id},
                },
                format="json",
            )
            assert response.status_code == status.HTTP_400_BAD_REQUEST

    def test_non_player_gets_403(self, api_client, db):
        """A user not in the game gets 403."""
        game, _users = _create_game(
            {
                "host_np": "Seer",
                "p1_np": "Werewolf",
                "p2_np": "Robber",
                "p3_np": "Villager",
                "p4_np": "Drunk",
            },
            center_cards=["Troublemaker", "Insomniac", "Villager"],
            current_wave=3,
        )
        outsider = User.objects.create_user(username="outsider_na", password="pass")
        api_client.force_authenticate(user=outsider)

        with _patch_channels():
            response = api_client.post(
                _action_url(game.id),
                {
                    "action_type": "peek_player",
                    "targets": {"player_id": 999},
                },
                format="json",
            )

        assert response.status_code == status.HTTP_403_FORBIDDEN

    def test_action_in_wrong_phase_rejected(self, api_client, db):
        """Cannot submit an action when the game is not in night phase."""
        game, users = _create_game(
            {
                "host_wp": "Seer",
                "p1_wp": "Werewolf",
                "p2_wp": "Robber",
                "p3_wp": "Villager",
                "p4_wp": "Drunk",
            },
            center_cards=["Troublemaker", "Insomniac", "Villager"],
            phase=Phase.DISCUSSION,
            current_wave=0,
        )

        seer_user = users["host_wp"]
        api_client.force_authenticate(user=seer_user)

        with _patch_channels():
            response = api_client.post(
                _action_url(game.id),
                {
                    "action_type": "peek_player",
                    "targets": {"player_id": users["p1_wp"].id},
                },
                format="json",
            )

        assert response.status_code == status.HTTP_400_BAD_REQUEST


class TestWaveAdvancement:
    """Tests for auto-advance and force-advance mechanics."""

    def test_wave_advances_when_all_actors_submit(self, api_client, db):
        """Wave auto-advances when all expected actors have submitted."""
        game, users = _create_game(
            {
                "host_aa": "Werewolf",
                "p1_aa": "Werewolf",
                "p2_aa": "Seer",
                "p3_aa": "Robber",
                "p4_aa": "Villager",
            },
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
            current_wave=2,
        )

        with _patch_channels():
            # Werewolf 1 submits
            api_client.force_authenticate(user=users["host_aa"])
            response = api_client.post(
                _action_url(game.id),
                {"action_type": "see_team", "targets": {}},
                format="json",
            )
            assert response.status_code == status.HTTP_200_OK

            # Werewolf 2 submits -- wave should auto-advance
            api_client.force_authenticate(user=users["p1_aa"])
            response = api_client.post(
                _action_url(game.id),
                {"action_type": "see_team", "targets": {}},
                format="json",
            )
            assert response.status_code == status.HTTP_200_OK

        # Game should have advanced to wave 3 (Seer and Robber act)
        game.refresh_from_db()
        assert game.current_wave == 3

        # Both werewolves should have results stored
        pr_ww1 = PlayerRole.objects.get(game=game, user=users["host_aa"])
        assert "wave_2_result" in pr_ww1.night_action_data
        assert "werewolves" in pr_ww1.night_action_data["wave_2_result"]

    def test_host_can_force_advance_wave(self, api_client, db):
        """Host can force-advance the wave, skipping non-submitters."""
        game, users = _create_game(
            {
                "host_fa": "Werewolf",
                "p1_fa": "Werewolf",
                "p2_fa": "Seer",
                "p3_fa": "Robber",
                "p4_fa": "Villager",
            },
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
            current_wave=2,
        )

        # Only Werewolf 1 submits
        with _patch_channels():
            api_client.force_authenticate(user=users["host_fa"])
            response = api_client.post(
                _action_url(game.id),
                {"action_type": "see_team", "targets": {}},
                format="json",
            )
            assert response.status_code == status.HTTP_200_OK

            # Host force-advances
            response = api_client.post(
                _advance_url(game.id),
                format="json",
            )
            assert response.status_code == status.HTTP_200_OK
            assert response.data["status"] == "advanced"

        # Wave should have advanced (Werewolf 2 skipped)
        game.refresh_from_db()
        assert game.current_wave == 3

    def test_game_transitions_to_discussion_after_all_waves(self, api_client, db):
        """Game transitions to discussion when no more active waves remain."""
        # Use only roles that act in wave 2 (no wave 3 or 4 roles)
        game, users = _create_game(
            {
                "host_td": "Werewolf",
                "p1_td": "Werewolf",
                "p2_td": "Villager",
                "p3_td": "Villager",
                "p4_td": "Villager",
            },
            center_cards=["Villager", "Tanner", "Hunter"],
            current_wave=2,
        )

        with _patch_channels():
            # Both werewolves submit
            api_client.force_authenticate(user=users["host_td"])
            api_client.post(
                _action_url(game.id),
                {"action_type": "see_team", "targets": {}},
                format="json",
            )

            api_client.force_authenticate(user=users["p1_td"])
            api_client.post(
                _action_url(game.id),
                {"action_type": "see_team", "targets": {}},
                format="json",
            )

        # Should transition to discussion (no wave 3 or 4 actors)
        game.refresh_from_db()
        assert game.phase == Phase.DISCUSSION
        assert game.current_wave == 0

    def test_non_host_cannot_force_advance(self, api_client, db):
        """Non-host players cannot force-advance the wave."""
        game, users = _create_game(
            {
                "host_nh": "Werewolf",
                "p1_nh": "Werewolf",
                "p2_nh": "Seer",
                "p3_nh": "Villager",
                "p4_nh": "Drunk",
            },
            center_cards=["Troublemaker", "Insomniac", "Villager"],
            current_wave=2,
        )

        api_client.force_authenticate(user=users["p1_nh"])

        with _patch_channels():
            response = api_client.post(
                _advance_url(game.id),
                format="json",
            )

        assert response.status_code == status.HTTP_403_FORBIDDEN
