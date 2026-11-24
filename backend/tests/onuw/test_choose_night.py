"""
The night: every phone with a choice sends one ``choose``.

``POST .../action/`` takes ``{"action_type": "choose", "picks": [0 to 2 picks],
"chosen": n, "stage": <from /me/>}`` from EVERY phone, whatever it was dealt; the
server reads the picks per role, answers every phone alike, sends one group event per
window, and each phone reads its own prompt, stage and results from ``GET /me/``. A
request names the stage it was aimed at: one for a stage that is over is 409
``wrong_stage`` and stores nothing.

All through the real API with seat order different from user-id order (``Night``).
"""

from typing import Any

from django.urls import reverse

import pytest
from rest_framework import status

from apps.core.wire import public_name, wire_time
from apps.onuw import night_flow, night_window, turns
from apps.onuw.models import Game, Phase, PlayerRole
from tests.onuw.stages import current_stage, staged
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
    """A Night whose window 1 (if any) is a fixed 15 s."""

    def factory(roles, center=None, **settings) -> Night:
        merged = {
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
# A window-2 result that says "you chose, and nothing happened".
NOTHING_CHOSEN_W2 = [
    {"wave": 2, "action_type": "skip", "revealed_info": {"nothing_chosen": True}}
]


def chosen_now(night: Night, who: str) -> int:
    """What ``who``'s prompt says now (``action_prompt.chosen``): their count in the
    open window."""
    game = Game.objects.get(id=night.game.id)
    pr = PlayerRole.objects.get(game=game, user=night.users[who])
    return turns.chose_count(pr, game.current_wave)


def choose(night: Night, who: str, picks: Any = None, **body: Any) -> Any:
    """A choose the way a phone sends it: naming the CURRENT stage and answering the
    prompt as it is now (``chosen``); ``stage=`` / ``chosen=`` name others."""
    night.client.force_authenticate(user=night.users[who])
    payload = {"action_type": "choose", "picks": [] if picks is None else picks}
    payload.update(body)
    payload.setdefault("chosen", chosen_now(night, who))
    payload = staged(night, payload)
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
    """Each player sends one choose (``picks`` by name; nothing for the rest; a
    sleeper's is taken alike, one sent after the close is refused)."""
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
                    "deadline": wire_time(night.game.phase_deadline),
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
            "night.window",
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
        assert me(night, "seer")["action_prompt"]["chooses_left"] == 0
        assert me(night, "robber")["action_prompt"]["chooses_left"] == 1

    @pytest.mark.parametrize(
        ("copied", "left_after_look"),
        [
            ("Seer", 1),
            ("Robber", 1),
            ("Troublemaker", 1),
            ("Drunk", 1),
            ("Minion", 0),  # nothing to pick: she sends nothing more
            ("Werewolf", 0),  # acts in window 2
            ("Mason", 0),
            ("Insomniac", 0),
            ("Villager", 0),
        ],
    )
    def test_chooses_left_says_whose_turn_comes_again_only_to_her(
        self, make_p2, copied, left_after_look
    ) -> None:
        roles = {"dop": "Doppelganger", "target": copied, "a": "Villager", "b": "Seer"}
        if copied == "Mason":
            roles["b"] = "Mason"
        night = make_p2(roles)
        night.start()
        assert me(night, "dop")["action_prompt"]["chooses_left"] == 1
        choose(night, "dop", [player(night, "target")])

        assert me(night, "dop")["action_prompt"]["chooses_left"] == left_after_look
        if left_after_look:
            choose(night, "dop", [])
            assert me(night, "dop")["action_prompt"]["chooses_left"] == 0
        # Everyone else has nothing to choose in window 1: nothing to send, though
        # a choose from them is still taken (the same answer as anyone's).
        for name in ("target", "a", "b"):
            assert me(night, name)["action_prompt"]["chooses_left"] == 0
            choose(night, name, [])
            assert me(night, name)["action_prompt"]["chooses_left"] == 0
            assert me(night, name)["action_prompt"]["chosen"] == 1
            assert me(night, name)["action_prompt"]["max_chooses"] == 2

    def test_get_me_names_the_viewer(self, make_p2) -> None:
        night = make_p2(LONE)
        night.start()

        assert {name: me(night, name)["player_id"] for name in LONE} == {
            name: pid(night, name) for name in LONE
        }

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
        # A phone with nothing to choose sends nothing, but a choose from it is
        # still taken, answered alike. The table's minimum keeps the window open
        # for every seat's choose.
        night = make_p2(TEN, night_min_window_seconds=8)
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
        whatever the phone holds, its choose gets the same bytes (a phone with
        nothing to choose sends none, but one sent is taken alike; the table's
        minimum keeps the window open for all of them)."""
        night = make_p2(table, night_min_window_seconds=8)
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

    def test_a_late_choose_after_the_window_closed_is_the_same_wrong_stage_for_all(
        self, make_p2
    ) -> None:
        night = make_p2(TEN)
        night.start()
        window = current_stage(night.game.id)
        finish_window_two(night)

        replies = {name: choose(night, name, [], stage=window) for name in TEN}

        assert {r.status_code for r in replies.values()} == {status.HTTP_409_CONFLICT}
        assert len({r.content for r in replies.values()}) == 1
        assert all(r.data["code"] == "wrong_stage" for r in replies.values())

    def test_a_stranger_is_refused(self, make_p2, django_user_model) -> None:
        night = make_p2(TEN)
        night.start()
        stranger = django_user_model.objects.create_user(
            username="nobody", password="x"
        )
        night.client.force_authenticate(user=stranger)

        response = night.client.post(
            reverse("onuw:night-action", kwargs={"game_id": str(night.game.id)}),
            {
                "action_type": "choose",
                "picks": [],
                "chosen": 0,
                "stage": current_stage(night.game.id),
            },
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

    def test_a_choose_in_the_look_stage_is_wrong_stage(self, make_p2) -> None:
        night = make_p2(TEN, card_look_seconds=30)
        with night.committed():
            night_flow.begin_night(night.game)
        night.refresh()
        assert night.game.current_wave == 0

        response = choose(night, "seer", [])  # names the look's own stage

        assert response.status_code == status.HTTP_409_CONFLICT
        assert response.data["code"] == "wrong_stage"


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
        assert result["revealed_info"]["target_name"] == public_name(
            night.users["wolf1"]
        )

    def test_a_seer_looks_at_two_centre_cards(self, make_p2) -> None:
        night = make_p2(TEN)
        night.start()
        finish_window_two(night, {"seer": [center(2), center(0)]})

        (result,) = results(night, "seer")

        assert result["action_type"] == "peek_center"
        # Which centre cards, in the order of the roles (the order she tapped).
        assert result["revealed_info"] == {
            "roles": ["Hunter", "Villager"],
            "center_indices": [2, 0],
        }

    def test_a_seer_who_picks_nothing_valid_sees_nothing(self, make_p2) -> None:
        night = make_p2(TEN)
        night.start()
        finish_window_two(night, {"seer": [center(1), SELF]})

        # Told that the choice did nothing (not left to guess from a missing entry).
        assert results(night, "seer") == NOTHING_CHOSEN_W2
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

        assert results(night, "robber") == NOTHING_CHOSEN_W2
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

        expected = night_window.drunk_timeout_center_index(
            night.game.random_seed, pid(night, "drunk"), 3
        )
        entry = log_entry(night, "drunk")
        assert entry["action_type"] == "swap_with_center"
        assert entry["targets"] == {"center_index": expected}
        assert entry["made_by_server"] is True
        assert night.role_of("drunk").current_role == CENTER[expected]
        # Only the Drunk is told the swap was the server's, not their pick.
        assert results(night, "drunk") == [
            {
                "wave": 2,
                "action_type": "swap_with_center",
                "revealed_info": {"card_index": expected, "nothing_chosen": True},
            }
        ]

    def test_a_lone_werewolf_looks_at_the_first_centre_card(self, make_p2) -> None:
        night = make_p2(LONE, ["Villager", "Robber", "Tanner"])
        night.start()
        finish_window_two(night, {"wolf": [center(1), center(2)]})

        (result,) = results(night, "wolf")

        assert result["action_type"] == "see_team"
        assert result["revealed_info"]["teammate_names"] == []
        assert result["revealed_info"]["center_card"] == {"index": 1, "role": "Robber"}
        assert "nothing_chosen" not in result["revealed_info"]

    def test_a_lone_werewolf_with_no_centre_pick_still_learns_it_is_alone(
        self, make_p2
    ) -> None:
        night = make_p2(LONE)
        night.start()
        finish_window_two(night, {"wolf": [player(night, "seer")]})

        (result,) = results(night, "wolf")

        assert result["revealed_info"]["teammate_names"] == []
        assert "center_card" not in result["revealed_info"]
        assert result["revealed_info"]["nothing_chosen"] is True

    def test_a_pack_werewolf_cannot_look_at_the_centre_and_still_sees_the_pack(
        self, make_p2
    ) -> None:
        night = make_p2(TEN)
        night.start()
        finish_window_two(night, {"wolf1": [center(0)]})

        (result,) = results(night, "wolf1")

        assert result["revealed_info"]["teammate_names"] == [
            public_name(night.users["wolf2"])
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
            public_name(night.users[n]) for n in ("wolf1", "wolf2")
        )
        assert insomniac["revealed_info"]["current_role"] == "Insomniac"
        assert mason["revealed_info"]["teammate_names"] == [
            public_name(night.users["mason2"])
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
            public_name(night.users["wolf"])
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

        assert results(night, "dop") == [
            {
                "wave": 1,
                "action_type": "skip",
                "revealed_info": {"nothing_chosen": True},
            }
        ]
        assert "copied_role" not in night.role_of("dop").night_action_data
        assert night.game.current_wave == 2

    def test_one_look_a_first_choose_with_no_other_player_copies_nobody(
        self, make_p2
    ) -> None:
        """Her first choose is her look whatever it holds; a second one does nothing."""
        night = make_p2(DOPPEL)
        night.start()
        choose(night, "dop", [])
        second = choose(night, "dop", [player(night, "seer")])

        assert second.status_code == status.HTTP_200_OK  # answered like anyone's
        assert results(night, "dop") == []
        assert "copied_role" not in night.role_of("dop").night_action_data
        night.fire_timer(1)
        assert [r["action_type"] for r in results(night, "dop")] == ["skip"]
        assert night.game.current_wave == 2

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

    def test_with_the_fixed_length_off_window_one_ends_when_she_has_chosen(
        self, make_night
    ) -> None:
        # night_doppelganger_window_seconds = 0 (the make_night default). Only her
        # phone has a choice in window 1; the others' chooses (still taken) hold
        # nothing open.
        night = make_night(DOPPEL, CENTER, night_wave_seconds=60)
        night.start()
        assert night.prompt("seer")["chooses_left"] == 0
        for name in ("seer", "wolf", "villager", "drunk"):
            choose(night, name)
            assert night.refresh().current_wave == 1

        choose(night, "dop")  # she copied nobody: nothing more to wait for

        assert night.refresh().current_wave == 2

    def test_with_the_fixed_length_off_a_copying_doppelganger_is_waited_for_twice(
        self, make_night
    ) -> None:
        night = make_night(DOPPEL, CENTER, night_wave_seconds=60)
        night.start()
        choose(night, "dop", [player(night, "seer")])  # copies the Seer
        for name in ("seer", "wolf", "villager", "drunk"):
            choose(night, name)
        assert night.refresh().current_wave == 1  # her follow-up is still to come

        choose(night, "dop", [center(0), center(1)])

        assert night.refresh().current_wave == 2


# ── when window two closes ───────────────────────────────────────────────────


class TestWindowTwoClose:
    def test_the_window_waits_only_for_the_phones_with_a_choice(self, make_p2) -> None:
        night = make_p2(LONE)
        night.start()
        left = {name: me(night, name)["action_prompt"]["chooses_left"] for name in LONE}
        assert left == {"wolf": 1, "seer": 1, "villager": 0, "hunter": 0, "tanner": 0}

        choose(night, "wolf")
        assert night.refresh().current_wave == 2
        choose(night, "seer")  # the sleepers sent nothing and are not waited for

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
        drop(night, "seer", seconds_ago=60)

        choose(night, "wolf")

        assert night.refresh().phase == Phase.DISCUSSION

    def test_a_phone_inside_the_grace_period_still_holds_the_window(
        self, make_p2
    ) -> None:
        night = make_p2(LONE)
        night.start()
        drop(night, "seer", seconds_ago=5)

        choose(night, "wolf")

        assert night.refresh().phase == Phase.NIGHT

    def test_a_sleeper_inside_the_grace_period_holds_nothing(self, make_p2) -> None:
        night = make_p2(LONE)
        night.start()
        drop(night, "tanner", seconds_ago=5)

        choose(night, "wolf")
        choose(night, "seer")

        assert night.refresh().phase == Phase.DISCUSSION

    def test_the_host_can_close_it_and_a_stale_tap_cannot(self, make_p2) -> None:
        night = make_p2(LONE)
        night.start()
        night.client.force_authenticate(user=night.host)

        stale = night.client.post(
            reverse("onuw:wave-advance", kwargs={"game_id": str(night.game.id)}),
            {"stage": "w1." + night.game.id.hex[:12]},  # window 1 is long over
            format="json",
        )
        ok = night.host_close_window()

        assert stale.status_code == status.HTTP_409_CONFLICT
        assert stale.data["code"] == "wrong_stage"
        assert ok.status_code == status.HTTP_200_OK
        assert night.refresh().phase == Phase.DISCUSSION

    def test_close_time_says_who_tapped_never_what_they_hold(self, make_p2) -> None:
        """Who taps at night is an accepted tell (the phones with a choice; first
        time play spec, section 8). Beyond it nothing a player can watch (a window
        that closes sooner, a deferred close that is scheduled or not) depends on
        the roles: the same seats tapping at the same times, different roles with a
        choice, give the same close."""
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
                "b1": "Drunk",
                "b2": "Troublemaker",
                "b3": "Hunter",
                "b4": "Seer",
                "b5": "Insomniac",
            },
            night_min_window_seconds=8,
        )
        for night in (a, b):
            night.start()
            night.pretend_window_opened(3)
        tapping = {a: ["a1", "a2", "a4"], b: ["b1", "b2", "b4"]}

        # Two of the three phones with a choice have chosen: neither closes,
        # neither has anything scheduled beyond the deadline.
        for night in (a, b):
            for name in tapping[night][:2]:
                choose(night, name, [SELF])
            assert night.refresh().phase == Phase.NIGHT
        assert len(a.timer_delays(2)) == len(b.timer_delays(2)) == 1

        # The last of them defers the close to the same moment; the sleepers
        # sent nothing.
        for night in (a, b):
            choose(night, tapping[night][2], [SELF])
        assert len(a.timer_delays(2)) == len(b.timer_delays(2)) == 2
        assert a.timer_delays(2)[-1] == pytest.approx(b.timer_delays(2)[-1], abs=0.5)
        assert a.refresh().phase == b.refresh().phase == Phase.NIGHT


# ── what a table can observe ─────────────────────────────────────────────────


class TestNightUniformity:
    @pytest.mark.parametrize("roles", [TEN, DOPPEL], ids=["plain", "doppelganger"])
    def test_every_seat_sees_the_same_events_and_answers_in_every_window(
        self, make_p2, roles
    ) -> None:
        """A seeded table played through every window, every seat choosing (a
        phone with nothing to choose sends none, but one sent is taken alike; the
        table's minimum keeps each window open for all of them): the events (their
        types, and who they go to) and the answer to every POST are the same
        whatever a seat was dealt. No seat has an event of its own."""
        night = make_p2(roles, night_min_window_seconds=8)
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

    def test_a_choice_that_did_nothing_is_told_only_to_its_own_phone(
        self, make_p2
    ) -> None:
        """The Seer, Robber and Drunk pick nothing valid (a skip, a skip, the
        server's swap); the Troublemaker acts. Only those three phones are told
        ``nothing_chosen``, each about itself; no other seat's /me/ carries a
        skip or the flag, in any window."""
        night = make_p2(TEN)
        night.start()
        finish_window_two(
            night,
            {
                "seer": [SELF],
                "robber": [center(0)],
                "drunk": [SELF],
                "trouble": [player(night, "wolf1"), player(night, "mason1")],
            },
        )

        told = {
            name
            for name in TEN
            if "nothing_chosen" in repr(me(night, name)["night_results"])
        }
        skips = {
            name
            for name in TEN
            for r in me(night, name)["night_results"]
            if r["action_type"] == "skip"
        }
        assert told == {"seer", "robber", "drunk"}
        assert skips == {"seer", "robber"}
        for name in TEN:
            assert all(r["wave"] == 2 for r in me(night, name)["night_results"])
            assert len(me(night, name)["night_results"]) <= 1  # its own one only


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

    @pytest.mark.parametrize("value", [1, 2, 0, "2", None], ids=repr)
    def test_a_protocol_flag_older_tables_carry_is_ignored(self, value) -> None:
        """Lobby rows written before the cleanup may still hold ``night_protocol``
        (older code wrote 1 or 2): it is never a reason to refuse them."""
        assert self.errors(night_protocol=value) == []

    @pytest.mark.parametrize("stored", [1, 2, None], ids=["1", "2", "absent"])
    def test_a_table_stored_by_older_code_plays_the_choose_night(
        self, make_night, stored
    ) -> None:
        """A table whose settings older code wrote (``night_protocol`` 1, 2 or no
        key at all) deals into the one night there is: every phone has a choose
        prompt and a choose is taken."""
        extra = {} if stored is None else {"night_protocol": stored}
        night = make_night(LONE, CENTER, night_wave_seconds=60, **extra)
        night.start()

        for name in LONE:
            assert me(night, name)["action_prompt"]["action_types"] == ["choose"]
        reply = choose(night, "seer", [player(night, "wolf")])

        assert reply.status_code == status.HTTP_200_OK
        assert reply.data == {"status": "submitted"}
        assert chosen_now(night, "seer") == 1

    def test_a_server_that_does_not_allow_untimed_nights_refuses_zero_timers(
        self,
    ) -> None:
        for key in ("night_wave_seconds", "night_doppelganger_window_seconds"):
            errors = self.errors(**{key: 0})
            assert any(key in e for e in errors), key

    def test_and_a_minimum_window_under_five_seconds(self) -> None:
        assert any(
            "night_min_window_seconds" in e
            for e in self.errors(night_min_window_seconds=4)
        )
        assert self.errors(night_min_window_seconds=5) == []

    def test_absent_timers_are_fine(self) -> None:
        assert self.errors() == []

    def test_the_deal_clamps_a_stored_untimed_night_where_it_is_not_allowed(
        self, settings, db
    ) -> None:
        """A table stored with zero night timers (older code allowed them) is not
        stuck: the game gets the default lengths and a 5 s minimum window."""
        from apps.core.models import Lobby
        from tests.onuw.test_play_again import Table

        settings.DEBUG = True
        table = Table()  # its timers are all 0
        settings.ONUW_ALLOW_UNTIMED_NIGHT = False
        assert Lobby.objects.get(code=table.code).settings["night_wave_seconds"] == 0

        reply = table.start()

        assert reply.status_code == status.HTTP_201_CREATED
        game = Game.objects.get(id=reply.data["game_id"])
        assert "night_wave_seconds" not in game.settings
        assert game.settings["night_min_window_seconds"] == 5

    def test_a_lobby_patch_refuses_it_too(self, settings, db) -> None:
        from tests.onuw.test_play_again import Table

        table = Table()
        settings.ONUW_ALLOW_UNTIMED_NIGHT = False

        reply = table.host.patch(
            reverse("core:lobby-detail", kwargs={"code": table.code}),
            {"settings": {"night_wave_seconds": 0}},
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


# ── stages: a request names the stage it is aimed at ─────────────────────────


class TestStages:
    def test_get_me_names_the_stage_and_it_changes_with_every_stage(
        self, make_p2
    ) -> None:
        night = make_p2(DOPPEL)
        night.start()
        tokens = [{me(night, n)["stage"] for n in DOPPEL}]  # window 1
        night.fire_timer(1)
        tokens.append({me(night, n)["stage"] for n in DOPPEL})  # window 2
        everyone_chooses(night)
        tokens.append({me(night, n)["stage"] for n in DOPPEL})  # the talk

        assert all(len(group) == 1 for group in tokens)  # every phone, one token
        flat = [token for group in tokens for token in group]
        assert [t.split(".")[0] for t in flat] == ["w1", "w2", "talk"]
        assert len(set(flat)) == 3

    def test_a_token_from_another_game_never_matches(self, make_p2) -> None:
        a = make_p2({f"a_{n}": r for n, r in LONE.items()})
        b = make_p2({f"b_{n}": r for n, r in LONE.items()})
        a.start()
        b.start()
        token_a, token_b = current_stage(a.game.id), current_stage(b.game.id)
        assert token_a.split(".")[0] == token_b.split(".")[0] == "w2"
        assert token_a != token_b

        reply = choose(b, "b_seer", [], stage=token_a)

        assert reply.status_code == status.HTTP_409_CONFLICT
        assert reply.data == {"detail": "That stage is over.", "code": "wrong_stage"}
        assert "chose_2" not in b.role_of("b_seer").night_action_data

    def test_a_token_from_an_earlier_game_after_play_again_never_matches(
        self, settings, db
    ) -> None:
        from tests.onuw.test_play_again import Table

        settings.DEBUG = True
        table = Table()
        first = table.start().data["game_id"]
        old = current_stage(first)
        assert old is not None and old.startswith("w2.")
        Game.objects.filter(id=first).update(phase=Phase.RESULTS)
        assert table.play_again().status_code == status.HTTP_200_OK
        second = table.start().data["game_id"]
        assert current_stage(second).startswith("w2.")  # the same stage name again

        reply = table.clients[0].post(
            reverse("onuw:night-action", kwargs={"game_id": second}),
            {"action_type": "choose", "picks": [], "chosen": 0, "stage": old},
            format="json",
        )

        assert reply.status_code == status.HTTP_409_CONFLICT
        assert reply.data["code"] == "wrong_stage"
        assert not PlayerRole.objects.filter(
            game_id=second, night_action_data__has_key="chose_2"
        ).exists()

    def test_a_stage_is_required_and_must_be_text(self, make_p2) -> None:
        night = make_p2(LONE)
        night.start()
        for stage in (None, 5, [], {}, ""):
            reply = raw_post(
                night,
                "seer",
                {"action_type": "choose", "picks": [], "chosen": 0, "stage": stage},
            )
            assert reply.status_code == status.HTTP_400_BAD_REQUEST, stage
            assert reply.data["code"] == "bad_request"
        reply = raw_post(
            night, "seer", {"action_type": "choose", "picks": [], "chosen": 0}
        )
        assert reply.status_code == status.HTTP_400_BAD_REQUEST
        assert "chose_2" not in night.role_of("seer").night_action_data

    def test_a_late_window_one_tap_cannot_land_in_window_two(self, make_p2) -> None:
        """A Robber's second window-1 choose arriving just after the close used to be
        stored as his window-2 action and rob the Werewolf, and his real choose then
        got 409. Now the late tap names a stage that is over and does nothing."""
        table = {
            "rob": "Robber",
            "wolf": "Werewolf",
            "seer": "Seer",
            "villager": "Villager",
            "tanner": "Tanner",
        }
        night = make_p2(table, ["Doppelganger", "Villager", "Hunter"])
        night.start()  # the Doppelganger card is in the centre: window 1 still runs
        window_one = current_stage(night.game.id)
        assert window_one.startswith("w1.")
        choose(night, "rob", [])  # his one real choose of window 1
        night.fire_timer(1)  # window 1 closes; window 2 opens
        assert night.refresh().current_wave == 2

        late = choose(night, "rob", [player(night, "wolf")], stage=window_one)

        assert late.status_code == status.HTTP_409_CONFLICT
        assert late.data["code"] == "wrong_stage"
        assert "chose_2" not in night.role_of("rob").night_action_data
        real = choose(night, "rob", [player(night, "seer")])  # his real choose
        assert real.status_code == status.HTTP_200_OK
        for name in table:
            if name != "rob":
                choose(night, name, [])
        assert night.refresh().phase == Phase.DISCUSSION
        assert night.role_of("rob").current_role == "Seer"
        assert night.role_of("wolf").current_role == "Werewolf"

    def test_the_host_names_the_stage_too(self, make_p2) -> None:
        night = make_p2(LONE)
        night.start()
        old = current_stage(night.game.id)
        night.client.force_authenticate(user=night.host)
        url = reverse("onuw:wave-advance", kwargs={"game_id": str(night.game.id)})

        missing = night.client.post(url, {}, format="json")
        wrong = night.client.post(url, {"stage": "w2.000000000000"}, format="json")
        with night.committed():
            ok = night.client.post(url, {"stage": old}, format="json")
        stale = night.client.post(url, {"stage": old}, format="json")

        assert missing.status_code == status.HTTP_400_BAD_REQUEST
        assert wrong.status_code == status.HTTP_409_CONFLICT
        assert wrong.data["code"] == "wrong_stage"
        assert ok.status_code == status.HTTP_200_OK
        assert stale.status_code == status.HTTP_409_CONFLICT  # the window is over
        assert night.refresh().phase == Phase.DISCUSSION


# ── the prompt says what a pick would do ─────────────────────────────────────


class TestDoppelgangerHeldFace:
    def test_with_nothing_to_choose_in_window_two_she_shows_her_copied_role(
        self, make_p2
    ) -> None:
        """A Doppelganger with no action in window 2 presents the role she copied as
        ``role_acting_as`` (her held face), not "Doppelganger"."""
        night = make_p2(DOPPEL)
        night.start()
        choose(night, "dop", [player(night, "villager")])  # copies the Villager
        night.fire_timer(1)

        prompt = me(night, "dop")["action_prompt"]

        assert prompt["kind"] == "none"
        assert prompt["role_acting_as"] == "Villager"
        assert me(night, "villager")["action_prompt"]["role_acting_as"] == "Villager"

    def test_one_who_copied_nobody_keeps_her_own_card(self, make_p2) -> None:
        night = make_p2(DOPPEL)
        night.start()
        choose(night, "dop", [SELF])
        night.fire_timer(1)

        assert me(night, "dop")["action_prompt"]["role_acting_as"] == "Doppelganger"


class TestShapes:
    SHAPES = {
        "wolf1": [{"any": 1}],  # a pack: nothing to choose
        "minion": [{"any": 1}],
        "mason1": [{"any": 1}],
        "seer": [{"players": 1}, {"center": 2}],
        "robber": [{"players": 1}],
        "trouble": [{"players": 2}],
        "drunk": [{"center": 1}],
        "insomniac": [{"any": 1}],
    }

    def test_every_role_gets_its_shapes_as_data(self, make_p2) -> None:
        night = make_p2(TEN)
        night.start()

        shapes = {
            name: me(night, name)["action_prompt"]["shapes"] for name in self.SHAPES
        }

        assert shapes == self.SHAPES

    def test_a_lone_werewolf_may_pick_one_centre_card(self, make_p2) -> None:
        night = make_p2(LONE)
        night.start()

        assert me(night, "wolf")["action_prompt"]["shapes"] == [{"center": 1}]
        assert me(night, "villager")["action_prompt"]["shapes"] == [{"any": 1}]

    def test_the_doppelganger_looks_at_one_player_then_follows_the_copied_role(
        self, make_p2
    ) -> None:
        night = make_p2(DOPPEL)
        night.start()
        assert me(night, "dop")["action_prompt"]["shapes"] == [{"players": 1}]
        assert me(night, "villager")["action_prompt"]["shapes"] == [{"any": 1}]

        choose(night, "dop", [player(night, "seer")])  # copies the Seer

        after = me(night, "dop")["action_prompt"]
        assert after["shapes"] == [{"players": 1}, {"center": 2}]
        assert after["chosen"] == 1 and after["max_chooses"] == 2

    def test_a_doppelganger_who_copied_nobody_has_nothing_more_to_pick(
        self, make_p2
    ) -> None:
        night = make_p2(DOPPEL)
        night.start()
        choose(night, "dop", [SELF])

        assert me(night, "dop")["action_prompt"]["shapes"] == [{"any": 1}]

    def test_the_shapes_cover_exactly_the_picks_the_server_reads(self, make_p2) -> None:
        """A pick that fits a shape does something; the prompt's board is the same
        for everyone, and a pick outside the shapes safely does nothing."""
        night = make_p2(TEN)
        night.start()
        prompt = me(night, "robber")["action_prompt"]

        assert prompt["valid_targets"]["center_indices"] == [0, 1, 2]
        finish_window_two(night, {"robber": [center(0)]})  # outside {"players": 1}

        assert night.role_of("robber").current_role == "Robber"  # nothing happened


# ── one cross-table check ────────────────────────────────────────────────────


class TestTablesLookAlike:
    """The same taps at the same times on tables dealt differently give the same
    statuses, the same events heard and the same close time."""

    A = ["Werewolf", "Seer", "Robber", "Villager", "Tanner"]
    B = ["Seer", "Werewolf", "Drunk", "Insomniac", "Minion"]
    C = ["Doppelganger", "Seer", "Werewolf", "Drunk", "Villager"]

    def run(self, night: Night) -> dict[str, Any]:
        night.start()
        if night.game.current_wave == 1:
            night.fire_timer(1)  # window 1 (a Doppelganger table) closes
        assert night.refresh().current_wave == 2
        night.pretend_window_opened(3)
        mark = len(night.recorder.events)
        replies = []
        names = list(night.users)
        for index, name in enumerate(names):
            other = names[(index + 1) % len(names)]
            reply = choose(night, name, [player(night, other)])
            replies.append((reply.status_code, reply.content))
        # Everyone chose, 3 s into an 8 s minimum: the close is deferred.
        deferred = night.timer_delays(2)[-1]
        night.fire_timer(2)
        return {
            "replies": replies,
            "events": [e["type"] for _, e in night.recorder.events[mark:]],
            "deferred": round(deferred),
            "phase": night.game.phase,
            "keys": [sorted(me(night, n)) for n in names],
        }

    def test_three_differently_dealt_tables_look_the_same_from_outside(
        self, make_p2
    ) -> None:
        seen = [
            self.run(
                make_p2(
                    {f"t{t}_{i}": role for i, role in enumerate(table)},
                    night_min_window_seconds=8,
                )
            )
            for t, table in enumerate((self.A, self.B, self.C))
        ]

        assert seen[0]["replies"] == [(200, b'{"status":"submitted"}')] * 5
        assert seen[0] == seen[1] == seen[2]
        assert seen[0]["deferred"] == 5
        assert seen[0]["phase"] == Phase.DISCUSSION


# ── races ────────────────────────────────────────────────────────────────────


@pytest.mark.django_db(transaction=True)
class TestChooseRaces:
    def post_choose(
        self, night: Night, who: str, token: str | None, out: list, barrier
    ) -> None:
        from django.db import connections

        from rest_framework.test import APIClient

        try:
            client = APIClient()
            client.force_authenticate(user=night.users[who])
            barrier.wait(timeout=10)
            reply = client.post(
                reverse("onuw:night-action", kwargs={"game_id": str(night.game.id)}),
                {"action_type": "choose", "picks": [], "chosen": 0, "stage": token},
                format="json",
            )
            out.append((reply.status_code, reply.data.get("code")))
        finally:
            connections.close_all()

    def run_all(self, targets: list) -> None:
        import threading

        threads = [threading.Thread(target=t) for t in targets]
        for t in threads:
            t.start()
        for t in threads:
            t.join(timeout=30)

    def test_the_last_choose_and_the_deadline_close_the_window_once(
        self, make_p2
    ) -> None:
        import threading

        from django.db import connections

        night = make_p2(LONE)
        night.start()
        for name in ("wolf", "seer", "villager", "hunter"):
            choose(night, name, [])
        token = current_stage(night.game.id)
        callback = [cb for k, _, cb in night.scheduled if k.endswith(":wave:2")][-1]
        barrier = threading.Barrier(2)
        out: list = []

        def deadline() -> None:
            try:
                barrier.wait(timeout=10)
                callback()
            finally:
                connections.close_all()

        self.run_all(
            [lambda: self.post_choose(night, "tanner", token, out, barrier), deadline]
        )

        # The choose is stored (200) or arrived after the close (409 wrong_stage);
        # either way the window closed exactly once.
        assert out in ([(200, None)], [(409, "wrong_stage")])
        assert night.refresh().phase == Phase.DISCUSSION
        assert len(night.broadcasts("phase.change")) == 1

    def test_two_copies_of_one_choose_at_once_store_one_and_answer_both_alike(
        self, make_p2
    ) -> None:
        """A phone that resends while its first request is still in flight: the
        Game lock orders them, the second is a resend of the first (both answered
        the prompt at ``chosen`` 0), so both get the same 200 and one is stored."""
        import threading

        night = make_p2(LONE)
        night.start()
        token = current_stage(night.game.id)
        barrier = threading.Barrier(2)
        out: list = []

        self.run_all([lambda: self.post_choose(night, "seer", token, out, barrier)] * 2)

        assert out == [(200, None), (200, None)]
        assert night.role_of("seer").night_action_data["chose_2"] == 1

    def test_the_hosts_advance_and_the_last_choose_close_the_window_once(
        self, make_p2
    ) -> None:
        import threading

        from django.db import connections

        from rest_framework.test import APIClient

        night = make_p2(LONE)
        night.start()
        for name in ("wolf", "seer", "villager", "hunter"):
            choose(night, name, [])
        token = current_stage(night.game.id)
        barrier = threading.Barrier(2)
        out: list = []
        advance: list = []

        def host() -> None:
            try:
                client = APIClient()
                client.force_authenticate(user=night.host)
                barrier.wait(timeout=10)
                reply = client.post(
                    reverse(
                        "onuw:wave-advance", kwargs={"game_id": str(night.game.id)}
                    ),
                    {"stage": token},
                    format="json",
                )
                advance.append(reply.status_code)
            finally:
                connections.close_all()

        self.run_all(
            [lambda: self.post_choose(night, "tanner", token, out, barrier), host]
        )

        assert advance in ([200], [409])
        assert out in ([(200, None)], [(409, "wrong_stage")])
        assert night.refresh().phase == Phase.DISCUSSION
        assert len(night.broadcasts("phase.change")) == 1
