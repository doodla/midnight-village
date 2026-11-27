"""The game socket's beat repairs what a lost message left undone (``repair.py``).

Phones no longer read ``/me/`` at every stage change, so the lazy repair that rode
on those reads (a lost timer, a lost practice move) must not wait for one. Each
case below is a stage at an UNTIMED table (no deadline, so no phone reads past
one) left waiting for good by a lost message; it ends with no ``GET /me/``, only
the beat of the game's oldest fresh socket. Several players, seeded deals.
"""

from __future__ import annotations

from datetime import timedelta
from typing import Any

from django.db import connection
from django.test.utils import CaptureQueriesContext
from django.urls import reverse
from django.utils import timezone

import pytest

from apps.onuw import repair, voting
from apps.onuw.models import Game, Phase, PlayerRole, SocketPresence
from apps.onuw.protocol import stage_token
from tests.onuw.stages import staged
from tests.onuw.test_night_windows import Night
from tests.onuw.test_practice_players import _deck, table  # noqa: F401 (fixture)

pytestmark = pytest.mark.integration

ROLES = {
    "wolf": "Werewolf",
    "seer": "Seer",
    "robber": "Robber",
    "villager": "Villager",
}


def _socket(game: Game, user: Any, name: str) -> str:
    """A fresh game socket row of ``user`` (what its consumer keeps): its name."""
    now = timezone.now()
    SocketPresence.objects.create(
        channel_name=name, user=user, game=game, connected_at=now, last_seen=now
    )
    return name


def _beat(night: Night, channel: str) -> None:
    """One heartbeat of socket ``channel``, its after-commit work run."""
    with night.committed():
        repair.repair_on_beat(night.game.id, channel)


def _fire(night: Night, key_end: str) -> None:
    key = f"{night.game.id}:{key_end}"
    callbacks = [cb for k, _, cb in night.scheduled if k == key]
    assert callbacks, f"no timer {key}: {[k for k, _, _ in night.scheduled]}"
    with night.committed():
        callbacks[-1]()
    night.refresh()


def test_only_the_games_oldest_fresh_socket_runs_the_repair(make_night) -> None:
    night = make_night(ROLES, night_wave_seconds=30)
    night.start()
    first = _socket(night.game, night.users["seer"], "socket-a")
    second = _socket(night.game, night.users["wolf"], "socket-b")
    assert repair.runs_the_repair(night.game.id, first)
    assert not repair.runs_the_repair(night.game.id, second)


def test_what_a_beat_costs_the_database(make_night) -> None:
    """Every socket's beat asks one question (is it the game's oldest?); only the
    one that is runs the repair, a handful more, whatever the table's size. (The
    frame itself costs nothing; the socket's own presence refresh is separate.)"""
    night = make_night(ROLES, night_wave_seconds=30)
    night.start()
    sockets = [_socket(night.game, u, f"socket-{n}") for n, u in night.users.items()]
    with CaptureQueriesContext(connection) as other:
        repair.repair_on_beat(night.game.id, sockets[-1])
    with CaptureQueriesContext(connection) as oldest:
        repair.repair_on_beat(night.game.id, sockets[0])
    assert len(other) == 1
    assert len(oldest) <= 7, [q["sql"] for q in oldest.captured_queries]


def test_an_untimed_window_whose_deferred_close_was_lost_closes_on_the_beat(
    make_night,
) -> None:
    """Window 2 with no clock and a minimum of 8 s: everyone chose before the
    minimum, so the close was deferred to it, and that timer was lost."""
    night = make_night(ROLES, night_wave_seconds=0, night_min_window_seconds=8)
    night.start()
    night.post("seer", "skip")
    night.post("robber", "skip")
    night.rest_choose()
    assert night.refresh().phase == Phase.NIGHT, "waiting for its minimum"
    night.scheduled.clear()  # the deferred close's message was lost
    night.pretend_window_opened(seconds_ago=10)
    channel = _socket(night.game, night.users["villager"], "socket-v")

    _beat(night, channel)
    _fire(night, "wave:2")

    assert night.game.phase == Phase.DISCUSSION


def test_an_untimed_vote_whose_grace_timer_was_lost_ends_on_the_beat(
    make_night,
) -> None:
    """No clock on the vote: the villager's phone dropped, everyone else locked,
    and the timer that ends the villager's grace period was lost. The table must
    not wait for that phone for good."""
    night = make_night(
        ROLES, night_wave_seconds=30, voting_seconds=0, disconnect_grace_seconds=30
    )
    night.start()
    night.rest_choose()
    night.fire_timer(2)
    with night.committed():
        voting.transition_to_voting(night.refresh())
    assert night.refresh().phase == Phase.VOTING
    villager = night.users["villager"]
    PlayerRole.objects.filter(game=night.game, user=villager).update(
        disconnected_at=timezone.now()
    )
    for name, target in (("wolf", "seer"), ("seer", "wolf"), ("robber", "wolf")):
        night.client.force_authenticate(user=night.users[name])
        body = {"target_player_id": night.users[target].id, "lock": True}
        url = reverse("onuw:vote", kwargs={"game_id": str(night.game.id)})
        with night.committed():
            assert (
                night.client.post(url, staged(night, body), format="json").status_code
                == 200
            )
    assert night.refresh().phase == Phase.VOTING, "waiting for the villager's grace"
    night.scheduled.clear()  # the grace timer's message was lost
    PlayerRole.objects.filter(game=night.game, user=villager).update(
        disconnected_at=timezone.now() - timedelta(seconds=31)
    )
    channel = _socket(night.game, night.users["wolf"], "socket-w")

    _beat(night, channel)
    _fire(night, f"grace:{villager.id}")

    assert night.game.phase == Phase.RESULTS


def test_a_practice_move_lost_at_an_untimed_talk_is_made_on_the_beat(
    table,  # noqa: F811
) -> None:
    """At a table with practice players and no clock on the talk, the practice
    players' "ready" at the talk's opening was lost (``practice.drive`` failed):
    the people are ready and the count stays short of the table for good."""
    t = table(
        ["Ana", "Ben"],
        discussion_seconds=0,
        **_deck(Werewolf=1, Seer=1, Robber=1, Villager=3, Tanner=1),
    )
    t.practice(count=2)
    ana, ben = t.people["Ana"].pk, t.people["Ben"].pk
    b1, b2 = t.practice_ids()
    t.deal(
        {ana: "Villager", ben: "Seer", b1: "Werewolf", b2: "Robber"},
        ["Villager", "Villager", "Tanner"],
    )
    t.ready("Ana")
    t.ready("Ben")
    t.choose("Ben", [{"player_id": b1}])
    assert t.refresh().phase == Phase.DISCUSSION
    # The practice players' move at the talk's opening was lost.
    PlayerRole.objects.filter(game=t.game, user_id__in=[b1, b2]).update(
        phase_ready=False
    )
    # The people tap "ready to vote" (the app sends the stage it holds; it reads
    # no /me/ for it, so the old repair on that read never runs).
    stage = stage_token(t.refresh())
    for name in ("Ana", "Ben"):
        t.post(name, t.url("ready"), {"ready": True, "stage": stage})
    assert t.refresh().phase == Phase.DISCUSSION, "waiting for the practice players"
    now = timezone.now()
    SocketPresence.objects.create(
        channel_name="socket-ana",
        user=t.people["Ana"],
        game=t.game,
        connected_at=now,
        last_seen=now,
    )

    with t.committed():
        repair.repair_on_beat(t.game.id, "socket-ana")

    assert t.refresh().phase == Phase.VOTING
