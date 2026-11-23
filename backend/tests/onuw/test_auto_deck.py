"""
Automatic decks and lobby defaults.

A lobby with ``deck: "auto"`` and a ``deck_chip`` (``simple``, ``classic``, ``chaos``)
has no card list of its own: the server builds the deck at the deal for the number
of players then at the table, from ONE table in code that the doc shows too. A lobby
created with ``defaults: "v2"`` starts with a card look and the automatic Simple
deck, and nothing else (no timer length is assumed).
"""

import re
from pathlib import Path
from typing import Any

from django.urls import reverse

import pytest
from rest_framework import status
from rest_framework.test import APIClient

from apps.onuw.engine.decks import (
    DECK_CHIPS,
    DECK_TABLE,
    MAX_AUTO_PLAYERS,
    MIN_AUTO_PLAYERS,
    auto_deck,
)
from apps.onuw.engine.validation import validate_onuw_settings
from apps.onuw.models import Game
from tests.onuw.test_play_again import Table

pytestmark = pytest.mark.integration

SETUPS_DOC = (
    Path(__file__).resolve().parents[3]
    / "docs"
    / "specs"
    / "onuw"
    / "recommended-setups.md"
)
ROWS = [(players, chip) for players in range(3, 11) for chip in DECK_CHIPS]


def cell_to_deck(cell: str) -> dict[str, int]:
    deck: dict[str, int] = {}
    for part in cell.split(","):
        match = re.fullmatch(r"\s*([A-Za-z]+)(?: \u00d7(\d+))?\s*", part)
        assert match, f"cannot read {part!r}"
        deck[match.group(1)] = deck.get(match.group(1), 0) + int(match.group(2) or 1)
    return deck


def doc_table() -> dict[tuple[int, str], dict[str, int]]:
    text = SETUPS_DOC.read_text()
    section = text.split("## Automatic Decks", 1)[1].split("\n## ", 1)[0]
    table: dict[tuple[int, str], dict[str, int]] = {}
    for line in section.splitlines():
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) == 4 and cells[0].isdigit():
            for chip, cell in zip(DECK_CHIPS, cells[1:], strict=True):
                table[(int(cells[0]), chip)] = cell_to_deck(cell)
    return table


class TestTheTable:
    def test_the_doc_shows_the_same_table_as_the_code(self) -> None:
        assert doc_table() == DECK_TABLE

    def test_there_is_a_row_for_every_player_count_and_chip(self) -> None:
        assert set(DECK_TABLE) == set(ROWS)
        assert (MIN_AUTO_PLAYERS, MAX_AUTO_PLAYERS) == (3, 10)

    @pytest.mark.parametrize(("players", "chip"), ROWS)
    def test_every_row_is_a_legal_deck_of_players_plus_three_cards(
        self, players, chip
    ) -> None:
        deck = auto_deck(players, chip)

        assert deck is not None
        assert sum(deck.values()) == players + 3
        assert validate_onuw_settings({"roles": deck}, players) == []

    def test_simple_has_no_minion_tanner_or_doppelganger_and_masons_only_when_forced(
        self,
    ) -> None:
        for players in range(3, 11):
            deck = DECK_TABLE[(players, "simple")]
            assert not {"Minion", "Tanner", "Doppelganger"} & set(deck), players
            assert ("Mason" in deck) == (players >= 9), players

    def test_the_doppelganger_is_only_in_chaos_at_nine_and_ten(self) -> None:
        with_dop = {row for row, deck in DECK_TABLE.items() if "Doppelganger" in deck}
        assert with_dop == {(9, "chaos"), (10, "chaos")}

    def test_auto_deck_defaults_to_simple_and_refuses_what_has_no_row(self) -> None:
        assert auto_deck(5) == DECK_TABLE[(5, "simple")]
        assert auto_deck(5, None) == DECK_TABLE[(5, "simple")]
        assert auto_deck(2) is None
        assert auto_deck(11) is None
        assert auto_deck(5, "wild") is None

    def test_the_callers_copy_cannot_change_the_table(self) -> None:
        deck = auto_deck(5, "simple")
        assert deck is not None
        deck["Villager"] = 99
        assert DECK_TABLE[(5, "simple")]["Villager"] == 3


class TestSettingsValidation:
    def test_an_auto_lobby_needs_no_card_list(self) -> None:
        assert validate_onuw_settings({"deck": "auto", "deck_chip": "classic"}, 5) == []
        assert validate_onuw_settings({"deck": "auto"}, 5) == []

    def test_a_card_list_given_beside_auto_is_ignored_not_checked(self) -> None:
        settings = {"deck": "auto", "roles": {"Werewolf": 1}}
        assert validate_onuw_settings(settings, 5) == []

    @pytest.mark.parametrize("players", [2, 11])
    def test_the_table_size_still_decides(self, players) -> None:
        errors = validate_onuw_settings({"deck": "auto"}, players)
        assert errors
        assert validate_onuw_settings({"deck": "auto"}, players, check_deck=False) == []

    @pytest.mark.parametrize("chip", ["wild", "", 1, None, ["simple"]])
    def test_an_unknown_chip_is_refused(self, chip) -> None:
        errors = validate_onuw_settings({"deck": "auto", "deck_chip": chip}, 5)
        assert any("deck_chip" in e for e in errors)

    @pytest.mark.parametrize("deck", ["manual", "", 1, None, True])
    def test_an_unknown_deck_mode_is_refused(self, deck) -> None:
        errors = validate_onuw_settings({"deck": deck, "roles": {}}, 5)
        assert any("'deck'" in e for e in errors)

    def test_a_custom_deck_still_needs_its_cards(self) -> None:
        errors = validate_onuw_settings({"deck": "custom"}, 5)
        assert any("roles" in e for e in errors)

    def test_a_custom_deck_is_checked_as_before(self) -> None:
        roles = {
            "Werewolf": 2,
            "Seer": 1,
            "Robber": 1,
            "Troublemaker": 1,
            "Villager": 3,
        }
        assert validate_onuw_settings({"deck": "custom", "roles": roles}, 5) == []
        assert validate_onuw_settings({"deck": "custom", "roles": roles}, 6) != []

    def test_a_chip_without_a_deck_mode_is_still_checked(self) -> None:
        roles = {
            "Werewolf": 2,
            "Seer": 1,
            "Robber": 1,
            "Troublemaker": 1,
            "Villager": 3,
        }
        errors = validate_onuw_settings({"roles": roles, "deck_chip": "wild"}, 5)
        assert any("deck_chip" in e for e in errors)


def new_client() -> tuple[APIClient, int]:
    client = APIClient()
    reply = client.post(reverse("core:guest-create"), {}, format="json")
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {reply.data['access']}")
    return client, reply.data["user"]["id"]


def join(table: Table) -> None:
    client, user_id = new_client()
    client.post(reverse("core:lobby-join", kwargs={"code": table.code}))
    table.clients.append(client)
    table.ids.append(user_id)


def set_deck(table: Table, **settings: Any):
    return table.host.patch(
        reverse("core:lobby-detail", kwargs={"code": table.code}),
        {"settings": settings},
        format="json",
    )


def dealt_roles(game: Game) -> dict[str, int]:
    counts: dict[str, int] = {}
    for role in [
        *game.player_roles.values_list("original_role", flat=True),
        *game.dealt_center_cards,
    ]:
        counts[role] = counts.get(role, 0) + 1
    return counts


@pytest.fixture
def table_at(db, settings):
    settings.DEBUG = True

    def build(players: int) -> Table:
        return Table(players=players)

    return build


class TestTheDeal:
    @pytest.mark.parametrize("players", [5, 9])
    @pytest.mark.parametrize("chip", DECK_CHIPS)
    def test_the_deal_builds_the_deck_for_the_table(
        self, table_at, players, chip
    ) -> None:
        table = table_at(players)
        assert set_deck(table, deck="auto", deck_chip=chip).status_code == 200

        reply = table.start()

        assert reply.status_code == status.HTTP_201_CREATED, reply.data
        game = Game.objects.get(id=reply.data["game_id"])
        assert game.settings["roles"] == DECK_TABLE[(players, chip)]
        assert dealt_roles(game) == DECK_TABLE[(players, chip)]

    def test_a_missing_chip_deals_simple(self, table_at) -> None:
        table = table_at(5)
        assert set_deck(table, deck="auto").status_code == 200

        game = Game.objects.get(id=table.start().data["game_id"])

        assert dealt_roles(game) == DECK_TABLE[(5, "simple")]

    def test_a_stale_card_list_is_ignored(self, table_at) -> None:
        table = table_at(5)  # its lobby carries a 5-player card list
        assert set_deck(table, deck="auto", deck_chip="chaos").status_code == 200

        game = Game.objects.get(id=table.start().data["game_id"])

        assert dealt_roles(game) == DECK_TABLE[(5, "chaos")]

    def test_the_deck_follows_the_player_count_at_the_deal(self, table_at) -> None:
        table = table_at(5)
        assert set_deck(table, deck="auto", deck_chip="classic").status_code == 200
        join(table)  # a sixth player, after the host picked the chip

        reply = table.start()

        assert reply.status_code == status.HTTP_201_CREATED, reply.data
        game = Game.objects.get(id=reply.data["game_id"])
        assert dealt_roles(game) == DECK_TABLE[(6, "classic")]
        assert game.player_roles.count() == 6

    def test_the_lobby_keeps_its_auto_deck_for_the_next_game(self, table_at) -> None:
        table = table_at(5)
        assert set_deck(table, deck="auto", deck_chip="simple").status_code == 200
        first = Game.objects.get(id=table.start().data["game_id"])
        table.finish_game(str(first.id))
        assert table.play_again().status_code == 200
        join(table)

        second = Game.objects.get(id=table.start().data["game_id"])

        assert dealt_roles(second) == DECK_TABLE[(6, "simple")]
        lobby = table.lobby()
        assert lobby.settings["deck"] == "auto"
        assert lobby.settings["roles"] != second.settings["roles"]  # untouched

    def test_a_custom_deck_is_used_as_chosen(self, table_at) -> None:
        table = table_at(5)
        custom = {
            "Werewolf": 2,
            "Seer": 1,
            "Robber": 1,
            "Troublemaker": 1,
            "Drunk": 1,
            "Villager": 2,
        }
        assert set_deck(table, deck="custom", roles=custom).status_code == 200

        game = Game.objects.get(id=table.start().data["game_id"])

        assert dealt_roles(game) == custom

    def test_too_few_players_are_refused_and_nothing_is_dealt(self, table_at) -> None:
        table = table_at(3)
        assert set_deck(table, deck="auto").status_code == 200
        # Two of the three leave.
        for client in table.clients[1:]:
            client.post(reverse("core:lobby-leave", kwargs={"code": table.code}))

        reply = table.start()

        assert reply.status_code == status.HTTP_400_BAD_REQUEST
        assert not Game.objects.filter(lobby__code=table.code).exists()

    def test_me_lists_the_deck_that_was_built(self, table_at) -> None:
        table = table_at(5)
        assert set_deck(table, deck="auto", deck_chip="chaos").status_code == 200
        game = Game.objects.get(id=table.start().data["game_id"])

        body = (
            table.clients[1]
            .get(reverse("onuw:game-me", kwargs={"game_id": str(game.id)}))
            .data
        )

        assert {r["role"]: r["count"] for r in body["roles_in_game"]} == DECK_TABLE[
            (5, "chaos")
        ]

    def test_a_bad_chip_is_refused_when_the_host_sets_it(self, table_at) -> None:
        table = table_at(5)

        assert set_deck(table, deck="auto", deck_chip="wild").status_code == 400
        assert "deck" not in table.lobby().settings


class TestDefaults:
    def create(self, **body: Any):
        client, _ = new_client()
        return client.post(
            reverse("core:lobby-list"), {"game_type": "onuw", **body}, format="json"
        )

    # ONLY what the app's screens need to start: a look at the cards and the
    # automatic Simple deck. No timer the server already defaults, never the
    # Doppelganger's window (the table's own setting, or the server's). The night
    # flag is for the code before the cleanup only (``deal.OLD_CODE_NIGHT_FLAG``):
    # this code ignores it.
    EXPECTED = {
        "card_look_seconds": 30,
        "deck": "auto",
        "deck_chip": "simple",
    }

    def test_the_app_defaults_are_written_when_the_create_body_asks(self, db) -> None:
        reply = self.create(defaults="v2")

        assert reply.status_code == status.HTTP_201_CREATED
        assert reply.data["settings"] == self.EXPECTED

    def test_given_settings_win_over_the_defaults(self, db) -> None:
        reply = self.create(
            defaults="v2", settings={"deck_chip": "chaos", "voting_seconds": 45}
        )

        assert reply.data["settings"] == {
            **self.EXPECTED,
            "deck_chip": "chaos",
            "voting_seconds": 45,
        }

    def test_no_timer_is_written_and_the_doppelganger_window_is_left_alone(
        self, db
    ) -> None:
        written = self.create(defaults="v2").data["settings"]

        assert not [
            key
            for key in written
            if key.endswith("_seconds") and key != "card_look_seconds"
        ]
        assert set(written) == {
            "card_look_seconds",
            "deck",
            "deck_chip",
        }

    def test_nothing_is_written_unless_the_body_asks(self, db) -> None:
        reply = self.create(settings={"voting_seconds": 45})

        assert reply.status_code == status.HTTP_201_CREATED
        assert reply.data["settings"] == {"voting_seconds": 45}
        assert self.create().data["settings"] == {}

    @pytest.mark.parametrize("name", ["v1", "", None, 2, ["v2"], "V2"])
    def test_an_unknown_name_is_refused(self, db, name) -> None:
        reply = self.create(defaults=name)

        assert reply.status_code == status.HTTP_400_BAD_REQUEST
        assert reply.data["code"] == "bad_request"

    def test_the_defaults_are_valid_where_untimed_nights_are_not_allowed(
        self, db, settings
    ) -> None:
        settings.ONUW_ALLOW_UNTIMED_NIGHT = False
        reply = self.create(defaults="v2")

        assert (
            validate_onuw_settings(reply.data["settings"], 5, allow_untimed=False) == []
        )

    def test_a_table_made_with_the_defaults_plays_from_the_deal_to_the_night(
        self, db, settings
    ) -> None:
        settings.DEBUG = True
        table = Table(players=5)
        # A lobby made the way the new screens make it.
        from apps.core.models import Lobby

        reply = self.create(defaults="v2")
        lobby = Lobby.objects.get(code=reply.data["code"])
        # Move the table's members into it by re-pointing the Table at it.
        Lobby.objects.filter(code=table.code).update(settings=lobby.settings)

        game = Game.objects.get(id=table.start().data["game_id"])

        assert "night_protocol" not in game.settings  # the old night's flag is gone
        assert (game.phase, game.current_wave) == ("night", 0)  # the look stage
        assert dealt_roles(game) == DECK_TABLE[(5, "simple")]
