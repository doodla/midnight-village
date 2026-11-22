"""
Integration tests for PATCH /api/core/lobbies/<code>/ (FR-030).

Tests host-only settings update with role validation and WebSocket broadcast.
"""

from unittest.mock import AsyncMock, MagicMock, patch

from django.urls import reverse

import pytest
from rest_framework import status

from apps.core.models import Lobby, LobbyMember, User

pytestmark = pytest.mark.integration


def _lobby_detail_url(code):
    return reverse("core:lobby-detail", kwargs={"code": code})


def _create_lobby_with_players(player_count: int, extra_settings: dict | None = None):
    """
    Create a lobby with `player_count` members (including host) and return
    (lobby, host, list_of_players).

    player_count must be >= 1 (host always included).
    """
    host = User.objects.create_user(
        username=f"host_patch_{player_count}", password="pass"
    )
    lobby = Lobby.objects.create(
        host=host,
        game_type="onuw",
        max_players=10,
        settings=extra_settings or {"roles": {}},
    )
    LobbyMember.objects.create(lobby=lobby, user=host, is_ready=True)

    players = []
    for i in range(player_count - 1):
        player = User.objects.create_user(
            username=f"player_patch_{player_count}_{i}", password="pass"
        )
        LobbyMember.objects.create(lobby=lobby, user=player, is_ready=True)
        players.append(player)

    return lobby, host, players


class TestLobbyPatch:
    """Tests for PATCH /api/core/lobbies/<code>/."""

    def test_host_can_patch_lobby_settings(self, api_client, db):
        """Host can update lobby settings with valid role configuration."""
        # 3 players → need 6 cards total (3 + 3 center)
        lobby, host, _ = _create_lobby_with_players(3)

        api_client.force_authenticate(user=host)
        url = _lobby_detail_url(lobby.code)

        new_roles = {"Werewolf": 2, "Seer": 1, "Villager": 2, "Drunk": 1}
        with patch("apps.core.views.get_channel_layer") as mock_get:
            mock_layer = MagicMock()
            mock_layer.group_send = AsyncMock()
            mock_get.return_value = mock_layer

            response = api_client.patch(
                url,
                {"settings": {"roles": new_roles}},
                format="json",
            )

        assert response.status_code == status.HTTP_200_OK
        assert response.data["settings"]["roles"] == new_roles

        lobby.refresh_from_db()
        assert lobby.settings["roles"] == new_roles

    @pytest.mark.parametrize(
        "bad_settings",
        [
            {"night_wave_seconds": "abc"},
            {"night_wave_seconds": -1},
            {"voting_seconds": 99999},
            {"night_doppelganger_window_seconds": None},
            {"night_wave_seconds": 5, "night_min_window_seconds": 6},
        ],
    )
    def test_patch_rejects_bad_timer_settings(self, api_client, db, bad_settings):
        """Timer settings must be whole seconds in range (400 with a clear error)."""
        lobby, host, _ = _create_lobby_with_players(3)
        api_client.force_authenticate(user=host)
        roles = {"Werewolf": 2, "Seer": 1, "Villager": 2, "Drunk": 1}

        response = api_client.patch(
            _lobby_detail_url(lobby.code),
            {"settings": {"roles": roles, **bad_settings}},
            format="json",
        )

        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert any("seconds" in e for e in response.data["detail"])
        lobby.refresh_from_db()
        assert lobby.settings == {"roles": {}}

    def test_patch_accepts_valid_timer_settings(self, api_client, db):
        lobby, host, _ = _create_lobby_with_players(3)
        api_client.force_authenticate(user=host)
        settings = {
            "roles": {"Werewolf": 2, "Seer": 1, "Villager": 2, "Drunk": 1},
            "night_wave_seconds": 30,
            "night_min_window_seconds": 8,
            "night_doppelganger_window_seconds": 10,
        }

        with patch("apps.core.views.get_channel_layer", return_value=None):
            response = api_client.patch(
                _lobby_detail_url(lobby.code), {"settings": settings}, format="json"
            )

        assert response.status_code == status.HTTP_200_OK
        assert response.data["settings"]["night_doppelganger_window_seconds"] == 10

    def test_patch_lobby_settings_broadcasts_lobby_update(self, api_client, db):
        """Successful PATCH broadcasts lobby_update WebSocket event."""
        lobby, host, _ = _create_lobby_with_players(3)

        api_client.force_authenticate(user=host)
        url = _lobby_detail_url(lobby.code)

        new_roles = {"Werewolf": 2, "Seer": 1, "Villager": 2, "Drunk": 1}

        with patch("apps.core.views.get_channel_layer") as mock_get:
            mock_layer = MagicMock()
            mock_layer.group_send = AsyncMock()
            mock_get.return_value = mock_layer

            api_client.patch(
                url,
                {"settings": {"roles": new_roles}},
                format="json",
            )

            mock_layer.group_send.assert_called_once()
            call_args = mock_layer.group_send.call_args
            group_name = call_args[0][0]
            event = call_args[0][1]

            assert group_name == f"lobby_{lobby.code}"
            assert event["type"] == "lobby.update"

    def test_non_host_cannot_patch_lobby_settings(self, api_client, db):
        """Non-host players receive 403 when attempting to PATCH settings."""
        lobby, _host, players = _create_lobby_with_players(3)
        non_host = players[0]

        api_client.force_authenticate(user=non_host)
        url = _lobby_detail_url(lobby.code)

        response = api_client.patch(
            url,
            {"settings": {"roles": {"Werewolf": 2}}},
            format="json",
        )

        assert response.status_code == status.HTTP_403_FORBIDDEN

    def test_patch_with_wrong_total_card_count_is_stored_and_reported_by_deal(
        self, api_client, db
    ):
        """A deck being built is stored card by card: a short one is kept, and the
        lobby body's ``deal`` says it does not fit (the deal is the one judge)."""
        # 3 players need 6 cards; provide only 4
        lobby, host, _ = _create_lobby_with_players(3)

        api_client.force_authenticate(user=host)
        url = _lobby_detail_url(lobby.code)

        # Only 4 roles for 3 players (needs 6)
        invalid_roles = {"Werewolf": 2, "Seer": 1, "Villager": 1}

        response = api_client.patch(
            url,
            {"settings": {"roles": invalid_roles}},
            format="json",
        )

        assert response.status_code == status.HTTP_200_OK
        assert response.data["deal"] == {
            "ok": False,
            "need": 6,
            "have": 4,
            "seats": None,
        }

    def test_patch_with_odd_mason_count_returns_400(self, api_client, db):
        """PATCH with a single Mason (must be 0 or 2) returns 400."""
        # 4 players need 7 cards
        lobby, host, _ = _create_lobby_with_players(4)

        api_client.force_authenticate(user=host)
        url = _lobby_detail_url(lobby.code)

        # 1 Mason is invalid (must be 0 or 2)
        invalid_roles = {"Werewolf": 2, "Seer": 1, "Mason": 1, "Villager": 3}

        response = api_client.patch(
            url,
            {"settings": {"roles": invalid_roles}},
            format="json",
        )

        assert response.status_code == status.HTTP_400_BAD_REQUEST

    def test_patch_returns_updated_lobby_serialization(self, api_client, db):
        """PATCH response includes full LobbySerializer fields."""
        lobby, host, _ = _create_lobby_with_players(3)

        api_client.force_authenticate(user=host)
        url = _lobby_detail_url(lobby.code)

        new_roles = {"Werewolf": 2, "Seer": 1, "Villager": 2, "Drunk": 1}

        with patch("apps.core.views.get_channel_layer", return_value=None):
            response = api_client.patch(
                url,
                {"settings": {"roles": new_roles}},
                format="json",
            )

        assert response.status_code == status.HTTP_200_OK
        assert "code" in response.data
        assert "host" in response.data
        assert "players" in response.data
        assert "settings" in response.data

    def test_patch_nonexistent_lobby_returns_404(self, api_client, db):
        """PATCH on a nonexistent lobby code returns 404."""
        user = User.objects.create_user(username="patchuser404", password="pass")
        api_client.force_authenticate(user=user)

        url = _lobby_detail_url("ZZZZZZ")
        response = api_client.patch(
            url,
            {"settings": {"roles": {}}},
            format="json",
        )

        assert response.status_code == status.HTTP_404_NOT_FOUND

    def test_patch_no_channel_layer_still_succeeds(self, api_client, db):
        """PATCH succeeds even when channel layer is unavailable."""
        lobby, host, _ = _create_lobby_with_players(3)

        api_client.force_authenticate(user=host)
        url = _lobby_detail_url(lobby.code)

        new_roles = {"Werewolf": 2, "Seer": 1, "Villager": 2, "Drunk": 1}

        with patch("apps.core.views.get_channel_layer", return_value=None):
            response = api_client.patch(
                url,
                {"settings": {"roles": new_roles}},
                format="json",
            )

        assert response.status_code == status.HTTP_200_OK
