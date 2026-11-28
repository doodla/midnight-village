"""The beat token's ``moved_on``: the only thing that frees a phone stuck on the
results screen after its ``play_again`` frame was lost (the results have no
deadline to heal it). One table of (what happened, expected token of the first
game), each row read through both token paths, ``beat.refresh`` (every beat)
and ``beat.token`` (a socket opening), which must agree for every seat.
"""

from __future__ import annotations

from collections.abc import Callable

from django.utils import timezone

import pytest

from apps.onuw import beat
from apps.onuw.models import Game, Phase, SocketPresence
from tests.onuw.test_play_again import Table, table  # noqa: F401 (fixture)

pytestmark = pytest.mark.integration


def _sockets(game_id: str, user_ids: list[int]) -> list[str]:
    """A fresh game socket row for every seat of ``game_id``: their names."""
    now = timezone.now()
    names = []
    for user_id in user_ids:
        name = f"socket-{game_id}-{user_id}"
        SocketPresence.objects.create(
            channel_name=name,
            user_id=user_id,
            game_id=game_id,
            connected_at=now,
            last_seen=now,
        )
        names.append(name)
    return names


def _both_paths(game_id: str, names: list[str]) -> dict:
    """The game's token as every socket's beat reads it, and as an opening
    socket reads it: all the same, or the test fails."""
    opened = beat.token(game_id)
    beats = [beat.refresh(name, elect=False).token for name in names]
    assert beats == [opened] * len(names), "the two token paths disagree"
    assert opened is not None
    return opened


def test_moved_on_is_false_at_the_results_and_true_once_the_table_moves_on(
    table: Table,  # noqa: F811 (fixture)
) -> None:
    first = table.play_to_results(seed=11)
    names = _sockets(first, table.ids)
    later: dict[str, str] = {}

    def deal() -> None:
        response = table.start(seed=12)
        assert response.status_code == 201, response.data
        later["game"] = response.data["game_id"]

    def finish_the_later_game() -> None:
        # The lobby is finished again: only the newer game says it moved on.
        table.finish_game(later["game"])

    steps: list[tuple[str, Callable[[], object], bool]] = [
        ("at the results", lambda: None, False),
        ("after play again", table.play_again, True),
        ("after a later deal", deal, True),
        ("after the later game ends too", finish_the_later_game, True),
    ]
    for what, happen, moved_on in steps:
        happen()
        token = _both_paths(first, names)
        assert token == {
            "phase": Phase.RESULTS,
            "window": Game.objects.get(id=first).current_wave,
            "moved_on": moved_on,
        }, what

    # The later game, at its own results, is the table's: not moved on.
    assert table.lobby().status == "finished"
    later_names = _sockets(later["game"], table.ids)
    assert _both_paths(later["game"], later_names)["moved_on"] is False
