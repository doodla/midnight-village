"""
The owner leaves: the table is not deleted from under everyone.

While other members remain, ownership moves for good to the next member in join
order (a connected one preferred), ``acting_host`` is cleared, and the lobby and
the newest game's table are told (``host_changed``, reason ``transferred``,
``host_id`` == ``original_host_id`` == the new owner). Only when the owner was the
last member is the lobby deleted. While a game runs leaving is still refused.
Finished games stay readable by the players who remain.
"""

from typing import Any

from django.urls import reverse
from django.utils import timezone

import pytest
from rest_framework import status

from apps.core.models import Lobby, LobbyMember, LobbySocket
from apps.onuw.models import Game, Phase
from tests.onuw.test_play_again import Table

pytestmark = pytest.mark.integration

ROLES = {"wolf": "Werewolf", "seer": "Seer", "robber": "Robber", "villager": "Villager"}


@pytest.fixture
def table(db, settings):
    settings.DEBUG = True
    return Table()


def leave(client: Any, code: str) -> Any:
    return client.post(reverse("core:lobby-leave", kwargs={"code": code}))


class TestTheOwnerLeavesAtTheResultsScreen:
    def test_the_table_and_the_finished_game_survive_for_the_others(self, table):
        game_id = table.play_to_results(seed=7)
        before = [
            c.get(reverse("onuw:results", kwargs={"game_id": game_id})).data
            for c in table.clients[1:]
        ]

        response = leave(table.host, table.code)

        assert response.status_code == status.HTTP_200_OK
        lobby = table.lobby()  # not deleted
        assert Game.objects.filter(id=game_id, phase=Phase.RESULTS).exists()
        for client, earlier in zip(table.clients[1:], before, strict=True):
            now = client.get(reverse("onuw:results", kwargs={"game_id": game_id}))
            assert now.status_code == status.HTTP_200_OK
            assert now.data == earlier
            me = client.get(reverse("onuw:game-me", kwargs={"game_id": game_id}))
            assert me.status_code == status.HTTP_200_OK
        assert lobby.host_id == table.ids[1]
        assert not LobbyMember.objects.filter(
            lobby=lobby, user_id=table.ids[0]
        ).exists()

    def test_the_new_owner_can_play_again_and_the_old_one_cannot(self, table):
        table.play_to_results(seed=7)
        leave(table.host, table.code)
        new_owner = table.clients[1]

        refused = table.play_again(table.host)  # no longer a member or the host
        again = table.play_again(new_owner)

        assert refused.status_code == status.HTTP_403_FORBIDDEN
        assert again.status_code == status.HTTP_200_OK
        assert again.data["host"]["id"] == table.ids[1]
        assert again.data["original_host_id"] == table.ids[1]
        assert again.data["is_acting_host"] is False
        assert len(again.data["players"]) == 4

    def test_the_new_owner_can_start_the_next_game(self, table):
        table.play_to_results(seed=7)
        leave(table.host, table.code)
        table.play_again(table.clients[1])
        four = {"Werewolf": 2, "Seer": 1, "Robber": 1, "Villager": 2, "Drunk": 1}
        table.clients[1].patch(
            reverse("core:lobby-detail", kwargs={"code": table.code}),
            {"settings": {"roles": four, **{"night_wave_seconds": 0}}},
            format="json",
        )

        started = table.clients[1].post(
            reverse("onuw:game-start", kwargs={"code": table.code}),
            {"debug": {"seed": 3}},
            format="json",
        )

        assert started.status_code == status.HTTP_201_CREATED


class TestWaitingLobbiesAndLastMembers:
    def test_the_owner_leaving_a_waiting_lobby_with_others_transfers_it(self, table):
        response = leave(table.host, table.code)

        assert response.status_code == status.HTTP_200_OK
        lobby = table.lobby()
        assert lobby.host_id == table.ids[1]
        assert lobby.acting_host_id is None
        assert lobby.players.count() == 4

    def test_the_last_member_leaving_deletes_the_lobby(self, db):
        solo = Table(players=1)
        assert leave(solo.host, solo.code).status_code == status.HTTP_200_OK
        assert not Lobby.objects.filter(code=solo.code).exists()

    def test_the_owner_is_refused_while_a_game_is_running(self, table):
        table.start(seed=1)

        response = leave(table.host, table.code)

        assert response.status_code == status.HTTP_409_CONFLICT
        assert table.lobby().host_id == table.ids[0]

    def test_a_connected_member_is_preferred_over_the_next_in_line(self, table):
        LobbySocket.objects.create(
            user_id=table.ids[3],
            lobby=table.lobby(),
            channel_name="owner-leaves-c",
            connected_at=timezone.now(),
            last_seen=timezone.now(),
        )

        leave(table.host, table.code)

        assert table.lobby().host_id == table.ids[3]

    def test_without_anyone_connected_it_is_the_next_in_join_order(self, table):
        leave(table.host, table.code)
        assert table.lobby().host_id == table.ids[1]

    def test_the_old_owners_sockets_and_the_membership_are_gone(self, table):
        lobby = table.lobby()
        LobbySocket.objects.create(
            user_id=table.ids[0],
            lobby=lobby,
            channel_name="old-owner",
            connected_at=timezone.now(),
            last_seen=timezone.now(),
        )

        leave(table.host, table.code)

        assert not LobbySocket.objects.filter(channel_name="old-owner").exists()
        assert not LobbyMember.objects.filter(
            lobby=lobby, user_id=table.ids[0]
        ).exists()


class TestActingHostInterplay:
    def test_an_acting_host_is_cleared_when_the_owner_leaves(self, table):
        lobby = table.lobby()
        Lobby.objects.filter(pk=lobby.pk).update(acting_host_id=table.ids[2])
        LobbySocket.objects.create(
            user_id=table.ids[2],
            lobby=lobby,
            channel_name="acting",
            connected_at=timezone.now(),
            last_seen=timezone.now(),
        )

        leave(table.host, table.code)

        lobby = table.lobby()
        assert lobby.acting_host_id is None
        assert lobby.host_id == table.ids[2]  # the connected one (here the acting host)
        assert lobby.effective_host_id == table.ids[2]

    def test_the_new_owner_is_not_forced_to_be_the_acting_host(self, table):
        lobby = table.lobby()
        Lobby.objects.filter(pk=lobby.pk).update(acting_host_id=table.ids[2])
        # The acting host is not connected; another member is.
        LobbySocket.objects.create(
            user_id=table.ids[4],
            lobby=lobby,
            channel_name="other",
            connected_at=timezone.now(),
            last_seen=timezone.now(),
        )

        leave(table.host, table.code)

        lobby = table.lobby()
        assert (lobby.host_id, lobby.acting_host_id) == (table.ids[4], None)

    def test_the_acting_host_leaving_is_unchanged(self, table):
        lobby = table.lobby()
        Lobby.objects.filter(pk=lobby.pk).update(acting_host_id=table.ids[1])

        response = leave(table.clients[1], table.code)

        assert response.status_code == status.HTTP_200_OK
        lobby = table.lobby()
        assert lobby.host_id == table.ids[0]  # the owner is still the owner
        assert lobby.acting_host_id is None


class TestEveryoneIsTold:
    def test_lobby_and_game_groups_hear_the_transfer(
        self, make_night, django_capture_on_commit_callbacks
    ):
        night = make_night(ROLES, night_wave_seconds=0)
        night.start()
        Game.objects.filter(id=night.game.id).update(
            phase=Phase.RESULTS, current_wave=0
        )
        Lobby.objects.filter(pk=night.game.lobby_id).update(
            status=Lobby.Status.FINISHED
        )
        code = Lobby.objects.get(pk=night.game.lobby_id).code
        night.recorder.events.clear()
        night.client.force_authenticate(user=night.users["wolf"])

        with night.committed():
            response = night.client.post(
                reverse("core:lobby-leave", kwargs={"code": code})
            )

        assert response.status_code == status.HTTP_200_OK
        new_owner = night.users["seer"]
        expected = {
            "type": "host.changed",
            "host_id": new_owner.id,
            "host_name": new_owner.display_name or new_owner.username,
            "original_host_id": new_owner.id,
            "reason": "transferred",
        }
        events = [
            (g, e) for g, e in night.recorder.events if e["type"] == "host.changed"
        ]
        assert sorted(events, key=lambda ge: ge[0]) == sorted(
            [(f"lobby_{code}", expected), (f"game_{night.game.id}", expected)],
            key=lambda ge: ge[0],
        )

    def test_a_game_less_view_of_the_new_owner_is_consistent(self, make_night):
        night = make_night(ROLES, night_wave_seconds=0)
        night.start()
        Game.objects.filter(id=night.game.id).update(
            phase=Phase.RESULTS, current_wave=0
        )
        Lobby.objects.filter(pk=night.game.lobby_id).update(
            status=Lobby.Status.FINISHED
        )
        code = Lobby.objects.get(pk=night.game.lobby_id).code
        night.client.force_authenticate(user=night.users["wolf"])

        with night.committed():
            night.client.post(reverse("core:lobby-leave", kwargs={"code": code}))

        lobby = Lobby.objects.get(code=code)
        assert lobby.host_id == night.users["seer"].id
