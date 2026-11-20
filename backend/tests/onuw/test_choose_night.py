"""
Night protocol 2: every phone sends one ``choose``.

``settings["night_protocol"] == 2`` turns the night into this: ``POST .../action/``
takes ``{"action_type": "choose", "picks": [0 to 2 picks]}`` from EVERY phone,
whatever it was dealt; the server reads the picks per role, answers every phone
alike, sends one group event per window, and each phone reads its own prompt and
results from ``GET /me/``. Games without that setting keep the original night (the
rest of the suite).

All through the real API with seat order different from user-id order (``Night``).
"""

from typing import Any

from django.urls import reverse

import pytest
from rest_framework import status

from apps.onuw import services
from apps.onuw.models import Game, Phase, PlayerRole
from tests.onuw.test_night_windows import Night
from tests.onuw.test_presence import drop

pytestmark = pytest.mark.integration

CENTER = ["Villager", "Tanner", "Hunter"]

# Ten players, every window-2 role that has something to look at or choose.
TEN = {
    "wolf1": "Werewolf",
    "wolf2": "Werewolf",
    "minion": "Minion",
    "mason1": "Mason",
    "mason2": "Mason",
    "seer": "Seer",
    "robber": "Robber",
    "trouble": "Troublemaker",
    "drunk": "Drunk",
    "insomniac": "Insomniac",
}
# A lone Werewolf and the roles with nothing to do at night.
LONE = {
    "wolf": "Werewolf",
    "seer": "Seer",
    "villager": "Villager",
    "hunter": "Hunter",
    "tanner": "Tanner",
}
# A Doppelganger table.
DOPPEL = {
    "dop": "Doppelganger",
    "seer": "Seer",
    "wolf": "Werewolf",
    "villager": "Villager",
    "drunk": "Drunk",
}


@pytest.fixture
def make_p2(make_night):
    """A Night that plays protocol 2 (window 1, if any, is a fixed 15 s)."""

    def factory(roles, center=None, **settings) -> Night:
        merged = {
            "night_protocol": 2,
            "night_wave_seconds": 60,
            "night_doppelganger_window_seconds": 15,
            **settings,
        }
        return make_night(roles, center or CENTER, **merged)

    return factory


def pid(night: Night, name: str) -> int:
    return night.users[name].id


def player(night: Night, name: str) -> dict[str, int]:
    return {"player_id": pid(night, name)}


def center(index: int) -> dict[str, int]:
    return {"center_index": index}


SELF = {"self": True}


def choose(night: Night, who: str, picks: Any = None, **body: Any) -> Any:
    night.client.force_authenticate(user=night.users[who])
    payload = {"action_type": "choose", "picks": [] if picks is None else picks}
    payload.update(body)
    with night.committed():
        return night.client.post(
            reverse("onuw:night-action", kwargs={"game_id": str(night.game.id)}),
            payload,
            format="json",
        )


def raw_post(night: Night, who: str, body: Any) -> Any:
    night.client.force_authenticate(user=night.users[who])
    with night.committed():
        return night.client.post(
            reverse("onuw:night-action", kwargs={"game_id": str(night.game.id)}),
            body,
            format="json",
        )


def me(night: Night, name: str) -> dict[str, Any]:
    night.client.force_authenticate(user=night.users[name])
    response = night.client.get(
        reverse("onuw:game-me", kwargs={"game_id": str(night.game.id)})
    )
    assert response.status_code == status.HTTP_200_OK
    return response.data


def results(night: Night, name: str) -> list[dict[str, Any]]:
    return me(night, name)["night_results"]


def log_entry(night: Night, name: str, role_acting_as: str | None = None) -> dict:
    """The player's first night-log entry (optionally as one role)."""
    return next(
        e
        for e in night.refresh().night_actions_log
        if e["player_id"] == pid(night, name)
        and role_acting_as in (None, e["role_acting_as"])
    )


def everyone_chooses(night: Night, picks: dict[str, Any] | None = None) -> None:
    """Every player chooses once (``picks`` by name; nothing for the rest)."""
    for name in night.users:
        choose(night, name, (picks or {}).get(name, []))


def finish_window_two(night: Night, picks: dict[str, Any] | None = None) -> None:
    everyone_chooses(night, picks)
    assert night.refresh().phase == Phase.DISCUSSION


# ── a window opens ───────────────────────────────────────────────────────────


class TestOpening:
    def test_a_window_opens_with_one_group_event_and_nothing_per_player(
        self, make_p2
    ) -> None:
        night = make_p2(TEN)

        night.start()

        assert night.game.current_wave == 2
        assert night.recorder.events == [
            (
                f"game_{night.game.id}",
                {
                    "type": "night.window",
                    "window": 2,
                    "deadline": night.game.phase_deadline.isoformat(),
                },
            )
        ]

    def test_a_whole_night_with_a_doppelganger_sends_nothing_per_player(
        self, make_p2
    ) -> None:
        night = make_p2(DOPPEL)
        night.start()
        choose(night, "dop", [player(night, "seer")])
        choose(night, "dop", [player(night, "wolf")])
        night.fire_timer(1)  # window 1's fixed length ends
        finish_window_two(night)

        assert [
            (group, event["type"])
            for group, event in night.recorder.events
            if "_player_" in group
        ] == []
        # What the table does hear is role-free.
        assert [e["type"] for _, e in night.recorder.events] == [
            "night.window",
            "wave.complete",
            "night.window",
            "wave.complete",
            "phase.change",
            "progress",
        ]

    def test_the_doppelganger_window_comes_first_and_is_fixed(self, make_p2) -> None:
        night = make_p2(DOPPEL)

        night.start()

        assert night.game.current_wave == 1
        assert night.timer_delays(1) == [15]
        # Everyone choosing does not close a fixed window.
        for name in night.users:
            choose(night, name)
            choose(night, name)
        assert night.refresh().current_wave == 1

    def test_the_legacy_events_are_not_sent(self, make_p2) -> None:
        night = make_p2(TEN)
        night.start()

        kinds = {e["type"] for _, e in night.recorder.events}

        assert kinds.isdisjoint({"wave.start", "action.prompt", "wave.waiting"})

    def test_the_consumer_has_a_handler_for_the_new_event(self) -> None:
        from apps.onuw.consumers import GameConsumer

        assert hasattr(GameConsumer, "night_window")


# ── the prompt in GET /me/ ───────────────────────────────────────────────────


class TestPrompts:
    KINDS = {
        "wolf1": "none",
        "wolf2": "none",
        "minion": "none",
        "mason1": "none",
        "mason2": "none",
        "seer": "seer",
        "robber": "robber",
        "trouble": "troublemaker",
        "drunk": "drunk",
        "insomniac": "none",
    }

    def test_every_player_has_a_prompt_with_the_right_instruction(
        self, make_p2
    ) -> None:
        night = make_p2(TEN)
        night.start()

        kinds = {name: me(night, name)["action_prompt"]["kind"] for name in TEN}

        assert kinds == self.KINDS

    def test_prompts_have_one_shape_and_one_board(self, make_p2) -> None:
        night = make_p2(TEN)
        night.start()

        prompts = {name: me(night, name)["action_prompt"] for name in TEN}

        assert len({tuple(sorted(p)) for p in prompts.values()}) == 1
        for name, prompt in prompts.items():
            assert prompt["window"] == 2
            assert prompt["action_types"] == ["choose"]
            assert prompt["max_picks"] == 2
            assert prompt["max_chooses"] == 1
            assert prompt["chosen"] == 0
            assert prompt["role_acting_as"] == TEN[name]
            assert prompt["valid_targets"]["center_indices"] == [0, 1, 2]
            others = prompt["valid_targets"]["player_ids"]
            assert sorted(others) == sorted(pid(night, n) for n in TEN if n != name)

    def test_a_pack_has_no_teammates_in_its_prompt(self, make_p2) -> None:
        night = make_p2(TEN)
        night.start()

        for name in ("wolf1", "minion", "mason1"):
            text = repr(me(night, name)["action_prompt"])
            assert "teammate" not in text and "see_team" not in text

    def test_a_lone_werewolf_is_told_its_real_option(self, make_p2) -> None:
        night = make_p2(LONE)
        night.start()

        prompt = me(night, "wolf")["action_prompt"]

        assert prompt["kind"] == "lone_werewolf"
        assert prompt["valid_targets"]["center_indices"] == [0, 1, 2]
        assert me(night, "villager")["action_prompt"]["kind"] == "none"

    def test_the_prompt_counts_the_callers_own_chooses(self, make_p2) -> None:
        night = make_p2(TEN)
        night.start()

        choose(night, "seer", [center(0), center(1)])

        assert me(night, "seer")["action_prompt"]["chosen"] == 1
        assert me(night, "robber")["action_prompt"]["chosen"] == 0

    def test_there_is_no_prompt_between_windows_or_after_the_night(
        self, make_p2
    ) -> None:
        night = make_p2(TEN)
        night.start()
        finish_window_two(night)

        assert all(me(night, name)["action_prompt"] is None for name in TEN)

    def test_the_doppelganger_reads_a_look_prompt_then_the_followup(
        self, make_p2
    ) -> None:
        night = make_p2(DOPPEL)
        night.start()
        assert me(night, "dop")["action_prompt"]["kind"] == "doppelganger_look"
        assert me(night, "villager")["action_prompt"]["kind"] == "none"

        choose(night, "dop", [player(night, "seer")])

        after = me(night, "dop")["action_prompt"]
        assert after["kind"] == "seer"
        assert after["chosen"] == 1
        assert after["max_chooses"] == 2
        assert me(night, "seer")["action_prompt"]["kind"] == "none"  # not her window

    def test_the_prompt_is_the_same_on_every_game_in_protocol_one(
        self, make_night
    ) -> None:
        night = make_night(TEN, CENTER, night_wave_seconds=60)  # no night_protocol
        night.start()

        body = me(night, "villager" if "villager" in TEN else "wolf1")

        assert body["action_prompt"]["action_types"] != ["choose"]


# ── every phone gets the same answer ─────────────────────────────────────────


PICK_LISTS = [
    [],
    [SELF],
    [{"center_index": 0}],
    [{"center_index": 0}, {"center_index": 2}],
    [{"player_id": "OTHER"}],
    [{"player_id": "OTHER"}, {"player_id": "OTHER2"}],
    [{"player_id": "OTHER"}, {"center_index": 1}],
]


def concrete(night: Night, picks: list[dict[str, Any]], who: str) -> list[dict]:
    others = [name for name in night.users if name != who]
    swap = {"OTHER": others[0], "OTHER2": others[1]}
    return [
        {"player_id": pid(night, swap[p["player_id"]])}
        if p.get("player_id") in swap
        else p
        for p in picks
    ]


class TestIdenticalAnswers:
    @pytest.mark.parametrize("picks", PICK_LISTS, ids=repr)
    def test_every_choose_gets_the_same_bytes_for_every_role(
        self, make_p2, picks
    ) -> None:
        night = make_p2(TEN)
        night.start()

        replies = {
            name: choose(night, name, concrete(night, picks, name)) for name in TEN
        }

        assert {r.status_code for r in replies.values()} == {status.HTTP_200_OK}
        assert {r.content for r in replies.values()} == {b'{"status":"submitted"}'}

    @pytest.mark.parametrize(
        "table",
        [
            TEN,
            LONE,
            DOPPEL,
            {
                "dop": "Doppelganger",
                "m": "Minion",
                "ma": "Mason",
                "mb": "Mason",
                "h": "Hunter",
            },
            {
                "dop": "Doppelganger",
                "i": "Insomniac",
                "t": "Troublemaker",
                "d": "Drunk",
                "x": "Tanner",
            },
        ],
        ids=[
            "ten",
            "lone",
            "doppelganger-seer",
            "doppelganger-minion",
            "doppelganger-misc",
        ],
    )
    def test_every_role_and_copy_is_answered_alike(self, make_p2, table) -> None:
        """All twelve roles, and a Doppelganger beside each kind of role she may copy:
        whatever the phone holds, its choose gets the same bytes."""
        night = make_p2(table)
        night.start()
        chooses = 2 if night.game.current_wave == 1 else 1

        contents = {
            choose(night, name, [SELF]).content
            for name in table
            for _ in range(chooses)
        }

        assert contents == {b'{"status":"submitted"}'}

    def test_a_second_choose_in_window_two_is_the_same_409_for_everyone(
        self, make_p2
    ) -> None:
        table = {
            "w": "Werewolf",
            "s": "Seer",
            "v": "Villager",
            "r": "Robber",
            "t": "Tanner",
        }
        night = make_p2(table)
        night.start()
        for name in ("s", "v", "w"):  # the window stays open: r and t have not chosen
            choose(night, name, [SELF])

        replies = [choose(night, name, [SELF]) for name in ("s", "v", "w")]

        assert {r.status_code for r in replies} == {status.HTTP_409_CONFLICT}
        assert {r.content for r in replies} == {
            b'{"detail":"You have already chosen.","code":"already_chosen"}'
        }

    def test_window_one_takes_two_chooses_from_every_phone_and_refuses_a_third(
        self, make_p2
    ) -> None:
        night = make_p2(DOPPEL)
        night.start()

        for name in DOPPEL:
            assert choose(night, name, []).status_code == status.HTTP_200_OK
            assert choose(night, name, [SELF]).status_code == status.HTTP_200_OK
        third = {name: choose(night, name, []) for name in DOPPEL}

        assert {r.status_code for r in third.values()} == {status.HTTP_409_CONFLICT}
        assert len({r.content for r in third.values()}) == 1
        assert night.refresh().current_wave == 1

    @pytest.mark.parametrize(
        "body",
        [
            {"action_type": "choose"},
            {"action_type": "choose", "picks": "x"},
            {"action_type": "choose", "picks": {}},
            {"action_type": "choose", "picks": [{}]},
            {"action_type": "choose", "picks": [{"player_id": 999999}]},
            {"action_type": "choose", "picks": [{"center_index": 3}]},
            {"action_type": "choose", "picks": [{"center_index": "0"}]},
            {"action_type": "choose", "picks": [{"self": 1}]},
            {"action_type": "choose", "picks": [SELF, SELF]},
            {"action_type": "choose", "picks": [SELF, SELF, SELF]},
            {"action_type": "skip", "picks": []},
            {"action_type": "peek_player", "targets": {}},
            {"action_type": None, "picks": []},
            {"picks": []},
            [],
            "choose",
        ],
        ids=repr,
    )
    def test_a_malformed_request_is_the_same_400_for_everyone(
        self, make_p2, body
    ) -> None:
        night = make_p2(TEN)
        night.start()

        replies = {name: raw_post(night, name, body) for name in TEN}

        assert {r.status_code for r in replies.values()} == {
            status.HTTP_400_BAD_REQUEST
        }
        assert len({r.content for r in replies.values()}) == 1
        assert all(r.data["code"] == "bad_request" for r in replies.values())
        assert not PlayerRole.objects.filter(game=night.game, has_acted=True).exists()

    def test_outside_a_window_everyone_gets_the_same_wrong_phase(self, make_p2) -> None:
        night = make_p2(TEN)
        night.start()
        finish_window_two(night)

        replies = {name: choose(night, name, []) for name in TEN}

        assert {r.status_code for r in replies.values()} == {
            status.HTTP_400_BAD_REQUEST
        }
        assert len({r.content for r in replies.values()}) == 1
        assert all(r.data["code"] == "wrong_phase" for r in replies.values())

    def test_a_stranger_is_refused(self, make_p2, django_user_model) -> None:
        night = make_p2(TEN)
        night.start()
        stranger = django_user_model.objects.create_user(
            username="nobody", password="x"
        )
        night.client.force_authenticate(user=stranger)

        response = night.client.post(
            reverse("onuw:night-action", kwargs={"game_id": str(night.game.id)}),
            {"action_type": "choose", "picks": []},
            format="json",
        )

        assert response.status_code == status.HTTP_403_FORBIDDEN

    def test_a_pick_that_means_nothing_for_the_role_is_not_an_error(
        self, make_p2
    ) -> None:
        night = make_p2(TEN)
        night.start()

        # A Seer who taps only herself, a wolf who taps a centre card in a pack.
        assert choose(night, "seer", [SELF]).status_code == status.HTTP_200_OK
        assert choose(night, "wolf1", [center(0)]).status_code == status.HTTP_200_OK
        assert choose(night, "insomniac", [player(night, "seer")]).status_code == 200

    def test_a_choose_in_the_look_stage_is_wrong_phase(self, make_p2) -> None:
        night = make_p2(TEN, card_look_seconds=30)
        with night.committed():
            services.begin_night(night.game)
        night.refresh()
        assert night.game.current_wave == 0

        response = choose(night, "seer", [])

        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert response.data["code"] == "wrong_phase"


# ── what the picks mean ──────────────────────────────────────────────────────


class TestReadingsThroughTheNight:
    def test_a_seer_looks_at_the_first_other_player(self, make_p2) -> None:
        night = make_p2(TEN)
        night.start()
        finish_window_two(
            night,
            {"seer": [SELF, player(night, "wolf1")]},
        )

        (result,) = results(night, "seer")

        assert result["action_type"] == "peek_player"
        assert result["revealed_info"]["role"] == "Werewolf"
        assert result["revealed_info"]["target_name"] == night.users["wolf1"].username

    def test_a_seer_looks_at_two_centre_cards(self, make_p2) -> None:
        night = make_p2(TEN)
        night.start()
        finish_window_two(night, {"seer": [center(2), center(0)]})

        (result,) = results(night, "seer")

        assert result["action_type"] == "peek_center"
        assert result["revealed_info"]["roles"] == ["Hunter", "Villager"]

    def test_a_seer_who_picks_nothing_valid_sees_nothing(self, make_p2) -> None:
        night = make_p2(TEN)
        night.start()
        finish_window_two(night, {"seer": [center(1), SELF]})

        assert results(night, "seer") == []
        skipped = [
            e
            for e in night.refresh().night_actions_log
            if e["player_id"] == pid(night, "seer")
        ]
        assert [e["action_type"] for e in skipped] == ["skip"]

    def test_a_robber_swaps_with_the_first_other_player_and_sees_the_new_card(
        self, make_p2
    ) -> None:
        night = make_p2(TEN)
        night.start()
        finish_window_two(night, {"robber": [player(night, "seer")]})

        (result,) = results(night, "robber")

        assert result["action_type"] == "swap_with_player"
        assert result["revealed_info"]["new_role"] == "Seer"
        assert night.role_of("robber").current_role == "Seer"
        assert night.role_of("seer").current_role == "Robber"

    def test_a_robber_who_picks_only_cards_that_do_not_count_swaps_nothing(
        self, make_p2
    ) -> None:
        night = make_p2(TEN)
        night.start()
        finish_window_two(night, {"robber": [center(0), SELF]})

        assert results(night, "robber") == []
        assert night.role_of("robber").current_role == "Robber"

    def test_a_troublemaker_swaps_two_other_players(self, make_p2) -> None:
        night = make_p2(TEN)
        night.start()
        finish_window_two(
            night, {"trouble": [player(night, "seer"), player(night, "drunk")]}
        )

        # The two cards changed hands (the Drunk's own later swap is with the centre).
        assert night.role_of("seer").current_role == "Drunk"

    def test_a_troublemaker_with_one_player_and_a_centre_card_swaps_nothing(
        self, make_p2
    ) -> None:
        night = make_p2(TEN)
        night.start()
        finish_window_two(night, {"trouble": [player(night, "seer"), center(0)]})

        assert night.role_of("seer").current_role == "Seer"
        assert night.role_of("drunk").current_role in (
            "Drunk",
            "Villager",
            "Tanner",
            "Hunter",
        )

    def test_a_drunk_swaps_with_the_first_centre_card(self, make_p2) -> None:
        night = make_p2(TEN)
        night.start()
        finish_window_two(night, {"drunk": [player(night, "seer"), center(2)]})

        assert night.role_of("drunk").current_role == "Hunter"
        assert night.refresh().center_cards[2] == "Drunk"
        assert not log_entry(night, "drunk").get("made_by_server", False)

    def test_a_drunk_who_keeps_their_card_is_swapped_by_the_server(
        self, make_p2
    ) -> None:
        night = make_p2(TEN)
        night.start()
        finish_window_two(night, {"drunk": [SELF]})

        expected = services.drunk_timeout_center_index(
            night.game.random_seed, pid(night, "drunk"), 3
        )
        entry = log_entry(night, "drunk")
        assert entry["action_type"] == "swap_with_center"
        assert entry["targets"] == {"center_index": expected}
        assert entry["made_by_server"] is True
        assert night.role_of("drunk").current_role == CENTER[expected]

    def test_a_lone_werewolf_looks_at_the_first_centre_card(self, make_p2) -> None:
        night = make_p2(LONE, ["Villager", "Robber", "Tanner"])
        night.start()
        finish_window_two(night, {"wolf": [center(1), center(2)]})

        (result,) = results(night, "wolf")

        assert result["action_type"] == "see_team"
        assert result["revealed_info"]["teammate_names"] == []
        assert result["revealed_info"]["center_card"] == {"index": 1, "role": "Robber"}

    def test_a_lone_werewolf_with_no_centre_pick_still_learns_it_is_alone(
        self, make_p2
    ) -> None:
        night = make_p2(LONE)
        night.start()
        finish_window_two(night, {"wolf": [player(night, "seer")]})

        (result,) = results(night, "wolf")

        assert result["revealed_info"]["teammate_names"] == []
        assert "center_card" not in result["revealed_info"]

    def test_a_pack_werewolf_cannot_look_at_the_centre_and_still_sees_the_pack(
        self, make_p2
    ) -> None:
        night = make_p2(TEN)
        night.start()
        finish_window_two(night, {"wolf1": [center(0)]})

        (result,) = results(night, "wolf1")

        assert result["revealed_info"]["teammate_names"] == [
            night.users["wolf2"].username
        ]
        assert "center_card" not in result["revealed_info"]

    def test_automatic_results_happen_whatever_the_phone_picked(self, make_p2) -> None:
        night = make_p2(TEN)
        night.start()
        finish_window_two(night, {"minion": [SELF], "insomniac": [center(0)]})

        (minion,) = results(night, "minion")
        (insomniac,) = results(night, "insomniac")
        (mason,) = results(night, "mason1")

        assert sorted(minion["revealed_info"]["teammate_names"]) == sorted(
            night.users[n].username for n in ("wolf1", "wolf2")
        )
        assert insomniac["revealed_info"]["current_role"] == "Insomniac"
        assert mason["revealed_info"]["teammate_names"] == [
            night.users["mason2"].username
        ]

    def test_a_player_with_nothing_to_do_has_no_results(self, make_p2) -> None:
        night = make_p2(LONE)
        night.start()
        finish_window_two(night, {"villager": [player(night, "seer")]})

        for name in ("villager", "hunter", "tanner"):
            assert results(night, name) == []

    def test_a_player_who_never_chooses_gets_the_role_default(self, make_p2) -> None:
        night = make_p2(TEN)
        night.start()
        for name in TEN:
            if name != "drunk":
                choose(night, name, [])
        assert night.refresh().phase == Phase.NIGHT  # still waiting for the Drunk

        night.fire_timer(2)  # the deadline

        assert night.game.phase == Phase.DISCUSSION
        assert log_entry(night, "drunk")["made_by_server"] is True

    def test_role_names_are_canonical_not_lowercase(self, make_p2) -> None:
        night = make_p2(TEN)
        night.start()
        finish_window_two(
            night,
            {
                "seer": [player(night, "robber")],
                "robber": [player(night, "wolf1")],
            },
        )

        assert results(night, "seer")[0]["revealed_info"]["role"] == "Robber"
        assert results(night, "robber")[0]["revealed_info"]["new_role"] == "Werewolf"
        assert (
            results(night, "insomniac")[0]["revealed_info"]["current_role"]
            == "Insomniac"
        )

    def test_protocol_one_still_lowercases(self, make_night) -> None:
        night = make_night(
            {"seer": "Seer", "wolf": "Werewolf", "robber": "Robber", "v": "Villager"},
            CENTER,
            night_wave_seconds=60,
        )
        night.start()
        night.post("seer", "peek_player", {"player_id": pid(night, "wolf")})
        night.post("robber", "skip")
        night.post("wolf", "see_team")

        assert results(night, "seer")[0]["revealed_info"]["role"] == "werewolf"


# ── the Doppelganger's window ────────────────────────────────────────────────


class TestWindowOne:
    def test_her_first_choose_is_the_look_and_it_is_resolved_at_once(
        self, make_p2
    ) -> None:
        night = make_p2(DOPPEL)
        night.start()

        choose(night, "dop", [player(night, "wolf")])

        # While window 1 is still open her phone can read the look.
        assert night.refresh().current_wave == 1
        (look,) = results(night, "dop")
        assert look["wave"] == 1
        assert look["action_type"] == "peek_player"
        assert look["revealed_info"]["role"] == "Werewolf"
        assert look["revealed_info"]["copied_role"] == "Werewolf"
        assert (
            night.role_of("dop").current_role == "Doppelganger"
        )  # copying is not a swap
        # Nobody else sees anything.
        assert all(results(night, n) == [] for n in DOPPEL if n != "dop")

    def test_her_look_can_be_acknowledged_once_it_is_shown(self, make_p2) -> None:
        night = make_p2(DOPPEL)
        night.start()
        choose(night, "dop", [player(night, "wolf")])
        night.client.force_authenticate(user=night.users["dop"])

        reply = night.client.post(
            reverse("onuw:night-results-seen", kwargs={"game_id": str(night.game.id)}),
            {"seen": 1},
            format="json",
        )

        assert reply.data == {"night_results_seen": 1}

    def test_the_followup_is_read_as_the_copied_role_and_resolves_at_the_close(
        self, make_p2
    ) -> None:
        night = make_p2(DOPPEL)
        night.start()
        choose(night, "dop", [player(night, "seer")])  # copies the Seer
        choose(night, "dop", [center(0), center(1)])  # her follow-up: look at two

        assert len(results(night, "dop")) == 1  # the follow-up waits for the close
        night.fire_timer(1)

        looks = results(night, "dop")
        assert [r["action_type"] for r in looks] == ["peek_player", "peek_center"]
        assert looks[1]["revealed_info"]["roles"] == ["Villager", "Tanner"]
        assert night.game.current_wave == 2

    def test_a_followup_with_no_choice_runs_automatically(self, make_p2) -> None:
        night = make_p2(
            {
                "dop": "Doppelganger",
                "minion": "Minion",
                "wolf": "Werewolf",
                "v": "Villager",
                "s": "Seer",
            }
        )
        night.start()
        choose(night, "dop", [player(night, "minion")])
        choose(night, "dop", [])
        night.fire_timer(1)

        assert [r["action_type"] for r in results(night, "dop")] == [
            "peek_player",
            "see_team",
        ]

    def test_a_copied_drunk_must_swap_even_if_she_picked_nothing(self, make_p2) -> None:
        night = make_p2(DOPPEL)
        night.start()
        choose(night, "dop", [player(night, "drunk")])
        choose(night, "dop", [SELF])
        night.fire_timer(1)

        assert log_entry(night, "dop", "Drunk")["made_by_server"] is True

    def test_a_copied_werewolf_acts_in_window_two(self, make_p2) -> None:
        night = make_p2(DOPPEL)
        night.start()
        choose(night, "dop", [player(night, "wolf")])
        choose(night, "dop", [])
        night.fire_timer(1)
        assert night.game.current_wave == 2
        assert me(night, "dop")["action_prompt"]["kind"] == "none"  # a pack of two

        finish_window_two(night)

        types = [r["action_type"] for r in results(night, "dop")]
        assert types == ["peek_player", "see_team"]
        assert results(night, "dop")[1]["revealed_info"]["teammate_names"] == [
            night.users["wolf"].username
        ]

    def test_a_copied_werewolf_makes_a_pack_of_two_so_neither_is_alone(
        self, make_p2
    ) -> None:
        night = make_p2(
            {
                "dop": "Doppelganger",
                "w": "Werewolf",
                "v": "Villager",
                "s": "Seer",
                "t": "Tanner",
            }
        )
        night.start()
        choose(night, "dop", [player(night, "w")])
        night.fire_timer(1)

        # Two werewolves now: neither is lone.
        assert me(night, "dop")["action_prompt"]["kind"] == "none"
        assert me(night, "w")["action_prompt"]["kind"] == "none"

    def test_a_look_that_picks_no_other_player_copies_nothing(self, make_p2) -> None:
        night = make_p2(DOPPEL)
        night.start()
        choose(night, "dop", [SELF])
        choose(night, "dop", [center(0)])
        night.fire_timer(1)

        assert results(night, "dop") == []
        assert "copied_role" not in night.role_of("dop").night_action_data
        assert night.game.current_wave == 2

    def test_a_second_look_attempt_is_still_a_look_when_the_first_found_nothing(
        self, make_p2
    ) -> None:
        night = make_p2(DOPPEL)
        night.start()
        choose(night, "dop", [])
        choose(night, "dop", [player(night, "seer")])

        assert results(night, "dop")[0]["revealed_info"]["copied_role"] == "Seer"

    def test_a_player_who_is_not_the_doppelganger_chooses_twice_to_no_effect(
        self, make_p2
    ) -> None:
        night = make_p2(DOPPEL)
        night.start()
        choose(night, "seer", [player(night, "wolf")])
        choose(night, "seer", [player(night, "villager")])
        night.fire_timer(1)

        assert results(night, "seer") == []
        assert night.role_of("seer").current_role == "Seer"

    def test_with_the_fixed_length_off_window_one_waits_for_every_phone_twice(
        self, make_night
    ) -> None:
        night = make_night(
            DOPPEL, CENTER, night_protocol=2, night_wave_seconds=60
        )  # night_doppelganger_window_seconds = 0 (the make_night default)
        night.start()
        for name in DOPPEL:
            choose(night, name)
            assert night.refresh().current_wave == 1
        for name in list(DOPPEL)[:-1]:
            choose(night, name)
            assert night.refresh().current_wave == 1

        choose(night, list(DOPPEL)[-1])

        assert night.refresh().current_wave == 2


# ── when window two closes ───────────────────────────────────────────────────


class TestWindowTwoClose:
    def test_the_window_waits_for_every_phone_including_the_sleepers(
        self, make_p2
    ) -> None:
        night = make_p2(LONE)
        night.start()

        for name in ("wolf", "seer", "hunter", "tanner"):
            choose(night, name)
            assert night.refresh().current_wave == 2
        choose(night, "villager")  # a sleeper holds the window like anyone

        assert night.refresh().phase == Phase.DISCUSSION

    def test_it_is_never_closed_before_the_minimum_length(self, make_p2) -> None:
        night = make_p2(LONE, night_min_window_seconds=8)
        night.start()
        night.pretend_window_opened(3)

        everyone_chooses(night)

        assert night.refresh().phase == Phase.NIGHT
        (delay,) = night.timer_delays(2)[-1:]
        assert 4 < delay <= 5.5  # 8 s from the open, 3 s have passed

    def test_the_deadline_closes_it_with_the_defaults(self, make_p2) -> None:
        night = make_p2(LONE)
        night.start()
        choose(night, "wolf", [center(0)])

        night.fire_timer(2)

        assert night.game.phase == Phase.DISCUSSION
        assert results(night, "wolf")[0]["revealed_info"]["center_card"]["index"] == 0

    def test_a_phone_gone_past_the_grace_period_is_not_waited_for(
        self, make_p2
    ) -> None:
        night = make_p2(LONE)
        night.start()
        drop(night, "tanner", seconds_ago=60)

        for name in ("wolf", "seer", "hunter"):
            choose(night, name)
        assert night.refresh().phase == Phase.NIGHT

        choose(night, "villager")

        assert night.refresh().phase == Phase.DISCUSSION

    def test_a_phone_inside_the_grace_period_still_holds_the_window(
        self, make_p2
    ) -> None:
        night = make_p2(LONE)
        night.start()
        drop(night, "tanner", seconds_ago=5)

        for name in ("wolf", "seer", "hunter", "villager"):
            choose(night, name)

        assert night.refresh().phase == Phase.NIGHT

    def test_the_host_can_close_it_and_a_stale_tap_cannot(self, make_p2) -> None:
        night = make_p2(LONE)
        night.start()
        night.client.force_authenticate(user=night.host)

        stale = night.client.post(
            reverse("onuw:wave-advance", kwargs={"game_id": str(night.game.id)}),
            {"from_window": 1},
            format="json",
        )
        ok = night.host_close_window()

        assert stale.status_code == status.HTTP_409_CONFLICT
        assert ok.status_code == status.HTTP_200_OK
        assert night.refresh().phase == Phase.DISCUSSION

    def test_close_time_does_not_depend_on_roles(self, make_p2) -> None:
        """Same taps at the same times, different roles: the same close. Nothing a
        player can watch (a window that closes sooner, a deferred close that is
        scheduled or not) says who had something to choose."""
        a = make_p2(
            {
                "a1": "Werewolf",
                "a2": "Seer",
                "a3": "Villager",
                "a4": "Robber",
                "a5": "Tanner",
            },
            night_min_window_seconds=8,
        )
        b = make_p2(
            {
                "b1": "Villager",
                "b2": "Tanner",
                "b3": "Hunter",
                "b4": "Werewolf",
                "b5": "Insomniac",
            },
            night_min_window_seconds=8,
        )
        for night in (a, b):
            night.start()
            night.pretend_window_opened(3)
        names = {a: list(a.users), b: list(b.users)}

        # Four of five have chosen: neither closes, neither has anything scheduled
        # beyond the deadline.
        for night in (a, b):
            for name in names[night][:4]:
                choose(night, name, [SELF])
            assert night.refresh().phase == Phase.NIGHT
        assert len(a.timer_delays(2)) == len(b.timer_delays(2)) == 1

        # The last tap defers the close to the same moment.
        for night in (a, b):
            choose(night, names[night][4], [SELF])
        assert len(a.timer_delays(2)) == len(b.timer_delays(2)) == 2
        assert a.timer_delays(2)[-1] == pytest.approx(b.timer_delays(2)[-1], abs=0.5)
        assert a.refresh().phase == b.refresh().phase == Phase.NIGHT


# ── what a table can observe ─────────────────────────────────────────────────


class TestNightUniformity:
    @pytest.mark.parametrize("roles", [TEN, DOPPEL], ids=["plain", "doppelganger"])
    def test_every_seat_sees_the_same_events_and_answers_in_every_window(
        self, make_p2, roles
    ) -> None:
        """A seeded table played through every window, every seat choosing: the
        events (their types, and who they go to) and the answer to every POST are
        the same whatever a seat was dealt. No seat has an event of its own."""
        night = make_p2(roles)
        night.start()
        answers: list[bytes] = []
        while night.refresh().phase == Phase.NIGHT:
            window = night.game.current_wave
            for name in night.users:
                for _ in range(2 if window == 1 else 1):
                    answers.append(choose(night, name, [SELF]).content)
            if (
                night.refresh().phase == Phase.NIGHT
                and night.game.current_wave == window
            ):
                night.fire_timer(window)  # a fixed window ends on its timer

        assert set(answers) == {b'{"status":"submitted"}'}
        # One group, and only the group: no seat has a channel of its own.
        assert {group for group, _ in night.recorder.events} == {
            f"game_{night.game.id}"
        }
        for name in roles:
            assert night.events_to(name) == []

    def test_get_me_has_the_same_keys_for_every_seat(self, make_p2) -> None:
        night = make_p2(TEN)
        night.start()

        shapes = {
            name: (
                tuple(sorted(me(night, name))),
                tuple(sorted(me(night, name)["action_prompt"])),
            )
            for name in TEN
        }

        assert len(set(shapes.values())) == 1

    def test_nothing_about_other_roles_is_in_a_seats_payloads(self, make_p2) -> None:
        night = make_p2(TEN)
        night.start()
        finish_window_two(night, {"seer": [player(night, "wolf1")]})
        # The sleeping Insomniac's page names no role but its own and its own card.
        text = repr(me(night, "insomniac"))
        for foreign in ("Seer", "Robber", "Troublemaker", "Drunk", "Minion", "Mason"):
            assert foreign not in text.replace("Insomniac", "")


# ── the setting ──────────────────────────────────────────────────────────────


class TestTheSetting:
    DECK = {
        "Werewolf": 2,
        "Seer": 1,
        "Robber": 1,
        "Villager": 3,
        "Drunk": 1,
        "Troublemaker": 1,
    }

    def errors(self, **extra: Any) -> list[str]:
        from apps.onuw.engine.validation import validate_onuw_settings

        return validate_onuw_settings(
            {"roles": self.DECK, **extra}, 6, allow_untimed=False
        )

    @pytest.mark.parametrize("value", [1, 2])
    def test_protocols_one_and_two_are_valid(self, value) -> None:
        assert self.errors(night_protocol=value) == []

    @pytest.mark.parametrize("value", [0, 3, "2", 2.0, True, None, [2]], ids=repr)
    def test_anything_else_is_refused(self, value) -> None:
        assert any("night_protocol" in e for e in self.errors(night_protocol=value))

    def test_a_server_that_does_not_allow_untimed_nights_refuses_zero_timers(
        self,
    ) -> None:
        for key in ("night_wave_seconds", "night_doppelganger_window_seconds"):
            errors = self.errors(night_protocol=2, **{key: 0})
            assert any(key in e for e in errors), key

    def test_and_a_minimum_window_under_five_seconds(self) -> None:
        assert any(
            "night_min_window_seconds" in e
            for e in self.errors(night_protocol=2, night_min_window_seconds=4)
        )
        assert self.errors(night_protocol=2, night_min_window_seconds=5) == []

    def test_protocol_one_keeps_every_old_timer_value(self) -> None:
        assert (
            self.errors(
                night_wave_seconds=0,
                night_min_window_seconds=0,
                night_doppelganger_window_seconds=0,
            )
            == []
        )

    def test_absent_timers_are_fine_under_protocol_two(self) -> None:
        assert self.errors(night_protocol=2) == []

    def test_the_deal_refuses_an_untimed_protocol_two_night_where_it_is_not_allowed(
        self, settings, db
    ) -> None:
        from apps.core.models import Lobby
        from tests.onuw.test_play_again import Table

        settings.DEBUG = True
        settings.ONUW_ALLOW_UNTIMED_NIGHT = False
        table = Table()  # its timers are all 0
        lobby = Lobby.objects.get(code=table.code)
        lobby.settings = {**lobby.settings, "night_protocol": 2}
        lobby.save()

        reply = table.start()

        assert reply.status_code == status.HTTP_400_BAD_REQUEST
        assert not Game.objects.filter(lobby__code=table.code).exists()

    def test_a_lobby_patch_refuses_it_too(self, settings, db) -> None:
        from tests.onuw.test_play_again import Table

        settings.ONUW_ALLOW_UNTIMED_NIGHT = False
        table = Table()

        reply = table.host.patch(
            reverse("core:lobby-detail", kwargs={"code": table.code}),
            {"settings": {"night_protocol": 2, "night_wave_seconds": 0}},
            format="json",
        )

        assert reply.status_code == status.HTTP_400_BAD_REQUEST

    def test_only_the_test_development_and_harness_settings_allow_untimed_nights(
        self,
    ) -> None:
        from config.settings import base, development, harness, test

        assert base.ONUW_ALLOW_UNTIMED_NIGHT is False
        assert development.ONUW_ALLOW_UNTIMED_NIGHT is True
        assert harness.ONUW_ALLOW_UNTIMED_NIGHT is True
        assert test.ONUW_ALLOW_UNTIMED_NIGHT is True

    def test_the_old_protocol_refuses_choose_as_it_always_did(self, make_night) -> None:
        night = make_night(LONE, CENTER, night_wave_seconds=60)
        night.start()

        response = choose(night, "seer", [])

        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert "code" not in response.data
