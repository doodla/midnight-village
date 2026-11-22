"""
No length a host can set freezes a game.

The set-up page offers every length within ``length_ranges`` (the rule table the
settings check uses). For several stored tables, each length is set to each end of
its range, the check takes it, and a whole game is played with one phone dead from
the start: the others look, choose nothing, get ready and vote; whenever nobody has
anything left to do, the timers the game scheduled fire. The game must reach the
results. (Talk or Vote at 0 has no clock; with Dropped phone at 0 nobody is ever
counted gone; the pair would wait for the dead phone for good, so the rules refuse
it.)
"""

from __future__ import annotations

from datetime import timedelta
from typing import Any

from django.utils import timezone

import pytest

from apps.onuw import services
from apps.onuw.engine.validation import (
    TIMER_SETTING_KEYS,
    length_errors,
    length_ranges,
)
from apps.onuw.models import Game, Phase, PlayerRole
from apps.onuw.protocol import in_look_stage, stage_token

pytestmark = pytest.mark.django_db

STORED = {
    "defaults": {},
    "no grace": {"disconnect_grace_seconds": 0},
    "no talk clock": {"discussion_seconds": 0},
    "untimed night and vote": {"night_wave_seconds": 0, "voting_seconds": 0},
    "a look and short windows": {
        "card_look_seconds": 20,
        "night_wave_seconds": 6,
        "night_min_window_seconds": 6,
    },
}

ROLES = {"Ana": "Seer", "Ben": "Robber", "Cleo": "Werewolf", "Dev": "Villager"}
DEAD = "Dev"


def _cases() -> list[Any]:
    cases = []
    for state_name, stored in STORED.items():
        ranges = length_ranges(stored, allow_untimed=True)
        for key in TIMER_SETTING_KEYS:
            for end, value in zip(("least", "most"), ranges[key], strict=True):
                cases.append(
                    pytest.param(
                        {**stored, key: value}, key, id=f"{state_name}-{key}-{end}"
                    )
                )
    return cases


def _snapshot(game: Game) -> tuple[Any, ...]:
    return (game.phase, game.current_wave, in_look_stage(game), stage_token(game))


def _live_players_act(night: Any) -> None:
    """Everyone but the dead phone does their part in the stage open now."""
    game = night.refresh()
    live = [name for name in ROLES if name != DEAD]
    if in_look_stage(game):
        for name in live:
            with night.committed():
                services.set_ready(
                    game, night.users[name].id, True, stage=stage_token(game)
                )
            game = night.refresh()
            if not in_look_stage(game):
                return
    elif game.phase == Phase.NIGHT:
        for name in live:
            if night.refresh().phase != Phase.NIGHT:
                return
            if night.turn_open(name):
                night.choose(name)
    elif game.phase == Phase.DISCUSSION:
        for name in live:
            game = night.refresh()
            if game.phase != Phase.DISCUSSION:
                return
            with night.committed():
                services.set_ready(
                    game, night.users[name].id, True, stage=stage_token(game)
                )
    elif game.phase == Phase.VOTING:
        names = list(ROLES)
        for i, name in enumerate(live):
            game = night.refresh()
            if game.phase != Phase.VOTING:
                return
            target = night.users[names[(i + 1) % len(names)]].id
            with night.committed():
                services.submit_vote(
                    game,
                    night.users[name].id,
                    target,
                    lock=True,
                    stage=stage_token(game),
                )


@pytest.mark.parametrize(("settings", "key"), _cases())
def test_a_game_with_a_dead_phone_still_finishes(make_night, settings, key) -> None:
    assert length_errors(settings, {key}, allow_untimed=True) == [], (key, settings)
    night = make_night(ROLES, **settings)
    PlayerRole.objects.filter(game=night.game, user=night.users[DEAD]).update(
        disconnected_at=timezone.now() - timedelta(hours=2)
    )
    with night.committed():
        services.begin_night(night.game)
    fired = 0
    for _ in range(60):
        game = night.refresh()
        if game.phase == Phase.RESULTS:
            return
        before = _snapshot(game)
        _live_players_act(night)
        if _snapshot(night.refresh()) != before:
            continue
        # Nobody has anything left to do: the clocks the game set run out.
        pending = night.scheduled[fired:]
        assert pending, f"frozen at {before} with {settings}"
        fired = len(night.scheduled)
        for _, _, job in pending:
            with night.committed():
                job()
    pytest.fail(f"never reached the results with {settings}")
