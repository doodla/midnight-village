"""
``GET /api/onuw/games/<id>/results/`` has ``night_timeline``.

All through the real API: five guests seated in the reverse of user-id order, a
game dealt from a fixed seed, the night closed by the host (the Drunk is swapped by
the server), the vote, the results. The timeline must agree with the game's own
final cards, whichever way the dealt centre was found.
"""

from typing import Any
from unittest.mock import patch

from django.urls import reverse

import pytest
from rest_framework import status

from apps.onuw.models import Game
from tests.onuw.test_play_again import Table

pytestmark = pytest.mark.integration


@pytest.fixture
def table(db, settings):
    settings.DEBUG = True  # fixed seeds and forced assignments
    return Table()


def results(table: Table, game_id: str, index: int = 0):
    return table.clients[index].get(
        reverse("onuw:results", kwargs={"game_id": game_id})
    )


def forced_game(table: Table) -> str:
    """A game with a known deal: the Drunk (never acts) is swapped by the server."""
    roles = ["Werewolf", "Seer", "Robber", "Drunk", "Insomniac"]
    forced = {
        "player_roles": {
            str(uid): role for uid, role in zip(table.ids, roles, strict=True)
        },
        "center": ["Werewolf", "Villager", "Villager"],
    }
    response = table.host.post(
        reverse("onuw:game-start", kwargs={"code": table.code}),
        {"debug": {"forced_assignment": forced}},
        format="json",
    )
    assert response.status_code == status.HTTP_201_CREATED, response.data
    return table.finish_game(response.data["game_id"])


def final_roles(timeline: dict[str, Any], key: str = "final"):
    role = {c["card_id"]: c["role"] for c in timeline["cards"]}
    positions = timeline[key]
    return (
        {int(uid): role[card] for uid, card in positions["players"].items()},
        [role[card] for card in positions["center"]],
    )


class TestTheResultsCarryTheTimeline:
    def test_the_timeline_ends_where_the_game_ended(self, table) -> None:
        game_id = forced_game(table)

        body = results(table, game_id, 2).data

        timeline = body["night_timeline"]
        assert timeline["seats"] == table.ids  # seat order, not user-id order
        assert timeline["seats"] != sorted(timeline["seats"])
        players, center = final_roles(timeline)
        assert players == {p["player_id"]: p["final_role"] for p in body["players"]}
        assert center == body["center_cards"]
        dealt_players, dealt_center = final_roles(timeline, "dealt")
        assert {p["player_id"]: p["original_role"] for p in body["players"]} == (
            dealt_players
        )
        assert dealt_center == ["Werewolf", "Villager", "Villager"]
        # The old fields are still there.
        assert {"night_actions_log", "winning_teams", "players"} <= set(body)

    def test_the_server_made_drunk_swap_is_in_the_timeline(self, table) -> None:
        game_id = forced_game(table)

        timeline = results(table, game_id).data["night_timeline"]

        drunk = next(s for s in timeline["steps"] if s["role"] == "Drunk")
        assert drunk["made_by_server"] is True
        assert drunk["actors"] == [table.ids[3]]
        assert any(timeline["center_moved"])
        assert [s["step"] for s in timeline["steps"]] == list(
            range(1, len(timeline["steps"]) + 1)
        )

    def test_every_player_gets_the_same_timeline(self, table) -> None:
        game_id = forced_game(table)

        bodies = [results(table, game_id, i).data["night_timeline"] for i in range(5)]

        assert all(body == bodies[0] for body in bodies)

    def test_a_game_dealt_before_the_centre_was_stored_recovers_it(self, table) -> None:
        game_id = forced_game(table)
        stored = results(table, game_id).data["night_timeline"]

        Game.objects.filter(id=game_id).update(dealt_center_cards=[])
        recovered = results(table, game_id).data["night_timeline"]

        assert recovered == stored  # undone from the final table, same night

    def test_timeline_null_and_logged_on_inconsistent_log(self, table) -> None:
        game_id = forced_game(table)
        game = Game.objects.get(id=game_id)
        # An entry for a player who is not at the table.
        bad = [
            *game.night_actions_log,
            {
                "wave": 3,
                "player_id": 987654,
                "action_type": "swap_with_player",
                "targets": {"player_id": 123456},
                "result": {},
                "timestamp_order": 99,
                "role_acting_as": "Robber",
            },
        ]
        Game.objects.filter(id=game_id).update(night_actions_log=bad)

        with patch("apps.onuw.services.logger") as log:
            response = results(table, game_id)

        assert response.status_code == status.HTTP_200_OK
        assert response.data["night_timeline"] is None
        assert response.data["players"]  # the rest of the results still show
        log.error.assert_called_once()
        assert str(game_id) in str(log.error.call_args)

    def test_an_old_game_whose_log_does_not_lead_back_to_the_deal_gets_none(
        self, table
    ) -> None:
        game_id = forced_game(table)
        game = Game.objects.get(id=game_id)
        # No stored centre, and a swap missing from the log: nothing to trust.
        Game.objects.filter(id=game_id).update(
            dealt_center_cards=[],
            night_actions_log=[
                e
                for e in game.night_actions_log
                if e["action_type"] != "swap_with_center"
            ],
        )

        with patch("apps.onuw.services.logger") as log:
            body = results(table, game_id).data

        assert body["night_timeline"] is None
        log.error.assert_called_once()


class TestResultsAccessIsUnchanged:
    def test_results_timeline_not_available_before_results_phase(self, table) -> None:
        game_id = table.start().data["game_id"]  # night

        response = results(table, game_id)

        assert response.status_code == status.HTTP_403_FORBIDDEN
        assert "night_timeline" not in response.data
        table.host.post(reverse("onuw:wave-advance", kwargs={"game_id": game_id}))
        talk = results(table, game_id)  # discussion
        assert talk.status_code == status.HTTP_403_FORBIDDEN
        assert "night_timeline" not in talk.data

    def test_a_player_of_another_game_cannot_read_it(self, table) -> None:
        game_id = forced_game(table)
        other = Table(players=3)

        response = other.clients[0].get(
            reverse("onuw:results", kwargs={"game_id": game_id})
        )

        assert response.status_code == status.HTTP_403_FORBIDDEN
        assert "night_timeline" not in response.data
