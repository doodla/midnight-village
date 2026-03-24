"""
End-to-end integration tests for Discussion -> Voting -> Results flow.

Tests the full game flow from discussion phase through voting to results
with 5 players, verifying hidden information, auto-reveal, and state
transitions.
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


class TestDiscussionToVotingE2E:
    """Full flow: discussion -> voting -> results with 5 players."""

    def _setup_game(self, phase=Phase.DISCUSSION):
        """
        Create a game with 5 players already in discussion phase.

        Returns (game, users_by_name, host).
        """
        host = User.objects.create_user(username="e2e_host_dv", password="pass")
        p1 = User.objects.create_user(username="e2e_p1_dv", password="pass")
        p2 = User.objects.create_user(username="e2e_p2_dv", password="pass")
        p3 = User.objects.create_user(username="e2e_p3_dv", password="pass")
        p4 = User.objects.create_user(username="e2e_p4_dv", password="pass")

        lobby = Lobby.objects.create(
            host=host,
            game_type="onuw",
            max_players=10,
            settings={"roles": {}},
        )
        for user in [host, p1, p2, p3, p4]:
            LobbyMember.objects.create(lobby=lobby, user=user, is_ready=True)
        lobby.status = Lobby.Status.IN_GAME
        lobby.save()

        game = Game.objects.create(
            lobby=lobby,
            phase=phase,
            current_wave=0,
            random_seed=42,
            settings=lobby.settings,
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
        )

        role_assignments = {
            host: "Werewolf",
            p1: "Werewolf",
            p2: "Seer",
            p3: "Robber",
            p4: "Villager",
        }
        for user, role in role_assignments.items():
            PlayerRole.objects.create(
                game=game,
                user=user,
                original_role=role,
                current_role=role,
            )

        users = {
            "host": host,
            "p1": p1,
            "p2": p2,
            "p3": p3,
            "p4": p4,
        }

        return game, users, host

    def test_full_discussion_to_voting_flow_with_force_reveal(self, db):
        """
        Complete flow with force-reveal:
        1. Game starts in discussion phase
        2. Host ends discussion -> game transitions to voting
        3. 4 of 5 players submit votes
        4. Host force-reveals -> vote_reveal includes all votes (4 targets + 1 null)
        5. Game transitions to results phase
        6. Verify: /me/ shows has_voted correctly throughout
        """
        game, users, host = self._setup_game()
        client = APIClient()

        end_discussion_url = reverse(
            "onuw:end-discussion", kwargs={"game_id": str(game.id)}
        )
        vote_url = reverse("onuw:vote", kwargs={"game_id": str(game.id)})
        reveal_url = reverse("onuw:reveal-votes", kwargs={"game_id": str(game.id)})
        me_url = reverse("onuw:game-me", kwargs={"game_id": str(game.id)})

        with _patch_channels():
            # ── Step 1: Verify game is in discussion ──────────────────────
            game.refresh_from_db()
            assert game.phase == Phase.DISCUSSION

            # ── Step 2: Verify has_voted is False during discussion ───────
            client.force_authenticate(user=users["p1"])
            response = client.get(me_url)
            # pyrefly: ignore [missing-attribute]
            assert response.status_code == status.HTTP_200_OK
            # pyrefly: ignore [missing-attribute]
            assert response.data["has_voted"] is False

            # ── Step 3: Host ends discussion ──────────────────────────────
            client.force_authenticate(user=host)
            response = client.post(end_discussion_url)
            # pyrefly: ignore [missing-attribute]
            assert response.status_code == status.HTTP_200_OK
            # pyrefly: ignore [missing-attribute]
            assert response.data["status"] == "voting_started"

            game.refresh_from_db()
            assert game.phase == Phase.VOTING

            # ── Step 4: Verify has_voted is False before voting ───────────
            client.force_authenticate(user=users["p2"])
            response = client.get(me_url)
            # pyrefly: ignore [missing-attribute]
            assert response.data["has_voted"] is False

            # ── Step 5: 4 of 5 players submit votes ──────────────────────
            # host, p1, p2, p3 vote for p4 (Villager)
            target = users["p4"]
            for uname in ["host", "p1", "p2", "p3"]:
                client.force_authenticate(user=users[uname])
                response = client.post(
                    vote_url,
                    # pyrefly: ignore [missing-attribute]
                    {"target_player_id": target.id},
                    format="json",
                )
                # pyrefly: ignore [missing-attribute]
                assert response.status_code == status.HTTP_200_OK

            # Game should still be in VOTING (only 4/5 voted)
            game.refresh_from_db()
            assert game.phase == Phase.VOTING

            # ── Step 6: Verify has_voted status ───────────────────────────
            # p1 (voted) should show has_voted=True
            client.force_authenticate(user=users["p1"])
            response = client.get(me_url)
            # pyrefly: ignore [missing-attribute]
            assert response.data["has_voted"] is True

            # p4 (not voted) should show has_voted=False
            client.force_authenticate(user=users["p4"])
            response = client.get(me_url)
            # pyrefly: ignore [missing-attribute]
            assert response.data["has_voted"] is False

            # ── Step 7: Host force-reveals ────────────────────────────────
            client.force_authenticate(user=host)
            response = client.post(reveal_url)
            # pyrefly: ignore [missing-attribute]
            assert response.status_code == status.HTTP_200_OK
            # pyrefly: ignore [missing-attribute]
            assert response.data["status"] == "revealed"

            # ── Step 8: Game transitions to results ───────────────────────
            game.refresh_from_db()
            assert game.phase == Phase.RESULTS

            # ── Step 9: Verify DB vote state ──────────────────────────────
            for uname in ["host", "p1", "p2", "p3"]:
                pr = PlayerRole.objects.get(game=game, user=users[uname])
                # pyrefly: ignore [missing-attribute]
                assert pr.vote_target_id == target.id

            # p4 did not vote
            pr_p4 = PlayerRole.objects.get(game=game, user=users["p4"])
            # pyrefly: ignore [missing-attribute]
            assert pr_p4.vote_target_id is None

    def test_full_discussion_to_voting_flow_with_auto_reveal(self, db):
        """
        Complete flow with auto-reveal:
        1. Game starts in voting phase (skipping discussion for brevity)
        2. All 5 players submit votes
        3. After last vote, auto-reveal triggers
        4. Game transitions to results
        """
        game, users, _host = self._setup_game(phase=Phase.VOTING)
        client = APIClient()

        vote_url = reverse("onuw:vote", kwargs={"game_id": str(game.id)})

        target = users["p1"]  # Everyone votes for p1

        with _patch_channels():
            for uname in ["host", "p1", "p2", "p3", "p4"]:
                client.force_authenticate(user=users[uname])
                response = client.post(
                    vote_url,
                    # pyrefly: ignore [missing-attribute]
                    {"target_player_id": target.id},
                    format="json",
                )
                # pyrefly: ignore [missing-attribute]
                assert response.status_code == status.HTTP_200_OK

        # After all 5 votes, game should auto-transition to results
        game.refresh_from_db()
        assert game.phase == Phase.RESULTS

        # All players should have votes recorded
        for uname in ["host", "p1", "p2", "p3", "p4"]:
            pr = PlayerRole.objects.get(game=game, user=users[uname])
            # pyrefly: ignore [missing-attribute]
            assert pr.vote_target_id == target.id
            assert pr.has_acted is True

    def test_votes_hidden_before_reveal(self, db):
        """
        Votes are hidden from the /me/ endpoint during voting.
        The vote_target should not be visible in the response.
        """
        game, users, _host = self._setup_game(phase=Phase.VOTING)
        client = APIClient()

        vote_url = reverse("onuw:vote", kwargs={"game_id": str(game.id)})
        me_url = reverse("onuw:game-me", kwargs={"game_id": str(game.id)})

        # p1 votes for host
        voter = users["p1"]
        target = users["host"]
        client.force_authenticate(user=voter)

        with _patch_channels():
            client.post(
                vote_url,
                # pyrefly: ignore [missing-attribute]
                {"target_player_id": target.id},
                format="json",
            )

        # Check /me/ - should show has_voted but NOT reveal target
        response = client.get(me_url)
        # pyrefly: ignore [missing-attribute]
        assert response.status_code == status.HTTP_200_OK
        # pyrefly: ignore [missing-attribute]
        assert response.data["has_voted"] is True

        # vote_target should not appear anywhere in the response
        # pyrefly: ignore [missing-attribute]
        response_str = str(response.data)
        assert "vote_target" not in response_str

    def test_discussion_resets_has_acted_for_voting(self, db):
        """
        Transitioning from discussion to voting resets has_acted so
        all players start with has_voted=False.
        """
        game, _users, host = self._setup_game(phase=Phase.DISCUSSION)

        # Manually mark some players as has_acted (from night phase leftovers)
        PlayerRole.objects.filter(game=game).update(has_acted=True)

        client = APIClient()
        end_discussion_url = reverse(
            "onuw:end-discussion", kwargs={"game_id": str(game.id)}
        )

        client.force_authenticate(user=host)

        with _patch_channels():
            response = client.post(end_discussion_url)
            # pyrefly: ignore [missing-attribute]
            assert response.status_code == status.HTTP_200_OK

        # All players should have has_acted=False after transition
        for pr in PlayerRole.objects.filter(game=game):
            assert pr.has_acted is False
            # pyrefly: ignore [missing-attribute]
            assert pr.vote_target_id is None
