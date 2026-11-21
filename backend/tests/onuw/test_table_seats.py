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

import pytest
from rest_framework import status

from apps.onuw.engine.decks import auto_deck
from apps.onuw.engine.validation import seats_of, validate_onuw_settings
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
        assert reply.data["detail"] == ["5 players are at the table already."]
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
    value the deal would use and what a PATCH would take now, so the set-up page
    shows and edits each one without holding a rule."""

    def test_every_timer_setting_is_there(self, table) -> None:
        from apps.onuw.engine.validation import TIMER_SETTING_KEYS

        body = table(players=1).body()

        assert set(body["lengths"]) == set(TIMER_SETTING_KEYS)
        assert set(body["length_ranges"]) == set(TIMER_SETTING_KEYS)

    def test_a_patch_at_each_end_of_a_range_is_taken(self, table, settings) -> None:
        settings.ONUW_ALLOW_UNTIMED_NIGHT = False
        t = table(players=3)
        ranges = t.body()["length_ranges"]
        assert ranges["night_wave_seconds"][0] >= 5
        assert ranges["night_min_window_seconds"] == [5, 30]
        assert ranges["host_handover_seconds"] == [0, 600]
        for key, (least, most) in ranges.items():
            for value in (least, most):
                reply = t.patch({key: value})
                assert reply.status_code == status.HTTP_200_OK, (key, value)
                assert reply.data["lengths"][key] == value
                t.patch({key: t.body()["lengths"][key]})
        # The server's own floors: no untimed night window, a shortest window of 5.
        for key, below in (
            ("night_wave_seconds", 0),
            ("night_doppelganger_window_seconds", 0),
            ("night_min_window_seconds", 4),
        ):
            reply = t.patch({key: below})
            assert reply.status_code == status.HTTP_400_BAD_REQUEST, key

    def test_the_shortest_window_never_passes_the_window(self, table) -> None:
        t = table(players=1)
        t.patch({"night_wave_seconds": 12, "night_min_window_seconds": 9})
        ranges = t.body()["length_ranges"]
        assert ranges["night_min_window_seconds"][1] == 12
        assert ranges["night_wave_seconds"][0] == 9
