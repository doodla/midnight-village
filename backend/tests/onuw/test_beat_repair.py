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
from unittest.mock import patch

from django.db import connection
from django.test.utils import CaptureQueriesContext
from django.urls import reverse
from django.utils import timezone

import pytest

from apps.observe import counts
from apps.onuw import beat, voting
from apps.onuw.consumers import GameConsumer
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


def _consumer(game: Game, user: Any, channel: str) -> GameConsumer:
    """A game socket's consumer as connect leaves it (its row is ``channel``)."""
    consumer = GameConsumer()
    consumer.game_id = str(game.id)
    consumer.user_id = user.id
    consumer.channel_name = channel
    return consumer


def _beat_of(consumer: GameConsumer, committed: Any) -> bool:
    """One heartbeat's database work of ``consumer`` (``_beat_work``), its
    after-commit work run."""
    with committed():
        return consumer._beat_work()


def _beat(night: Night, channel: str) -> None:
    """One heartbeat of socket ``channel`` (its row's user's consumer)."""
    row = SocketPresence.objects.get(channel_name=channel)
    _beat_of(_consumer(night.game, row.user, channel), night.committed)


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
    assert beat.refresh(first, elect=True).oldest
    assert not beat.refresh(second, elect=True).oldest
    assert not beat.refresh(first, elect=False).oldest, "not asked: not told"


def test_the_beat_token_is_where_the_table_is_the_same_for_every_socket(
    make_night,
) -> None:
    """``phase`` and ``window`` as the table's events say them, ``moved_on`` false
    while the game is the table's; every socket of the game reads the same."""
    night = make_night(ROLES, night_wave_seconds=30)
    night.start()
    names = [_socket(night.game, u, f"socket-{n}") for n, u in night.users.items()]
    tokens = [beat.refresh(name, elect=True).token for name in names]
    game = night.refresh()
    expected = {"phase": game.phase, "window": game.current_wave, "moved_on": False}
    assert tokens == [expected] * len(names)
    assert beat.token(game.id) == expected


def test_what_a_beat_costs_the_database(make_night) -> None:
    """A beat is the presence refresh's own two queries (its row, with the
    election and the table's token in the same statement, and the presence
    check's timer), as on main; only the game's oldest socket adds the repair, a
    handful more, whatever the table's size. The frame itself costs nothing."""
    night = make_night(ROLES, night_wave_seconds=30)
    night.start()
    sockets = [
        (_socket(night.game, u, f"socket-{n}"), u) for n, u in night.users.items()
    ]
    consumers = [_consumer(night.game, u, name) for name, u in sockets]
    with CaptureQueriesContext(connection) as other:
        consumers[-1]._beat_work()
    with CaptureQueriesContext(connection) as oldest:
        consumers[0]._beat_work()
    assert len(other) == 2, [q["sql"] for q in other.captured_queries]
    assert len(oldest) == 2 + 6, [q["sql"] for q in oldest.captured_queries]


def test_a_failing_repair_still_refreshes_the_row_and_is_counted(make_night) -> None:
    """The presence first, the repair after it: a repair that fails leaves this
    socket counted as connected, and the owner's report counts it (a closed
    word, no ids)."""
    night = make_night(ROLES, night_wave_seconds=30)
    night.start()
    name = _socket(night.game, night.users["seer"], "socket-s")
    old = timezone.now() - timedelta(seconds=30)
    SocketPresence.objects.filter(channel_name=name).update(last_seen=old)
    with patch("apps.onuw.repair.ensure_timers", side_effect=RuntimeError("down")):
        _beat(night, name)
    assert SocketPresence.objects.get(channel_name=name).last_seen > old
    assert counts.totals() == {"repair_failed": 1}


def test_at_the_results_a_beat_elects_and_repairs_nothing(make_night) -> None:
    """Once its game is at the results a socket's beat is its row alone: nothing
    is left to repair, so it stops asking."""
    night = make_night(ROLES, night_wave_seconds=30)
    night.start()
    name = _socket(night.game, night.users["seer"], "socket-s")
    consumer = _consumer(night.game, night.users["seer"], name)
    Game.objects.filter(pk=night.game.pk).update(phase=Phase.RESULTS)
    with patch("apps.onuw.repair.repair_on_beat") as repaired:
        consumer._beat_work()
        consumer._beat_work()
    repaired.assert_not_called()
    assert consumer._at_results
    token = consumer._beat_token
    assert token is not None and token["phase"] == Phase.RESULTS


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

    _beat_of(_consumer(t.game, t.people["Ana"], "socket-ana"), t.committed)

    assert t.refresh().phase == Phase.VOTING
