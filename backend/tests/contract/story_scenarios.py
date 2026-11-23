"""The night's stories the app shows: one talk ``/me/`` per kind of night result,
and the results of games with a Doppelganger who copied a role that moves cards.

One seven-player table made the way the app makes it (``defaults: "v2"``, every
timer on), played game after game by play again. Recorded after every other
table (``record_all`` calls it last), so no earlier sample's ids, codes or
clocks move.

Each game is dealt so that the player recorded is the case named:

- a village night: a Troublemaker swaps a Werewolf with the Insomniac (who
  then sees her new card), a Seer looks at two centre cards, a lone Mason, a
  Hunter and a Tanner;
- no Werewolf among the players: the Minion sees none, the Seer lets her
  window run out (no choose at all), the table votes out a Villager;
- a Doppelganger per copied role (Troublemaker, Robber, Drunk with a chosen
  centre card and timed out, Werewolf, Insomniac, Villager) and one whose look
  timed out. Window 1 ends on its fixed timer, as at any timed table.
"""

from __future__ import annotations

from .recorder import Recording, Table
from .scenarios import (
    CREATE,
    ME,
    _choose,
    _deal_table,
    _join,
    _lock_votes,
    _player,
    _record_results,
    _rest_choose,
    _sign_in,
    _to_vote,
)

SEVEN = ["Ana", "Ben", "Cleo", "Dev", "Esme", "Fin", "Gus"]


def story_tables(run: Recording) -> None:
    """Every game of the story table, in order."""
    t = _story_lobby(run)
    _village_night(t)
    _no_werewolf_night(t)
    for copied in DOPPELGANGER_GAMES:
        _doppelganger_game(t, *copied)


def _story_lobby(run: Recording) -> Table:
    """Seven players at a table made the way the app makes it. The lobby code is
    the generator's (the run.table() slot and the generator are one apart since
    the account that is gone), so it is taken from the create's answer."""
    t = run.table()
    _sign_in(t, SEVEN)
    created = t.call("POST", "Ana", CREATE, {"game_type": "onuw", "defaults": "v2"})
    t.code = created["code"]
    _join(t, SEVEN[1:])
    return t


def _talk_me(t: Table, who: str, kind: str, about: str) -> None:
    t.record(
        f"game/me_discussion_choose_{kind}",
        "GET",
        who,
        ME,
        status=200,
        about=f"/me/ in the talk: {about}",
    )


def _window_2(t: Table, picks: dict[str, list[dict]], *, silent: str = "") -> None:
    """Window 2: the phones in ``picks`` choose them, every other phone with a
    choice chooses nothing, except ``silent``, who sends no choose at all; the
    window ends on its timer."""
    t.clock.advance(5)
    for name, chosen in picks.items():
        _choose(t, name, chosen)
    _rest_choose(t, [n for n in SEVEN if n not in picks and n != silent])
    t.clock.advance(5)
    t.fire("{game_id}:wave:2")


def _finish(t: Table, out: str) -> None:
    """The talk, then everyone votes ``out`` (who votes for Gus, or Ben when
    ``out`` is Gus)."""
    other = "Ben" if out == "Gus" else "Gus"
    _to_vote(t, SEVEN)
    _lock_votes(t, {n: (other if n == out else out) for n in SEVEN})


def _village_night(t: Table) -> None:
    dealt = {
        "Ana": "Troublemaker",
        "Ben": "Seer",
        "Cleo": "Werewolf",
        "Dev": "Insomniac",
        "Esme": "Mason",
        "Fin": "Hunter",
        "Gus": "Tanner",
    }
    _deal_table(t, dealt, ["Mason", "Villager", "Werewolf"], again=False)
    _window_2(
        t,
        {
            "Ana": [_player(t, "Cleo"), _player(t, "Dev")],
            "Ben": [{"center_index": 0}, {"center_index": 2}],
        },
    )
    # The Troublemaker's talk /me/ is recorded by the plain choose table
    # (scenarios.py, me_discussion_choose_troublemaker): not again here.
    _talk_me(t, "Ben", "seer_center", "a dealt Seer who looked at two centre cards.")
    _talk_me(
        t,
        "Dev",
        "insomniac_changed",
        "the Insomniac whose card was swapped in the night (she now holds a Werewolf).",
    )
    _talk_me(
        t, "Esme", "mason_lone", "a Mason whose fellow Mason card is in the centre."
    )
    _talk_me(t, "Fin", "hunter", "the Hunter (no night action).")
    _talk_me(t, "Gus", "tanner", "the Tanner (no night action).")
    _finish(t, "Dev")


def _no_werewolf_night(t: Table) -> None:
    dealt = {
        "Ana": "Seer",
        "Ben": "Minion",
        "Cleo": "Villager",
        "Dev": "Villager",
        "Esme": "Mason",
        "Fin": "Mason",
        "Gus": "Hunter",
    }
    _deal_table(t, dealt, ["Werewolf", "Werewolf", "Villager"])
    _window_2(t, {}, silent="Ana")
    _talk_me(
        t,
        "Ben",
        "minion_no_werewolves",
        "a Minion who sees no Werewolf (both are in the centre).",
    )
    _talk_me(
        t,
        "Ana",
        "seer_timed_out",
        "a Seer who sent no choose; her window ended on its timer.",
    )
    _finish(t, "Cleo")
    _record_results(
        t,
        "results_minion_no_werewolves",
        "No Werewolf among the players: the Minion saw none, and the table votes "
        "out a Villager, so the Minion (Werewolf team) wins.",
    )


# (copied role, dealt to Ben, the follow-up she sends in window 1 or None,
#  the sample's kind, what it shows, who is voted out, the results sample or "")
DOPPELGANGER_GAMES: list[tuple[str, list[dict] | None, str, str, str, str]] = [
    (
        "Troublemaker",
        [{"player": "Cleo"}, {"player": "Esme"}],
        "troublemaker",
        "she copied the Troublemaker and swapped a Werewolf with a Villager.",
        "Esme",
        "results_doppelganger_troublemaker",
    ),
    (
        "Robber",
        [{"player": "Cleo"}],
        "robber",
        "she copied the Robber and robbed a Werewolf.",
        "Ana",
        "results_doppelganger_robber",
    ),
    (
        "Drunk",
        [{"center_index": 1}],
        "drunk",
        "she copied the Drunk and swapped with a centre card she chose.",
        "Cleo",
        "results_doppelganger_drunk",
    ),
    (
        "Drunk",
        None,
        "drunk_timed_out",
        "she copied the Drunk and chose no centre card: the server swapped her.",
        "Cleo",
        "",
    ),
    (
        "Werewolf",
        None,
        "werewolf",
        "she copied a Werewolf and woke with the Werewolves.",
        "Dev",
        "",
    ),
    (
        "Insomniac",
        None,
        "insomniac",
        "she copied the Insomniac and looked at her own card at the end.",
        "Cleo",
        "results_doppelganger_insomniac",
    ),
    (
        "Villager",
        None,
        "villager",
        "she copied a Villager (nothing more to do).",
        "Cleo",
        "",
    ),
    (
        "",
        None,
        "look_timed_out",
        "she sent no look; window 1 ended on its timer and she copied nobody.",
        "Cleo",
        "",
    ),
]


def _doppelganger_game(
    t: Table,
    copied: str,
    followup: list[dict] | None,
    kind: str,
    about: str,
    out: str,
    results: str,
) -> None:
    """Ana is dealt the Doppelganger and looks at Ben (dealt ``copied``), or
    sends nothing when ``copied`` is empty; Cleo is the Werewolf at the table."""
    dealt = {
        "Ana": "Doppelganger",
        "Ben": copied or "Seer",
        "Cleo": "Werewolf",
        "Dev": "Villager",
        "Esme": "Villager",
        "Fin": "Mason",
        "Gus": "Mason",
    }
    if copied == "Villager":
        dealt["Dev"] = "Seer"
    if copied == "Werewolf":
        dealt["Cleo"] = "Seer"
    _deal_table(t, dealt, ["Werewolf", "Villager", "Tanner"])
    t.clock.advance(3)
    if copied:
        _choose(t, "Ana", [_player(t, "Ben")])
    if followup is not None:
        _choose(t, "Ana", [_pick(t, p) for p in followup])
    t.clock.advance(7)
    t.fire("{game_id}:wave:1")
    _window_2(t, {})
    _talk_me(t, "Ana", f"doppelganger_{kind}", about)
    _finish(t, out)
    if results:
        _record_results(t, results, f"A game where {about}")


def _pick(t: Table, pick: dict) -> dict:
    """A follow-up pick: a player by name, or a centre card as sent."""
    if "player" in pick:
        return _player(t, pick["player"])
    return pick
