"""
A lost answer and a resend: every stage request is safe to send twice.

A phone whose answer is lost sends the SAME request again (same body, same ``stage``).
The server must then leave the game exactly as the first copy left it, and answer so
the phone can carry on. The bug that made this a rule (found by a model checker,
``docs/dev/models/night2/``): in window 1 the Doppelganger's resent look was counted
as her SECOND choose and read as the copied role's action (as Robber she robbed the
player she had looked at), and her real follow-up was refused 409 ``already_chosen``.

The mechanism, for every phone and both windows: a ``choose`` names the prompt it
answers (``chosen``, the count ``GET /me/``'s prompt showed). Under the Game lock a
``chosen`` LOWER than the stored count is a resend of a choose already taken: the
same ``200 {"status": "submitted"}``, nothing stored. Every other stage request is
idempotent by what it does (a flag set to a value, a pick replaced by the same pick,
a lock repeated, a count raised with GREATEST), or ends its stage so the copy names
a stage that is over (409 ``wrong_stage``, nothing stored).

All through the real API, seat order different from user-id order (``Night``),
seeded.
"""

from __future__ import annotations

import json
import random
from collections.abc import Callable
from dataclasses import dataclass
from typing import Any

from django.urls import reverse

import pytest
from rest_framework import status
from rest_framework.test import APIClient

from apps.core.models import LobbyMember
from apps.onuw import night_flow, night_window, turns, voting
from apps.onuw.models import Game, Phase, PlayerRole
from tests.onuw.stages import outside, staged
from tests.onuw.test_night_windows import Night

pytestmark = pytest.mark.integration

CENTER = ["Villager", "Tanner", "Hunter"]
SELF = {"self": True}
SUBMITTED = b'{"status":"submitted"}'

# The model's table, made bigger: a Doppelganger, the role she copies, and others.
DOPPEL_ROBBER = {
    "dop": "Doppelganger",
    "robber": "Robber",
    "villager": "Villager",
    "wolf": "Werewolf",
    "seer": "Seer",
}
LONE = {
    "wolf": "Werewolf",
    "seer": "Seer",
    "robber": "Robber",
    "villager": "Villager",
    "hunter": "Hunter",
}


@pytest.fixture
def make_p2(make_night):
    """A Night whose window 1 (if any) is a fixed 15 s; nothing else waits."""

    def factory(roles, center=None, **settings) -> Night:
        merged = {
            "night_wave_seconds": 60,
            "night_doppelganger_window_seconds": 15,
            "discussion_seconds": 300,
            "voting_seconds": 120,
            **settings,
        }
        return make_night(roles, center or CENTER, **merged)

    return factory


# ── sending what a phone sends ───────────────────────────────────────────────


def pid(night: Night, name: str) -> int:
    return night.users[name].id


def player(night: Night, name: str) -> dict[str, int]:
    return {"player_id": pid(night, name)}


def chosen_now(night: Night, who: str) -> int:
    game = Game.objects.get(id=night.game.id)
    pr = PlayerRole.objects.get(game=game, user=night.users[who])
    return turns.chose_count(pr, game.current_wave)


def choose_body(night: Night, who: str, picks: list) -> dict[str, Any]:
    """A choose as a phone builds it from its prompt NOW: the stage and ``chosen``
    are fixed in the body, so sending the body again is a true resend."""
    return staged(
        night,
        {"action_type": "choose", "picks": picks, "chosen": chosen_now(night, who)},
    )


def send(night: Night, who: str, url_name: str, body: Any) -> Any:
    """POST ``body`` as ``who`` (unchanged: the caller staged it)."""
    night.client.force_authenticate(user=night.users[who])
    with night.committed():
        return night.client.post(
            reverse(url_name, kwargs={"game_id": str(night.game.id)}),
            body,
            format="json",
        )


def choose(night: Night, who: str, picks: list) -> Any:
    return send(night, who, "onuw:night-action", choose_body(night, who, picks))


def me(night: Night, who: str) -> dict[str, Any]:
    night.client.force_authenticate(user=night.users[who])
    response = night.client.get(
        reverse("onuw:game-me", kwargs={"game_id": str(night.game.id)})
    )
    assert response.status_code == status.HTTP_200_OK
    return response.data


def snapshot(night: Night) -> tuple:
    """Everything a request can change: the game row's play state, every player's
    row, the timers scheduled and the events sent (both only ever appended)."""
    game = Game.objects.get(id=night.game.id)
    rows = {
        pr.user_id: (
            pr.current_role,
            pr.night_action_data,
            pr.has_acted,
            pr.phase_ready,
            pr.vote_target_id,
            pr.night_results_seen,
        )
        for pr in PlayerRole.objects.filter(game=game)
    }
    return (
        game.phase,
        game.current_wave,
        list(game.center_cards),
        list(game.night_actions_log),
        game.phase_deadline,
        game.night_window_opened_at,
        game.results,
        rows,
        len(night.scheduled),
    )


def to_talk(night: Night) -> None:
    with night.committed():
        night_window.transition_to_discussion(Game.objects.get(id=night.game.id))
    night.refresh()


def to_vote(night: Night) -> None:
    to_talk(night)
    with night.committed():
        voting.transition_to_voting(Game.objects.get(id=night.game.id))
    night.refresh()
    assert night.game.phase == Phase.VOTING


# ── the bug the model found, replayed ────────────────────────────────────────


class TestTheDoppelgangersResentLook:
    def test_a_resent_look_is_not_read_as_her_robber_followup(self, make_p2) -> None:
        """The model's path: window 1 opens, she looks at the Robber (copies the
        Robber), the answer is lost and her phone resends the SAME body, then she
        sends her real follow-up (rob the Villager), then window 1 ends.

        It used to end with her holding the ROBBER's card (the resend robbed him)
        and her real follow-up refused 409 ``already_chosen``."""
        night = make_p2(DOPPEL_ROBBER)
        night.start()
        assert night.refresh().current_wave == 1

        look = choose_body(night, "dop", [player(night, "robber")])
        first = send(night, "dop", "onuw:night-action", look)
        events_after_look = len(night.recorder.events)
        resend = send(night, "dop", "onuw:night-action", look)
        followup = choose(night, "dop", [player(night, "villager")])

        assert (
            outside(first.content)
            == outside(resend.content)
            == outside(followup.content)
            == SUBMITTED
        )
        assert (
            len(night.recorder.events) == events_after_look
        )  # the resend sent nothing
        assert night.role_of("dop").night_action_data["chose_1"] == 2

        night.fire_timer(1)

        # She robbed whom she chose: the Villager, not the Robber she looked at.
        assert night.role_of("dop").current_role == "Villager"
        assert night.role_of("villager").current_role == "Doppelganger"
        assert night.role_of("robber").current_role == "Robber"
        hers = [
            e
            for e in night.refresh().night_actions_log
            if e["player_id"] == pid(night, "dop")
        ]
        assert [(e["role_acting_as"], e["action_type"]) for e in hers] == [
            ("Doppelganger", "peek_player"),
            ("Robber", "swap_with_player"),
        ]
        assert hers[1]["targets"] == {"player_id": pid(night, "villager")}
        assert [r["action_type"] for r in me(night, "dop")["night_results"]] == [
            "peek_player",
            "swap_with_player",
        ]

    def test_without_the_lost_answer_the_same_night_ends_the_same(
        self, make_p2
    ) -> None:
        """Control: the same choices with no resend reach the same table."""
        night = make_p2(DOPPEL_ROBBER)
        night.start()
        choose(night, "dop", [player(night, "robber")])
        choose(night, "dop", [player(night, "villager")])
        night.fire_timer(1)

        assert night.role_of("dop").current_role == "Villager"
        assert night.role_of("robber").current_role == "Robber"

    @pytest.mark.parametrize(
        ("copied", "followup", "expect"),
        [
            ("Seer", lambda n: [player(n, "villager")], "peek_player"),
            ("Robber", lambda n: [player(n, "villager")], "swap_with_player"),
            (
                "Troublemaker",
                lambda n: [player(n, "villager"), player(n, "wolf")],
                "swap_others",
            ),
            ("Drunk", lambda n: [{"center_index": 2}], "swap_with_center"),
            ("Minion", lambda n: [SELF], "see_team"),
        ],
    )
    def test_for_every_role_with_a_followup_the_resend_costs_her_nothing(
        self, make_p2, copied, followup, expect
    ) -> None:
        table = {
            "dop": "Doppelganger",
            "target": copied,
            "villager": "Villager",
            "wolf": "Werewolf",
        }
        night = make_p2(table)
        night.start()
        look = choose_body(night, "dop", [player(night, "target")])
        send(night, "dop", "onuw:night-action", look)
        send(night, "dop", "onuw:night-action", look)  # lost answer: sent again
        assert me(night, "dop")["action_prompt"]["chosen"] == 1  # still one taken

        assert outside(choose(night, "dop", followup(night)).content) == SUBMITTED
        night.fire_timer(1)

        followups = [
            e
            for e in night.refresh().night_actions_log
            if e["player_id"] == pid(night, "dop") and e["role_acting_as"] == copied
        ]
        assert [e["action_type"] for e in followups] == [expect]
        assert not followups[0].get("made_by_server", False)


# ── choose: the mechanism ────────────────────────────────────────────────────


class TestChooseResend:
    def test_a_resent_window_two_choose_is_answered_alike_and_stores_nothing(
        self, make_p2
    ) -> None:
        night = make_p2(LONE)
        night.start()
        body = choose_body(night, "seer", [player(night, "wolf")])
        first = send(night, "seer", "onuw:night-action", body)
        before = snapshot(night)
        events = len(night.recorder.events)

        again = send(night, "seer", "onuw:night-action", body)

        assert again.status_code == first.status_code == status.HTTP_200_OK
        assert outside(again.content) == outside(first.content) == SUBMITTED
        assert snapshot(night) == before
        assert len(night.recorder.events) == events

    def test_the_first_copy_counts_even_if_the_resend_holds_other_picks(
        self, make_p2
    ) -> None:
        """A choose answering a prompt already answered is never read: what was
        taken stays taken (the phone reads ``/me/`` to see where it stands)."""
        night = make_p2(LONE)
        night.start()
        send(night, "robber", "onuw:night-action", choose_body(night, "robber", [SELF]))
        stale = staged(
            night,
            {
                "action_type": "choose",
                "picks": [player(night, "wolf")],
                "chosen": 0,
            },
        )

        assert (
            outside(send(night, "robber", "onuw:night-action", stale).content)
            == SUBMITTED
        )
        for name in ("wolf", "seer", "villager", "hunter"):
            choose(night, name, [])
        assert night.refresh().phase == Phase.DISCUSSION
        assert night.role_of("robber").current_role == "Robber"  # robbed nobody

    def test_a_resend_is_the_same_bytes_for_every_role(self, make_p2) -> None:
        table = {
            "dop": "Doppelganger",
            "wolf": "Werewolf",
            "seer": "Seer",
            "drunk": "Drunk",
            "villager": "Villager",
        }
        night = make_p2(table)
        night.start()
        bodies = {name: choose_body(night, name, []) for name in table}
        firsts = {n: send(night, n, "onuw:night-action", b) for n, b in bodies.items()}
        resends = {n: send(night, n, "onuw:night-action", b) for n, b in bodies.items()}

        assert {outside(r.content) for r in [*firsts.values(), *resends.values()]} == {
            SUBMITTED
        }
        assert all(chosen_now(night, n) == 1 for n in table)

    def test_a_resent_followup_is_also_a_resend(self, make_p2) -> None:
        night = make_p2(DOPPEL_ROBBER)
        night.start()
        choose(night, "dop", [player(night, "robber")])
        followup = choose_body(night, "dop", [player(night, "villager")])
        send(night, "dop", "onuw:night-action", followup)
        before = snapshot(night)

        again = send(night, "dop", "onuw:night-action", followup)

        assert outside(again.content) == SUBMITTED
        assert snapshot(night) == before

    def test_the_last_choose_resent_after_it_closed_the_window_is_wrong_stage(
        self, make_p2
    ) -> None:
        """The copy names a stage the first copy ended: 409 ``wrong_stage``, the
        same for every role, nothing stored, never landing in the next stage."""
        night = make_p2(LONE)
        night.start()
        _all_but_robber_chose(night)
        last = choose_body(night, "robber", [])
        assert send(night, "robber", "onuw:night-action", last).status_code == 200
        assert night.refresh().phase == Phase.DISCUSSION
        before = snapshot(night)

        again = send(night, "robber", "onuw:night-action", last)

        assert again.status_code == status.HTTP_409_CONFLICT
        assert again.data["code"] == "wrong_stage"
        assert snapshot(night) == before

    @pytest.mark.parametrize("value", [None, True, False, -1, 1.0, "0", [0], {}])
    def test_chosen_is_required_and_must_be_a_count(self, make_p2, value) -> None:
        night = make_p2(LONE)
        night.start()
        body = choose_body(night, "seer", [])
        if value is None:
            del body["chosen"]
        else:
            body["chosen"] = value
        replies = {n: send(night, n, "onuw:night-action", body) for n in LONE}

        assert {r.status_code for r in replies.values()} == {400}
        assert len({r.content for r in replies.values()}) == 1
        assert all(r.data["code"] == "bad_request" for r in replies.values())
        assert not PlayerRole.objects.filter(game=night.game, has_acted=True).exists()

    def test_a_count_the_server_never_showed_is_bad_request(self, make_p2) -> None:
        night = make_p2(LONE)
        night.start()
        body = choose_body(night, "seer", [])
        body["chosen"] = 1  # the prompt says 0

        reply = send(night, "seer", "onuw:night-action", body)

        assert reply.status_code == status.HTTP_400_BAD_REQUEST
        assert reply.data["code"] == "bad_request"
        assert chosen_now(night, "seer") == 0

    def test_already_chosen_is_left_for_a_choose_on_a_used_up_prompt(
        self, make_p2
    ) -> None:
        """After the fix ``409 already_chosen`` means one thing: a choose that
        answers a prompt whose ``chosen`` already equals ``max_chooses`` (a second
        phone of the same player, a client that ignores its prompt). A resend never
        gets it."""
        night = make_p2(LONE)
        night.start()
        choose(night, "seer", [])
        assert me(night, "seer")["action_prompt"]["chosen"] == 1

        reply = choose(night, "seer", [])  # answers the prompt at chosen 1 of 1

        assert reply.status_code == status.HTTP_409_CONFLICT
        assert reply.data == {
            "detail": "You have already chosen.",
            "code": "already_chosen",
        }


# ── every other stage request ────────────────────────────────────────────────


class TestOtherRequestsResent:
    def test_a_resent_lock_is_answered_alike_and_sends_nothing(self, make_p2) -> None:
        night = make_p2(LONE)
        night.start()
        to_vote(night)
        body = staged(night, {"target_player_id": pid(night, "wolf"), "lock": True})
        first = send(night, "seer", "onuw:vote", body)
        before = snapshot(night)
        events = len(night.recorder.events)

        again = send(night, "seer", "onuw:vote", body)

        # The same answer: the stored lock and the count (the count read again).
        assert first.content == again.content
        assert json.loads(first.content) == {
            "status": "submitted",
            "target_player_id": pid(night, "wolf"),
            "locked": True,
            "progress": {"stage": "vote", "done": 1, "needed": 5},
        }
        assert snapshot(night) == before
        assert len(night.recorder.events) == events  # no second progress

    def test_after_locking_any_other_vote_is_still_refused(self, make_p2) -> None:
        night = make_p2(LONE)
        night.start()
        to_vote(night)
        lock = staged(night, {"target_player_id": pid(night, "wolf"), "lock": True})
        send(night, "seer", "onuw:vote", lock)

        other = staged(night, {"target_player_id": pid(night, "robber"), "lock": True})
        same_pick = staged(
            night, {"target_player_id": pid(night, "wolf"), "lock": False}
        )
        for body in (other, same_pick):
            reply = send(night, "seer", "onuw:vote", body)
            assert reply.status_code == status.HTTP_409_CONFLICT
            assert reply.data["code"] == "vote_locked"
        assert night.role_of("seer").vote_target_id == pid(night, "wolf")

    def test_a_resent_pick_stores_the_same_pick(self, make_p2) -> None:
        night = make_p2(LONE)
        night.start()
        to_vote(night)
        body = staged(night, {"target_player_id": pid(night, "wolf"), "lock": False})
        first = send(night, "seer", "onuw:vote", body)
        before = snapshot(night)

        again = send(night, "seer", "onuw:vote", body)

        assert first.content == again.content
        assert snapshot(night) == before

    def test_a_resent_ready_in_the_talk_changes_nothing(self, make_p2) -> None:
        night = make_p2(LONE)
        night.start()
        to_talk(night)
        for value in (True, False):
            body = staged(night, {"ready": value})
            first = send(night, "seer", "onuw:ready", body)
            before = snapshot(night)
            again = send(night, "seer", "onuw:ready", body)
            assert first.content == again.content
            assert snapshot(night) == before

    def test_a_resent_look_ready_changes_nothing(self, make_p2) -> None:
        night = make_p2(LONE, card_look_seconds=30)
        with night.committed():
            night_flow.begin_night(night.game)
        body = staged(night, {"ready": True})
        first = send(night, "seer", "onuw:ready", body)
        before = snapshot(night)

        again = send(night, "seer", "onuw:ready", body)

        assert first.content == again.content
        assert json.loads(first.content) == {
            "status": "ok",
            "ready": True,
            "progress": {"stage": "look", "done": 1, "needed": 5},
        }
        assert snapshot(night) == before

    def test_a_results_ack_resent_changes_nothing(self, make_p2) -> None:
        night = make_p2(LONE)
        night.start()
        for name in LONE:
            choose(night, name, [player(night, "wolf")] if name == "seer" else [])
        first = send(night, "seer", "onuw:night-results-seen", {"seen": 1})
        before = snapshot(night)

        again = send(night, "seer", "onuw:night-results-seen", {"seen": 1})

        assert first.content == again.content == b'{"night_results_seen":1}'
        assert snapshot(night) == before

    @pytest.mark.parametrize(
        ("url_name", "to_stage"),
        [
            ("onuw:wave-advance", lambda n: None),
            ("onuw:end-discussion", to_talk),
            ("onuw:reveal-votes", to_vote),
        ],
    )
    def test_a_resent_host_button_names_a_stage_that_is_over(
        self, make_p2, url_name, to_stage
    ) -> None:
        night = make_p2(DOPPEL_ROBBER)
        night.start()
        to_stage(night)
        body = staged(night, {})
        assert send(night, "dop", url_name, body).status_code == status.HTTP_200_OK
        before = snapshot(night)

        again = send(night, "dop", url_name, body)

        assert again.status_code == status.HTTP_409_CONFLICT
        assert again.data["code"] == "wrong_stage"
        assert snapshot(night) == before


class TestLobbyRequestsResent:
    """Start and play again are lobby requests (no stage): the Lobby row lock and
    the status check make a copy do nothing."""

    def test_a_resent_start_deals_one_game(self, settings, db) -> None:
        from tests.onuw.test_play_again import Table

        settings.DEBUG = True
        table = Table()
        assert table.start().status_code == status.HTTP_201_CREATED

        again = table.start()

        assert again.status_code == status.HTTP_400_BAD_REQUEST
        assert table.lobby().games.count() == 1

    def test_a_resent_play_again_answers_alike(self, settings, db) -> None:
        from tests.onuw.test_play_again import Table

        settings.DEBUG = True
        table = Table()
        game_id = table.start().data["game_id"]
        Game.objects.filter(id=game_id).update(phase=Phase.RESULTS)
        first = table.play_again()
        lobby = table.lobby()

        again = table.play_again()

        assert first.status_code == again.status_code == status.HTTP_200_OK
        assert first.data == again.data
        assert table.lobby().status == lobby.status
        assert table.lobby().games.count() == 1

    @staticmethod
    def lobby_state(table) -> tuple:
        lobby = table.lobby()
        members = sorted(
            (m.user_id, m.token) for m in LobbyMember.objects.filter(lobby=lobby)
        )
        return lobby.status, lobby.settings, lobby.host_id, members

    def test_a_resent_join_changes_nothing_but_answers_already_in_lobby(
        self, db
    ) -> None:
        """The client treats ``already_in_lobby`` on its own resend as success."""
        from tests.onuw.test_play_again import Table

        table = Table(players=4)
        newcomer = APIClient()  # signed in, at no table yet
        guest = newcomer.post(reverse("core:guest-create"), {}, format="json")
        newcomer.credentials(HTTP_AUTHORIZATION=f"Bearer {guest.data['access']}")
        url = reverse("core:lobby-join", kwargs={"code": table.code})
        assert newcomer.post(url).status_code == status.HTTP_200_OK
        before = self.lobby_state(table)

        again = newcomer.post(url)

        assert again.status_code == status.HTTP_400_BAD_REQUEST
        assert again.data["code"] == "already_in_lobby"
        assert self.lobby_state(table) == before

    def test_a_resent_leave_changes_nothing_but_answers_not_in_lobby(self, db) -> None:
        from tests.onuw.test_play_again import Table

        table = Table()
        url = reverse("core:lobby-leave", kwargs={"code": table.code})
        assert table.clients[-1].post(url).status_code == status.HTTP_200_OK
        before = self.lobby_state(table)

        again = table.clients[-1].post(url)

        assert again.status_code == status.HTTP_400_BAD_REQUEST
        assert self.lobby_state(table) == before

    def test_a_resent_settings_patch_answers_alike(self, db) -> None:
        from tests.onuw.test_play_again import Table

        table = Table()
        detail = reverse("core:lobby-detail", kwargs={"code": table.code})
        for client, url, body, method in (
            (table.host, detail, {"settings": {"pace": "quick"}}, "patch"),
        ):
            first = getattr(client, method)(url, body, format="json")
            before = self.lobby_state(table)
            again = getattr(client, method)(url, body, format="json")
            assert first.status_code == again.status_code == status.HTTP_200_OK
            # The same body, told again: one number higher (telling is the bump).
            assert {**first.data, "rev": 0} == {**again.data, "rev": 0}
            assert again.data["rev"] == first.data["rev"] + 1
            assert self.lobby_state(table) == before


# ── the property: twice is once ──────────────────────────────────────────────


@dataclass(frozen=True)
class Case:
    name: str
    roles: dict[str, str]
    setup: Callable[[Night], None]
    who: str
    url_name: str
    body: Callable[[Night], Any]
    look_stage: bool = False  # the deal opens a look stage, begun by setup


def _w1(night: Night) -> None:
    pass


def _dop_looked(night: Night) -> None:
    choose(night, "dop", [player(night, "robber")])


def _all_but_robber_chose(night: Night) -> None:
    """Every phone with a choice but the Robber's has chosen (the Villager and the
    Hunter have nothing to choose and send nothing)."""
    for name in ("wolf", "seer"):
        choose(night, name, [])


def _look_stage(night: Night) -> None:
    with night.committed():
        night_flow.begin_night(night.game)


def _all_but_villager_looked(night: Night) -> None:
    _look_stage(night)
    for name in ("wolf", "seer", "robber", "hunter"):
        send(night, name, "onuw:ready", staged(night, {"ready": True}))


def _talk_all_but_villager_ready(night: Night) -> None:
    to_talk(night)
    for name in ("wolf", "seer", "robber", "hunter"):
        send(night, name, "onuw:ready", staged(night, {"ready": True}))


def _vote_all_but_villager_locked(night: Night) -> None:
    to_vote(night)
    for name in ("wolf", "seer", "robber", "hunter"):
        target = "seer" if name == "wolf" else "wolf"
        send(
            night,
            name,
            "onuw:vote",
            staged(night, {"target_player_id": pid(night, target), "lock": True}),
        )


def _window_two_closed(night: Night) -> None:
    for name in LONE:
        choose(night, name, [player(night, "wolf")] if name == "seer" else [])


CASES = [
    Case(
        "look",
        DOPPEL_ROBBER,
        _w1,
        "dop",
        "onuw:night-action",
        lambda n: choose_body(n, "dop", [player(n, "robber")]),
    ),
    Case(
        "followup",
        DOPPEL_ROBBER,
        _dop_looked,
        "dop",
        "onuw:night-action",
        lambda n: choose_body(n, "dop", [player(n, "villager")]),
    ),
    Case(
        "window-1 sleeper",
        DOPPEL_ROBBER,
        _w1,
        "wolf",
        "onuw:night-action",
        lambda n: choose_body(n, "wolf", [SELF]),
    ),
    Case(
        "window-2 choose",
        LONE,
        _w1,
        "robber",
        "onuw:night-action",
        lambda n: choose_body(n, "robber", [player(n, "wolf")]),
    ),
    Case(
        "window-2 last choose",
        LONE,
        _all_but_robber_chose,
        "robber",
        "onuw:night-action",
        lambda n: choose_body(n, "robber", []),
    ),
    Case(
        "look ready",
        LONE,
        _look_stage,
        "seer",
        "onuw:ready",
        lambda n: staged(n, {"ready": True}),
        True,
    ),
    Case(
        "last look ready",
        LONE,
        _all_but_villager_looked,
        "villager",
        "onuw:ready",
        lambda n: staged(n, {"ready": True}),
        True,
    ),
    Case(
        "talk ready",
        LONE,
        to_talk,
        "seer",
        "onuw:ready",
        lambda n: staged(n, {"ready": True}),
    ),
    Case(
        "last talk ready",
        LONE,
        _talk_all_but_villager_ready,
        "villager",
        "onuw:ready",
        lambda n: staged(n, {"ready": True}),
    ),
    Case(
        "vote pick",
        LONE,
        to_vote,
        "seer",
        "onuw:vote",
        lambda n: staged(n, {"target_player_id": pid(n, "wolf"), "lock": False}),
    ),
    Case(
        "vote lock",
        LONE,
        to_vote,
        "seer",
        "onuw:vote",
        lambda n: staged(n, {"target_player_id": pid(n, "wolf"), "lock": True}),
    ),
    Case(
        "last vote lock",
        LONE,
        _vote_all_but_villager_locked,
        "villager",
        "onuw:vote",
        lambda n: staged(n, {"target_player_id": pid(n, "wolf"), "lock": True}),
    ),
    Case(
        "results ack",
        LONE,
        _window_two_closed,
        "seer",
        "onuw:night-results-seen",
        lambda n: {"seen": 1},
    ),
    Case(
        "advance window 1",
        DOPPEL_ROBBER,
        _w1,
        "dop",
        "onuw:wave-advance",
        lambda n: staged(n, {}),
    ),
    Case(
        "advance window 2",
        LONE,
        _w1,
        "wolf",
        "onuw:wave-advance",
        lambda n: staged(n, {}),
    ),
    Case(
        "advance the look",
        LONE,
        _look_stage,
        "wolf",
        "onuw:wave-advance",
        lambda n: staged(n, {}),
        True,
    ),
    Case(
        "end the talk",
        LONE,
        to_talk,
        "wolf",
        "onuw:end-discussion",
        lambda n: staged(n, {}),
    ),
    Case(
        "reveal the vote",
        LONE,
        to_vote,
        "wolf",
        "onuw:reveal-votes",
        lambda n: staged(n, {}),
    ),
]


class TestTwiceIsOnce:
    @pytest.mark.parametrize("case", CASES, ids=lambda c: c.name)
    def test_any_request_sent_twice_leaves_the_state_sending_it_once_did(
        self, make_p2, case: Case
    ) -> None:
        night = make_p2(case.roles, card_look_seconds=30 if case.look_stage else 0)
        if not case.look_stage:  # a look stage is begun by its own setup
            night.start()
        case.setup(night)
        body = case.body(night)  # built ONCE: the copy is byte for byte the same

        first = send(night, case.who, case.url_name, body)
        once = snapshot(night)
        second = send(night, case.who, case.url_name, body)

        assert first.status_code == status.HTTP_200_OK, first.data
        assert snapshot(night) == once
        if second.status_code == status.HTTP_200_OK:
            assert second.content == first.content
        else:  # the first copy ended its stage
            assert second.status_code == status.HTTP_409_CONFLICT
            assert second.data["code"] == "wrong_stage"

    @pytest.mark.parametrize("seed", range(12))
    def test_a_whole_seeded_game_with_every_request_resent_ends_as_without(
        self, make_p2, monkeypatch, seed: int
    ) -> None:
        """Random picks for a random Doppelganger table, played twice from the same
        seed: once sending every request once, once sending every request (chooses
        in both windows, ready, locks) and then sending it again. Every copy changes
        nothing, and the two games end the same: cards, log, votes and winners."""
        # The server's Drunk default is seeded by the player id, which differs
        # between the two tables; tie it to the game seed so they are comparable.
        monkeypatch.setattr(
            night_window, "drunk_timeout_center_index", lambda seed_, _pid, n: seed_ % n
        )
        plain = _play_seeded_game(make_p2, seed, "a", resend=False)
        resent = _play_seeded_game(make_p2, seed, "b", resend=True)

        assert resent == plain


def _play_seeded_game(make_p2, seed: int, prefix: str, *, resend: bool) -> dict:
    """Play one seeded game to the results and return its outcome with
    every player id replaced by the player's seat (comparable across tables)."""
    rng = random.Random(seed)  # noqa: S311 (seeded test data, not secret)
    others = ["Robber", "Seer", "Troublemaker", "Drunk", "Werewolf", "Villager"]
    rng.shuffle(others)
    dop = f"{prefix}dop"
    roles = {dop: "Doppelganger"} | {
        f"{prefix}{i}": role for i, role in enumerate(others[:4])
    }
    night = make_p2(roles)
    night.start()
    names = list(roles)
    seat = {pid(night, n): i for i, n in enumerate(names)}

    def random_picks(who: str) -> list:
        board = [player(night, n) for n in names if n != who]
        board += [{"center_index": i} for i in range(3)] + [SELF]
        return rng.sample(board, rng.randint(0, 2))

    def request(who: str, url_name: str, body: Any) -> None:
        first = send(night, who, url_name, body)
        assert first.status_code == status.HTTP_200_OK, (who, body, first.data)
        if not resend:
            return
        once = snapshot(night)
        second = send(night, who, url_name, body)
        assert snapshot(night) == once, (who, body)
        assert second.status_code == 200 or second.data["code"] == "wrong_stage"

    # Window 1: everyone chooses once (her first is the look), then she again.
    order = names[:]
    rng.shuffle(order)
    for who in order:
        request(who, "onuw:night-action", choose_body(night, who, random_picks(who)))
    request(dop, "onuw:night-action", choose_body(night, dop, random_picks(dop)))
    assert {n: chosen_now(night, n) for n in names} == {
        n: 2 if n == dop else 1 for n in names
    }
    night.fire_timer(1)
    assert night.refresh().current_wave == 2

    # Window 2: every phone with a choice chooses (the others send nothing).
    rng.shuffle(order)
    for who in order:
        if night.refresh().phase == Phase.NIGHT and night.turn_open(who):
            body = choose_body(night, who, random_picks(who))
            request(who, "onuw:night-action", body)
    assert night.refresh().phase == Phase.DISCUSSION

    for who in names:
        request(who, "onuw:ready", staged(night, {"ready": True}))
    assert night.refresh().phase == Phase.VOTING
    for who in names:
        target = rng.choice([n for n in names if n != who])
        body = {"target_player_id": pid(night, target), "lock": True}
        request(who, "onuw:vote", staged(night, body))
    game = night.refresh()
    assert game.phase == Phase.RESULTS

    def targets(t: dict) -> dict:
        out = dict(t)
        if "player_id" in out:
            out["player_id"] = seat[out["player_id"]]
        if "player_ids" in out:
            out["player_ids"] = [seat[i] for i in out["player_ids"]]
        return out

    rows = {pr.user_id: pr for pr in PlayerRole.objects.filter(game=game)}
    results = game.results
    return {
        "cards": [rows[pid(night, n)].current_role for n in names],
        "center": list(game.center_cards),
        "log": [
            (
                seat[e["player_id"]],
                e["role_acting_as"],
                e["action_type"],
                targets(e["targets"]),
                e.get("made_by_server", False),
            )
            for e in game.night_actions_log
        ],
        "votes": [seat[rows[pid(night, n)].vote_target_id] for n in names],
        "winning_teams": sorted(results["winning_teams"]),
        "eliminated": sorted(seat[i] for i in results["eliminated_players"]),
        "outcomes": {seat[int(k)]: v for k, v in results["player_outcomes"].items()},
    }
