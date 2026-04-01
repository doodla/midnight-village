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

    def test_duplicate_action_returns_409(self, api_client, db):
        """A duplicate action returns 409 Conflict so the frontend treats it as idempotent."""
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

            # Second submission returns 409 (not 400) for idempotent handling
            response = api_client.post(
                _action_url(game.id),
                {
                    "action_type": "peek_player",
                    "targets": {"player_id": target_user.id},
                },
                format="json",
            )
            assert response.status_code == status.HTTP_409_CONFLICT

            # Original action preserved — retry didn't clobber it
            pr = PlayerRole.objects.get(game=game, user=seer_user)
            assert pr.has_acted is True
            assert pr.night_action_data["action_type"] == "peek_player"

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

    def test_force_advance_is_noop_if_timer_already_advanced(self, api_client, db):
        """If the wave timer already advanced the wave, the host force-advance
        is a no-op (400). This prevents duplicate wave processing that could
        overwrite log entries and reset has_acted for the next wave."""
        game, users = _create_game(
            {
                "host_race_fa": "Werewolf",
                "p1_race_fa": "Werewolf",
                "p2_race_fa": "Seer",
                "p3_race_fa": "Robber",
                "p4_race_fa": "Villager",
            },
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
            current_wave=2,
        )

        api_client.force_authenticate(user=users["host_race_fa"])

        # Simulate: the timer callback fires and transitions to discussion
        # before the host request acquires the lock.
        game.phase = Phase.DISCUSSION
        game.current_wave = 0
        game.save(update_fields=["phase", "current_wave"])

        with _patch_channels():
            response = api_client.post(
                _advance_url(game.id),
                format="json",
            )

        assert response.status_code == status.HTTP_400_BAD_REQUEST
        # Phase should still be DISCUSSION, not re-processed
        game.refresh_from_db()
        assert game.phase == Phase.DISCUSSION

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


class TestTimeoutAutoResolution:
    """Tests that automatic roles (Insomniac, see_team) are auto-resolved
    rather than skipped when the wave timer expires without player submission.

    Per ONUW rules, these actions require no player choice — the information
    is revealed automatically. Skipping them on timeout would lose information
    the player is entitled to see.
    """

    def test_insomniac_sees_current_role_on_timeout(self, api_client, db):
        """When the wave timer expires without the Insomniac submitting,
        they should still see their current role (auto-resolved, not skipped).

        Before this fix, a timed-out Insomniac would get empty revealed_info,
        losing the only chance to learn whether their card was swapped.
        """
        game, users = _create_game(
            {
                "host_ito": "Villager",
                "p1_ito": "Insomniac",
                "p2_ito": "Villager",
                "p3_ito": "Villager",
                "p4_ito": "Villager",
            },
            center_cards=["Werewolf", "Seer", "Robber"],
            current_wave=4,
        )

        # Force-advance wave 4 WITHOUT the Insomniac submitting
        api_client.force_authenticate(user=users["host_ito"])
        with _patch_channels():
            response = api_client.post(_advance_url(game.id), format="json")
        assert response.status_code == status.HTTP_200_OK

        # Insomniac should have auto-resolved result with their current role
        insomniac_pr = PlayerRole.objects.get(game=game, user=users["p1_ito"])
        assert "wave_4_result" in insomniac_pr.night_action_data
        assert (
            insomniac_pr.night_action_data["wave_4_result"]["current_role"]
            == "Insomniac"
        )

    def test_insomniac_auto_resolve_logged_as_none_not_skip(self, api_client, db):
        """Auto-resolved Insomniac action is logged as 'none', not 'skip'."""
        game, users = _create_game(
            {
                "host_ial": "Villager",
                "p1_ial": "Insomniac",
                "p2_ial": "Villager",
                "p3_ial": "Villager",
                "p4_ial": "Villager",
            },
            center_cards=["Werewolf", "Seer", "Robber"],
            current_wave=4,
        )

        api_client.force_authenticate(user=users["host_ial"])
        with _patch_channels():
            api_client.post(_advance_url(game.id), format="json")

        game.refresh_from_db()
        wave_4_entries = [e for e in game.night_actions_log if e["wave"] == 4]
        assert len(wave_4_entries) == 1
        assert wave_4_entries[0]["action_type"] == "none"

    def test_werewolf_sees_teammates_on_timeout(self, api_client, db):
        """When the wave timer expires without a Werewolf submitting,
        they should still see their teammates (auto-resolved see_team)."""
        game, users = _create_game(
            {
                "host_wto": "Werewolf",
                "p1_wto": "Werewolf",
                "p2_wto": "Villager",
                "p3_wto": "Villager",
                "p4_wto": "Villager",
            },
            center_cards=["Seer", "Robber", "Drunk"],
            current_wave=2,
        )

        # Neither Werewolf submits. Host force-advances.
        api_client.force_authenticate(user=users["host_wto"])
        with _patch_channels():
            api_client.post(_advance_url(game.id), format="json")

        # Both Werewolves should have auto-resolved results with teammate info
        pr_ww1 = PlayerRole.objects.get(game=game, user=users["host_wto"])
        assert "wave_2_result" in pr_ww1.night_action_data
        assert "werewolves" in pr_ww1.night_action_data["wave_2_result"]
        assert (
            users["p1_wto"].id
            in pr_ww1.night_action_data["wave_2_result"]["werewolves"]
        )

        pr_ww2 = PlayerRole.objects.get(game=game, user=users["p1_wto"])
        assert "wave_2_result" in pr_ww2.night_action_data
        assert (
            users["host_wto"].id
            in pr_ww2.night_action_data["wave_2_result"]["werewolves"]
        )

    def test_seer_still_skipped_on_timeout(self, api_client, db):
        """Roles with meaningful choices (Seer) are still skipped on timeout,
        because the player forfeited their choice by not submitting."""
        game, users = _create_game(
            {
                "host_sst": "Werewolf",
                "p1_sst": "Seer",
                "p2_sst": "Robber",
                "p3_sst": "Villager",
                "p4_sst": "Villager",
            },
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
            current_wave=3,
        )

        # Nobody submits in wave 3. Host force-advances.
        api_client.force_authenticate(user=users["host_sst"])
        with _patch_channels():
            api_client.post(_advance_url(game.id), format="json")

        # Seer should have been skipped (no result stored)
        pr_seer = PlayerRole.objects.get(game=game, user=users["p1_sst"])
        # Skip actions have empty revealed_info, so no wave_3_result is stored
        assert "wave_3_result" not in pr_seer.night_action_data

        # Action log should record "skip" for the Seer
        game.refresh_from_db()
        seer_entries = [
            e
            for e in game.night_actions_log
            if e["player_id"] == users["p1_sst"].id and e["wave"] == 3
        ]
        assert len(seer_entries) == 1
        assert seer_entries[0]["action_type"] == "skip"
