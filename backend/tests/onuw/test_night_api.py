"""
Integration tests for the ONUW Night Phase API endpoints.

Tests the NightActionView (every phone's ``choose``) and WaveAdvanceView with
various scenarios. Every request names the stage ``GET /me/`` shows.
"""

from unittest.mock import patch

from django.urls import reverse

import pytest
from rest_framework import status

from apps.core.models import Lobby, LobbyMember, User
from apps.onuw import choose_night
from apps.onuw.models import Game, Phase, PlayerRole
from apps.onuw.protocol import stage_token

pytestmark = pytest.mark.integration


def _create_game(
    players_roles: dict[str, str],
    center_cards: list[str],
    phase: str = Phase.NIGHT,
    current_wave: int = 2,
    host_username: str = "host_na",
    extra_settings: dict | None = None,
):
    """
    Create a game with specific role assignments.

    Args:
        players_roles: Mapping of username -> role name.
        center_cards: List of 3 center card role names.
        phase: Game phase.
        current_wave: Current night window (1 = Doppelganger, 2 = everyone else).
        host_username: Username for the host (first player).
        extra_settings: Game settings merged over the defaults. The default sets
            ``night_min_window_seconds`` to 0 so a window closes as soon as its
            last actor submits (the minimum length has its own tests).

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
    game_settings = {"roles": {}, "night_min_window_seconds": 0}
    game_settings.update(extra_settings or {})
    for user in users.values():
        LobbyMember.objects.create(lobby=lobby, user=user, is_ready=True)
    lobby.status = Lobby.Status.IN_GAME
    lobby.save()

    game = Game.objects.create(
        lobby=lobby,
        phase=phase,
        current_wave=current_wave,
        random_seed=42,
        settings=game_settings,
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


def _stage(game) -> str | None:
    return stage_token(Game.objects.get(id=game.id))


def _choose(api_client, game, user, picks=None, *, chosen=None):
    """``user``'s phone chooses ``picks`` for the open window (the stage and the
    prompt's ``chosen`` as ``GET /me/`` shows them, unless ``chosen`` is given)."""
    api_client.force_authenticate(user=user)
    if chosen is None:
        fresh = Game.objects.get(id=game.id)
        pr = PlayerRole.objects.get(game=fresh, user=user)
        chosen = choose_night.chose_count(pr, fresh.current_wave)
    return api_client.post(
        _action_url(game.id),
        {
            "action_type": "choose",
            "picks": picks or [],
            "chosen": chosen,
            "stage": _stage(game),
        },
        format="json",
    )


def _advance(api_client, game, stage=None):
    return api_client.post(
        _advance_url(game.id), {"stage": stage or _stage(game)}, format="json"
    )


def _patch_channels():
    """Context manager to mock out channel layer so WebSocket sends are no-ops."""
    return patch("apps.core.effects.get_channel_layer", return_value=None)


class TestNightActionSubmission:
    """Tests for POST /api/onuw/games/<game_id>/action/."""

    ROLES = {
        "host_seer": "Seer",
        "p1_ww": "Werewolf",
        "p2_rob": "Robber",
        "p3_vill": "Villager",
        "p4_drunk": "Drunk",
    }

    def test_seer_can_choose_a_player_to_look_at(self, api_client, db):
        """A Seer's choose of another player is stored as a look at that card."""
        game, users = _create_game(
            self.ROLES, center_cards=["Troublemaker", "Insomniac", "Villager"]
        )

        with _patch_channels():
            response = _choose(
                api_client, game, users["host_seer"], [{"player_id": users["p1_ww"].id}]
            )

        assert response.status_code == status.HTTP_200_OK
        assert response.data == {"status": "submitted"}

        pr = PlayerRole.objects.get(game=game, user=users["host_seer"])
        assert pr.has_acted is True
        assert pr.night_action_data["action_type"] == "peek_player"
        assert pr.night_action_data["role_acting_as"] == "Seer"

    def test_a_request_that_is_not_a_choose_is_refused(self, api_client, db):
        """Only ``choose`` exists at night: any other action type is a 400."""
        game, users = _create_game(
            self.ROLES, center_cards=["Troublemaker", "Insomniac", "Villager"]
        )
        api_client.force_authenticate(user=users["host_seer"])

        with _patch_channels():
            response = api_client.post(
                _action_url(game.id),
                {
                    "action_type": "peek_player",
                    "targets": {"player_id": users["p1_ww"].id},
                    "stage": _stage(game),
                },
                format="json",
            )

        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert response.data["code"] == "bad_request"
        assert not PlayerRole.objects.get(game=game, user=users["host_seer"]).has_acted

    def test_a_choose_in_a_window_the_role_does_not_act_in_reads_as_nothing(
        self, api_client, db
    ):
        """A Werewolf's choose in window 1 is taken like anyone's, and means nothing."""
        game, users = _create_game(
            self.ROLES,
            center_cards=["Troublemaker", "Insomniac", "Villager"],
            current_wave=1,
        )

        with _patch_channels():
            response = _choose(api_client, game, users["p1_ww"], [{"center_index": 0}])

        assert response.status_code == status.HTTP_200_OK
        data = PlayerRole.objects.get(game=game, user=users["p1_ww"]).night_action_data
        assert data["chose_1"] == 1
        assert "action_type" not in data

    def test_a_second_choose_in_window_two_is_409_and_a_resend_changes_nothing(
        self, api_client, db
    ):
        """A phone chooses once in window 2: a second (answering a used-up prompt)
        is 409 ``already_chosen``; a resend of the first is the same 200."""
        game, users = _create_game(
            self.ROLES, center_cards=["Troublemaker", "Insomniac", "Villager"]
        )
        seer = users["host_seer"]
        look = [{"player_id": users["p1_ww"].id}]

        with _patch_channels():
            assert _choose(api_client, game, seer, look).status_code == 200
            resend = _choose(api_client, game, seer, [], chosen=0)
            again = _choose(api_client, game, seer, look)

        assert resend.status_code == status.HTTP_200_OK
        assert again.status_code == status.HTTP_409_CONFLICT
        assert again.data["code"] == "already_chosen"
        # The original choose is kept: neither request clobbered it.
        pr = PlayerRole.objects.get(game=game, user=seer)
        assert pr.night_action_data["action_type"] == "peek_player"
        assert pr.night_action_data["chose_2"] == 1

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
        )
        outsider = User.objects.create_user(username="outsider_na", password="pass")
        api_client.force_authenticate(user=outsider)

        with _patch_channels():
            response = api_client.post(
                _action_url(game.id),
                {
                    "action_type": "choose",
                    "picks": [],
                    "chosen": 0,
                    "stage": _stage(game),
                },
                format="json",
            )

        assert response.status_code == status.HTTP_403_FORBIDDEN

    def test_a_choose_after_the_night_names_a_stage_that_is_over(self, api_client, db):
        """A choose in the talk is 409 ``wrong_stage`` and stores nothing."""
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

        with _patch_channels():
            response = _choose(
                api_client,
                game,
                users["host_wp"],
                [{"player_id": users["p1_wp"].id}],
                chosen=0,
            )

        assert response.status_code == status.HTTP_409_CONFLICT
        assert response.data["code"] == "wrong_stage"


class TestWaveAdvancement:
    """Tests for auto-advance and force-advance mechanics."""

    def test_window_closes_when_every_phone_has_chosen(self, api_client, db):
        """Window 2 closes only once EVERY phone has chosen, and no result is
        stored before that."""
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

        def submit(name, picks=None):
            response = _choose(api_client, game, users[name], picks)
            assert response.status_code == status.HTTP_200_OK

        with _patch_channels():
            submit("host_aa")
            submit("p1_aa")
            submit("p2_aa", [{"player_id": users["p4_aa"].id}])
            submit("p4_aa")

            # The Robber has not chosen: the window is still open and nobody
            # has a stored result yet.
            game.refresh_from_db()
            assert game.phase == Phase.NIGHT
            assert game.current_wave == 2
            pr_ww1 = PlayerRole.objects.get(game=game, user=users["host_aa"])
            assert "wave_2_result" not in pr_ww1.night_action_data

            submit("p3_aa")

        game.refresh_from_db()
        assert game.phase == Phase.DISCUSSION
        assert game.current_wave == 0

        # Both werewolves have results stored for window 2
        pr_ww1 = PlayerRole.objects.get(game=game, user=users["host_aa"])
        assert "werewolves" in pr_ww1.night_action_data["wave_2_result"]

    def test_host_can_force_advance_wave(self, api_client, db):
        """Host can close the window, auto-resolving non-submitters."""
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

        # Only Werewolf 1 chooses
        with _patch_channels():
            response = _choose(api_client, game, users["host_fa"])
            assert response.status_code == status.HTTP_200_OK

            # Host force-advances
            response = _advance(api_client, game)
            assert response.status_code == status.HTTP_200_OK
            assert response.data["status"] == "advanced"

        # The host closed the window: everyone who had not submitted got their
        # automatic action, and the night is over.
        game.refresh_from_db()
        assert game.phase == Phase.DISCUSSION
        assert game.current_wave == 0
        pr_ww2 = PlayerRole.objects.get(game=game, user=users["p1_fa"])
        assert "werewolves" in pr_ww2.night_action_data["wave_2_result"]

    def test_force_advance_is_noop_if_timer_already_advanced(self, api_client, db):
        """If the wave timer already advanced the wave, the host's tap names a stage
        that is over: a no-op (409). This prevents duplicate wave processing that
        could overwrite log entries and reset has_acted for the next wave."""
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
        tapped_in = _stage(game)  # the window the host saw

        # Simulate: the timer callback fires and transitions to discussion
        # before the host request acquires the lock.
        game.phase = Phase.DISCUSSION
        game.current_wave = 0
        game.save(update_fields=["phase", "current_wave"])

        with _patch_channels():
            response = _advance(api_client, game, tapped_in)

        assert response.status_code == status.HTTP_409_CONFLICT
        assert response.data["code"] == "wrong_stage"
        # Phase should still be DISCUSSION, not re-processed
        game.refresh_from_db()
        assert game.phase == Phase.DISCUSSION

    def test_game_transitions_to_discussion_after_all_waves(self, api_client, db):
        """Game transitions to discussion once window 2, the last, has closed."""
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
            for user in users.values():
                assert _choose(api_client, game, user).status_code == 200

        # Should transition to discussion
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
            response = _advance(api_client, game)

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
            current_wave=2,
        )

        # Force-close the window WITHOUT the Insomniac choosing
        api_client.force_authenticate(user=users["host_ito"])
        with _patch_channels():
            response = _advance(api_client, game)
        assert response.status_code == status.HTTP_200_OK

        # Insomniac should have auto-resolved result with their current role
        insomniac_pr = PlayerRole.objects.get(game=game, user=users["p1_ito"])
        assert "wave_2_result" in insomniac_pr.night_action_data
        assert (
            insomniac_pr.night_action_data["wave_2_result"]["current_role"]
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
            current_wave=2,
        )

        api_client.force_authenticate(user=users["host_ial"])
        with _patch_channels():
            _advance(api_client, game)

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

        # Neither Werewolf chooses. Host force-advances.
        api_client.force_authenticate(user=users["host_wto"])
        with _patch_channels():
            _advance(api_client, game)

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
        because the player forfeited their choice by not choosing."""
        game, users = _create_game(
            {
                "host_sst": "Werewolf",
                "p1_sst": "Seer",
                "p2_sst": "Robber",
                "p3_sst": "Villager",
                "p4_sst": "Villager",
            },
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
            current_wave=2,
        )

        # Nobody chooses. Host closes the window.
        api_client.force_authenticate(user=users["host_sst"])
        with _patch_channels():
            _advance(api_client, game)

        # Seer should have been skipped (no result stored)
        pr_seer = PlayerRole.objects.get(game=game, user=users["p1_sst"])
        # Skip actions have empty revealed_info, so no wave_3_result is stored
        assert "wave_2_result" not in pr_seer.night_action_data

        # Action log should record "skip" for the Seer
        game.refresh_from_db()
        seer_entries = [
            e
            for e in game.night_actions_log
            if e["player_id"] == users["p1_sst"].id and e["wave"] == 3
        ]
        assert len(seer_entries) == 1
        assert seer_entries[0]["action_type"] == "skip"
