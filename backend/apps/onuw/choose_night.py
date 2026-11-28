"""The night: every phone with a choice sends a ``choose``.

The phone-facing half of the night lives here (choose storage, the close rule, the
prompt, the one group event), behind a narrow set of entry points that ``services``
calls; ``services`` resolves the windows through the engine.

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
* A phone with nothing to choose (its prompt's ``kind`` is ``none``) sends nothing:
  its prompt says ``chooses_left`` 0 from the start. Window 2 closes when every
  present phone WITH a choice has chosen, never before the minimum length, else at
  the deadline; a sleeper is never waited for. Who taps is an accepted tell (first
  time play spec, section 8). A choose from a sleeper is still taken (the same
  answer as anyone's) and does nothing.
* Every request names the stage it was aimed at (``protocol``): a request for a stage
  that is over is refused with ``WrongStageError`` under the Game lock and stores
  nothing.

Lock order: Game, then PlayerRole (as everywhere).
"""

from __future__ import annotations

import logging
from typing import Any

from django.db import transaction

from apps.core.wire import public_name

from . import basics, night_flow, night_results, night_window, readiness, turns
from .engine.choose import (
    Interpretation,
    build_choose_prompt,
    chooses_left,
    interpret_choice,
    is_lone_werewolf,
    max_chooses,
    parse_picks,
)
from .engine.night import action_order_group, resolve_wave, settled_at_choose
from .engine.state import GameState, NightAction
from .models import Game, Phase, PlayerRole
from .protocol import NIGHT_CHOOSE_STAGES, WrongStageError, require_stage

logger = logging.getLogger(__name__)

CHOOSE_BAD_PICKS = "Invalid picks."
CHOOSE_ALREADY = "You have already chosen."
CHOOSE_BAD_COUNT = "chosen is ahead of the choices you have made."
# The only refusals a ``choose`` can get (and ``wrong_stage``, 409, from the stage
# check). None names a role or depends on one.
CHOOSE_ERROR_CODES = {
    CHOOSE_BAD_PICKS: "bad_request",
    CHOOSE_BAD_COUNT: "bad_request",
}


# ── what a phone sends ──────────────────────────────────────────────────────


def submit_choose(
    game: Game,
    user_id: int,
    raw_picks: object,
    stage: str,
    answered: int,
    *,
    answer: bool = True,
) -> tuple[list[str], dict[str, Any]]:
    """A phone's ``choose``. Returns the list of errors (empty = success: stored, or
    a resend of a choose already taken) and, on success, what the answer carries
    (``answer_for``: the caller's own ``night_results`` and ``chooses_left`` as
    ``GET /me/`` would show them now); ``CHOOSE_ERROR_CODES`` maps the errors to
    codes (``answer=False``: a practice player, nobody reads it, an empty dict). A
    phone that has used its chooses in the window raises
    ``basics.AlreadyActedError``; a request aimed at a stage that is over raises
    ``WrongStageError``.

    ``answered`` is the request's ``chosen``: the count the prompt it answers showed.
    Lower than the stored count = a resend (the first answer was lost): success,
    nothing stored; it gets the answer the first one did. Equal = a new choose.
    Higher = 400.

    The choose is ONE transaction (``_take_choose``), Game lock then the player's
    row. The answer is read AFTER it commits, outside the lock (other phones are not
    kept waiting for it), and can never undo a choose: if it cannot be built the
    choose still stands and the answer is the bare ``{"status": "submitted"}`` (the
    phone then reads ``GET /me/``). The caller is known to play in this game (the
    view checked).
    """
    errors = _take_choose(game, user_id, raw_picks, stage, answered)
    if errors or not answer:
        return errors, {}
    try:
        return [], answer_for(game.id, user_id)
    except Exception:
        logger.exception(
            "Could not build the answer to a choose of player %s in game %s",
            user_id,
            game.id,
        )
        return [], {}


def _take_choose(
    game: Game, user_id: int, raw_picks: object, stage: str, answered: int
) -> list[str]:
    """The locked, all-or-nothing part of a choose: check the stage, the count, the
    shape of the picks (against the table), read what the picks mean for the
    caller's acting role, store (with the early entry), count, and close the
    window if everyone it waits for has chosen. Returns the errors (empty = taken,
    or a resend of one already taken)."""
    with transaction.atomic():
        game = Game.objects.select_for_update().get(id=game.id)
        require_stage(game, stage, expected=NIGHT_CHOOSE_STAGES)
        window = game.current_wave  # 1 or 2: the stage check said so
        pr = PlayerRole.objects.select_for_update().get(game=game, user_id=user_id)

        chosen = turns.chose_count(pr, window)
        if answered < chosen:
            # Already taken: the same answer the original got, and nothing else
            # (no store, no reading, no close check), whoever sends it.
            return []
        if answered > chosen:
            return [CHOOSE_BAD_COUNT]
        if chosen >= max_chooses(window):
            raise basics.AlreadyActedError(CHOOSE_ALREADY)

        state = basics.build_game_state(game)  # for EVERY caller, not only Werewolves
        picks = parse_picks(
            raw_picks,
            own_id=user_id,
            player_ids=set(state.original_roles),
            center_count=len(game.center_cards),
        )
        if picks is None:
            return [CHOOSE_BAD_PICKS]

        acting = turns.get_player_acting_role_for_wave(pr, window)
        # One look: a Doppelganger who has not copied has had her look (her first
        # choose, whatever it held), so a later choose of hers reads as nothing.
        reads = acting is not None and not (acting == "Doppelganger" and chosen >= 1)
        reading = None
        lone = acting == "Werewolf" and is_lone_werewolf(state, user_id)
        if reads:
            reading = interpret_choice(acting, picks, lone_werewolf=lone)
        # A phone with nothing to choose that sends one anyway learns nothing early.
        has_turn = chooses_left(window, acting, chosen, lone_werewolf=lone) > 0

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
            # What the close will show the caller, when nothing else chosen in
            # the window can change it: shown from now on (``night_results``).
            data.pop(turns.early_key(window), None)
            early = _early_entry(game, state, user_id, window, acting, reading)
            if early is not None and has_turn:
                data[turns.early_key(window)] = early
        pr.night_action_data = data
        pr.has_acted = True
        pr.save(update_fields=["night_action_data", "has_acted"])

        # The Doppelganger's look resolves here (her copy must be known to the
        # follow-up and to the close): the one role-dependent step of a request.
        if window == 1 and acting == "Doppelganger" and reading is not None:
            night_window._resolve_doppelganger_look(game)
        if readiness._night_ready_to_close(game):
            night_flow._close_or_defer(game)
        return []


def _early_entry(
    game: Game,
    state: GameState,
    user_id: int,
    window: int,
    acting: str | None,
    reading: Interpretation | None,
) -> dict[str, Any] | None:
    """The night-log entry the window's close will write for the caller, when it is
    already settled (``engine.night.settled_at_choose``): the caller's action as the
    close collects it (their reading, else the role's default, a Drunk's server swap
    included), resolved alone on the table as it is now, exactly as the close
    resolves it. Nothing else chosen in the window resolves before it and moves a
    card it shows, so the close writes the same entry (tests/onuw/
    test_night_result_now.py plays both ways). None when it is not settled, or for
    an action the engine refuses (the close then applies its own fallback)."""
    if not settled_at_choose(window, acting) or acting is None:
        return None
    if reading is None:
        action = night_window._timeout_action(game, user_id, acting)
    else:
        action = NightAction(
            player_id=user_id,
            role_acting_as=acting,
            action_type=reading.action_type,
            targets=reading.targets,
        )
    group = 1 if window == 1 else action_order_group(action)
    try:
        resolved, _ = resolve_wave(state, [action], group)
    except Exception:
        # The close will meet the same action and apply its own fallback; the
        # phone just gets nothing early. Loud, so a missing result can be explained.
        logger.exception(
            "No early result for player %s (%s) in game %s", user_id, acting, game.id
        )
        return None
    return resolved.action_log[-1].to_dict()


def answer_for(game_id: Any, user_id: int) -> dict[str, Any]:
    """What a taken ``choose`` answers besides its status: the caller's own
    ``night_results`` as ``GET /me/`` lists them now, and the ``chooses_left`` of
    the caller's prompt (0 once the window is over). Read after the choose
    committed, in ONE query (every row of the game, with its user and its game): the
    names, the table and the caller's own row. The same keys, and the same read,
    for every caller; nothing about anyone else."""
    rows = list(
        PlayerRole.objects.filter(game_id=game_id).select_related("game", "user")
    )
    pr = next(row for row in rows if row.user_id == user_id)
    game = pr.game
    window = game.current_wave
    left = 0
    if game.phase == Phase.NIGHT and window in (1, 2):
        left = build_choose_prompt(
            basics.game_state_from(game, rows),
            user_id,
            window,
            turns.prompt_role(pr, window),
            turns.chose_count(pr, window),
        )["chooses_left"]
    names = {row.user_id: public_name(row.user) for row in rows}
    return {
        "night_results": night_results.night_results_for_player(
            game, user_id, names, pr.night_action_data
        ),
        "chooses_left": left,
    }


# ── what a phone reads ──────────────────────────────────────────────────────


def prompt_for(
    game: Game, pr: PlayerRole, state: GameState | None = None
) -> dict[str, Any] | None:
    """The prompt the caller reads from ``GET /me/`` in an open window: every player
    has one, shaped alike (``engine.choose.build_choose_prompt``). ``state``: the
    game's engine state when the caller built it already from every row it read
    (``basics.game_state_from``), else it is read here."""
    window = game.current_wave
    if game.phase != Phase.NIGHT or window not in (1, 2):
        return None
    return build_choose_prompt(
        state if state is not None else basics.build_game_state(game),
        pr.user_id,
        window,
        turns.prompt_role(pr, window),
        turns.chose_count(pr, window),
    )


__all__ = [
    "CHOOSE_ERROR_CODES",
    "WrongStageError",
    "answer_for",
    "prompt_for",
    "submit_choose",
]
