"""
The night as a timeline: who did what, in wake order, and where every card was
after each step.

NO Django imports allowed in this module. This is pure game logic.

The timeline is built FORWARDS from the cards as dealt and the night log, so the
client only draws (it computes nothing). Every physical card gets a stable id
(``k0``..``k<n-1>`` by seat, then ``k<n>``..``k<n+2>`` for the centre), so two
Werewolves or two Masons still have distinct paths. There is no randomness.

Games dealt before the dealt centre was stored have to recover it:
``recover_dealt_center`` undoes the logged swaps from the final table and refuses
(``TimelineError``) if the players' cards it arrives at are not the roles they
were dealt, because then the log cannot be trusted to describe the night.
"""

from __future__ import annotations

from typing import Any

from .roles import window_for_order_group

# A row's team is shown for roles that wake together (the actors are the team).
_TEAM_ROLES = ("Werewolf", "Mason")


class TimelineError(ValueError):
    """The night log cannot be turned into a timeline (malformed or inconsistent)."""


# --- undo (games dealt before dealt_center_cards existed) --------------------


def _swap_pairs(entry: dict[str, Any]) -> list[tuple[Any, Any]]:
    """The position swaps an entry made: each side is a player id or ("c", index)."""
    action = entry.get("action_type")
    actor = entry.get("player_id")
    targets = entry.get("targets") or {}
    try:
        if action == "swap_with_player":
            return [(actor, int(targets["player_id"]))]
        if action == "swap_others":
            first, second = targets["player_ids"]
            return [(int(first), int(second))]
        if action == "swap_with_center":
            return [(actor, ("c", int(targets["center_index"])))]
    except (KeyError, TypeError, ValueError) as exc:
        raise TimelineError("A night action has unusable targets.") from exc
    return []


def undo_to_dealt(
    final_players: dict[int, str], final_center: list[str], log: list[dict[str, Any]]
) -> tuple[dict[int, str], list[str]]:
    """The roles as dealt, found by undoing the logged swaps from the final table.

    Every swap is its own inverse, so undoing is replaying them in reverse order.
    Returns (role per player, centre roles).
    """
    players = dict(final_players)
    center = list(final_center)

    def get(side: Any) -> str:
        return center[side[1]] if isinstance(side, tuple) else players[side]

    def put(side: Any, role: str) -> None:
        if isinstance(side, tuple):
            center[side[1]] = role
        else:
            players[side] = role

    for entry in reversed(log):
        for one, other in _swap_pairs(entry):
            try:
                a, b = get(one), get(other)
            except (KeyError, IndexError) as exc:
                raise TimelineError("A swap names a card that is not there.") from exc
            put(one, b)
            put(other, a)
    return players, center


def recover_dealt_center(
    original_roles: dict[int, str],
    final_players: dict[int, str],
    final_center: list[str],
    log: list[dict[str, Any]],
) -> list[str]:
    """The centre as dealt, for a game that did not store it, or ``TimelineError``.

    The players' cards that undoing arrives at must equal each player's dealt
    role; if they do not, the log does not describe this game.
    """
    players, center = undo_to_dealt(final_players, final_center, log)
    if players != original_roles:
        raise TimelineError("The night log does not lead back to the dealt cards.")
    return center


# --- forward replay -----------------------------------------------------------


def _where(side: Any) -> dict[str, int]:
    return {"center_index": side[1]} if isinstance(side, tuple) else {"player_id": side}


class _Table:
    """Which card is where, and the moves that change it."""

    def __init__(self, seats: list[int], center_ids: list[str]) -> None:
        self.players: dict[int, str] = {uid: f"k{i}" for i, uid in enumerate(seats)}
        self.center: list[str] = list(center_ids)

    def card_at(self, side: Any) -> str:
        try:
            return (
                self.center[side[1]] if isinstance(side, tuple) else self.players[side]
            )
        except (KeyError, IndexError) as exc:
            raise TimelineError(
                "A night action names a card that is not there."
            ) from exc

    def _put(self, side: Any, card: str) -> None:
        if isinstance(side, tuple):
            self.center[side[1]] = card
        else:
            self.players[side] = card

    def swap(self, one: Any, other: Any) -> list[dict[str, Any]]:
        first, second = self.card_at(one), self.card_at(other)
        self._put(one, second)
        self._put(other, first)
        return [
            {"card_id": first, "from": _where(one), "to": _where(other)},
            {"card_id": second, "from": _where(other), "to": _where(one)},
        ]

    def snapshot(self) -> dict[str, Any]:
        return {
            "players": {str(uid): card for uid, card in self.players.items()},
            "center": list(self.center),
        }


def _center_look(table: _Table, index: Any) -> dict[str, Any]:
    side = ("c", int(index))
    return {"center_index": side[1], "card_id": table.card_at(side)}


def _player_look(table: _Table, uid: Any) -> dict[str, Any]:
    return {"player_id": int(uid), "card_id": table.card_at(int(uid))}


def _action(entry: dict[str, Any]) -> str:
    """The timeline's name for what a log entry did."""
    action = entry.get("action_type")
    role = entry.get("role_acting_as")
    targets = entry.get("targets") or {}
    if role == "Doppelganger" and action == "peek_player":
        return "copy"
    if action == "see_team" and targets.get("center_index") is not None:
        return "peek_center"  # a lone Werewolf's look at one centre card
    if action == "none" and role == "Insomniac":
        return "look_own"
    if action in (
        "see_team",
        "skip",
        "peek_player",
        "peek_center",
        "swap_with_player",
        "swap_others",
        "swap_with_center",
    ):
        return action
    raise TimelineError("A night action is not one the timeline knows.")


def _apply(
    table: _Table, entry: dict[str, Any], action: str
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    """Apply one log entry to the table: (looked_at, moves). Looks use the table
    as it is BEFORE this entry moves anything."""
    actor = entry["player_id"]
    targets = entry.get("targets") or {}
    try:
        if action == "copy" or action == "peek_player":
            return [_player_look(table, targets["player_id"])], []
        if action == "peek_center":
            if "center_indices" in targets:
                return [_center_look(table, i) for i in targets["center_indices"]], []
            return [_center_look(table, targets["center_index"])], []
        if action == "look_own":
            return [{"player_id": actor, "card_id": table.card_at(actor)}], []
        if action == "swap_with_player":
            target = int(targets["player_id"])
            looked = _player_look(table, target)  # the card the Robber takes
            return [looked], table.swap(actor, target)
        if action == "swap_others":
            first, second = (int(x) for x in targets["player_ids"])
            return [], table.swap(first, second)
        if action == "swap_with_center":
            return [], table.swap(actor, ("c", int(targets["center_index"])))
    except (KeyError, TypeError, ValueError) as exc:
        raise TimelineError("A night action has unusable targets.") from exc
    return [], []  # see_team, skip


def _seen_players(entry: dict[str, Any]) -> list[int]:
    result = entry.get("result") or {}
    seen = result.get("werewolves", []) or result.get("masons", [])
    return [int(uid) for uid in seen]


def _row(
    entry: dict[str, Any], action: str, original_roles: dict[int, str]
) -> dict[str, Any]:
    try:
        order_group = int(entry["wave"])
        window = window_for_order_group(order_group)
    except (KeyError, TypeError, ValueError) as exc:
        raise TimelineError("A night action has no usable window.") from exc
    role = entry.get("role_acting_as") or ""
    if not role:
        raise TimelineError("A night action does not say which role acted.")
    actor = entry["player_id"]
    return {
        "window": window,
        "order_group": order_group,
        "role": role,
        "doppelganger": original_roles.get(actor) == "Doppelganger",
        "actors": [actor],
        "action": action,
        "made_by_server": bool(entry.get("made_by_server", False)),
        "looked_at": [],
        "team": [],
        "copied_role": (entry.get("result") or {}).get("copied_role")
        if action == "copy"
        else None,
        "moves": [],
    }


def _merge_team_rows(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Consecutive ``see_team`` rows of one role wake together: one row, several
    actors ("Werewolves wake"). A Doppelganger who copied the role stays on a row
    of her own (right after the real ones), so her row can say she copied it."""
    merged: list[dict[str, Any]] = []
    index = 0
    while index < len(rows):
        row = rows[index]
        if row["action"] != "see_team":
            merged.append(row)
            index += 1
            continue
        run = [row]
        while (
            index + len(run) < len(rows)
            and rows[index + len(run)]["action"] == "see_team"
            and rows[index + len(run)]["role"] == row["role"]
        ):
            run.append(rows[index + len(run)])
        index += len(run)
        for doppelganger in (False, True):
            part = [r for r in run if r["doppelganger"] is doppelganger]
            if not part:
                continue
            first = dict(part[0])
            first["actors"] = [a for r in part for a in r["actors"]]
            first["team"] = sorted(
                {a for r in part for a in r["team"]}
                | (set(first["actors"]) if first["role"] in _TEAM_ROLES else set())
            )
            first["positions_after"] = part[-1]["positions_after"]
            merged.append(first)
    return merged


def build_night_timeline(
    seats: list[int],
    original_roles: dict[int, str],
    dealt_center: list[str],
    log: list[dict[str, Any]],
) -> dict[str, Any]:
    """The night, step by step, from the dealt cards and the night log.

    ``seats`` lists the player ids in seat order; ``original_roles`` the card each
    was dealt; ``dealt_center`` the centre as dealt; ``log`` the night log in the
    order the engine resolved it (wake order). Raises ``TimelineError`` if the log
    names a card that is not there or an action the timeline does not know.
    """
    if set(seats) != set(original_roles) or len(set(seats)) != len(seats):
        raise TimelineError("The players do not match the dealt cards.")
    n = len(seats)
    center_ids = [f"k{n + j}" for j in range(len(dealt_center))]
    roles = [original_roles[uid] for uid in seats] + list(dealt_center)
    table = _Table(seats, center_ids)
    dealt = table.snapshot()

    rows: list[dict[str, Any]] = []
    for entry in log:
        action = _action(entry)
        row = _row(entry, action, original_roles)
        row["looked_at"], row["moves"] = _apply(table, entry, action)
        if action == "see_team":
            row["team"] = _seen_players(entry)
        row["positions_after"] = table.snapshot()
        rows.append(row)

    steps = _merge_team_rows(rows)
    for number, step in enumerate(steps, start=1):
        step["step"] = number

    final = table.snapshot()
    return {
        "seats": list(seats),
        "cards": [
            {"card_id": f"k{i}", "role": role, "werewolf": role == "Werewolf"}
            for i, role in enumerate(roles)
        ],
        "dealt": dealt,
        "steps": [
            {key: step[key] for key in _STEP_KEYS if key in step} for step in steps
        ],
        "final": final,
        "center_moved": [
            a != b for a, b in zip(dealt["center"], final["center"], strict=True)
        ],
    }


_STEP_KEYS = (
    "step",
    "window",
    "order_group",
    "role",
    "doppelganger",
    "actors",
    "action",
    "made_by_server",
    "looked_at",
    "team",
    "copied_role",
    "moves",
    "positions_after",
)
