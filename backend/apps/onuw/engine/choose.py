"""
The night as one ``choose``: how the server reads what a phone picked.

Under night protocol 2 every phone sends the same thing, ``choose`` with 0 to 2
ordered picks, whatever its role, and the server alone decides what the picks mean
for the role the player acts as. A pick that holds no valid action for the role is
not an error: it reads as "nothing", and the window close then gives the role its
timeout default (a Drunk is swapped by the server, a lone Werewolf still sees that
it is alone, a Seer / Robber / Troublemaker / Doppelganger look is skipped, team
views and the Insomniac still happen). The phone is never told which.

The reading table (``docs/specs/frontend/first-time-play.md``, "How the server reads
a ``choose``"). The first valid action in tap order wins; "You" is never a target:

=====================  =======================================================
Acting as              The picks mean
=====================  =======================================================
Seer                   first two picks both centre cards: look at both;
                       otherwise the first other player: look at that card
Robber                 the first other player: swap
Troublemaker           the first two picks are two other players: swap them
Drunk                  the first centre card: swap
Lone Werewolf          the first centre card: look at it
Doppelganger's look    the first other player: copy
Everyone else          nothing (sleep; automatic results still happen)
=====================  =======================================================

NO Django imports allowed in this module. This is pure game logic.
"""

from __future__ import annotations

from collections.abc import Collection
from dataclasses import dataclass
from typing import Any, Literal

from .behaviors import is_effective_werewolf
from .state import GameState

PickKind = Literal["player", "center", "self"]

MAX_PICKS = 2
# How many ``choose`` a phone may send in a night window. Window 1 takes two from
# every phone (the Doppelganger's look, then her follow-up, so a second tap is not a
# tell); window 2 takes exactly one.
MAX_CHOOSES = {1: 2, 2: 1}


def max_chooses(window: int) -> int:
    """How many ``choose`` a phone may send in this night window."""
    return MAX_CHOOSES.get(window, 0)


@dataclass(frozen=True)
class Pick:
    """One tapped card: another player's, a centre card, or the player's own."""

    kind: PickKind
    value: int = 0  # the player id or the centre index; unused for "self"


@dataclass(frozen=True)
class Interpretation:
    """The engine action a ``choose`` means for a role."""

    action_type: str
    targets: dict[str, Any]


def parse_picks(
    raw: object,
    *,
    own_id: int,
    player_ids: Collection[int],
    center_count: int,
) -> list[Pick] | None:
    """Turn the request's ``picks`` into ordered ``Pick``s, or None if malformed.

    Malformed means the body is wrong whoever sends it: not a list, more than two
    picks, an item that is not exactly one of ``{"player_id": n}``,
    ``{"center_index": n}`` or ``{"self": true}``, a value that is not a plain JSON
    integer, a player who is not at the table, a centre index off the board, or a
    duplicate. Nothing here looks at the player's role. A pick of the player's own id
    is the same as ``{"self": true}``.
    """
    if not isinstance(raw, list) or len(raw) > MAX_PICKS:
        return None
    picks: list[Pick] = []
    for item in raw:
        if not isinstance(item, dict) or len(item) != 1:
            return None
        ((key, value),) = item.items()
        if key == "self":
            if value is not True:
                return None
            pick = Pick("self")
        elif key == "player_id":
            if type(value) is not int or value not in player_ids:
                return None
            pick = Pick("self") if value == own_id else Pick("player", value)
        elif key == "center_index":
            if type(value) is not int or not 0 <= value < center_count:
                return None
            pick = Pick("center", value)
        else:
            return None
        if pick in picks:
            return None
        picks.append(pick)
    return picks


def interpret_choice(
    role_acting_as: str, picks: list[Pick], *, lone_werewolf: bool = False
) -> Interpretation | None:
    """What ``picks`` mean for a player acting as ``role_acting_as``.

    ``None`` means "nothing valid": the window close applies the role's timeout
    default. ``lone_werewolf`` is whether the acting player is the only Werewolf at
    the table (a Doppelganger who copied the Werewolf counts as one). The
    Doppelganger's look is ``role_acting_as == "Doppelganger"``; her follow-up is
    the copied role's own reading. The returned action is valid for the engine by
    construction (other players only, in-range centre cards, distinct cards).
    """
    others = [p for p in picks if p.kind == "player"]
    centers = [p for p in picks if p.kind == "center"]

    if role_acting_as == "Seer":
        if len(picks) >= 2 and picks[0].kind == "center" and picks[1].kind == "center":
            return Interpretation(
                "peek_center", {"center_indices": [picks[0].value, picks[1].value]}
            )
        if others:
            return Interpretation("peek_player", {"player_id": others[0].value})
        return None

    if role_acting_as == "Robber":
        if others:
            return Interpretation("swap_with_player", {"player_id": others[0].value})
        return None

    if role_acting_as == "Troublemaker":
        if len(picks) >= 2 and picks[0].kind == "player" and picks[1].kind == "player":
            return Interpretation(
                "swap_others", {"player_ids": [picks[0].value, picks[1].value]}
            )
        return None

    if role_acting_as == "Drunk":
        if centers:
            return Interpretation(
                "swap_with_center", {"center_index": centers[0].value}
            )
        return None

    if role_acting_as == "Werewolf" and lone_werewolf:
        if centers:
            return Interpretation("see_team", {"center_index": centers[0].value})
        return None

    if role_acting_as == "Doppelganger":
        if others:
            # The look is stored like the old protocol stored it: a peek at a player.
            return Interpretation("peek_player", {"player_id": others[0].value})
        return None

    return None


def prompt_kind(role_acting_as: str | None, *, lone_werewolf: bool = False) -> str:
    """Which instruction a phone shows before choosing (``none`` = "Nothing to
    choose. Tap any card.")."""
    if role_acting_as == "Seer":
        return "seer"
    if role_acting_as == "Robber":
        return "robber"
    if role_acting_as == "Troublemaker":
        return "troublemaker"
    if role_acting_as == "Drunk":
        return "drunk"
    if role_acting_as == "Werewolf" and lone_werewolf:
        return "lone_werewolf"
    if role_acting_as == "Doppelganger":
        return "doppelganger_look"
    return "none"


def is_lone_werewolf(state: GameState, player_id: int) -> bool:
    """True if the player wakes as a Werewolf and no other player does."""
    return is_effective_werewolf(player_id, state) and not any(
        pid != player_id and is_effective_werewolf(pid, state)
        for pid in state.player_roles
    )


def build_choose_prompt(
    state: GameState,
    player_id: int,
    window: int,
    acting_role: str | None,
    chosen: int,
) -> dict[str, Any]:
    """The prompt a phone reads from ``GET /me/`` while a night window is open.

    Every player gets one, with the same shape and the same board
    (``valid_targets`` lists everyone else and every centre card whatever the role),
    so the prompt's presence says nothing. ``kind`` selects the instruction line.
    There are no teammates in it: teams are shown with the results. ``acting_role``
    is None for a player with no action in this window; ``chosen`` is how many
    ``choose`` the caller has already sent in it (so a restarted phone shows
    "Chosen").
    """
    lone = (
        acting_role == "Werewolf" and is_lone_werewolf(state, player_id) and window == 2
    )
    role = acting_role or state.original_roles.get(player_id, "")
    return {
        "window": window,
        "kind": prompt_kind(acting_role, lone_werewolf=lone),
        "role_acting_as": role,
        "action_types": ["choose"],
        "max_picks": MAX_PICKS,
        "max_chooses": max_chooses(window),
        "chosen": chosen,
        "valid_targets": {
            "player_ids": [pid for pid in state.player_roles if pid != player_id],
            "center_indices": list(range(len(state.center_cards))),
        },
    }
