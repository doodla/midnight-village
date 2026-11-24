"""A late, lost request refused because a newer tap already got there (issue #16).

One three-player table made the way the app makes it, recorded after every other
table (``record_all`` calls it last), so no earlier sample's ids, codes or clocks
move. Each refusal is a request carrying ``asked`` (the phone's tap time) older
than a tap of the same phone the server already applied: the settings PATCH,
ready in the talk, and a vote pick. Each answers ``409 stale_request`` and changes
nothing.
"""

from __future__ import annotations

from .recorder import Recording
from .scenarios import (
    CREATE,
    GAME_READY,
    LOBBY,
    VOTE,
    _choose_night,
    _deal_table,
    _join,
    _player,
    _sign_in,
    _to_vote,
)

THREE = ["Ana", "Ben", "Cleo"]


def asked_table(run: Recording) -> None:
    """The lobby code is the generator's (the run.table() slot and the generator
    are one apart since the account that is gone), so it is taken from the
    create's answer."""
    t = run.table()
    _sign_in(t, THREE)
    created = t.call("POST", "Ana", CREATE, {"game_type": "onuw", "defaults": "v2"})
    t.code = created["code"]
    _join(t, THREE[1:])

    t.call("PATCH", "Ana", LOBBY, {"settings": {"pace": "long"}, "asked": 2000})
    t.record(
        "lobby/settings_stale",
        "PATCH",
        "Ana",
        LOBBY,
        {"settings": {"pace": "quick"}, "asked": 1000},
        status=409,
        about="A settings change tapped before one already applied (`asked` older "
        "than the newest for every key it names): nothing changes, nobody hears.",
    )

    _deal_table(
        t,
        {"Ana": "Seer", "Ben": "Werewolf", "Cleo": "Villager"},
        ["Robber", "Troublemaker", "Villager"],
        again=False,
    )
    _choose_night(t, THREE, {"Ana": [_player(t, "Ben")]})
    t.call("POST", "Ana", GAME_READY, {"ready": False, "asked": 2000})
    t.record(
        "game/ready_stale",
        "POST",
        "Ana",
        GAME_READY,
        {"ready": True, "asked": 1000},
        status=409,
        about="A ready tapped before a newer one already applied in this stage: "
        "nothing changes.",
    )

    _to_vote(t, THREE)
    t.call(
        "POST",
        "Ana",
        VOTE,
        {"target_player_id": t.pid("Ben"), "lock": False, "asked": 2000},
    )
    t.record(
        "game/vote_stale",
        "POST",
        "Ana",
        VOTE,
        {"target_player_id": t.pid("Cleo"), "lock": False, "asked": 1000},
        status=409,
        about="A pick tapped before a newer pick already applied: the newer pick "
        "stays.",
    )
