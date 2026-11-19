"""
Integration tests for ONUW reconnection-related endpoints.

Tests the GET /api/onuw/me/current-game/ and updated
GET /api/onuw/games/<game_id>/me/ endpoints.
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
    current_wave: int = 0,
):
    """
    Create a game with specific role assignments.

    Returns (game, users_dict, host_user) where users_dict maps username -> User.
    The first key in players_roles is the host.
    """
    usernames = list(players_roles.keys())
    users = {}
    for uname in usernames:
        users[uname] = User.objects.create_user(
            username=uname,
            password="pass",
            display_name=uname.replace("_", " ").title(),
        )

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

    return game, users, host


def _current_game_url():
    return reverse("onuw:current-game")


def _me_url(game_id):
    return reverse("onuw:game-me", kwargs={"game_id": str(game_id)})


def _patch_channels():
    """Context manager to mock out channel layer so WebSocket sends are no-ops."""
    return patch("apps.core.effects.get_channel_layer", return_value=None)


class TestCurrentGame:
    """Tests for GET /api/onuw/me/current-game/."""

    def test_current_game_returns_active_game(self, api_client, db):
        """Returns the user's current active game when one exists."""
        game, _users, host = _create_game(
            {
                "cg_host": "Werewolf",
                "cg_p1": "Seer",
            },
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
            phase=Phase.NIGHT,
        )

        api_client.force_authenticate(user=host)
        response = api_client.get(_current_game_url())

        assert response.status_code == status.HTTP_200_OK
        assert response.data["game_id"] == str(game.id)
        assert response.data["phase"] == "night"
        assert response.data["lobby_code"] == game.lobby.code

    def test_current_game_returns_null_when_no_game(self, api_client, db):
        """Returns {"game": null} when user is not in any active game."""
        user = User.objects.create_user(username="cg_nobody", password="pass")

        api_client.force_authenticate(user=user)
        response = api_client.get(_current_game_url())

        assert response.status_code == status.HTTP_200_OK
        assert response.data["game"] is None

    def test_current_game_excludes_finished_games(self, api_client, db):
        """Finished games (phase=results) are not returned."""
        _game, _users, host = _create_game(
            {
                "cgf_host": "Werewolf",
                "cgf_p1": "Seer",
            },
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
            phase=Phase.RESULTS,
        )

        api_client.force_authenticate(user=host)
        response = api_client.get(_current_game_url())

        assert response.status_code == status.HTTP_200_OK
        assert response.data["game"] is None

    def test_current_game_returns_most_recent_active(self, api_client, db):
        """If somehow in multiple active games, returns the most recent."""
        user = User.objects.create_user(
            username="cgm_user", password="pass", display_name="Multi User"
        )
        other = User.objects.create_user(
            username="cgm_other", password="pass", display_name="Other"
        )

        # Create older game
        lobby1 = Lobby.objects.create(
            host=user,
            game_type="onuw",
            settings={"roles": {}},
        )
        LobbyMember.objects.create(lobby=lobby1, user=user, is_ready=True)
        LobbyMember.objects.create(lobby=lobby1, user=other, is_ready=True)
        lobby1.status = Lobby.Status.IN_GAME
        lobby1.save()
        game1 = Game.objects.create(
            lobby=lobby1,
            phase=Phase.DISCUSSION,
            random_seed=1,
            settings={},
            center_cards=["A", "B", "C"],
        )
        PlayerRole.objects.create(
            game=game1,
            user=user,
            original_role="Seer",
            current_role="Seer",
        )

        # Create newer game
        lobby2 = Lobby.objects.create(
            host=user,
            game_type="onuw",
            settings={"roles": {}},
        )
        LobbyMember.objects.create(lobby=lobby2, user=user, is_ready=True)
        LobbyMember.objects.create(lobby=lobby2, user=other, is_ready=True)
        lobby2.status = Lobby.Status.IN_GAME
        lobby2.save()
        game2 = Game.objects.create(
            lobby=lobby2,
            phase=Phase.NIGHT,
            random_seed=2,
            settings={},
            center_cards=["D", "E", "F"],
        )
        PlayerRole.objects.create(
            game=game2,
            user=user,
            original_role="Robber",
            current_role="Robber",
        )

        api_client.force_authenticate(user=user)
        response = api_client.get(_current_game_url())

        assert response.status_code == status.HTTP_200_OK
        # Should return the more recently created game
        assert response.data["game_id"] == str(game2.id)

    def test_current_game_works_for_each_active_phase(self, api_client, db):
        """Active phases (lobby, night, discussion, voting) are all returned."""
        for idx, phase in enumerate(
            [Phase.LOBBY, Phase.NIGHT, Phase.DISCUSSION, Phase.VOTING]
        ):
            user = User.objects.create_user(username=f"cgp_user_{idx}", password="pass")
            other = User.objects.create_user(
                username=f"cgp_other_{idx}", password="pass"
            )
            lobby = Lobby.objects.create(
                host=user,
                game_type="onuw",
                settings={"roles": {}},
            )
            LobbyMember.objects.create(lobby=lobby, user=user, is_ready=True)
            LobbyMember.objects.create(lobby=lobby, user=other, is_ready=True)
            lobby.status = Lobby.Status.IN_GAME
            lobby.save()
            game = Game.objects.create(
                lobby=lobby,
                phase=phase,
                random_seed=idx,
                settings={},
                center_cards=["A", "B", "C"],
            )
            PlayerRole.objects.create(
                game=game,
                user=user,
                original_role="Seer",
                current_role="Seer",
            )

            api_client.force_authenticate(user=user)
            response = api_client.get(_current_game_url())

            assert response.status_code == status.HTTP_200_OK
            assert response.data["game_id"] == str(game.id)
            assert response.data["phase"] == phase


class TestMeEndpointReconnection:
    """Tests for the updated GET /api/onuw/games/<game_id>/me/ endpoint."""

    def test_me_endpoint_includes_players_list(self, api_client, db):
        """The /me/ endpoint includes a list of all players."""
        game, users, host = _create_game(
            {
                "mep_host": "Werewolf",
                "mep_p1": "Seer",
                "mep_p2": "Villager",
            },
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
            phase=Phase.DISCUSSION,
        )

        api_client.force_authenticate(user=host)
        response = api_client.get(_me_url(game.id))

        assert response.status_code == status.HTTP_200_OK
        assert "deadline" in response.data
        assert response.data["deadline"] is None
        assert "players" in response.data
        assert len(response.data["players"]) == 3

        # Verify all players are listed
        returned_ids = {p["player_id"] for p in response.data["players"]}
        expected_ids = {u.id for u in users.values()}
        assert returned_ids == expected_ids

        # Verify only public info is included
        for p in response.data["players"]:
            assert "player_id" in p
            assert "display_name" in p
            # No roles should be leaked
            assert "original_role" not in p
            assert "current_role" not in p

    def test_me_endpoint_players_hide_roles(self, api_client, db):
        """The players list in /me/ never contains role information."""
        game, users, _host = _create_game(
            {
                "meph_host": "Werewolf",
                "meph_p1": "Seer",
            },
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
        )

        api_client.force_authenticate(user=users["meph_p1"])
        response = api_client.get(_me_url(game.id))

        assert response.status_code == status.HTTP_200_OK
        assert response.data["deadline"] is None

        # Convert players list to string and verify no roles leak
        players_str = str(response.data["players"])
        assert "Werewolf" not in players_str
        assert "Seer" not in players_str

    def test_me_endpoint_includes_action_prompt_during_night(self, api_client, db):
        """
        During night phase, if the player needs to act in the current window,
        the action_prompt field is populated with the prompt data.
        """
        game, users, _host = _create_game(
            {
                "meap_host": "Werewolf",
                "meap_p1": "Seer",
                "meap_p2": "Robber",
                "meap_p3": "Villager",
                "meap_p4": "Drunk",
            },
            center_cards=["Troublemaker", "Insomniac", "Villager"],
            phase=Phase.NIGHT,
            current_wave=2,
        )

        # Seer acts in the shared window (window 2)
        api_client.force_authenticate(user=users["meap_p1"])
        response = api_client.get(_me_url(game.id))

        assert response.status_code == status.HTTP_200_OK
        assert "deadline" in response.data
        assert response.data["action_prompt"] is not None

        prompt = response.data["action_prompt"]
        assert prompt["role_acting_as"] == "Seer"
        assert "peek_player" in prompt["action_types"]
        assert "peek_center" in prompt["action_types"]
        assert "valid_targets" in prompt
        assert prompt["wave"] == 2
        # Optional actions advertise the explicit "do nothing" choice
        assert "skip" in prompt["action_types"]

    def test_me_endpoint_no_action_prompt_when_not_acting(self, api_client, db):
        """
        During night phase, if the player does not act in the current window,
        action_prompt is None.
        """
        game, users, _host = _create_game(
            {
                "menap_host": "Werewolf",
                "menap_p1": "Seer",
                "menap_p2": "Villager",
                "menap_p3": "Robber",
                "menap_p4": "Drunk",
            },
            center_cards=["Troublemaker", "Insomniac", "Villager"],
            phase=Phase.NIGHT,
            current_wave=2,
        )

        # Villager does NOT act in the shared window
        api_client.force_authenticate(user=users["menap_p2"])
        response = api_client.get(_me_url(game.id))

        assert response.status_code == status.HTTP_200_OK
        assert response.data["deadline"] is None
        assert response.data["action_prompt"] is None

    def test_me_endpoint_no_action_prompt_outside_night(self, api_client, db):
        """Outside night phase, action_prompt is always None."""
        game, _users, host = _create_game(
            {
                "menon_host": "Werewolf",
                "menon_p1": "Seer",
            },
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
            phase=Phase.DISCUSSION,
        )

        api_client.force_authenticate(user=host)
        response = api_client.get(_me_url(game.id))

        assert response.status_code == status.HTTP_200_OK
        assert response.data["deadline"] is None
        assert response.data["action_prompt"] is None

    def test_me_endpoint_no_action_prompt_after_acting(self, api_client, db):
        """After a player has acted, action_prompt is None."""
        game, users, _host = _create_game(
            {
                "meaa_host": "Werewolf",
                "meaa_p1": "Seer",
                "meaa_p2": "Robber",
                "meaa_p3": "Villager",
                "meaa_p4": "Drunk",
            },
            center_cards=["Troublemaker", "Insomniac", "Villager"],
            phase=Phase.NIGHT,
            current_wave=2,
        )

        # Mark Seer as having already acted
        pr = PlayerRole.objects.get(game=game, user=users["meaa_p1"])
        pr.has_acted = True
        pr.save(update_fields=["has_acted"])

        api_client.force_authenticate(user=users["meaa_p1"])
        response = api_client.get(_me_url(game.id))

        assert response.status_code == status.HTTP_200_OK
        assert response.data["deadline"] is None
        assert response.data["action_prompt"] is None

    def test_me_endpoint_players_show_vote_status_during_voting(self, api_client, db):
        """During voting, the players list includes has_voted for each player."""
        game, users, host = _create_game(
            {
                "mev_host": "Werewolf",
                "mev_p1": "Seer",
                "mev_p2": "Villager",
            },
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
            phase=Phase.VOTING,
        )

        # Mark p1 as having voted
        pr = PlayerRole.objects.get(game=game, user=users["mev_p1"])
        pr.has_acted = True
        pr.save(update_fields=["has_acted"])

        api_client.force_authenticate(user=host)
        response = api_client.get(_me_url(game.id))

        assert response.status_code == status.HTTP_200_OK
        assert response.data["deadline"] is None

        vote_map = {p["player_id"]: p["has_voted"] for p in response.data["players"]}
        assert vote_map[users["mev_p1"].id] is True
        assert vote_map[users["mev_host"].id] is False
        assert vote_map[users["mev_p2"].id] is False
