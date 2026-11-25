"""A result that is settled at the choose is given at the choose.

What a player learns is fixed the moment they choose when nothing that resolves
before their step in the window can move a card they see (``engine.night.
settled_at_choose``): the Seer, the Robber, the Troublemaker, the Drunk, a lone
Werewolf's centre look, and the Doppelganger's follow-up as any of them. Their
choose's answer carries it (``night_results``, as ``GET /me/`` lists it) and
``GET /me/`` lists it from then on. Anything else (the Insomniac, team views, a
Doppelganger who copied the Minion) still waits for the window's close.

The proof that the result given early is the one the close computes: seeded games
for every role, played through the real API, every chooser's answer compared with
what ``GET /me/`` shows for that window once it has closed.
"""

from __future__ import annotations

import json
import logging
import random
from typing import Any

from django.urls import reverse

import pytest

from apps.onuw import choose_night, night_window
from apps.onuw.engine.night import settled_at_choose
from apps.onuw.models import Phase
from tests.onuw.night_rules_reference import POOL
from tests.onuw.stages import staged
from tests.onuw.test_night_windows import Night

pytestmark = pytest.mark.integration

SEED = 20261125
GAMES = 60
CHOOSERS = {"Seer", "Robber", "Troublemaker", "Drunk"}


def _random_picks(rng: random.Random, night: Night, name: str) -> list[dict]:
    """0 to 2 distinct picks of any kind, as a phone could send them."""
    others = [{"player_id": night.users[n].id} for n in night.users if n != name]
    board = [*others, *({"center_index": i} for i in range(3)), {"self": True}]
    return rng.sample(board, rng.randint(0, 2))


def _window_entries(results: list[dict], window: int) -> list[dict]:
    return [r for r in results if r["wave"] == window]


def _play(rng: random.Random, make_night: Any, game: int) -> list[tuple[str, str, int]]:
    """One seeded game: every chooser chooses in a random order with random picks.
    Checks each answer against the closed window; returns what it compared."""
    n = rng.randint(3, 8)
    deck = rng.sample(POOL, n + 3)
    names = [f"g{game}p{i}" for i in range(n)]
    night = make_night(dict(zip(names, deck[:n], strict=True)), deck[n:])
    night.start()
    compared: list[tuple[str, str, int]] = []
    while night.refresh().phase == Phase.NIGHT:
        window = night.game.current_wave
        given: dict[str, list[dict]] = {}
        acting: dict[str, str] = {}
        for _ in range(2):  # window 1: the look, then her follow-up
            if (
                night.refresh().phase != Phase.NIGHT
                or night.game.current_wave != window
            ):
                break
            order = [m for m in names if night.prompt(m)["chooses_left"] > 0]
            rng.shuffle(order)
            for name in order:
                if night.refresh().current_wave != window:
                    break
                role = night.prompt(name)["role_acting_as"]
                reply = night.choose(name, _random_picks(rng, night, name))
                assert reply.status_code == 200, reply.content
                assert set(reply.data) == {"status", "night_results", "chooses_left"}
                # The answer is what GET /me/ would list at this moment.
                if night.refresh().current_wave == window:
                    assert (
                        reply.data["night_results"] == night.me(name)["night_results"]
                    )
                if settled_at_choose(window, role):
                    given[name] = _window_entries(reply.data["night_results"], window)
                    acting[name] = role
        if night.refresh().phase == Phase.NIGHT and night.game.current_wave == window:
            night.host_close_window()
        for name, early in given.items():
            closed = _window_entries(night.results(name), window)
            # The look (logged at once) and the settled result: exactly the close's.
            assert early == closed, (name, acting[name], early, closed)
            compared.append((name, acting[name], window))
    return compared


def test_every_settled_result_given_at_the_choose_is_the_one_the_close_computes(
    make_night,
) -> None:
    rng = random.Random(SEED)  # noqa: S311 (seeded so a failure reproduces)
    seen: set[tuple[str, int]] = set()
    for game in range(GAMES):
        seen.update((role, window) for _, role, window in _play(rng, make_night, game))
    # Every role that learns at the choose was played, and her follow-ups.
    assert {(r, 2) for r in CHOOSERS} | {("Werewolf", 2)} <= seen
    assert any(window == 1 for _, window in seen)


def test_which_roles_are_settled_at_the_choose() -> None:
    for role in [*CHOOSERS, "Werewolf"]:
        assert settled_at_choose(2, role), role
    for role in CHOOSERS:
        assert settled_at_choose(1, role), role  # her follow-up
    assert not settled_at_choose(2, "Insomniac")
    assert not settled_at_choose(1, "Doppelganger")  # her look: its own path


TABLE = {
    "seer": "Seer",
    "wolf": "Werewolf",
    "robber": "Robber",
    "insomniac": "Insomniac",
    "villager": "Villager",
}


def test_a_seer_sees_her_card_at_once_and_still_after_a_reload(make_night) -> None:
    night = make_night(TABLE, night_min_window_seconds=30)
    night.start()
    wolf = night.users["wolf"].id

    reply = night.choose("seer", [{"player_id": wolf}])

    seen = {
        "wave": 2,
        "action_type": "peek_player",
        "revealed_info": {"target_name": "Named wolf", "role": "Werewolf"},
    }
    assert reply.data["night_results"] == [seen]
    assert night.refresh().phase == Phase.NIGHT  # the window is still open
    assert night.me("seer")["night_results"] == [seen]  # a reload shows it


def test_the_robber_learns_her_new_card_even_if_the_seer_looks_after(
    make_night,
) -> None:
    night = make_night(TABLE, night_min_window_seconds=30)
    night.start()
    wolf = night.users["wolf"].id

    robbed = night.choose("robber", [{"player_id": wolf}])
    looked = night.choose("seer", [{"player_id": wolf}])

    assert robbed.data["night_results"][0]["revealed_info"]["new_role"] == "Werewolf"
    # The Seer looks before the Robber moves, whoever tapped first.
    assert looked.data["night_results"][0]["revealed_info"]["role"] == "Werewolf"
    night.host_close_window()
    assert night.results("seer") == looked.data["night_results"]
    assert night.results("robber") == robbed.data["night_results"]


def test_the_insomniac_and_the_teams_still_wait_for_the_close(make_night) -> None:
    night = make_night(
        {**TABLE, "wolf2": "Werewolf", "minion": "Minion"},
        night_min_window_seconds=30,
    )
    night.start()
    night.choose("robber", [{"player_id": night.users["insomniac"].id}])
    night.choose("seer", [{"center_index": 0}, {"center_index": 1}])

    assert night.refresh().phase == Phase.NIGHT
    for name in ("insomniac", "wolf", "wolf2", "minion", "villager"):
        assert night.me(name)["night_results"] == [], name
    night.host_close_window()
    assert night.results("insomniac")[0]["revealed_info"] == {"current_role": "Robber"}


def test_another_phone_sees_nothing_new_when_someone_learns(make_night) -> None:
    night = make_night(TABLE, night_min_window_seconds=30)
    night.start()
    others = [n for n in TABLE if n != "seer"]
    before = {n: json.dumps(night.me(n), sort_keys=True) for n in others}
    events = len(night.recorder.events)

    night.choose("seer", [{"player_id": night.users["wolf"].id}])

    assert {n: json.dumps(night.me(n), sort_keys=True) for n in others} == before
    assert len(night.recorder.events) == events  # a choose sends no event


def test_a_doppelganger_who_copied_the_seer_sees_her_follow_up_at_once(
    make_night,
) -> None:
    night = make_night(
        {"dop": "Doppelganger", "seer": "Seer", "wolf": "Werewolf"},
        night_min_window_seconds=30,
        night_doppelganger_window_seconds=30,
    )
    night.start()
    look = night.choose("dop", [{"player_id": night.users["seer"].id}])
    assert look.data["chooses_left"] == 1  # her follow-up is next

    follow = night.choose("dop", [{"player_id": night.users["wolf"].id}])

    assert [r["action_type"] for r in follow.data["night_results"]] == [
        "peek_player",
        "peek_player",
    ]
    assert follow.data["night_results"][1]["revealed_info"]["role"] == "Werewolf"
    assert follow.data["chooses_left"] == 0
    night.fire_timer(1)
    assert night.results("dop") == follow.data["night_results"]
    # The waiting copy is gone with the close: only the log shows it now.
    assert "early_1" not in night.role_of("dop").night_action_data


def _send(night: Any, name: str, body: dict[str, Any]) -> Any:
    """``body`` posted as ``name`` exactly as given (a true resend when repeated)."""
    night.client.force_authenticate(user=night.users[name])
    url = reverse("onuw:night-action", kwargs={"game_id": str(night.game.id)})
    with night.committed():
        return night.client.post(url, body, format="json")


def _body(night: Any, name: str, picks: list[dict]) -> dict[str, Any]:
    return staged(
        night,
        {"action_type": "choose", "picks": picks, "chosen": night.chosen(name)},
    )


def test_a_resent_choose_gets_the_same_result_and_looks_no_second_time(
    make_night,
) -> None:
    night = make_night(TABLE, night_min_window_seconds=30)
    night.start()
    wolf = night.users["wolf"].id
    bodies = {
        "seer": _body(night, "seer", [{"player_id": wolf}]),
        "robber": _body(night, "robber", [{"player_id": wolf}]),
    }
    firsts = {n: _send(night, n, b) for n, b in bodies.items()}
    stored = {n: dict(night.role_of(n).night_action_data) for n in bodies}

    for name, body in bodies.items():
        again = _send(night, name, body)
        assert again.status_code == firsts[name].status_code == 200
        assert again.json() == firsts[name].json(), name
        assert again.json()["night_results"], name  # the result, not a bare status
        assert night.role_of(name).night_action_data == stored[name], name


def test_a_resent_followup_of_a_doppelganger_gets_the_same_result(make_night) -> None:
    night = make_night(
        {"dop": "Doppelganger", "seer": "Seer", "wolf": "Werewolf"},
        night_min_window_seconds=30,
        night_doppelganger_window_seconds=30,
    )
    night.start()
    look = _send(
        night, "dop", _body(night, "dop", [{"player_id": night.users["seer"].id}])
    )
    follow = _body(night, "dop", [{"player_id": night.users["wolf"].id}])
    first = _send(night, "dop", follow)
    stored = dict(night.role_of("dop").night_action_data)

    again = _send(night, "dop", follow)

    assert len(first.json()["night_results"]) == 2
    assert again.json() == first.json() != look.json()
    assert night.role_of("dop").night_action_data == stored


def test_a_phone_with_nothing_to_choose_that_chooses_anyway_learns_nothing(
    make_night,
) -> None:
    night = make_night(
        {
            "seer": "Seer",
            "wolf": "Werewolf",
            "wolf2": "Werewolf",
            "minion": "Minion",
            "mason": "Mason",
            "mason2": "Mason",
            "insomniac": "Insomniac",
        },
        night_min_window_seconds=30,
    )
    night.start()
    picks = [{"player_id": night.users["seer"].id}]
    for name in ("wolf", "wolf2", "minion", "mason", "mason2", "insomniac"):
        assert not night.turn_open(name), name
        reply = night.choose(name, picks)
        assert reply.status_code == 200, name
        assert reply.json()["night_results"] == [], name
        assert reply.json()["chooses_left"] == 0, name
        assert night.me(name)["night_results"] == [], name
        assert not any(
            k.startswith("early_") for k in night.role_of(name).night_action_data
        )
    assert night.refresh().phase == Phase.NIGHT  # the Seer has not chosen yet


def test_a_choose_stands_when_its_answer_cannot_be_built(
    make_night, monkeypatch, caplog
) -> None:
    night = make_night(TABLE, night_min_window_seconds=30)
    night.start()

    def broken(*_: Any, **__: Any) -> Any:
        raise RuntimeError("the answer failed")

    monkeypatch.setattr(choose_night, "answer_for", broken)
    with caplog.at_level(logging.ERROR):
        reply = night.choose("seer", [{"player_id": night.users["wolf"].id}])

    assert reply.status_code == 200
    assert reply.json() == {"status": "submitted"}  # the old, status-only shape
    assert any("answer to a choose" in r.message for r in caplog.records)
    assert night.chosen("seer") == 1  # the choose was kept
    assert night.me("seer")["night_results"][0]["revealed_info"]["role"] == "Werewolf"


def test_a_result_that_cannot_be_settled_early_is_logged_not_swallowed(
    make_night, monkeypatch, caplog
) -> None:
    night = make_night(TABLE, night_min_window_seconds=30)
    night.start()

    def broken(*_: Any, **__: Any) -> Any:
        raise RuntimeError("cannot resolve")

    monkeypatch.setattr(choose_night, "resolve_wave", broken)
    with caplog.at_level(logging.ERROR):
        reply = night.choose("seer", [{"player_id": night.users["wolf"].id}])

    assert reply.json()["night_results"] == []  # nothing early; the close decides
    assert any("No early result" in r.message for r in caplog.records)


def test_a_last_resort_close_says_whose_shown_result_it_overrides(
    make_night, monkeypatch, caplog
) -> None:
    night = make_night(TABLE, night_min_window_seconds=30)
    night.start()
    night.choose("seer", [{"player_id": night.users["wolf"].id}])
    real = night_window.resolve_window

    def fails_together(state: Any, actions: list, window: int) -> Any:
        if len(actions) > 1 and any(a.action_type == "peek_player" for a in actions):
            raise RuntimeError("only together")
        return real(state, actions, window)

    monkeypatch.setattr(night_window, "resolve_window", fails_together)
    with caplog.at_level(logging.ERROR):
        night.host_close_window()

    assert night.refresh().phase == Phase.DISCUSSION  # the window still closes
    contradiction = [r for r in caplog.records if "contradicts" in r.message]
    assert len(contradiction) == 1
    assert str(night.users["seer"].id) in contradiction[0].message
