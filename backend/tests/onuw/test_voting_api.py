"""
Integration tests for the ONUW Discussion & Voting API endpoints.

Tests the EndDiscussionView, VoteView, and ForceRevealView.
"""

from unittest.mock import MagicMock, patch

from django.urls import reverse

import pytest
from rest_framework import status

from apps.core.models import Lobby, LobbyMember, User
from apps.onuw.models import Game, Phase, PlayerRole

pytestmark = pytest.mark.integration


def _create_game(
    players_roles: dict[str, str],
    center_cards: list[str],
    phase: str = Phase.DISCUSSION,
    host_username: str | None = None,
):
    """
    Create a game with specific role assignments.

    Returns (game, users_dict, host_user) where users_dict maps username -> User.
    The first key in players_roles is the host unless host_username is specified.
    """
    usernames = list(players_roles.keys())
    users = {}
    for uname in usernames:
        users[uname] = User.objects.create_user(username=uname, password="pass")

    host_key = host_username or usernames[0]
    host = users[host_key]
    lobby = Lobby.objects.create(
        host=host,
        game_type="onuw",
        max_players=10,
        settings={"roles": {}, "voting_seconds": 0},
    )
    for user in users.values():
        LobbyMember.objects.create(lobby=lobby, user=user, is_ready=True)
    lobby.status = Lobby.Status.IN_GAME
    lobby.save()

    game = Game.objects.create(
        lobby=lobby,
        phase=phase,
        current_wave=0,
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


def _end_discussion_url(game_id):
    return reverse("onuw:end-discussion", kwargs={"game_id": str(game_id)})


def _vote_url(game_id):
    return reverse("onuw:vote", kwargs={"game_id": str(game_id)})


def _reveal_url(game_id):
    return reverse("onuw:reveal-votes", kwargs={"game_id": str(game_id)})


def _me_url(game_id):
    return reverse("onuw:game-me", kwargs={"game_id": str(game_id)})


def _patch_channels():
    """Context manager to mock out channel layer so WebSocket sends are no-ops."""
    return patch("apps.onuw.services.get_channel_layer", return_value=None)


class TestEndDiscussion:
    """Tests for POST /api/onuw/games/<game_id>/end-discussion/."""

    def test_host_can_end_discussion(self, api_client, db):
        """Host can end discussion and transition to voting."""
        game, _users, host = _create_game(
            {
                "host_ed": "Werewolf",
                "p1_ed": "Seer",
                "p2_ed": "Villager",
            },
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
            phase=Phase.DISCUSSION,
        )

        api_client.force_authenticate(user=host)

        with _patch_channels():
            response = api_client.post(_end_discussion_url(game.id))

        assert response.status_code == status.HTTP_200_OK
        assert response.data["status"] == "voting_started"

        game.refresh_from_db()
        assert game.phase == Phase.VOTING

    def test_non_host_cannot_end_discussion(self, api_client, db):
        """Non-host players cannot end discussion (403)."""
        game, users, _host = _create_game(
            {
                "host_ned": "Werewolf",
                "p1_ned": "Seer",
                "p2_ned": "Villager",
            },
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
            phase=Phase.DISCUSSION,
        )

        api_client.force_authenticate(user=users["p1_ned"])

        with _patch_channels():
            response = api_client.post(_end_discussion_url(game.id))

        assert response.status_code == status.HTTP_403_FORBIDDEN

        # Phase should not have changed
        game.refresh_from_db()
        assert game.phase == Phase.DISCUSSION

    def test_cannot_end_discussion_in_wrong_phase(self, api_client, db):
        """Cannot end discussion when game is not in discussion phase."""
        game, _users, host = _create_game(
            {
                "host_wp_ed": "Werewolf",
                "p1_wp_ed": "Seer",
                "p2_wp_ed": "Villager",
            },
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
            phase=Phase.NIGHT,
        )

        api_client.force_authenticate(user=host)

        with _patch_channels():
            response = api_client.post(_end_discussion_url(game.id))

        assert response.status_code == status.HTTP_400_BAD_REQUEST


class TestVoting:
    """Tests for POST /api/onuw/games/<game_id>/vote/."""

    def test_player_can_submit_vote(self, api_client, db):
        """A player can submit a vote targeting another player."""
        game, users, _host = _create_game(
            {
                "host_v": "Werewolf",
                "p1_v": "Seer",
                "p2_v": "Villager",
            },
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
            phase=Phase.VOTING,
        )

        api_client.force_authenticate(user=users["p1_v"])
        target = users["host_v"]

        with _patch_channels():
            response = api_client.post(
                _vote_url(game.id),
                {"target_player_id": target.id},
                format="json",
            )

        assert response.status_code == status.HTTP_200_OK
        assert response.data["status"] == "submitted"

        # Verify DB state
        pr = PlayerRole.objects.get(game=game, user=users["p1_v"])
        assert pr.has_acted is True
        # pyrefly: ignore [missing-attribute]
        assert pr.vote_target_id == target.id

    def test_player_cannot_vote_twice(self, api_client, db):
        """A player who has already voted cannot vote again."""
        game, users, _host = _create_game(
            {
                "host_vt": "Werewolf",
                "p1_vt": "Seer",
                "p2_vt": "Villager",
            },
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
            phase=Phase.VOTING,
        )

        voter = users["p1_vt"]
        target = users["host_vt"]
        api_client.force_authenticate(user=voter)

        with _patch_channels():
            # First vote
            response = api_client.post(
                _vote_url(game.id),
                {"target_player_id": target.id},
                format="json",
            )
            assert response.status_code == status.HTTP_200_OK

            # Second vote should fail
            response = api_client.post(
                _vote_url(game.id),
                {"target_player_id": users["p2_vt"].id},
                format="json",
            )
            assert response.status_code == status.HTTP_400_BAD_REQUEST

    def test_player_cannot_vote_in_wrong_phase(self, api_client, db):
        """Cannot vote when game is not in voting phase."""
        game, users, _host = _create_game(
            {
                "host_wp": "Werewolf",
                "p1_wp": "Seer",
                "p2_wp": "Villager",
            },
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
            phase=Phase.DISCUSSION,
        )

        api_client.force_authenticate(user=users["p1_wp"])

        with _patch_channels():
            response = api_client.post(
                _vote_url(game.id),
                {"target_player_id": users["host_wp"].id},
                format="json",
            )

        assert response.status_code == status.HTTP_400_BAD_REQUEST

    def test_vote_does_not_reveal_target_in_broadcast(self, api_client, db):
        """
        The vote_submitted broadcast contains player_id but NOT target_player_id.
        """
        game, users, _host = _create_game(
            {
                "host_br": "Werewolf",
                "p1_br": "Seer",
                "p2_br": "Villager",
            },
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
            phase=Phase.VOTING,
        )

        voter = users["p1_br"]
        target = users["host_br"]
        api_client.force_authenticate(user=voter)

        mock_channel_layer = MagicMock()
        with (
            patch(
                "apps.onuw.services.get_channel_layer",
                return_value=mock_channel_layer,
            ),
            patch("apps.onuw.services.async_to_sync") as mock_a2s,
        ):
            response = api_client.post(
                _vote_url(game.id),
                {"target_player_id": target.id},
                format="json",
            )
            assert response.status_code == status.HTTP_200_OK

            # Find the vote.submitted call
            send_fn = mock_a2s.return_value
            vote_submitted_calls = [
                call
                for call in send_fn.call_args_list
                if call[0][1].get("type") == "vote.submitted"
            ]
            assert len(vote_submitted_calls) == 1

            event = vote_submitted_calls[0][0][1]
            assert event["player_id"] == voter.id
            assert "target_player_id" not in event
            assert "target" not in event

    def test_non_player_cannot_vote(self, api_client, db):
        """A user not in the game gets an error when trying to vote."""
        game, users, _host = _create_game(
            {
                "host_np": "Werewolf",
                "p1_np": "Seer",
                "p2_np": "Villager",
            },
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
            phase=Phase.VOTING,
        )

        outsider = User.objects.create_user(username="outsider_vote", password="pass")
        api_client.force_authenticate(user=outsider)

        with _patch_channels():
            response = api_client.post(
                _vote_url(game.id),
                {"target_player_id": users["host_np"].id},
                format="json",
            )

        assert response.status_code == status.HTTP_400_BAD_REQUEST

    def test_self_vote_is_rejected(self, api_client, db):
        """Players cannot vote for themselves (spec: 'No self-votes')."""
        game, users, _host = _create_game(
            {
                "host_sv": "Werewolf",
                "p1_sv": "Seer",
                "p2_sv": "Villager",
            },
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
            phase=Phase.VOTING,
        )

        voter = users["p1_sv"]
        api_client.force_authenticate(user=voter)

        with _patch_channels():
            response = api_client.post(
                _vote_url(game.id),
                {"target_player_id": voter.id},
                format="json",
            )

        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert "cannot vote for yourself" in response.data["detail"][0].lower()

    def test_invalid_target_rejected(self, api_client, db):
        """Voting for a player not in the game is rejected."""
        game, users, _host = _create_game(
            {
                "host_it": "Werewolf",
                "p1_it": "Seer",
                "p2_it": "Villager",
            },
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
            phase=Phase.VOTING,
        )

        api_client.force_authenticate(user=users["p1_it"])

        with _patch_channels():
            response = api_client.post(
                _vote_url(game.id),
                {"target_player_id": 99999},
                format="json",
            )

        assert response.status_code == status.HTTP_400_BAD_REQUEST


class TestForceReveal:
    """Tests for POST /api/onuw/games/<game_id>/reveal-votes/."""

    def test_host_can_force_reveal_votes(self, api_client, db):
        """Host can force-reveal votes even if not all players have voted."""
        game, users, host = _create_game(
            {
                "host_fr": "Werewolf",
                "p1_fr": "Seer",
                "p2_fr": "Villager",
            },
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
            phase=Phase.VOTING,
        )

        # Only one player votes
        api_client.force_authenticate(user=users["p1_fr"])
        with _patch_channels():
            api_client.post(
                _vote_url(game.id),
                {"target_player_id": host.id},
                format="json",
            )

        # Host force-reveals
        api_client.force_authenticate(user=host)
        with _patch_channels():
            response = api_client.post(_reveal_url(game.id))

        assert response.status_code == status.HTTP_200_OK
        assert response.data["status"] == "revealed"

        game.refresh_from_db()
        assert game.phase == Phase.RESULTS

    def test_non_host_cannot_force_reveal(self, api_client, db):
        """Non-host players cannot force-reveal votes."""
        game, users, _host = _create_game(
            {
                "host_nfr": "Werewolf",
                "p1_nfr": "Seer",
                "p2_nfr": "Villager",
            },
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
            phase=Phase.VOTING,
        )

        api_client.force_authenticate(user=users["p1_nfr"])

        with _patch_channels():
            response = api_client.post(_reveal_url(game.id))

        assert response.status_code == status.HTTP_403_FORBIDDEN

    def test_all_votes_triggers_auto_reveal(self, api_client, db):
        """When all players have voted, reveal is triggered automatically."""
        game, users, _host = _create_game(
            {
                "host_ar": "Werewolf",
                "p1_ar": "Seer",
                "p2_ar": "Villager",
            },
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
            phase=Phase.VOTING,
        )

        # Each player votes for someone other than themselves
        vote_targets = {
            "host_ar": users["p1_ar"],
            "p1_ar": users["host_ar"],
            "p2_ar": users["host_ar"],
        }

        with _patch_channels():
            for uname, target in vote_targets.items():
                api_client.force_authenticate(user=users[uname])
                response = api_client.post(
                    _vote_url(game.id),
                    {"target_player_id": target.id},
                    format="json",
                )
                assert response.status_code == status.HTTP_200_OK

        # After all votes, game should auto-transition to results
        game.refresh_from_db()
        assert game.phase == Phase.RESULTS

    def test_reveal_includes_null_for_non_voters(self, api_client, db):
        """
        Force-reveal includes null target_player_id for players who did not vote.
        """
        game, users, host = _create_game(
            {
                "host_nv": "Werewolf",
                "p1_nv": "Seer",
                "p2_nv": "Villager",
            },
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
            phase=Phase.VOTING,
        )

        # Only host votes
        api_client.force_authenticate(user=host)
        with _patch_channels():
            api_client.post(
                _vote_url(game.id),
                {"target_player_id": users["p1_nv"].id},
                format="json",
            )

        # Capture the broadcast from force-reveal
        mock_channel_layer = MagicMock()
        with (
            patch(
                "apps.onuw.services.get_channel_layer",
                return_value=mock_channel_layer,
            ),
            patch("apps.onuw.services.async_to_sync") as mock_a2s,
        ):
            api_client.force_authenticate(user=host)
            response = api_client.post(_reveal_url(game.id))
            assert response.status_code == status.HTTP_200_OK

            # Find the vote.reveal call
            send_fn = mock_a2s.return_value
            reveal_calls = [
                call
                for call in send_fn.call_args_list
                if call[0][1].get("type") == "vote.reveal"
            ]
            assert len(reveal_calls) == 1

            votes = reveal_calls[0][0][1]["votes"]

            # Should have 3 vote entries
            assert len(votes) == 3

            # Build a map of player_id -> target
            vote_map = {v["player_id"]: v["target_player_id"] for v in votes}

            # Host voted for p1
            assert vote_map[host.id] == users["p1_nv"].id
            # p1 and p2 did not vote -> null targets
            assert vote_map[users["p1_nv"].id] is None
            assert vote_map[users["p2_nv"].id] is None


class TestMeEndpointVotingStatus:
    """Tests for /me/ endpoint during voting phase."""

    def test_me_shows_has_voted_false_before_voting(self, api_client, db):
        """Before voting, has_voted is False."""
        game, users, _host = _create_game(
            {
                "host_mev": "Werewolf",
                "p1_mev": "Seer",
                "p2_mev": "Villager",
            },
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
            phase=Phase.VOTING,
        )

        api_client.force_authenticate(user=users["p1_mev"])
        response = api_client.get(_me_url(game.id))

        assert response.status_code == status.HTTP_200_OK
        assert response.data["has_voted"] is False

    def test_me_shows_has_voted_true_after_voting(self, api_client, db):
        """After voting, has_voted is True."""
        game, users, _host = _create_game(
            {
                "host_mev2": "Werewolf",
                "p1_mev2": "Seer",
                "p2_mev2": "Villager",
            },
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
            phase=Phase.VOTING,
        )

        voter = users["p1_mev2"]
        target = users["host_mev2"]
        api_client.force_authenticate(user=voter)

        with _patch_channels():
            api_client.post(
                _vote_url(game.id),
                {"target_player_id": target.id},
                format="json",
            )

        response = api_client.get(_me_url(game.id))
        assert response.status_code == status.HTTP_200_OK
        assert response.data["has_voted"] is True

    def test_me_does_not_reveal_vote_target_during_voting(self, api_client, db):
        """The /me/ response during voting does not include the vote target."""
        game, users, _host = _create_game(
            {
                "host_mev3": "Werewolf",
                "p1_mev3": "Seer",
                "p2_mev3": "Villager",
            },
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
            phase=Phase.VOTING,
        )

        voter = users["p1_mev3"]
        target = users["host_mev3"]
        api_client.force_authenticate(user=voter)

        with _patch_channels():
            api_client.post(
                _vote_url(game.id),
                {"target_player_id": target.id},
                format="json",
            )

        response = api_client.get(_me_url(game.id))
        assert response.status_code == status.HTTP_200_OK

        # Ensure vote_target is not in the response anywhere
        response_str = str(response.data)
        assert "vote_target" not in response_str
