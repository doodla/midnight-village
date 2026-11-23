"""
``PATCH /api/lobbies/<code>/`` MERGES the settings it is given over the stored ones.

Every screen that writes settings sends only its own keys (the deck screen the
roles, the pace screen the timers); replacing the whole object made one screen
silently drop the other's. The merge happens under the Lobby row lock, the game's
validator checks the merged result, and a game in progress is not touched.
"""

import threading
from unittest.mock import patch

from django.db import connections
from django.urls import reverse

import pytest
from rest_framework import status
from rest_framework.test import APIClient

from apps.core.models import Lobby, LobbyMember, User
from apps.onuw.engine.validation import PACE_LABELS, validate_onuw_settings
from tests.core.test_lobby_patch import _create_lobby_with_players

pytestmark = pytest.mark.integration

ROLES = {"Werewolf": 2, "Seer": 1, "Villager": 2, "Drunk": 1}  # 3 players + 3 centre
PRESETS = {
    "quick": {
        "discussion_seconds": 180,
        "voting_seconds": 45,
        "night_wave_seconds": 20,
        "night_doppelganger_window_seconds": 10,
    },
    "normal": {
        "discussion_seconds": 300,
        "voting_seconds": 90,
        "night_wave_seconds": 30,
        "night_doppelganger_window_seconds": 10,
    },
    "long": {
        "discussion_seconds": 480,
        "voting_seconds": 120,
        "night_wave_seconds": 45,
        "night_doppelganger_window_seconds": 15,
    },
}


def url(code: str) -> str:
    return reverse("core:lobby-detail", kwargs={"code": code})


@pytest.fixture
def table(db):
    lobby, host, _players = _create_lobby_with_players(
        3, {"roles": ROLES, "discussion_seconds": 300}
    )
    client = APIClient()
    client.force_authenticate(user=host)
    with patch("apps.core.views.get_channel_layer", return_value=None):
        yield lobby, host, client


def patch_settings(client: APIClient, code: str, settings):
    return client.patch(url(code), {"settings": settings}, format="json")


def stored(lobby: Lobby) -> dict:
    lobby.refresh_from_db()
    return lobby.settings


class TestTheGivenKeysAreMerged:
    def test_a_screen_that_sends_only_its_keys_drops_nobody_elses(self, table) -> None:
        lobby, _, client = table

        response = patch_settings(client, lobby.code, {"voting_seconds": 90})

        assert response.status_code == status.HTTP_200_OK
        assert response.data["settings"] == {
            "roles": ROLES,
            "discussion_seconds": 300,
            "voting_seconds": 90,
        }
        assert stored(lobby) == response.data["settings"]

    def test_the_deck_screen_alone_keeps_the_timers_set_before(self, table) -> None:
        """What the app sends today: only ``roles``."""
        lobby, _, client = table
        patch_settings(client, lobby.code, {"night_wave_seconds": 30})
        new_roles = {"Werewolf": 2, "Seer": 1, "Villager": 1, "Drunk": 1, "Robber": 1}

        response = patch_settings(client, lobby.code, {"roles": new_roles})

        assert response.status_code == status.HTTP_200_OK
        assert stored(lobby) == {
            "roles": new_roles,
            "discussion_seconds": 300,
            "night_wave_seconds": 30,
        }

    def test_a_complete_settings_object_still_works_as_before(self, table) -> None:
        """The harness and the game driver send everything at once."""
        lobby, _, client = table
        complete = {"roles": ROLES, "night_wave_seconds": 0, "discussion_seconds": 0}

        response = patch_settings(client, lobby.code, complete)

        assert response.status_code == status.HTTP_200_OK
        assert stored(lobby) == complete

    def test_a_key_given_again_is_replaced_whole_not_merged_inside(self, table) -> None:
        lobby, _, client = table
        smaller = {"Werewolf": 2, "Villager": 3, "Drunk": 1}

        patch_settings(client, lobby.code, {"roles": smaller})

        assert stored(lobby)["roles"] == smaller  # no Seer left over

    def test_the_merged_result_is_what_the_game_validates(self, table) -> None:
        lobby, _, client = table

        response = patch_settings(client, lobby.code, {"night_min_window_seconds": 9})
        # (night_wave_seconds is not set, so a minimum alone is fine)
        assert response.status_code == status.HTTP_200_OK

        # A key that is fine alone but wrong beside a STORED one is refused.
        patch_settings(client, lobby.code, {"night_wave_seconds": 20})
        bad = patch_settings(client, lobby.code, {"night_min_window_seconds": 25})

        assert bad.status_code == status.HTTP_400_BAD_REQUEST
        assert stored(lobby)["night_min_window_seconds"] == 9  # nothing half-applied

    @pytest.mark.parametrize("junk", ["roles", ["roles"], 3, True])
    def test_settings_must_be_an_object(self, table, junk) -> None:
        lobby, _, client = table

        response = patch_settings(client, lobby.code, junk)

        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert stored(lobby)["roles"] == ROLES

    def test_settings_are_required(self, table) -> None:
        lobby, _, client = table

        response = client.patch(url(lobby.code), {}, format="json")

        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert response.data["detail"] == "settings field is required."


class TestWhoAndWhen:
    def test_only_the_host_may_change_settings(self, table) -> None:
        lobby, _, _ = table
        other = lobby.players.exclude(user=lobby.host).first().user
        client = APIClient()
        client.force_authenticate(user=other)

        response = patch_settings(client, lobby.code, {"voting_seconds": 90})

        assert response.status_code == status.HTTP_403_FORBIDDEN
        assert "voting_seconds" not in stored(lobby)

    def test_an_unknown_lobby_is_404(self, table) -> None:
        _, _, client = table

        assert (
            patch_settings(client, "ZZZZZZ", {}).status_code
            == status.HTTP_404_NOT_FOUND
        )

    def test_settings_do_not_change_while_a_game_is_in_progress(self, table) -> None:
        lobby, _, client = table
        Lobby.objects.filter(pk=lobby.pk).update(status=Lobby.Status.IN_GAME)

        response = patch_settings(client, lobby.code, {"voting_seconds": 90})

        assert response.status_code == status.HTTP_409_CONFLICT
        assert response.data["code"] == "lobby_in_game"
        assert "voting_seconds" not in stored(lobby)

    def test_a_finished_table_may_change_the_deck_for_the_next_game(
        self, table
    ) -> None:
        lobby, _, client = table
        Lobby.objects.filter(pk=lobby.pk).update(status=Lobby.Status.FINISHED)

        response = patch_settings(client, lobby.code, {"voting_seconds": 90})

        assert response.status_code == status.HTTP_200_OK

    @pytest.mark.django_db(transaction=True)
    def test_two_screens_patching_at_once_both_keep_their_keys(self) -> None:
        """Under the Lobby row lock the merges queue up; without it, one thread's
        read-merge-write overwrites the other's and a key is lost."""
        lobby, host, _ = _create_lobby_with_players(3, {"roles": ROLES})
        rounds, barrier_size = 15, 2
        lost: list[int] = []

        def tap(settings: dict, barrier: threading.Barrier) -> None:
            try:
                client = APIClient()
                client.force_authenticate(user=host)
                barrier.wait(timeout=10)
                with patch("apps.core.views.get_channel_layer", return_value=None):
                    patch_settings(client, lobby.code, settings)
            finally:
                connections.close_all()

        for i in range(rounds):
            Lobby.objects.filter(pk=lobby.pk).update(settings={"roles": ROLES})
            barrier = threading.Barrier(barrier_size)
            threads = [
                threading.Thread(
                    target=tap, args=({"discussion_seconds": 100 + i}, barrier)
                ),
                threading.Thread(
                    target=tap, args=({"voting_seconds": 50 + i}, barrier)
                ),
            ]
            for t in threads:
                t.start()
            for t in threads:
                t.join(timeout=30)
            now = stored(lobby)
            if (
                now.get("discussion_seconds") != 100 + i
                or now.get("voting_seconds") != 50 + i
            ):
                lost.append(i)

        assert lost == []


class TestTheDeckIsCheckedOnlyWhenTheDeckChanges:
    @pytest.fixture
    def somebody_joined(self, table):
        """The deck fits 3 players; a 4th sits down afterwards."""
        lobby, _, client = table
        newcomer = User.objects.create_user(username="latecomer", password="x")
        LobbyMember.objects.create(lobby=lobby, user=newcomer)
        return lobby, client

    def test_a_pace_only_patch_is_not_refused_because_a_player_joined(
        self, somebody_joined
    ) -> None:
        lobby, client = somebody_joined

        response = patch_settings(client, lobby.code, {"pace": "quick"})

        assert response.status_code == status.HTTP_200_OK, response.data
        assert stored(lobby)["pace"] == "quick"

    def test_a_timer_patch_is_not_refused_either_but_a_bad_timer_still_is(
        self, somebody_joined
    ) -> None:
        lobby, client = somebody_joined

        ok = patch_settings(client, lobby.code, {"voting_seconds": 90})
        bad = patch_settings(client, lobby.code, {"voting_seconds": -5})

        assert ok.status_code == status.HTTP_200_OK
        assert bad.status_code == status.HTTP_400_BAD_REQUEST
        assert stored(lobby)["voting_seconds"] == 90

    def test_a_patch_that_sets_roles_is_stored_and_deal_says_it_does_not_fit(
        self, somebody_joined
    ) -> None:
        lobby, client = somebody_joined  # 4 players need 7 cards; ROLES is 6

        response = patch_settings(client, lobby.code, {"roles": ROLES})

        assert response.status_code == status.HTTP_200_OK
        assert stored(lobby)["roles"] == ROLES
        assert response.data["deal"]["ok"] is False
        assert (response.data["deal"]["need"], response.data["deal"]["have"]) == (7, 6)

    def test_a_patch_with_an_illegal_role_count_is_still_refused(
        self, somebody_joined
    ) -> None:
        lobby, client = somebody_joined

        response = patch_settings(client, lobby.code, {"roles": {"Seer": 2}})

        assert response.status_code == status.HTTP_400_BAD_REQUEST

    def test_the_deal_still_refuses_the_mismatched_deck(self, somebody_joined) -> None:
        lobby, client = somebody_joined
        patch_settings(client, lobby.code, {"pace": "quick"})

        response = client.post(reverse("onuw:game-start", kwargs={"code": lobby.code}))

        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert any("Total role count" in e for e in response.data["detail"])


class TestPaceLabel:
    @pytest.mark.parametrize("label", PACE_LABELS)
    def test_pace_label_validated_if_present(self, label) -> None:
        settings = {"roles": ROLES, "pace": label}

        assert validate_onuw_settings(settings, 3) == []

    @pytest.mark.parametrize("junk", ["fast", "", "Quick", 3, None, ["quick"]])
    def test_a_junk_pace_label_is_refused(self, junk) -> None:
        errors = validate_onuw_settings({"roles": ROLES, "pace": junk}, 3)

        assert any("'pace'" in e for e in errors)

    def test_no_pace_label_is_fine(self) -> None:
        assert validate_onuw_settings({"roles": ROLES}, 3) == []

    def test_junk_pace_is_refused_by_the_patch_and_nothing_is_stored(
        self, table
    ) -> None:
        lobby, _, client = table

        response = patch_settings(client, lobby.code, {"pace": "fast"})

        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert "pace" not in stored(lobby)

    @pytest.mark.parametrize("preset", PRESETS)
    def test_preset_values_pass_validation(self, table, preset) -> None:
        lobby, _, client = table
        settings = {**PRESETS[preset], "night_min_window_seconds": 8, "pace": preset}

        response = patch_settings(client, lobby.code, settings)

        assert response.status_code == status.HTTP_200_OK, response.data
        assert stored(lobby)["pace"] == preset
        assert stored(lobby)["roles"] == ROLES

    @pytest.mark.parametrize(
        "custom",
        [
            # the slider bounds of the "custom" preset (60-900, 20-300, 10-120, 8-30)
            (60, 20, 10, 8),
            (900, 300, 120, 30),
        ],
    )
    def test_the_custom_bounds_pass_validation(self, table, custom) -> None:
        lobby, _, client = table
        discussion, voting, wave, doppelganger = custom

        response = patch_settings(
            client,
            lobby.code,
            {
                "discussion_seconds": discussion,
                "voting_seconds": voting,
                "night_wave_seconds": wave,
                "night_doppelganger_window_seconds": doppelganger,
                "night_min_window_seconds": 8,
                "pace": "custom",
            },
        )

        assert response.status_code == status.HTTP_200_OK, response.data
