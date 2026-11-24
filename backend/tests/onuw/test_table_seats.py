"""
A table set for a number of players (``settings.seats``, 3 to 10).

The host picks the number before anyone joins and the table waits for that many:

- ``deal.need`` and ``deck_preview`` are for that number, so they never move when
  people join or leave; ``deal.seats`` says the number (null: an open table, which
  deals to whoever is there, as every table did before).
- ``deal.ok`` only once exactly that many are here (and the deck fits); the deal view
  answers the same (a sweep).
- A join past the number is refused as ``lobby_full``.
- The host changes the number any time before the deal, never below the players
  already here: an automatic deck follows it; a custom deck that no longer fits is
  kept and reported by ``deal``, never changed.
- A deck being built is stored card by card (only each role's own limits are
  checked at a PATCH); the deal checks the rest.

All through the real API, several players, seeded deals.
"""

from __future__ import annotations

from typing import Any

from django.urls import reverse

import pytest
from rest_framework import status

from apps.core.models import Lobby
from apps.onuw.engine.decks import auto_deck
from apps.onuw.engine.validation import (
    TIMER_SETTING_KEYS,
    seats_of,
    validate_onuw_settings,
)
from apps.onuw.models import Game

from . import test_lobby_table_extras as extras

CUSTOM_5 = extras.CUSTOM_5
V2 = extras.V2
# The lobby test's fixtures: a table through the real API, its sockets faked.
layer = extras.layer
table = extras.table

pytestmark = pytest.mark.integration

# Eleven cards: a deck for 8 players.
CUSTOM_8 = {
    "Werewolf": 2,
    "Minion": 1,
    "Seer": 1,
    "Robber": 1,
    "Troublemaker": 1,
    "Drunk": 1,
    "Insomniac": 1,
    "Villager": 3,
}


def deal_of(body: dict[str, Any]) -> tuple[bool, int, int, int | None]:
    d = body["deal"]
    return d["ok"], d["need"], d["have"], d["seats"]


class TestSetForANumber:
    def test_a_new_table_is_open(self, table) -> None:
        t = table(players=1)
        body = t.body()
        assert "seats" not in body["settings"]
        assert body["deal"]["seats"] is None
        assert body["deal"]["need"] == 4  # an open table follows who is here

    def test_the_host_alone_sets_up_a_table_for_eight(self, table) -> None:
        t = table(players=1)

        reply = t.patch({"seats": 8, "deck_chip": "classic"})

        assert reply.status_code == status.HTTP_200_OK, reply.data
        assert deal_of(reply.data) == (False, 11, 11, 8)
        assert reply.data["deck_preview"] == auto_deck(8, "classic")

    def test_need_and_preview_never_move_as_people_arrive(self, table) -> None:
        t = table(players=1)
        t.patch({"seats": 8})
        seen = []
        for i in range(1, 8):
            assert t.join(f"p{i}").status_code == status.HTTP_200_OK
            body = t.body()
            seen.append((len(body["players"]), deal_of(body), body["deck_preview"]))

        for present, (ok, need, have, seats), preview in seen:
            assert (need, have, seats) == (11, 11, 8)
            assert preview == auto_deck(8, "simple")
            assert ok is (present == 8)

    def test_a_join_past_the_number_is_refused_as_full(self, table) -> None:
        t = table(players=3)
        t.patch({"seats": 4})
        assert t.join("p3").status_code == status.HTTP_200_OK

        reply = t.join("late")

        assert reply.status_code == status.HTTP_400_BAD_REQUEST
        assert reply.data["code"] == "lobby_full"
        assert len(t.body()["players"]) == 4

    def test_the_deal_deals_exactly_that_many(self, table) -> None:
        t = table(players=5)
        t.patch({"seats": 5, "deck_chip": "chaos"})

        reply = t.deal(seed=21)

        assert reply.status_code == status.HTTP_201_CREATED, reply.data
        game = Game.objects.get(id=reply.data["game_id"])
        assert game.player_roles.count() == 5
        assert game.settings["roles"] == auto_deck(5, "chaos")


class TestChangingTheNumber:
    def test_fewer_came_the_host_lowers_it_and_the_automatic_deck_follows(
        self, table
    ) -> None:
        t = table(players=1)
        t.patch({"seats": 8})
        for i in range(1, 7):
            t.join(f"p{i}")
        assert deal_of(t.body()) == (False, 11, 11, 8)

        reply = t.patch({"seats": 7})

        assert deal_of(reply.data) == (True, 10, 10, 7)
        assert reply.data["deck_preview"] == auto_deck(7, "simple")
        assert t.deal(seed=3).status_code == status.HTTP_201_CREATED

    def test_raising_it_waits_for_more(self, table) -> None:
        t = table(players=5)
        t.patch({"seats": 5})
        assert t.body()["deal"]["ok"] is True

        reply = t.patch({"seats": 6})

        assert deal_of(reply.data) == (False, 9, 9, 6)
        assert t.join("p5").status_code == status.HTTP_200_OK
        assert t.body()["deal"]["ok"] is True

    def test_a_custom_deck_that_no_longer_fits_is_kept_and_reported(
        self, table
    ) -> None:
        t = table(players=1)
        t.patch({"seats": 8, "deck": "custom", "roles": CUSTOM_8})
        for i in range(1, 7):
            t.join(f"p{i}")

        reply = t.patch({"seats": 7})

        assert reply.status_code == status.HTTP_200_OK
        assert reply.data["settings"]["roles"] == CUSTOM_8  # never changed
        assert deal_of(reply.data) == (False, 10, 11, 7)
        assert t.deal().status_code == status.HTTP_400_BAD_REQUEST

        back = t.patch({"deck": "auto"})  # one tap back to a starter deck
        assert deal_of(back.data) == (True, 10, 10, 7)

    def test_never_below_the_players_here(self, table) -> None:
        t = table(players=5)

        reply = t.patch({"seats": 4})

        assert reply.status_code == status.HTTP_400_BAD_REQUEST
        assert reply.data["detail"] == "5 players are at the table already."
        assert "seats" not in t.lobby().settings

    def test_null_opens_the_table_again(self, table) -> None:
        t = table(players=4)
        t.patch({"seats": 8})

        reply = t.patch({"seats": None})

        assert deal_of(reply.data) == (True, 7, 7, None)

    @pytest.mark.parametrize("junk", [2, 11, "8", 8.0, True, [8]])
    def test_a_junk_number_is_refused(self, table, junk) -> None:
        t = table(players=1)

        reply = t.patch({"seats": junk})

        assert reply.status_code == status.HTTP_400_BAD_REQUEST
        assert "seats" not in t.lobby().settings


class TestADeckBuiltCardByCard:
    def test_every_tap_is_stored_and_deal_reports_the_count(self, table) -> None:
        t = table(players=1)
        t.patch({"seats": 8, "deck": "custom", "roles": {}})
        deck: dict[str, int] = {}
        for role, count in CUSTOM_8.items():
            for _ in range(count):
                deck[role] = deck.get(role, 0) + 1
                reply = t.patch({"roles": dict(deck)})
                assert reply.status_code == status.HTTP_200_OK, reply.data
                assert reply.data["deal"]["have"] == sum(deck.values())
                assert reply.data["deal"]["need"] == 11
        assert t.lobby().settings["roles"] == CUSTOM_8

    def test_a_role_past_its_own_limit_is_still_refused(self, table) -> None:
        t = table(players=1)
        for bad in ({"Seer": 2}, {"Mason": 1}, {"Wizard": 1}, {"Villager": -1}):
            reply = t.patch({"deck": "custom", "roles": bad})
            assert reply.status_code == status.HTTP_400_BAD_REQUEST, bad


# ``deal.ok`` and the deal view never disagree, at tables set for a number.
SWEEP = [
    # (settings, players at the table)
    ({**V2, "seats": 3}, 3),
    ({**V2, "seats": 5}, 3),
    ({**V2, "seats": 5}, 5),
    ({**V2, "seats": 10}, 9),
    ({**V2, "seats": 10}, 10),
    ({**V2, "seats": 8, "deck_chip": "chaos"}, 8),
    ({**V2, "seats": 8, "deck": "custom", "roles": CUSTOM_8}, 8),
    ({**V2, "seats": 8, "deck": "custom", "roles": CUSTOM_8}, 7),
    ({**V2, "seats": 7, "deck": "custom", "roles": CUSTOM_8}, 7),
    ({**V2, "seats": 5, "deck": "custom", "roles": CUSTOM_5}, 5),
    ({**V2, "seats": 6, "deck": "custom", "roles": CUSTOM_5}, 5),
    ({**V2, "seats": None}, 4),
]


class TestDealOkSweep:
    @pytest.mark.parametrize(("settings", "players"), SWEEP)
    def test_ok_is_what_the_deal_view_answers(self, table, settings, players) -> None:
        t = table(settings, players=players)
        body = t.body()
        size = seats_of(settings) or players
        deck = (
            auto_deck(size, settings.get("deck_chip"))
            if settings.get("deck") == "auto"
            else settings.get("roles")
        )

        reply = t.deal(seed=players)

        assert body["deal"]["need"] == size + 3
        assert body["deal"]["have"] == sum((deck or {}).values())
        assert body["deal"]["seats"] == seats_of(settings)
        assert body["deal"]["ok"] is (reply.status_code == 201), reply.data


class TestValidation:
    def test_the_deal_names_the_waiting(self) -> None:
        errors = validate_onuw_settings({"deck": "auto", "seats": 8}, 6)
        assert errors == ["The table is set for 8 players, 6 are here."]

    def test_a_patch_checks_the_number_against_who_is_here(self) -> None:
        settings = {"seats": 3}
        only = {"changed": {"seats"}, "check_deck": False}
        assert validate_onuw_settings(settings, 3, **only) == []
        assert validate_onuw_settings(settings, 4, **only) == [
            "4 players are at the table already."
        ]


class TestDeckCardsFaceUp:
    """``deck_cards``: the roles the table would deal, in every state, the same for
    every viewer."""

    def test_an_open_table_of_one_shows_the_smallest_games_deck(self, table) -> None:
        t = table(settings={**V2, "deck_chip": "chaos"}, players=1)
        assert t.body()["deck_cards"] == auto_deck(3, "chaos")

    def test_a_table_set_for_eight_shows_the_deck_for_eight(self, table) -> None:
        t = table(players=2)
        t.patch({"seats": 8, "deck_chip": "classic"})
        assert t.body()["deck_cards"] == auto_deck(8, "classic")

    def test_a_custom_deck_shows_what_is_picked_so_far(self, table) -> None:
        t = table(players=1)
        t.patch({"seats": 8, "deck": "custom", "roles": {"Seer": 1, "Drunk": 0}})
        t.join("guest")
        assert t.body("guest")["deck_cards"] == {"Seer": 1}

    def test_a_guest_sees_what_the_host_sees(self, table) -> None:
        t = table(players=4)
        t.patch({"deck_chip": "chaos"})
        assert t.body("p1")["deck_cards"] == t.body()["deck_cards"]
        assert t.body("p1")["deck_cards"] == auto_deck(4, "chaos")


class TestEveryLengthWithItsRange:
    """``lengths`` and ``length_ranges``: every timer setting the server reads, the
    value the deal would use and what a PATCH would take now. The ranges are the
    check's own (one rule table), so the phone is never offered what is refused."""

    def test_every_timer_setting_is_there(self, table) -> None:
        body = table(players=1).body()

        assert set(body["lengths"]) == set(TIMER_SETTING_KEYS)
        assert set(body["length_ranges"]) == set(TIMER_SETTING_KEYS)

    @pytest.mark.parametrize("untimed", [False, True])
    def test_each_end_of_every_range_is_taken_and_one_past_is_refused(
        self, table, settings, untimed
    ) -> None:
        settings.ONUW_ALLOW_UNTIMED_NIGHT = untimed
        t = table(players=3)
        for key in TIMER_SETTING_KEYS:
            # Read again after every change: a range follows the other lengths.
            start = t.body()["lengths"][key]
            least, most = t.body()["length_ranges"][key]
            for value in (least, most):
                reply = t.patch({key: value})
                assert reply.status_code == status.HTTP_200_OK, (key, value)
                assert reply.data["lengths"][key] == value, (key, value)
            for value in (least - 1, most + 1):
                reply = t.patch({key: value})
                assert reply.status_code == status.HTTP_400_BAD_REQUEST, (key, value)
            back = t.patch({key: start})
            assert back.status_code == status.HTTP_200_OK, (key, start)
            assert t.body()["lengths"][key] == start

    def test_the_shortest_window_never_passes_the_window(self, table) -> None:
        t = table(players=1)
        t.patch({"night_wave_seconds": 12, "night_min_window_seconds": 9})
        assert t.body()["length_ranges"]["night_min_window_seconds"][1] == 12
        reply = t.patch({"night_min_window_seconds": 13})
        assert reply.status_code == status.HTTP_400_BAD_REQUEST

    def test_no_clock_and_nobody_ever_counted_gone_is_refused(
        self, table, settings
    ) -> None:
        settings.ONUW_ALLOW_UNTIMED_NIGHT = False
        t = table(players=3)
        assert t.patch({"discussion_seconds": 0}).status_code == 200
        ranges = t.body()["length_ranges"]
        assert ranges["disconnect_grace_seconds"][0] == 1
        assert t.patch({"disconnect_grace_seconds": 0}).status_code == 400
        assert t.patch({"discussion_seconds": 60}).status_code == 200
        assert t.patch({"disconnect_grace_seconds": 0}).status_code == 200
        ranges = t.body()["length_ranges"]
        assert ranges["discussion_seconds"][0] == 1
        assert ranges["voting_seconds"][0] == 1
        assert t.patch({"voting_seconds": 0}).status_code == 400

    @pytest.mark.parametrize(
        "stored",
        [
            {"night_wave_seconds": 6},
            {"night_wave_seconds": 3, "night_min_window_seconds": 2},
            {"discussion_seconds": 0, "disconnect_grace_seconds": 0},
            {"night_wave_seconds": 0, "voting_seconds": 0},
            {"night_min_window_seconds": 50},
            {"voting_seconds": "junk", "host_handover_seconds": 9000},
        ],
    )
    def test_what_older_code_stored_is_reported_as_it_will_run_within_its_range(
        self, table, settings, stored
    ) -> None:
        settings.ONUW_ALLOW_UNTIMED_NIGHT = False
        t = table(players=3)
        Lobby.objects.filter(code=t.code).update(settings={**V2, **stored})
        body = t.body()
        for key, value in body["lengths"].items():
            least, most = body["length_ranges"][key]
            assert least <= value <= most, (key, value, least, most)
        # The minimum window never runs longer than the window.
        lengths = body["lengths"]
        assert lengths["night_min_window_seconds"] <= lengths["night_wave_seconds"]


class TestSeatsRange:
    def test_the_number_is_never_above_what_the_table_holds(self, table) -> None:
        t = table(players=2)
        Lobby.objects.filter(code=t.code).update(max_players=6)
        assert t.body()["seats_range"] == [3, 6]
        assert t.patch({"seats": 6}).status_code == 200
        reply = t.patch({"seats": 7})
        assert reply.status_code == status.HTTP_400_BAD_REQUEST
        assert reply.data["detail"] == "The table holds 6 players at most."

    def test_never_below_who_is_here(self, table) -> None:
        t = table(players=5)
        assert t.body()["seats_range"] == [5, 10]


class TestTheDealtDeckDuringAGame:
    def test_in_a_game_the_body_shows_the_deck_dealt(self, table) -> None:
        t = table({**V2, "deck_chip": "chaos"}, players=5)
        dealt = auto_deck(5, "chaos")
        assert t.deal(seed=4).status_code == status.HTTP_201_CREATED
        t.join("late")  # refused (playing), the deck must not follow anyone
        body = t.body()
        assert body["deck_cards"] == dealt
        assert body["deal"]["have"] == sum(dealt.values())


class TestLeaveRefusalCode:
    def test_a_leave_from_a_table_one_is_not_at_says_so_by_code(self, table) -> None:
        t = table(players=3)
        t.user("stranger")
        reply = t.post("stranger", reverse("core:lobby-leave", kwargs={"code": t.code}))
        assert reply.status_code == status.HTTP_400_BAD_REQUEST
        assert reply.data["code"] == "not_in_lobby"
