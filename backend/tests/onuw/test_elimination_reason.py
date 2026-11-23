"""
Integration tests for elimination_reason in the results endpoint (FR-033).

Tests that GET /api/onuw/games/<id>/results/ returns elimination_reason
for each eliminated player: "vote" or "hunter_chain".
"""

from unittest.mock import patch

from django.urls import reverse

import pytest
from rest_framework import status

from apps.core.models import Lobby, LobbyMember, User
from apps.onuw.models import Game, Phase, PlayerRole

pytestmark = pytest.mark.integration


def _results_url(game_id):
    return reverse("onuw:results", kwargs={"game_id": str(game_id)})


def _create_voting_game(players_roles: dict[str, str], center_cards: list[str]):
    """
    Create a game in VOTING phase. players_roles maps username -> role.

    Returns (game, users_dict).
    """
    users = {}
    for uname, _role in players_roles.items():
        users[uname] = User.objects.create_user(
            username=uname, password="pass", display_name=uname
        )

    usernames = list(players_roles.keys())
    host = users[usernames[0]]
    lobby = Lobby.objects.create(
        host=host,
        game_type="onuw",
        max_players=10,
        settings={"roles": {}},
    )
    for user in users.values():
        LobbyMember.objects.create(lobby=lobby, user=user)
    lobby.status = Lobby.Status.IN_GAME
    lobby.save()

    game = Game.objects.create(
        lobby=lobby,
        phase=Phase.VOTING,
        current_wave=0,
        random_seed=42,
        settings=lobby.settings,
        center_cards=center_cards,
    )
    for uname, role in players_roles.items():
        PlayerRole.objects.create(
            game=game, user=users[uname], original_role=role, current_role=role
        )

    return game, users


class TestEliminationReason:
    """Tests for elimination_reason field in the results endpoint."""

    def test_vote_eliminated_player_has_vote_reason(self, api_client, db):
        """A player eliminated by votes has elimination_reason == 'vote'."""
        game, users = _create_voting_game(
            {
                "elim_host": "Werewolf",
                "elim_p1": "Seer",
                "elim_p2": "Villager",
            },
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
        )

        # All vote for host (Werewolf) → host is eliminated by votes
        for uname, target in [
            ("elim_host", "elim_p1"),
            ("elim_p1", "elim_host"),
            ("elim_p2", "elim_host"),
        ]:
            pr = PlayerRole.objects.get(game=game, user=users[uname])
            pr.vote_target = users[target]
            pr.has_acted = True
            pr.save(update_fields=["vote_target", "has_acted"])

        with patch("apps.core.effects.get_channel_layer", return_value=None):
            from apps.onuw.services import reveal_votes

            reveal_votes(game)

        game.refresh_from_db()

        api_client.force_authenticate(user=users["elim_p1"])
        response = api_client.get(_results_url(game.id))

        assert response.status_code == status.HTTP_200_OK

        eliminated = response.data["eliminated_players"]
        elim_ids = [e["player_id"] for e in eliminated]
        assert users["elim_host"].id in elim_ids

        host_entry = next(
            e for e in eliminated if e["player_id"] == users["elim_host"].id
        )
        assert host_entry["elimination_reason"] == "vote"

    def test_hunter_chain_kill_has_hunter_chain_reason(self, api_client, db):
        """A player killed by Hunter chain has elimination_reason == 'hunter_chain'."""
        # Setup: hunter_player is eliminated by vote, and kills hc_target via chain
        game, users = _create_voting_game(
            {
                "hc_host": "Werewolf",
                "hc_hunter": "Hunter",
                "hc_target": "Villager",
                "hc_p3": "Seer",
            },
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
        )

        # Votes: everyone votes for hc_hunter (Hunter gets eliminated by votes)
        # Hunter's vote target: hc_target (will be killed by Hunter chain)
        vote_map = {
            "hc_host": "hc_hunter",
            "hc_hunter": "hc_target",  # Hunter's chain kill target
            "hc_target": "hc_hunter",
            "hc_p3": "hc_hunter",
        }
        for voter_name, target_name in vote_map.items():
            pr = PlayerRole.objects.get(game=game, user=users[voter_name])
            pr.vote_target = users[target_name]
            pr.has_acted = True
            pr.save(update_fields=["vote_target", "has_acted"])

        with patch("apps.core.effects.get_channel_layer", return_value=None):
            from apps.onuw.services import reveal_votes

            reveal_votes(game)

        game.refresh_from_db()

        api_client.force_authenticate(user=users["hc_host"])
        response = api_client.get(_results_url(game.id))

        assert response.status_code == status.HTTP_200_OK

        eliminated = response.data["eliminated_players"]
        elim_ids = [e["player_id"] for e in eliminated]

        # Hunter should be vote-eliminated
        assert users["hc_hunter"].id in elim_ids
        hunter_entry = next(
            e for e in eliminated if e["player_id"] == users["hc_hunter"].id
        )
        assert hunter_entry["elimination_reason"] == "vote"

        # hc_target should be hunter_chain eliminated
        assert users["hc_target"].id in elim_ids
        target_entry = next(
            e for e in eliminated if e["player_id"] == users["hc_target"].id
        )
        assert target_entry["elimination_reason"] == "hunter_chain"

    def test_non_eliminated_players_have_no_elimination_reason(self, api_client, db):
        """Non-eliminated players do not appear in eliminated_players list."""
        game, users = _create_voting_game(
            {
                "ne_host": "Werewolf",
                "ne_p1": "Seer",
                "ne_p2": "Villager",
            },
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
        )

        # Majority vote for host
        for uname, target in [
            ("ne_host", "ne_p1"),
            ("ne_p1", "ne_host"),
            ("ne_p2", "ne_host"),
        ]:
            pr = PlayerRole.objects.get(game=game, user=users[uname])
            pr.vote_target = users[target]
            pr.has_acted = True
            pr.save(update_fields=["vote_target", "has_acted"])

        with patch("apps.core.effects.get_channel_layer", return_value=None):
            from apps.onuw.services import reveal_votes

            reveal_votes(game)

        game.refresh_from_db()

        api_client.force_authenticate(user=users["ne_p1"])
        response = api_client.get(_results_url(game.id))

        assert response.status_code == status.HTTP_200_OK

        # Non-eliminated players should not be in eliminated_players
        eliminated_ids = {e["player_id"] for e in response.data["eliminated_players"]}
        assert users["ne_p1"].id not in eliminated_ids
        assert users["ne_p2"].id not in eliminated_ids

    def test_elimination_reason_field_present_on_all_eliminated(self, api_client, db):
        """All entries in eliminated_players include elimination_reason field."""
        game, users = _create_voting_game(
            {
                "er_host": "Werewolf",
                "er_p1": "Seer",
                "er_p2": "Villager",
            },
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
        )

        for uname, target in [
            ("er_host", "er_p1"),
            ("er_p1", "er_host"),
            ("er_p2", "er_host"),
        ]:
            pr = PlayerRole.objects.get(game=game, user=users[uname])
            pr.vote_target = users[target]
            pr.has_acted = True
            pr.save(update_fields=["vote_target", "has_acted"])

        with patch("apps.core.effects.get_channel_layer", return_value=None):
            from apps.onuw.services import reveal_votes

            reveal_votes(game)

        game.refresh_from_db()

        api_client.force_authenticate(user=users["er_p1"])
        response = api_client.get(_results_url(game.id))

        assert response.status_code == status.HTTP_200_OK

        for entry in response.data["eliminated_players"]:
            assert "elimination_reason" in entry
            assert entry["elimination_reason"] in ("vote", "hunter_chain")

    def test_no_eliminations_results_in_empty_eliminated_list(self, api_client, db):
        """When no one reaches the vote threshold, eliminated_players is empty."""
        game, users = _create_voting_game(
            {
                "zero_host": "Werewolf",
                "zero_p1": "Seer",
                "zero_p2": "Villager",
                "zero_p3": "Villager",
            },
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
        )

        # Split votes so no one gets >= 2
        for uname, target in [
            ("zero_host", "zero_p1"),
            ("zero_p1", "zero_p2"),
            ("zero_p2", "zero_p3"),
            ("zero_p3", "zero_host"),
        ]:
            pr = PlayerRole.objects.get(game=game, user=users[uname])
            pr.vote_target = users[target]
            pr.has_acted = True
            pr.save(update_fields=["vote_target", "has_acted"])

        with patch("apps.core.effects.get_channel_layer", return_value=None):
            from apps.onuw.services import reveal_votes

            reveal_votes(game)

        game.refresh_from_db()

        api_client.force_authenticate(user=users["zero_p1"])
        response = api_client.get(_results_url(game.id))

        assert response.status_code == status.HTTP_200_OK
        assert response.data["eliminated_players"] == []
