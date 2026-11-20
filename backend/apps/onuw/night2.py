"""Night protocol 2: the night where every phone sends a ``choose``.

Everything that only exists under ``night_protocol: 2`` lives here (choose storage,
the close rule, the prompt, the one group event), behind a narrow set of entry points
that ``services`` calls. Removing protocol 1 later is deleting the original per-role
branches in ``services``; removing this module is not part of it.

The rules this module keeps:

* A request does the SAME work for every role. ``submit_choose`` checks the stage,
  validates the shape of the picks against the table, builds the game state, looks up
  the caller's acting role, stores the picks and counts them, and checks whether the
  window can close: the same queries in the same order for every caller, whatever
  they hold. The ONE role-dependent step is the Doppelganger's look, which resolves in
  her request the moment she chooses (she needs the copied role to choose her
  follow-up). That extra work is small and visible only to someone timing the network:
  the phone changes what others can see at once on tap, never on the response.
* Window 1 (when the Doppelganger card is in the deck) is ONE stage of fixed length,
  ``night_doppelganger_window_seconds``, whatever that setting is. A phone chooses
  once; only the Doppelganger sends a second (her follow-up), but the server accepts a
  second choose from anyone (the simpler rule, and the same answer for every phone;
  only hers is ever read). Her FIRST choose is her look whatever it holds; if it holds
  no other player she has not copied and her second choose does nothing.
* Every choose names the prompt it answers: ``chosen``, the count the prompt showed
  (``GET /me/``'s ``action_prompt.chosen``). Under the Game lock a request whose
  ``chosen`` is LOWER than the stored count is a resend of a choose already taken (its
  answer was lost and the phone sent the same request again): it gets the same
  ``200 {"status": "submitted"}`` and stores nothing. Without this a resent look was
  counted as the Doppelganger's second choose and read as her follow-up (as Robber
  she robbed the player she had looked at), and her real follow-up was refused. A
  ``chosen`` above the stored count names a prompt the server never showed: 400.
* ``GET /me/``'s prompt carries ``shapes`` (``engine.choose.pick_shapes``): which picks
  would do something for the caller, as data, so a phone can keep a player from
  wasting a turn without holding any rule. The server's reading stays the authority.
* Window 2 takes one choose from every phone and closes when every present phone has
  chosen, never before the minimum length, else at the deadline.
* Every request names the stage it was aimed at (``protocol``): a request for a stage
  that is over is refused with ``WrongStageError`` under the Game lock and stores
  nothing.

Lock order: Game, then PlayerRole (as everywhere).
"""

from __future__ import annotations

import logging
from typing import Any

from django.db import transaction

from . import services as svc
from .engine.choose import (
    build_choose_prompt,
    interpret_choice,
    is_lone_werewolf,
    max_chooses,
    parse_picks,
)
from .models import Game, Phase, PlayerRole
from .protocol import NIGHT_CHOOSE_STAGES, WrongStageError, require_stage

logger = logging.getLogger(__name__)

CHOOSE_WRONG_PHASE = "Nothing is waiting for a choice right now."
CHOOSE_BAD_PICKS = "Invalid picks."
CHOOSE_ALREADY = "You have already chosen."
CHOOSE_BAD_COUNT = "chosen is ahead of the choices you have made."
# The only refusals a ``choose`` can get (and ``wrong_stage``, 409, from the stage
# check). None names a role or depends on one.
CHOOSE_ERROR_CODES = {
    CHOOSE_WRONG_PHASE: "wrong_phase",
    CHOOSE_BAD_PICKS: "bad_request",
    CHOOSE_BAD_COUNT: "bad_request",
}


# ── what a phone sends ──────────────────────────────────────────────────────


def chose_count(pr: PlayerRole, window: int) -> int:
    """How many ``choose`` the player has sent in the window."""
    count = pr.night_action_data.get(f"chose_{window}", 0)
    return count if type(count) is int else 0


def submit_choose(
    game: Game, user_id: int, raw_picks: object, stage: str, answered: int
) -> list[str]:
    """A phone's ``choose``. Returns the list of errors (empty = success: stored, or
    a resend of a choose already taken); ``CHOOSE_ERROR_CODES`` maps them to codes. A
    phone that has used its chooses in the window raises
    ``services.AlreadyActedError``; a request aimed at a stage that is over raises
    ``WrongStageError``.

    ``answered`` is the request's ``chosen``: the count the prompt it answers showed.
    Lower than the stored count = a resend (the first answer was lost): success,
    nothing stored, nothing read. Equal = a new choose. Higher = 400.

    ONE transaction, Game lock then the player's row: check the stage, the count,
    the shape of the picks (against the table), read what the picks mean for the
    caller's acting role, store, count, and close the window if everyone it waits
    for has chosen. The caller is known to play in this game (the view checked).
    """
    with transaction.atomic():
        game = Game.objects.select_for_update().get(id=game.id)
        require_stage(game, stage, expected=NIGHT_CHOOSE_STAGES)
        window = game.current_wave  # 1 or 2: the stage check said so
        pr = PlayerRole.objects.select_for_update().get(game=game, user_id=user_id)

        chosen = chose_count(pr, window)
        if answered < chosen:
            # Already taken: the same answer the original got, and nothing else
            # (no store, no reading, no close check), whoever sends it.
            return []
        if answered > chosen:
            return [CHOOSE_BAD_COUNT]
        if chosen >= max_chooses(window):
            raise svc.AlreadyActedError(CHOOSE_ALREADY)

        state = svc.build_game_state(game)  # for EVERY caller, not only Werewolves
        picks = parse_picks(
            raw_picks,
            own_id=user_id,
            player_ids=set(state.original_roles),
            center_count=len(game.center_cards),
        )
        if picks is None:
            return [CHOOSE_BAD_PICKS]

        acting = svc.get_player_acting_role_for_wave(pr, window)
        # One look: a Doppelganger who has not copied has had her look (her first
        # choose, whatever it held), so a later choose of hers reads as nothing.
        reads = acting is not None and not (acting == "Doppelganger" and chosen >= 1)
        reading = None
        if reads:
            reading = interpret_choice(
                acting,
                picks,
                lone_werewolf=acting == "Werewolf" and is_lone_werewolf(state, user_id),
            )

        data: dict[str, Any] = dict(pr.night_action_data)
        data[f"chose_{window}"] = chosen + 1
        if reads:
            # A role with something to do this window: the latest choose replaces
            # what an earlier one stored (a Doppelganger's follow-up replaces her
            # look's record; the look itself is already resolved and logged).
            data.pop("action_type", None)
            data.pop("targets", None)
            data["wave"] = window
            data["role_acting_as"] = acting
            if reading is not None:
                data["action_type"] = reading.action_type
                data["targets"] = reading.targets
        pr.night_action_data = data
        pr.has_acted = True
        pr.save(update_fields=["night_action_data", "has_acted"])

        # The Doppelganger's look resolves here (her copy must be known to the
        # follow-up and to the close): the one role-dependent step of a request.
        if window == 1 and acting == "Doppelganger" and reading is not None:
            svc._resolve_doppelganger_look(game)
        if svc._night_ready_to_close(game):
            svc._close_or_defer(game)
    return []


# ── what a phone reads ──────────────────────────────────────────────────────


def prompt_for(game: Game, pr: PlayerRole) -> dict[str, Any] | None:
    """The prompt the caller reads from ``GET /me/`` in an open window: every player
    has one, shaped alike (``engine.choose.build_choose_prompt``)."""
    window = game.current_wave
    if game.phase != Phase.NIGHT or window not in (1, 2):
        return None
    acting = svc.get_player_acting_role_for_wave(pr, window)
    chosen = chose_count(pr, window)
    if acting == "Doppelganger" and chosen >= 1:
        acting = None  # her one look is over: a second choose does nothing
    return build_choose_prompt(
        svc.build_game_state(game), pr.user_id, window, acting, chosen
    )


# ── opening and closing a window ────────────────────────────────────────────


def announce_window(game: Game, window: int) -> None:
    """Tell the table a window opened with ONE group event, the same bytes for every
    phone and nothing per player (each phone reads its prompt from ``GET /me/``).
    The caller (``services.send_wave_prompts``) has set the deadline and the timer."""
    svc._send_after_commit(
        [
            (
                f"game_{game.id}",
                {
                    "type": "night.window",
                    "window": window,
                    "deadline": game.phase_deadline.isoformat()
                    if game.phase_deadline
                    else None,
                },
            )
        ]
    )


def ready_to_close(prs: list[PlayerRole], window: int, grace: int, now: Any) -> bool:
    """Every present phone has chosen once in the window (a phone gone past the grace
    period is not waited for), so the stage ends the moment everyone has done their
    part. (Window 1 is fixed-length; this is only asked of it when its length was
    switched off, in development, and then a Doppelganger who copied a role with a
    follow-up is also waited for until she has sent it.)"""

    def needed(pr: PlayerRole) -> int:
        if window == 1 and svc.get_player_acting_role_for_wave(pr, 1) not in (
            None,
            "Doppelganger",
        ):
            return 2  # her follow-up
        return 1

    return all(
        chose_count(pr, window) >= needed(pr) or svc._is_gone(pr, grace, now)
        for pr in prs
    )


__all__ = [
    "CHOOSE_ERROR_CODES",
    "WrongStageError",
    "announce_window",
    "chose_count",
    "prompt_for",
    "ready_to_close",
    "submit_choose",
]
