"""
Whose turn it is in a night window.

Small reads over one player's stored night: the role they act as in a window (from
the card they were DEALT), how many times they have chosen in it, the role their
prompt speaks for, and whether they still have a choose to send. Everything that
waits for the night, opens a window or takes a choose asks here, so none of them
has to import another.
"""

from __future__ import annotations

from .engine.behaviors import get_doppelganger_followup_wave
from .engine.choose import chooses_left, is_lone_werewolf
from .engine.roles import get_role, window_for_order_group
from .engine.state import GameState
from .models import PlayerRole


def get_player_acting_role_for_wave(pr: PlayerRole, wave: int) -> str | None:
    """
    Role this player acts as in the given night window, or None if they do
    not act in it.

    Decided from the DEALT card (original_role), never the card held now: the
    player dealt the Seer wakes as the Seer whatever has been swapped since.

    Window 1: the Doppelganger's look; once she has copied, her immediate
    follow-up if the copied role has one (Seer, Robber, Troublemaker, Drunk,
    Minion). Window 2: every other actor, plus a Doppelganger who copied
    Werewolf, Mason or Insomniac.
    """
    dealt = pr.original_role
    if dealt == "Doppelganger":
        copied = pr.night_action_data.get("copied_role")
        if wave == 1 and not copied:
            return "Doppelganger"
        if not copied:
            return None
        followup = get_doppelganger_followup_wave(copied)
        if followup is not None and window_for_order_group(followup) == wave:
            return copied
        return None

    order_group = get_role(dealt).wave
    if order_group is not None and window_for_order_group(order_group) == wave:
        return dealt
    return None


def chose_count(pr: PlayerRole, window: int) -> int:
    """How many ``choose`` the player has sent in the window."""
    count = pr.night_action_data.get(f"chose_{window}", 0)
    return count if type(count) is int else 0


def early_key(window: int) -> str:
    """Where a player's settled result of an open window waits for its close, in
    their own ``night_action_data`` (``choose_night._early_entry``): the very
    night-log entry the close will write. Dropped when the window closes."""
    return f"early_{window}"


def prompt_role(pr: PlayerRole, window: int) -> str | None:
    """The role the caller's prompt acts as: their acting role in the window, except
    a Doppelganger whose one look is over (a second choose does nothing)."""
    acting = get_player_acting_role_for_wave(pr, window)
    if acting == "Doppelganger" and chose_count(pr, window) >= 1:
        return None
    return acting


def turn_open(state: GameState, pr: PlayerRole, window: int) -> bool:
    """The phone still has a choose to send in the window: its prompt's
    ``chooses_left`` is above 0 (never for a phone with nothing to choose)."""
    acting = prompt_role(pr, window)
    lone = acting == "Werewolf" and window == 2 and is_lone_werewolf(state, pr.user_id)
    return chooses_left(window, acting, chose_count(pr, window), lone_werewolf=lone) > 0
