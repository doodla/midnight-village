"""
ONUW game service layer.

Coordinates between HTTP/WS (views, consumers) and the pure-Python engine.
All game state transitions go through this module.
"""

from __future__ import annotations

import functools
import logging
import random
import threading
import uuid
from collections.abc import Callable
from datetime import timedelta
from typing import Any

from django.conf import settings as django_settings
from django.db import DatabaseError, transaction
from django.db.models.functions import Now
from django.utils import timezone

from channels.layers import get_channel_layer

from apps.core import effects, timers
from apps.core.models import Lobby
from apps.onuw import presence

from .engine.behaviors import (
    get_doppelganger_followup_wave,
    is_effective_werewolf,
)
from .engine.night import (
    build_role_prompt,
    get_required_actions_for_window,
    resolve_wave,
    resolve_window,
)
from .engine.roles import ActionType, get_role, window_for_order_group
from .engine.state import ActionResult, GameState, NightAction
from .engine.validation import is_valid_timer_value, max_seconds_for
from .engine.voting import apply_hunter, count_votes, determine_elimination
from .engine.win_conditions import evaluate_winner
from .models import Game, Phase, PlayerRole, SocketPresence

logger = logging.getLogger(__name__)


class AlreadyActedError(Exception):
    """Raised when a player tries to act again after already submitting."""


# Night windows: 1 = Doppelganger alone, 2 = everyone else at once.
NIGHT_WINDOWS = (1, 2)

# Default maximum length of a night window (seconds). 0 disables the timer.
DEFAULT_NIGHT_WAVE_SECONDS = 30
# Default minimum length of a night window (seconds). A window never closes
# sooner than this after it opened, so a fast window gives nothing away.
DEFAULT_NIGHT_MIN_WINDOW_SECONDS = 8
# Exact length of window 1 (the Doppelganger's), whatever happens in it. 0
# turns the fixed length off: window 1 then behaves like any other window.
DEFAULT_NIGHT_DOPPELGANGER_WINDOW_SECONDS = 10
# How long a player's phone may be disconnected before the game stops waiting
# for them at night and in the vote (0 turns the feature off).
DEFAULT_DISCONNECT_GRACE_SECONDS = 25

# Phases that run on a clock (and so need a timer to move on).
TIMED_PHASES = (Phase.NIGHT, Phase.DISCUSSION, Phase.VOTING)

# After a restart no phone is connected yet. A deadline that is overdue, or less
# than this many seconds away, is moved to this long from now when its timer is
# rebuilt, so phones can reconnect before the vote is revealed or the night closes.
RECOVERY_RECONNECT_ALLOWANCE_SECONDS = 15


def get_timer_seconds(game: Game, key: str, default: int) -> int:
    """Read a timer duration from game settings.

    Returns default if the key is not set or the stored value is not a valid
    number of seconds (settings are validated on the way in, but a bad row must
    never be able to crash a window close).
    """
    stored = (
        game.settings.get(key, default) if isinstance(game.settings, dict) else default
    )
    return stored if is_valid_timer_value(stored, max_seconds_for(key)) else default


def _window_timer_key(game: Game, window: int) -> str:
    return f"{game.id}:wave:{window}"


# ── Side effects run only after the transaction commits ──────────────────────
#
# Night transitions change the database inside the caller's atomic block (timer
# thread, host request, submission). WebSocket sends and timer changes must not
# happen until that block has committed: otherwise a rollback would leave
# players told about a window that never opened (and its timer cancelled), and
# a client reacting to wave.start could read the old window from GET /me/.
# transaction.on_commit runs at once when there is no open transaction.


_after_commit = effects.after_commit
_send_after_commit = effects.send_after_commit
_schedule_after_commit = effects.schedule_after_commit
_cancel_after_commit = effects.cancel_after_commit


def _window_job_params(game: Game, window: int, *, deferred: bool = False) -> dict:
    return {"game_id": str(game.id), "wave": window, "deferred": deferred}


def _get_player_names(game: Game) -> dict[int, str]:
    """Build a player_id -> display_name lookup for the game."""
    # pyrefly: ignore [missing-attribute]
    return {
        pr.user_id: pr.user.display_name or pr.user.username
        for pr in game.player_roles.select_related("user").all()
    }


def _client_action_type(action: NightAction) -> str:
    """Map engine action to the action_type string the frontend expects.

    The Insomniac automatically checks its own card (no target selection).
    The frontend routes on "insomniac" to display the correct result view.
    """
    if action.role_acting_as == "Insomniac":
        return "insomniac"
    return action.action_type


def _transform_revealed_info(
    action: NightAction,
    result: ActionResult,
    player_names: dict[int, str],
) -> dict[str, Any]:
    """Transform engine revealed_info into the format the frontend expects.

    The engine returns raw data (player IDs, internal key names). The frontend
    expects display names and a consistent key schema per action type.
    """
    raw = result.revealed_info
    action_type = action.action_type
    targets = action.targets

    # Insomniac sees their current role (may have changed via swap).
    if action.role_acting_as == "Insomniac":
        current = raw.get("current_role", "")
        return {
            "current_role": current.lower() if isinstance(current, str) else current
        }

    if action_type == "peek_player":
        # Seer peek at a player, or Doppelganger copy.
        target_id = int(targets.get("player_id", 0))
        target_name = player_names.get(target_id, "Unknown")
        # Engine uses "peeked_role" for Seer, "copied_role" for Doppelganger.
        role = raw.get("peeked_role") or raw.get("copied_role", "")
        out: dict[str, Any] = {
            "target_name": target_name,
            "role": role.lower() if isinstance(role, str) else role,
        }
        # Preserve copied_role for Doppelganger follow-up logic.
        if "copied_role" in raw:
            out["copied_role"] = raw["copied_role"]
        return out

    if action_type == "peek_center":
        # Seer peek at 2 center cards.
        peeked = raw.get("peeked_center", [])
        roles = [
            entry["role"].lower()
            for entry in peeked
            if isinstance(entry, dict) and "role" in entry
        ]
        return {"roles": roles}

    if action_type == "swap_with_player":
        # Robber swaps with target, learns their role.
        target_id = int(targets.get("player_id", 0))
        target_name = player_names.get(target_id, "Unknown")
        new_role = raw.get("new_role", "")
        return {
            "target_name": target_name,
            "new_role": new_role.lower() if isinstance(new_role, str) else new_role,
        }

    if action_type == "swap_with_center":
        # Drunk swaps with a center card, learns nothing.
        center_index = targets.get("center_index")
        return {"card_index": int(center_index) if center_index is not None else 0}

    if action_type == "swap_others":
        # Troublemaker swaps two other players, learns nothing.
        player_ids = targets.get("player_ids", [])
        name1 = (
            player_names.get(int(player_ids[0]), "Unknown")
            if len(player_ids) > 0
            else "Unknown"
        )
        name2 = (
            player_names.get(int(player_ids[1]), "Unknown")
            if len(player_ids) > 1
            else "Unknown"
        )
        return {"player1_name": name1, "player2_name": name2}

    if action_type == "see_team":
        # Werewolf, Mason, or Minion see teammates.
        # Engine sends "werewolves" for Werewolf/Minion, "masons" for Mason.
        teammate_ids: list[int] = raw.get("werewolves", raw.get("masons", []))
        teammate_names = [player_names.get(pid, "Unknown") for pid in teammate_ids]
        see_team_out: dict[str, Any] = {
            "teammate_names": teammate_names,
            "role_acting_as": action.role_acting_as,
        }
        # Lone werewolf center card peek (optional).
        if "center_card" in raw:
            cc = raw["center_card"]
            see_team_out["center_card"] = {
                "index": cc["index"],
                "role": cc["role"].lower()
                if isinstance(cc.get("role"), str)
                else cc.get("role", ""),
            }
        return see_team_out

    if action_type == "skip":
        return {}

    # Unknown action — pass through as-is.
    return dict(raw)


def client_action_result(
    action: NightAction,
    revealed_info: dict[str, Any],
    player_names: dict[int, str],
) -> tuple[str, dict[str, Any]]:
    """The (action_type, revealed_info) pair a player is shown for one result.

    The single place that turns an engine result into what the client sees. It
    feeds both the ``action.result`` socket event and the ``night_results`` list
    in ``GET /me/``, so the two cannot drift apart.
    """
    result = ActionResult(
        player_id=action.player_id, revealed_info=revealed_info, state_mutations=[]
    )
    return (
        _client_action_type(action),
        _transform_revealed_info(action, result, player_names),
    )


def night_results_for_player(
    game: Game, user_id: int, player_names: dict[int, str]
) -> list[dict[str, Any]]:
    """The caller's own night results for every window that has closed.

    Rebuilt from the stored night log with the same transform the
    ``action.result`` socket event uses, so a phone that was offline when a
    window closed shows exactly what it would have received. One entry per
    result, in window order (a Doppelganger with a follow-up gets two in
    window 1: the copy, then the follow-up).

    Every action the socket carried is returned exactly as sent, including a
    swap (Drunk, Troublemaker), whose engine result is empty but whose client
    payload is the slot / the two names swapped. Only an explicit ``skip`` is
    left out: it carries nothing. Only this player's own entries are read, and a
    window that is still open
    contributes nothing: nothing reaches a player before its window closes
    (the Doppelganger's look, which is sent early because she needs it to
    choose her follow-up, is held back here until window 1 closes).
    """
    if game.phase == Phase.NIGHT:
        closed_before = game.current_wave  # windows 1..current_wave-1 have closed
    elif game.phase in (Phase.DISCUSSION, Phase.VOTING, Phase.RESULTS):
        closed_before = NIGHT_WINDOWS[-1] + 1
    else:
        return []

    entries: list[tuple[int, dict[str, Any]]] = []
    for entry in game.night_actions_log:
        # Only the player's own entries, and not an explicit "do nothing": every
        # other entry, including a swap whose engine result is empty (the
        # client learns its slot / the names it swapped from the action), was
        # sent over the socket and is returned here exactly as sent.
        if entry.get("player_id") != user_id or entry.get("action_type") == "skip":
            continue
        try:
            window = window_for_order_group(entry["wave"])
        except (KeyError, ValueError):
            continue
        if window >= closed_before:
            continue
        action = NightAction(
            player_id=user_id,
            role_acting_as=entry.get("role_acting_as", ""),
            action_type=entry.get("action_type", ""),
            targets=entry.get("targets", {}),
        )
        try:
            action_type, revealed = client_action_result(
                action, entry.get("result") or {}, player_names
            )
        except Exception:
            logger.exception("Could not rebuild a night result for player %s", user_id)
            continue
        entries.append(
            (
                window,
                {"wave": window, "action_type": action_type, "revealed_info": revealed},
            )
        )
    entries.sort(key=lambda item: item[0])  # stable: keeps wake order within a window
    return [payload for _, payload in entries]


def build_game_state(game: Game) -> GameState:
    """
    Build an engine GameState from DB models.

    Reads all PlayerRole rows for the game and constructs the immutable
    state snapshot the engine needs.
    """
    player_roles: dict[int, str] = {}
    original_roles: dict[int, str] = {}
    doppelganger_copied: dict[int, str] = {}

    # pyrefly: ignore [missing-attribute]
    for pr in game.player_roles.all():
        player_roles[pr.user_id] = pr.current_role
        original_roles[pr.user_id] = pr.original_role
        if pr.original_role == "Doppelganger" and pr.night_action_data.get(
            "copied_role"
        ):
            doppelganger_copied[pr.user_id] = pr.night_action_data["copied_role"]

    return GameState(
        player_roles=player_roles,
        center_cards=list(game.center_cards),
        original_roles=original_roles,
        doppelganger_copied_role=doppelganger_copied,
    )


def get_wave_actors(game: Game, wave: int) -> list[int]:
    """Return user_ids of players who should act in the given night window."""
    state = build_game_state(game)
    doppelganger_info = state.doppelganger_copied_role if wave > 1 else None
    prompts = get_required_actions_for_window(state, wave, doppelganger_info)
    return [p["player_id"] for p in prompts]


def _doppelganger_in_deck(game: Game) -> bool:
    """True if the Doppelganger card is in the deck: dealt to a player or in the center."""
    # pyrefly: ignore [missing-attribute]
    dealt = game.player_roles.filter(original_role="Doppelganger").exists()
    return dealt or "Doppelganger" in game.center_cards


def start_night_phase(game: Game) -> None:
    """
    Open the night.

    Window 1 (Doppelganger) runs whenever the Doppelganger card is in the deck,
    dealt or in the center, even if nobody can act in it (so a missing
    Doppelganger cannot be told from a present one by timing). Window 2 always
    runs. A window is never skipped because it has no actors.
    """
    first_window = 1 if _doppelganger_in_deck(game) else 2
    with transaction.atomic():
        locked = Game.objects.select_for_update().get(id=game.id)
        if locked.phase == Phase.NIGHT and locked.current_wave == 0:
            _open_window(locked, first_window)
        # else: already opened (start-up recovery or a lazy ensure_timers got
        # there first); opening twice would re-prompt everyone.
    game.refresh_from_db()


def _open_window(game: Game, window: int) -> None:
    """Open a night window: record it, prompt its actors, and arrange its close."""
    with transaction.atomic():
        game.current_wave = window
        game.save(update_fields=["current_wave", "updated_at"])
        # Fresh window: nobody has acted in it yet.
        # pyrefly: ignore [missing-attribute]
        game.player_roles.update(has_acted=False)

    send_wave_prompts(game, window)

    # With nobody to wait for (no actors, or every actor's phone has been gone
    # past the grace period), the window still lasts its minimum length.
    if _night_ready_to_close(game):
        _close_or_defer(game)


def _min_close_delay(game: Game) -> float:
    """Seconds until the current window may close (0 if its minimum has passed).

    The minimum never exceeds the window's maximum (night_wave_seconds).
    """
    min_seconds = get_timer_seconds(
        game, "night_min_window_seconds", DEFAULT_NIGHT_MIN_WINDOW_SECONDS
    )
    max_seconds = get_timer_seconds(
        game, "night_wave_seconds", DEFAULT_NIGHT_WAVE_SECONDS
    )
    if max_seconds > 0:
        min_seconds = min(min_seconds, max_seconds)
    opened_at = game.night_window_opened_at
    if min_seconds <= 0 or opened_at is None:
        return 0.0
    ready_at = opened_at + timedelta(seconds=min_seconds)
    return max(0.0, (ready_at - timezone.now()).total_seconds())


def _fixed_window_seconds(game: Game, window: int) -> int:
    """Exact length of a fixed-length window in seconds, or 0 if it is not fixed.

    Window 1 (the Doppelganger's) lasts exactly night_doppelganger_window_seconds
    whenever it runs, so its length says nothing about whether the Doppelganger
    is in play, copied a role, or has a follow-up. Setting it to 0 turns the
    fixed length off: window 1 then closes like window 2 (when its actors are
    done, no sooner than night_min_window_seconds, no later than
    night_wave_seconds).
    """
    if window != 1:
        return 0
    return get_timer_seconds(
        game,
        "night_doppelganger_window_seconds",
        DEFAULT_NIGHT_DOPPELGANGER_WINDOW_SECONDS,
    )


def _close_or_defer(game: Game) -> None:
    """Close the current window now, or at its minimum length if that is later.

    Called with the Game row locked once every actor in the window is done.
    Rescheduling replaces the window's maximum timer under the same key; the
    callback is idempotent per window. A fixed-length window (window 1) never
    closes because its actors are done: only its own timer closes it.
    """
    window = game.current_wave
    if _fixed_window_seconds(game, window) > 0:
        return
    delay = _min_close_delay(game)
    if delay > 0:
        _schedule_after_commit(
            _window_timer_key(game, window),
            delay,
            "night_window",
            _window_job_params(game, window, deferred=True),
        )
        return
    advance_wave(game)


def drunk_timeout_center_index(
    random_seed: int, player_id: int, center_size: int
) -> int:
    """The center card the server swaps a timed-out Drunk with.

    Deterministic and independent of timing or of any other event: a dedicated
    RNG seeded from the game seed, a fixed label and the player id, so a replay
    of the same game reproduces it.
    """
    rng = random.Random(f"{random_seed}:drunk-timeout:{player_id}")  # noqa: S311 (seeded, not secret)
    return rng.randrange(center_size)


def _timeout_action(game: Game, player_id: int, role_acting_as: str) -> NightAction:
    """What happens for a player who submitted nothing before the window closed.

    The Drunk (and a Doppelganger who copied the Drunk) MUST swap, so the
    server swaps with a seeded random center card and marks it
    ``made_by_server`` in the log. It looks exactly like a chosen swap to
    everyone else: it resolves when the window closes and the Drunk is sent the
    same result. Everything else is the automatic or skipped default.
    """
    if role_acting_as == "Drunk" and game.center_cards:
        index = drunk_timeout_center_index(
            game.random_seed, player_id, len(game.center_cards)
        )
        return NightAction(
            player_id=player_id,
            role_acting_as=role_acting_as,
            action_type="swap_with_center",
            targets={"center_index": index},
            made_by_server=True,
        )
    return NightAction(
        player_id=player_id,
        role_acting_as=role_acting_as,
        action_type=_timeout_action_type(role_acting_as),
        targets={},
    )


def _timeout_action_type(role_acting_as: str) -> str:
    """Determine the action type for a player who didn't submit before the timer.

    Automatic roles (Insomniac, see_team roles) are auto-resolved rather than
    skipped, because their actions require no player choice — the information
    is revealed automatically per the ONUW rules. Skipping these would lose
    information the player is entitled to (e.g., Insomniac not seeing their
    current card after swaps).

    Roles with an optional choice (Seer, Robber, Troublemaker, Doppelganger's
    look) are skipped — the player forfeited it by not submitting. The Drunk is
    never skipped: see _timeout_action, which swaps for them.
    """
    role_def = get_role(role_acting_as)
    if role_def.action_types == (ActionType.NONE,):
        return "none"
    if role_def.action_types == (ActionType.SEE_TEAM,):
        return "see_team"
    return "skip"


def _auto_advance_wave(game: Game, wave_number: int, deferred: bool = False) -> None:
    """Auto-advance a wave when its timer expires, marking non-actors as skipped.

    ``deferred`` marks the early close scheduled for a window's minimum length
    (everyone it waited for was done). Anything may have happened since: a
    player treated as gone may have reconnected. So it re-checks, under the
    lock, that the window may still close; if not, the window's normal deadline
    timer is put back instead. A deadline that has been reached always closes.
    In the ordinary case (still ready) this closes at exactly the same moment.
    """
    if game.current_wave != wave_number:
        return  # Wave already advanced — stale callback.
    if deferred:
        deadline = game.phase_deadline
        deadline_reached = deadline is not None and timezone.now() >= deadline
        if not deadline_reached and not _night_ready_to_close(game):
            _restore_deadline_timer(game)
            return
    advance_wave(game)


def _restore_deadline_timer(game: Game) -> None:
    """Re-arm the open night window's own deadline timer (after a deferred
    close turned out to be premature). No deadline means no timer: the host or
    the players moving it are all that is left, as before."""
    if game.phase_deadline is None:
        return
    window = game.current_wave
    delay = max(0.0, (game.phase_deadline - timezone.now()).total_seconds())
    _schedule_after_commit(
        _window_timer_key(game, window),
        delay,
        "night_window",
        _window_job_params(game, window),
    )


def send_wave_prompts(game: Game, wave: int) -> None:
    """
    Open the timing of a night window and prompt every actor in it at once.

    ``wave`` is the window number. Records when the window opened (the minimum
    length is measured from here) and its deadline, then, once the transaction
    commits: schedules the window's one timer (night_wave_seconds, or exactly
    night_doppelganger_window_seconds for window 1), broadcasts wave.start,
    sends each actor their action.prompt, and tells everyone else wave.waiting.
    A timer of 0 seconds means no timer and no deadline.
    """
    seconds = _fixed_window_seconds(game, wave) or get_timer_seconds(
        game, "night_wave_seconds", DEFAULT_NIGHT_WAVE_SECONDS
    )
    opened_at = timezone.now()
    game.night_window_opened_at = opened_at
    game.phase_deadline = (
        opened_at + timedelta(seconds=seconds) if seconds > 0 else None
    )
    game.save(update_fields=["phase_deadline", "night_window_opened_at", "updated_at"])

    if seconds > 0:
        _schedule_after_commit(
            _window_timer_key(game, wave),
            seconds,
            "night_window",
            _window_job_params(game, wave),
        )

    state = build_game_state(game)
    doppelganger_info = state.doppelganger_copied_role if wave > 1 else None
    prompts = get_required_actions_for_window(state, wave, doppelganger_info)
    acting_player_ids = {p["player_id"] for p in prompts}

    # wave.start to everyone; prompts to actors; waiting to everyone else.
    messages: list[tuple[str, dict[str, Any]]] = [
        (
            f"game_{game.id}",
            {
                "type": "wave.start",
                "wave": wave,
                "deadline": game.phase_deadline.isoformat()
                if game.phase_deadline
                else None,
            },
        )
    ]
    for prompt in prompts:
        messages.append(
            (
                f"game_{game.id}_player_{prompt['player_id']}",
                {
                    "type": "action.prompt",
                    "wave": wave,
                    "role_acting_as": prompt["role_acting_as"],
                    "action_types": prompt["action_types"],
                    "valid_targets": prompt["valid_targets"],
                },
            )
        )
    for pid in state.player_roles:
        if pid not in acting_player_ids:
            messages.append(
                (f"game_{game.id}_player_{pid}", {"type": "wave.waiting", "wave": wave})
            )
    _send_after_commit(messages)


def _doppelganger_player_role(game: Game) -> PlayerRole | None:
    """The PlayerRole of the player who was dealt the Doppelganger, if any."""
    # pyrefly: ignore [missing-attribute]
    return game.player_roles.filter(original_role="Doppelganger").first()


def _doppelganger_look_submitted(game: Game) -> bool:
    """True if the Doppelganger submitted the look and it is not resolved yet."""
    pr = _doppelganger_player_role(game)
    if pr is None or not pr.has_acted:
        return False
    data = pr.night_action_data
    return data.get("role_acting_as") == "Doppelganger" and "copied_role" not in data


def resolve_doppelganger_look(game: Game) -> bool:
    """Resolve the Doppelganger's stored look now (public name for the view).

    Called by ``NightActionView`` inside the transaction that stores the look
    (the Game row is locked), so there is never a committed look whose copy is
    unknown to the window close. See ``_resolve_doppelganger_look``.
    """
    return _resolve_doppelganger_look(game)


def _resolve_doppelganger_look(game: Game, *, send_prompt: bool = True) -> bool:
    """Resolve the Doppelganger's look as soon as she submits it.

    The look is the one result delivered before its window closes: she needs
    it to choose her follow-up. It goes only to her. Returns True if the copied
    role calls for an immediate follow-up, in which case (``send_prompt``) the
    follow-up prompt has been sent and the window stays open for it. With
    ``send_prompt=False`` (the window is closing) only the look is resolved, so the
    copied role is known and an unsubmitted follow-up gets its timeout default.
    """
    pr = _doppelganger_player_role(game)
    if pr is None:
        return False
    data = pr.night_action_data
    look = NightAction(
        player_id=pr.user_id,
        role_acting_as="Doppelganger",
        action_type=data["action_type"],
        targets=data.get("targets", {}),
    )
    state = build_game_state(game)
    new_state, results = resolve_wave(state, [look], 1)
    with transaction.atomic():
        persist_wave_results(game, new_state, results, 1)
    send_action_results(game, results, [look], 1)

    copied = new_state.doppelganger_copied_role.get(pr.user_id)
    if copied is None or get_doppelganger_followup_wave(copied) != 1:
        return False
    if not send_prompt:
        return True

    # Prompt the follow-up (Seer, Robber, Troublemaker, Drunk, Minion) at once.
    # No timer is scheduled or moved: window 1 has the one timer set when it
    # opened, so nothing about the follow-up is visible in the window's timing.
    with transaction.atomic():
        PlayerRole.objects.filter(game=game, user_id=pr.user_id).update(has_acted=False)
    prompt = build_role_prompt(build_game_state(game), pr.user_id, copied)
    _send_after_commit(
        [
            (
                f"game_{game.id}_player_{pr.user_id}",
                {
                    "type": "action.prompt",
                    "wave": 1,
                    "role_acting_as": prompt["role_acting_as"],
                    "action_types": prompt["action_types"],
                    "valid_targets": prompt["valid_targets"],
                },
            )
        ]
    )
    return True


def _collect_window_actions(game: Game, window: int) -> list[NightAction]:
    """Gather the window's actions: what each actor submitted, else their default.

    A player who submitted nothing gets the automatic action for their role:
    team views and the Insomniac's look still happen (they need no choice),
    anything with a choice is skipped.
    """
    # pyrefly: ignore [missing-attribute]
    player_roles = {pr.user_id: pr for pr in game.player_roles.all()}
    actions: list[NightAction] = []
    for pid in get_wave_actors(game, window):
        pr = player_roles[pid]
        role_acting_as = _determine_acting_role(pr, window)
        if role_acting_as is None:
            continue  # Already fully resolved earlier (the Doppelganger's look).
        data = pr.night_action_data
        if (
            pr.has_acted
            and data.get("wave") == window
            and data.get("role_acting_as") == role_acting_as
        ):
            action_type, targets = data.get("action_type"), data.get("targets", {})
            if isinstance(action_type, str) and isinstance(targets, dict):
                actions.append(
                    NightAction(
                        player_id=pid,
                        role_acting_as=role_acting_as,
                        action_type=action_type,
                        targets=targets,
                    )
                )
                continue
            logger.error(
                "Malformed stored night action for player %s in game %s: "
                "treated as a timeout",
                pid,
                game.id,
            )
        actions.append(_timeout_action(game, pid, role_acting_as))
    return actions


def _resolve_window_safely(
    game: Game, state: GameState, actions: list[NightAction], window: int
) -> tuple[list[NightAction], GameState, list[ActionResult]]:
    """Resolve a window; one player's stored action can never block the close.

    If resolving raises, each stored action is tried alone; one that raises is
    replaced by its role's timeout default (logged loudly) and the window closes.
    As a last resort every action falls back to its default. Returns the actions
    that were really resolved (the results are labelled with them).
    """
    try:
        new_state, results = resolve_window(state, actions, window)
        return actions, new_state, results
    except Exception:
        logger.exception(
            "Resolving night window %s of game %s failed; finding the stored "
            "action that breaks it",
            window,
            game.id,
        )
    safe: list[NightAction] = []
    for action in actions:
        try:
            resolve_window(state, [action], window)
            safe.append(action)
        except Exception:
            logger.error(
                "Stored night action of player %s (%s as %s) cannot be resolved "
                "in game %s: treated as a timeout",
                action.player_id,
                action.action_type,
                action.role_acting_as,
                game.id,
                exc_info=True,
            )
            safe.append(_timeout_action(game, action.player_id, action.role_acting_as))
    try:
        new_state, results = resolve_window(state, safe, window)
        return safe, new_state, results
    except Exception:
        logger.exception(
            "Night window %s of game %s still fails; every stored action is "
            "treated as a timeout",
            window,
            game.id,
        )
    defaults = [_timeout_action(game, a.player_id, a.role_acting_as) for a in actions]
    new_state, results = resolve_window(state, defaults, window)
    return defaults, new_state, results


def advance_wave(game: Game) -> None:
    """
    Close the current night window.

    Resolves the whole window through the engine (window 2: team views, then
    Seer, Robber, Troublemaker, Drunk, then Insomniac, each seeing the table
    after the previous step), persists the results, and only then sends each
    player their own result. Then opens window 2 or moves on to discussion.

    Closing here ignores the minimum length: the host and the maximum timer
    both come through this function. The minimum is enforced by
    _close_or_defer.
    """
    window = game.current_wave
    _cancel_after_commit(_window_timer_key(game, window))
    if window == 1 and _doppelganger_look_submitted(game):
        # A look that is stored but not resolved yet (the window job got the lock
        # first, or the step after the submission failed): resolve it now, so her
        # copied role is known and an unsubmitted follow-up (a Drunk must swap, a
        # Minion still looks) gets the same default as any other timeout.
        _resolve_doppelganger_look(game, send_prompt=False)
    state = build_game_state(game)
    night_actions = _collect_window_actions(game, window)

    night_actions, new_state, results = _resolve_window_safely(
        game, state, night_actions, window
    )

    with transaction.atomic():
        persist_wave_results(game, new_state, results, window)

    send_wave_results(game, results, night_actions, window)

    if window < NIGHT_WINDOWS[-1]:
        _open_window(game, window + 1)
    else:
        transition_to_discussion(game)


def _determine_acting_role(pr: PlayerRole, wave: int) -> str | None:
    """
    Role a player acts as in a night window, or None if they do not act in it.

    Decided from the DEALT card (original_role), never the card held now;
    a Doppelganger acts as the role she copied.
    """
    return get_player_acting_role_for_wave(pr, wave)


def persist_wave_results(
    game: Game,
    new_state: GameState,
    results: list[ActionResult],
    wave: int,
) -> None:
    """Write engine results back to DB within an atomic transaction.

    ``wave`` is the night window. Results are stored per window
    (``wave_<window>_result``); a player gets at most one in window 2. Log
    entries keep the order group they were resolved in, so the night log stays
    in wake order.
    """
    # Update center cards
    game.center_cards = new_state.center_cards

    # Append the action log entries produced by this resolution
    log = list(game.night_actions_log)
    for entry in new_state.action_log:
        log.append(
            {
                "wave": entry.wave,
                "player_id": entry.player_id,
                "action_type": entry.action_type,
                "targets": entry.targets,
                "result": entry.result,
                "timestamp_order": entry.timestamp_order,
                "role_acting_as": entry.role_acting_as,
                # Only present when the server moved for a player who timed out.
                **({"made_by_server": True} if entry.made_by_server else {}),
            }
        )
    game.night_actions_log = log
    game.save(update_fields=["center_cards", "night_actions_log", "updated_at"])

    # Update player roles (swaps may have occurred)
    for pid, role in new_state.player_roles.items():
        PlayerRole.objects.filter(game=game, user_id=pid).update(current_role=role)

    # Store action results in each player's night_action_data
    for result in results:
        if result.revealed_info:
            pr = PlayerRole.objects.get(game=game, user_id=result.player_id)
            data = dict(pr.night_action_data)
            data[f"wave_{wave}_result"] = result.revealed_info
            # For Doppelganger, also store copied_role at top level
            if "copied_role" in result.revealed_info:
                data["copied_role"] = result.revealed_info["copied_role"]
            pr.night_action_data = data
            pr.save(update_fields=["night_action_data"])


def _action_result_messages(
    game: Game,
    results: list[ActionResult],
    night_actions: list[NightAction],
    wave: int,
) -> list[tuple[str, dict[str, Any]]]:
    """Build each player's own action.result (and no one else's).

    Transforms the engine's raw revealed_info into the client-friendly
    format the frontend expects (display names, consistent keys, action_type).
    """
    player_names = _get_player_names(game)
    # A player can have more than one result in a resolution (the Doppelganger's
    # look, then her follow-up): label each result with ITS action, in the order
    # the engine resolves them (the look first).
    actions_by_player: dict[int, list[NightAction]] = {}
    for a in sorted(night_actions, key=lambda x: x.role_acting_as != "Doppelganger"):
        actions_by_player.setdefault(a.player_id, []).append(a)
    messages: list[tuple[str, dict[str, Any]]] = []
    for result in results:
        queue = actions_by_player.get(result.player_id)
        action = queue.pop(0) if queue else None
        if action is not None:
            try:
                action_type, client_info = client_action_result(
                    action, result.revealed_info, player_names
                )
            except Exception:
                # Never let a malformed stored target block the close.
                logger.exception(
                    "Could not build the result of player %s", result.player_id
                )
                action_type, client_info = "skip", {}
        else:
            client_info = result.revealed_info
            action_type = "unknown"
        messages.append(
            (
                f"game_{game.id}_player_{result.player_id}",
                {
                    "type": "action.result",
                    "wave": wave,
                    "action_type": action_type,
                    "revealed_info": client_info,
                },
            )
        )
    return messages


def send_action_results(
    game: Game,
    results: list[ActionResult],
    night_actions: list[NightAction],
    wave: int,
) -> None:
    """Send each player their own result (action.result only) after commit."""
    if get_channel_layer() is None:
        return
    _send_after_commit(_action_result_messages(game, results, night_actions, wave))


def send_wave_results(
    game: Game,
    results: list[ActionResult],
    night_actions: list[NightAction],
    wave: int,
) -> None:
    """Window closed: after commit, send every player their result, then wave.complete."""
    if get_channel_layer() is None:
        return
    messages = _action_result_messages(game, results, night_actions, wave)
    messages.append((f"game_{game.id}", {"type": "wave.complete", "wave": wave}))
    _send_after_commit(messages)


def transition_to_discussion(game: Game) -> None:
    """Transition the game from night to discussion phase."""
    discussion_seconds = get_timer_seconds(game, "discussion_seconds", 300)

    with transaction.atomic():
        game.phase = Phase.DISCUSSION
        game.current_wave = 0
        game.night_window_opened_at = None
        if discussion_seconds > 0:
            game.phase_deadline = timezone.now() + timedelta(seconds=discussion_seconds)
        else:
            game.phase_deadline = None
        game.save(
            update_fields=[
                "phase",
                "current_wave",
                "night_window_opened_at",
                "phase_deadline",
                "updated_at",
            ]
        )

        # Reset has_acted for voting phase later
        # pyrefly: ignore [missing-attribute]
        game.player_roles.update(has_acted=False)

    if discussion_seconds > 0:
        _schedule_after_commit(
            f"{game.id}:discussion",
            discussion_seconds,
            "discussion_deadline",
            {"game_id": str(game.id)},
        )

    # Broadcast phase change to all players
    _send_after_commit(
        [
            (
                f"game_{game.id}",
                {
                    "type": "phase.change",
                    "phase": "discussion",
                    "deadline": game.phase_deadline.isoformat()
                    if game.phase_deadline
                    else None,
                },
            )
        ]
    )


def _advance_if_ready(game: Game) -> None:
    """Close the open night window if there is nothing left to wait for.

    The caller holds the Game row lock and has checked the phase is night.
    The Doppelganger's look is resolved at once (she needs it to choose her
    follow-up). Window 1 has a fixed length and is never closed from here:
    only its own timer (or the host) closes it.
    """
    window = game.current_wave
    if window == 1 and _doppelganger_look_submitted(game):
        if _resolve_doppelganger_look(game):
            return  # The follow-up prompt went out; the window stays open.

    if _night_ready_to_close(game):
        _close_or_defer(game)


def check_and_maybe_advance(game: Game) -> None:
    """
    After a submission, close the window if everyone it waits for has submitted.

    The window still lasts at least its minimum length: if everyone is done
    early, the close is scheduled for when the minimum is reached. See
    _night_ready_to_close for who the window waits for.

    Uses select_for_update on the Game row to prevent double-fire
    when two players submit simultaneously.
    """
    with transaction.atomic():
        game = Game.objects.select_for_update().get(id=game.id)
        if game.phase != Phase.NIGHT:
            # Already advanced by another concurrent request
            return
        _advance_if_ready(game)


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


MALFORMED_TARGET = "Invalid target."

# The target keys each action type accepts (and nothing else).
ALLOWED_TARGET_KEYS: dict[str, set[str]] = {
    "skip": set(),
    "none": set(),
    "peek_player": {"player_id"},
    "peek_center": {"center_indices"},
    "swap_with_player": {"player_id"},
    "swap_with_center": {"center_index"},
    "swap_others": {"player_ids"},
    "see_team": {"center_index"},
}


def _strict_int(value: object) -> int | None:
    """The value if it is a plain integer, else None (bool, str, float, list, null)."""
    if isinstance(value, int) and not isinstance(value, bool):
        return value
    return None


def validate_night_action(
    game: Game,
    pr: PlayerRole,
    action_type: str,
    targets: dict[str, Any],
) -> list[str]:
    """
    Validate a submitted night action.

    Returns a list of error messages. Empty list means valid.
    """
    errors: list[str] = []
    wave = game.current_wave

    # Determine what role the player acts as this wave
    acting_role = get_player_acting_role_for_wave(pr, wave)
    if acting_role is None:
        errors.append("You do not act in the current wave.")
        return errors

    # Validate action_type is allowed for this role
    role_def = get_role(acting_role)
    allowed_types = [at.value for at in role_def.prompt_action_types]
    if action_type not in allowed_types:
        # Generic on purpose: never name a role or what it may do.
        errors.append("Invalid action type for this wave.")
        return errors

    # Only the target fields of this action type may be present: anything else
    # would be stored and read back at the window close.
    if set(targets) - ALLOWED_TARGET_KEYS.get(action_type, set()):
        errors.append("Invalid action.")
        return errors

    # Get all player IDs in this game (for target validation)
    # pyrefly: ignore [missing-attribute]
    game_player_ids = set(game.player_roles.values_list("user_id", flat=True))

    # Validate targets based on action_type. Values come from the client, so
    # anything that is not a plain JSON integer (strings, null, booleans, lists,
    # floats) is rejected with a generic message, never coerced.
    center_count = len(game.center_cards)

    def center_error(idx: int) -> str:
        return f"Invalid center card index: {idx}. Must be 0-{center_count - 1}."

    if action_type == "skip":
        # Explicit "do nothing": no targets allowed.
        if targets:
            errors.append("Invalid action.")

    elif action_type in ("peek_player", "swap_with_player"):
        raw = targets.get("player_id")
        if raw is None:
            errors.append(f"targets.player_id is required for {action_type}.")
        elif (target_id := _strict_int(raw)) is None:
            errors.append(MALFORMED_TARGET)
        # pyrefly: ignore [missing-attribute]
        elif target_id == pr.user_id:
            errors.append("Cannot target yourself.")
        elif target_id not in game_player_ids:
            errors.append(f"Invalid target player: {target_id}.")

    elif action_type == "peek_center":
        indices = targets.get("center_indices")
        if not isinstance(indices, list) or len(indices) != 2:
            errors.append("targets.center_indices must be a list of exactly 2 indices.")
        else:
            parsed = [_strict_int(idx) for idx in indices]
            ints = [idx for idx in parsed if idx is not None]
            if len(ints) != len(parsed):
                errors.append(MALFORMED_TARGET)
            else:
                for idx_int in ints:
                    if idx_int < 0 or idx_int >= center_count:
                        errors.append(center_error(idx_int))
                if ints[0] == ints[1]:
                    errors.append("Must peek at 2 different center cards.")

    elif action_type == "swap_with_center":
        raw = targets.get("center_index")
        if raw is None:
            errors.append("targets.center_index is required for swap_with_center.")
        elif (idx := _strict_int(raw)) is None:
            errors.append(MALFORMED_TARGET)
        elif idx < 0 or idx >= center_count:
            errors.append(center_error(idx))

    elif action_type == "swap_others":
        player_ids = targets.get("player_ids")
        if not isinstance(player_ids, list) or len(player_ids) != 2:
            errors.append("targets.player_ids must be a list of exactly 2 player IDs.")
        else:
            parsed = [_strict_int(pid) for pid in player_ids]
            ints = [pid for pid in parsed if pid is not None]
            if len(ints) != len(parsed):
                errors.append(MALFORMED_TARGET)
            else:
                for pid_int in ints:
                    # pyrefly: ignore [missing-attribute]
                    if pid_int == pr.user_id:
                        errors.append("Cannot target yourself in swap_others.")
                    elif pid_int not in game_player_ids:
                        errors.append(f"Invalid target player: {pid_int}.")
                if ints[0] == ints[1]:
                    errors.append("Must target 2 different players.")

    elif action_type == "see_team":
        # No targets required. Only a lone Werewolf may optionally peek center.
        # A PRESENT center_index must be a plain integer: null, strings, floats,
        # booleans and lists are refused (a null used to read as "absent" and was
        # stored, then broke the window close). Declining the peek is an empty
        # targets dict. Messages are generic: nothing here may name a role.
        if "center_index" in targets:
            center_idx = _strict_int(targets["center_index"])
            if center_idx is None:
                errors.append(MALFORMED_TARGET)
            else:
                # Verify the player is acting as Werewolf and is the only one.
                if acting_role != "Werewolf":
                    errors.append("Center card peek is not available.")
                else:
                    state = build_game_state(game)
                    other_werewolves = [
                        pid
                        for pid in state.player_roles
                        if pid != pr.user_id and is_effective_werewolf(pid, state)
                    ]
                    if other_werewolves:
                        errors.append("Center card peek is not available.")
                if center_idx < 0 or center_idx >= center_count:
                    errors.append(center_error(center_idx))

    return errors


# ── Discussion & Voting ────────────────────────────────────────────────────


def _auto_transition_to_voting(game: Game) -> None:
    """Auto-transition to voting when discussion timer expires."""
    transition_to_voting(game)


def _auto_reveal_votes(game: Game) -> None:
    """Auto-reveal votes when the voting timer expires."""
    reveal_votes(game)


def transition_to_voting(game: Game) -> None:
    """Transition from discussion to voting phase."""
    from .engine.phases import validate_phase_transition

    if not validate_phase_transition(game.phase, Phase.VOTING):
        msg = f"Cannot transition from {game.phase} to voting."
        raise ValueError(msg)

    voting_seconds = get_timer_seconds(game, "voting_seconds", 120)

    with transaction.atomic():
        game.phase = Phase.VOTING
        if voting_seconds > 0:
            game.phase_deadline = timezone.now() + timedelta(seconds=voting_seconds)
        else:
            game.phase_deadline = None
        game.save(update_fields=["phase", "phase_deadline", "updated_at"])

        # Reset has_acted for all players (tracks vote submission)
        # pyrefly: ignore [missing-attribute]
        game.player_roles.update(has_acted=False, vote_target=None)

    if voting_seconds > 0:
        _schedule_after_commit(
            f"{game.id}:voting",
            voting_seconds,
            "voting_deadline",
            {"game_id": str(game.id)},
        )

    # A phone that dropped during the talk is already on the clock: the vote
    # stops waiting for it when its grace period ends.
    _schedule_grace_timers_after_commit(game)

    # Broadcast phase change to all players
    _send_after_commit(
        [
            (
                f"game_{game.id}",
                {
                    "type": "phase.change",
                    "phase": "voting",
                    "deadline": game.phase_deadline.isoformat()
                    if game.phase_deadline
                    else None,
                },
            )
        ]
    )


def end_discussion(game: Game) -> None:
    """End discussion early (host action). Transitions to voting."""
    _cancel_after_commit(f"{game.id}:discussion")
    game.phase_deadline = None
    transition_to_voting(game)


def submit_vote(game: Game, voter_id: int, target_player_id: int) -> list[str]:
    """
    Submit a vote. Returns list of errors (empty = success).

    Validates:
    - Game is in VOTING phase
    - Voter is in the game
    - Voter hasn't already voted (has_acted or vote_target is set)
    - Target is not the voter (no self-votes)
    - Target is a valid player in the game

    On success:
    - Sets PlayerRole.vote_target = target user
    - Sets PlayerRole.has_acted = True
    - Broadcasts vote_submitted (WHO voted, NOT their target) to game group
    - Checks if all players have voted -> if so, trigger reveal
    """
    errors: list[str] = []

    if game.phase != Phase.VOTING:
        errors.append("Game is not in the voting phase.")
        return errors

    # Lock the voter's PlayerRole row to prevent TOCTOU race on has_acted.
    with transaction.atomic():
        try:
            voter_pr = PlayerRole.objects.select_for_update().get(
                game=game, user_id=voter_id
            )
        except PlayerRole.DoesNotExist:
            errors.append("You are not a player in this game.")
            return errors

        if voter_pr.has_acted:
            raise AlreadyActedError("You have already voted.")

        # No self-votes per spec
        if voter_id == target_player_id:
            errors.append("You cannot vote for yourself.")
            return errors

        # Validate target is a valid player in the game
        # pyrefly: ignore [missing-attribute]
        game_player_ids = set(game.player_roles.values_list("user_id", flat=True))
        if target_player_id not in game_player_ids:
            errors.append("Invalid vote target.")
            return errors

        # Store vote
        # pyrefly: ignore [missing-attribute]
        voter_pr.vote_target_id = target_player_id
        voter_pr.has_acted = True
        voter_pr.save(update_fields=["vote_target", "has_acted"])

    # Broadcast and auto-reveal OUTSIDE the transaction to avoid
    # holding the row lock during channel operations.
    _send_after_commit(
        [(f"game_{game.id}", {"type": "vote.submitted", "player_id": voter_id})]
    )

    # Check if all players have voted -> auto-reveal.
    # Lock the Game row to prevent double-fire when two players
    # submit simultaneously and both see all votes in.
    with transaction.atomic():
        game = Game.objects.select_for_update().get(id=game.id)
        if game.phase != Phase.VOTING:
            # Already revealed by another concurrent request
            return errors
        # Reveal once everyone has voted, or everyone still being waited for
        # has (a player gone past the grace period counts as a non-voter).
        if _votes_ready(game):
            reveal_votes(game)

    return errors


def reveal_votes(game: Game) -> None:
    """
    Reveal all votes simultaneously, compute win conditions, and
    transition to results.

    Collects all votes (including None for abstainers).
    Broadcasts vote_reveal event with full vote data.
    Computes elimination and win conditions.
    Stores results in game.results.
    Transitions game to RESULTS phase.
    Broadcasts game_results event.
    """
    # Cancel the voting timer — covers both the host force-reveal and
    # the all-voted path (double-cancel is safe). After commit, like every
    # other side effect, so a rollback leaves the vote running.
    _cancel_after_commit(f"{game.id}:voting")

    # Collect vote data
    # pyrefly: ignore [missing-attribute]
    player_roles_qs = game.player_roles.all()
    votes_broadcast: dict[str, int | None] = {}
    votes_dict: dict[int, int | None] = {}
    current_roles: dict[int, str] = {}
    doppelganger_copied: dict[int, str] = {}

    for pr in player_roles_qs:
        # pyrefly: ignore [missing-attribute]
        votes_broadcast[str(pr.user_id)] = pr.vote_target_id
        # pyrefly: ignore [missing-attribute]
        votes_dict[pr.user_id] = pr.vote_target_id
        current_roles[pr.user_id] = pr.current_role
        if pr.original_role == "Doppelganger" and pr.night_action_data.get(
            "copied_role"
        ):
            doppelganger_copied[pr.user_id] = pr.night_action_data["copied_role"]

    messages: list[tuple[str, dict[str, Any]]] = [
        (f"game_{game.id}", {"type": "vote.reveal", "votes": votes_broadcast})
    ]

    # Compute elimination
    vote_counts = count_votes(votes_dict)
    vote_eliminated = determine_elimination(vote_counts)

    # Apply Hunter chain — adds hunter targets on top of vote-eliminated
    eliminated = apply_hunter(
        vote_eliminated, current_roles, votes_dict, doppelganger_copied
    )

    # Build elimination_reasons: vote for vote-eliminated, hunter_chain for the rest
    vote_eliminated_set = set(vote_eliminated)
    elimination_reasons: dict[str, str] = {}
    for pid in eliminated:
        elimination_reasons[str(pid)] = (
            "vote" if pid in vote_eliminated_set else "hunter_chain"
        )

    # Compute win conditions
    result = evaluate_winner(eliminated, current_roles, doppelganger_copied)

    # Transition to results phase, store results, and finalize the lobby
    # atomically so game and lobby state are always consistent.
    with transaction.atomic():
        game.phase = Phase.RESULTS
        game.phase_deadline = None
        game.results = {
            "winning_teams": result.winning_teams,
            "reason": result.reason,
            "eliminated_players": result.eliminated_players,
            "elimination_reasons": elimination_reasons,
            "player_outcomes": {str(k): v for k, v in result.player_outcomes.items()},
        }
        game.save(update_fields=["phase", "phase_deadline", "results", "updated_at"])

        Lobby.objects.filter(id=game.lobby_id).update(status=Lobby.Status.FINISHED)

    # Clean up all remaining timers for this game (safety net — individual
    # timers are cancelled at each phase transition, but this catches any
    # that were missed due to unusual flow, and the grace timers).
    game_id = str(game.id)
    _after_commit(lambda: timers.cancel_all_for_game(game_id))

    # Broadcast the reveal, then the results, once the transition has committed.
    messages.append(
        (
            f"game_{game.id}",
            {
                "type": "game.results",
                "data": {
                    "winning_teams": result.winning_teams,
                    "reason": result.reason,
                    "eliminated_players": result.eliminated_players,
                },
            },
        )
    )
    _send_after_commit(messages)


# ── Presence: dropped phones ────────────────────────────────────────────────
#
# Each open game WebSocket is a row (SocketPresence, see presence.py) kept fresh
# by a heartbeat; a player is connected while one of their rows is fresh. When
# the last one closes (cleanly, or silently: its heartbeat went stale and the
# durable presence check noticed) PlayerRole.disconnected_at is stamped.
# Presence is public ("player_presence" events, "connected" in the player list).
#
# A player whose phone has been gone for the grace period (disconnect_grace_seconds,
# default 25, 0 = off) is "gone": at night and in the vote the game stops waiting
# for them and treats them exactly as it treats a timeout / a non-voter. The
# talk (discussion) never waits for anyone and is not affected.
#
# Hidden-information rule: while a player is inside their grace period the night
# window waits for them WHETHER OR NOT THEY HAVE AN ACTION. If it waited only for
# a dropped player who still had to act, the moment the window closed would tell
# the table whether that player was an actor, i.e. something about their card.


def _grace_seconds(game: Game) -> int:
    return get_timer_seconds(
        game, "disconnect_grace_seconds", DEFAULT_DISCONNECT_GRACE_SECONDS
    )


def _pr_connected(pr: PlayerRole) -> bool:
    """Is the player connected now? Uses ``pr.is_connected`` when the caller
    annotated it (presence.annotate), else asks the database."""
    known = getattr(pr, "is_connected", None)
    if known is None:
        known = presence.fresh_rows(game_id=pr.game_id, user_id=pr.user_id).exists()  # type: ignore[attr-defined]
        pr.is_connected = known  # type: ignore[attr-defined]
    return bool(known)


def _player_roles(game: Game) -> list[PlayerRole]:
    """The game's PlayerRoles with ``is_connected`` set (one extra query)."""
    # pyrefly: ignore [missing-attribute]
    return presence.annotate(list(game.player_roles.all()), game.id)


def _seconds_disconnected(pr: PlayerRole, now: Any) -> float | None:
    """Seconds since the player was noticed to have no open socket, or None if
    connected / never seen disconnected."""
    if pr.disconnected_at is None or _pr_connected(pr):
        return None
    return (now - pr.disconnected_at).total_seconds()


def _is_gone(pr: PlayerRole, grace: int, now: Any) -> bool:
    """True once the player has been disconnected for at least the grace period."""
    if grace <= 0:
        return False
    away = _seconds_disconnected(pr, now)
    return away is not None and away >= grace


def _is_recently_dropped(pr: PlayerRole, grace: int, now: Any) -> bool:
    """True while the player is disconnected but still inside the grace period."""
    if grace <= 0:
        return False
    away = _seconds_disconnected(pr, now)
    return away is not None and away < grace


def _grace_timer_key(game_id: Any, user_id: int) -> str:
    return f"{game_id}:grace:{user_id}"


def _night_ready_to_close(game: Game, *, ignore_recent_drops: bool = False) -> bool:
    """True when the open night window has nothing left to wait for.

    Every actor has acted, except actors whose phone has been gone past the
    grace period (treated as a timeout, through the normal close path, so the
    minimum window length still applies). A player still inside their grace
    period holds the window open whatever their role (see the note above), and
    so does an empty table: if every phone is gone nobody is there to be told,
    so only the window's own deadline (or the host) closes it.

    ``ignore_recent_drops`` is for rebuilding timers after a restart, where
    every player has just been stamped disconnected only because no socket
    survived: that is not a real drop and must not defer a close that was
    already due.
    """
    prs = _player_roles(game)
    actor_ids = set(get_wave_actors(game, game.current_wave))
    grace = _grace_seconds(game)
    now = timezone.now()
    if not ignore_recent_drops and any(
        _is_recently_dropped(pr, grace, now) for pr in prs
    ):
        return False
    if prs and all(_is_gone(pr, grace, now) for pr in prs):
        return False
    return all(
        pr.has_acted or _is_gone(pr, grace, now)
        for pr in prs
        if pr.user_id in actor_ids
    )


def _votes_ready(game: Game) -> bool:
    """True when the vote can be revealed: everyone has voted, or everyone the
    vote still waits for has (a player gone past the grace period is a non-voter,
    exactly as at the voting deadline). Needs someone present to be told."""
    prs = _player_roles(game)
    if all(pr.has_acted for pr in prs):
        return True
    grace = _grace_seconds(game)
    now = timezone.now()
    present = [pr for pr in prs if not _is_gone(pr, grace, now)]
    return bool(present) and all(pr.has_acted for pr in present)


def _evaluate_presence(game: Game) -> None:
    """Re-check whether the night window / the vote can now proceed.

    The caller holds the Game row lock. Called when a grace period ends.
    """
    if game.phase == Phase.NIGHT and game.current_wave in NIGHT_WINDOWS:
        _advance_if_ready(game)
    elif game.phase == Phase.VOTING and _votes_ready(game):
        reveal_votes(game)


def _grace_expired(game_id: Any, user_id: int) -> None:
    """Timer callback: a dropped player's grace period has run out."""
    try:
        with transaction.atomic():
            try:
                game = Game.objects.select_for_update().get(id=game_id)
            except Game.DoesNotExist:
                return
            if game.phase not in (Phase.NIGHT, Phase.VOTING):
                return  # Nothing waits for anyone in the talk, or the game is over.
            pr = PlayerRole.objects.filter(game=game, user_id=user_id).first()
            if pr is None:
                return
            away = _seconds_disconnected(pr, timezone.now())
            if away is None:
                return  # Reconnected (or never dropped): keep waiting for them.
            remaining = _grace_seconds(game) - away
            if remaining > 0:
                # Fired a hair early (timer and wall clocks differ): try again.
                _schedule_after_commit(
                    _grace_timer_key(game_id, user_id),
                    remaining,
                    "grace_expired",
                    {"game_id": str(game_id), "user_id": user_id},
                )
                return
            _evaluate_presence(game)
    except Exception:
        logger.exception(
            "Grace-period callback failed for game %s player %s", game_id, user_id
        )
        raise  # the timer job: fire() rolls back and keeps the row for a retry


def _grace_timer_plan(
    game: Game, prs: list[PlayerRole], *, include_expired: bool
) -> list[tuple[int, float]]:
    """(user_id, delay) for each disconnected player who needs a grace timer.

    A player still inside their grace period is timed for the rest of it. One
    already past it is timed for "now" when include_expired is set, so a lost
    timer cannot leave the game waiting for someone it has stopped waiting for.
    """
    grace = _grace_seconds(game)
    if grace <= 0 or game.phase not in (Phase.NIGHT, Phase.VOTING):
        return []
    now = timezone.now()
    plan: list[tuple[int, float]] = []
    for pr in prs:
        away = _seconds_disconnected(pr, now)
        if away is None:
            continue
        remaining = grace - away
        if remaining > 0:
            plan.append((pr.user_id, remaining))
        elif include_expired:
            plan.append((pr.user_id, 0.0))
    return plan


def _schedule_grace_timers_after_commit(game: Game) -> None:
    """Time the grace period of every player who is already disconnected.

    Used when voting opens: a phone that dropped during the talk had no timer.
    """
    # pyrefly: ignore [missing-attribute]
    prs = list(game.player_roles.filter(disconnected_at__isnull=False))
    for user_id, delay in _grace_timer_plan(game, prs, include_expired=False):
        _schedule_after_commit(
            _grace_timer_key(game.id, user_id),
            delay,
            "grace_expired",
            {"game_id": str(game.id), "user_id": user_id},
        )


def _lock_game_and_player(
    game_id: Any, user_id: int
) -> tuple[Game | None, PlayerRole | None]:
    """Lock the Game row, then the player's row (the order used everywhere)."""
    game = Game.objects.select_for_update().filter(id=game_id).first()
    if game is None:
        return None, None
    pr = (
        PlayerRole.objects.select_for_update()
        .filter(game=game, user_id=user_id)
        .first()
    )
    return game, pr


def _new_channel_name() -> str:
    """A unique stand-in for a channel name (callers without a real socket)."""
    return f"direct.{uuid.uuid4().hex}"


def register_connection(
    game_id: Any, user_id: int, channel_name: str | None = None
) -> bool:
    """A game socket opened for this player (sync; call from the consumer).

    Inserts the socket's row under row locks. If the player had no fresh row
    before, this is "coming back": it cancels any grace timer, tells the table
    the player is back, and (at night or in the vote) re-checks whether the game
    can now proceed (the player holding a night window open by being inside
    their grace period no longer does). Also makes sure a presence check is
    pending for this player. Returns True if the player just went from offline
    to online.
    """
    channel_name = channel_name or _new_channel_name()
    with transaction.atomic():
        game, pr = _lock_game_and_player(game_id, user_id)
        if game is None or pr is None:
            return False
        was_connected = presence.fresh_rows(game_id=game.id, user_id=user_id).exists()
        # Stale rows of this player are dead sockets: drop them.
        SocketPresence.objects.filter(game=game, user_id=user_id).exclude(
            last_seen__gte=presence.cutoff()
        ).delete()
        SocketPresence.objects.update_or_create(
            channel_name=channel_name,
            defaults={
                "user_id": user_id,
                "game": game,
                "connected_at": Now(),
                "last_seen": Now(),
            },
        )
        _after_commit(lambda: presence.ensure_check_timer("game", game_id, user_id))
        if was_connected:
            return False

        if pr.disconnected_at is not None:
            pr.disconnected_at = None
            pr.save(update_fields=["disconnected_at"])
        _cancel_after_commit(_grace_timer_key(game_id, user_id))
        _send_after_commit(
            [
                (
                    f"game_{game_id}",
                    {
                        "type": "player.presence",
                        "player_id": user_id,
                        "connected": True,
                    },
                )
            ]
        )
        if game.phase in (Phase.NIGHT, Phase.VOTING):
            try:
                with transaction.atomic():  # a savepoint: never costs the connect
                    _evaluate_presence(game)
            except Exception:
                logger.exception("Presence check failed for game %s", game_id)
        return True


def _game_went_offline(game: Game, pr: PlayerRole, user_id: int) -> None:
    """The player has no fresh socket left: stamp it, tell the table, start the
    grace timer. The ONE code path for a clean last-socket disconnect and for a
    silent death noticed by the presence check. Caller holds the locks."""
    pr.disconnected_at = timezone.now()
    pr.save(update_fields=["disconnected_at"])
    _send_after_commit(
        [
            (
                f"game_{game.id}",
                {"type": "player.presence", "player_id": user_id, "connected": False},
            )
        ]
    )
    grace = _grace_seconds(game)
    if game.phase in (Phase.NIGHT, Phase.VOTING) and grace > 0:
        _schedule_after_commit(
            _grace_timer_key(game.id, user_id),
            grace,
            "grace_expired",
            {"game_id": str(game.id), "user_id": user_id},
        )


def unregister_connection(
    game_id: Any, user_id: int, channel_name: str | None = None
) -> bool:
    """A game socket closed for this player (sync; call from the consumer).

    Deletes the socket's row (``channel_name``; without one, the player's
    newest row). When no fresh row is left, runs the went-offline path: stamps
    disconnected_at, tells the table, and (at night or in the vote) starts the
    grace timer. Returns True if the player just went from online to offline.
    """
    with transaction.atomic():
        game, pr = _lock_game_and_player(game_id, user_id)
        if game is None or pr is None:
            return False
        rows = SocketPresence.objects.filter(game=game, user_id=user_id)
        if channel_name is not None:
            rows = rows.filter(channel_name=channel_name)
        else:
            newest = rows.order_by("-connected_at", "-id").first()
            rows = rows.filter(pk=newest.pk) if newest else rows.none()
        if not rows.delete()[0]:
            return False  # not counted (rejected, or already cleaned up)
        if presence.fresh_rows(game_id=game.id, user_id=user_id).exists():
            return False
        SocketPresence.objects.filter(game=game, user_id=user_id).delete()
        _cancel_after_commit(presence.check_key("game", game.id, user_id))
        _game_went_offline(game, pr, user_id)
        return True


def refresh_connection(game_id: Any, user_id: int, channel_name: str) -> bool:
    """Heartbeat of a game socket: bump ``last_seen`` and make sure a presence
    check is pending. A socket whose row was already removed (a long pause let
    the check clean it up) is re-registered, which is a real "coming back"
    (returns True then). Closes this thread's database connection: nothing is
    held open between beats."""
    try:
        updated = SocketPresence.objects.filter(channel_name=channel_name).update(
            last_seen=Now()
        )
        if not updated:
            return register_connection(game_id, user_id, channel_name)
        presence.ensure_check_timer("game", game_id, user_id)
        return False
    finally:
        timers.release_connections()


def check_game_presence(game_id: Any, user_id: int) -> bool:
    """The durable presence check of a (game, player) fired.

    A fresh socket row: all is well, re-arm for when it would go stale (no
    Game lock is taken). Only stale rows: the socket died silently, so (under
    the usual Game then PlayerRole locks, re-checking) delete them and run the
    same went-offline path as a clean disconnect. Returns True if the player
    went offline; the caller runs host handover AFTER committing.
    """

    def rearm(age: float) -> None:
        _schedule_after_commit(
            presence.check_key("game", game_id, user_id),
            presence.next_check_delay(age),
            "presence_check",
            presence.check_params("game", game_id, user_id),
        )

    rows = SocketPresence.objects.filter(game_id=game_id, user_id=user_id)
    age = presence.seconds_since_newest(rows)
    if age is None:
        return False  # a clean disconnect already dealt with it
    if age <= presence.stale_seconds():
        rearm(age)
        return False
    with transaction.atomic():
        game, pr = _lock_game_and_player(game_id, user_id)
        if game is None or pr is None:
            return False
        rows = SocketPresence.objects.filter(game=game, user_id=user_id)
        age = presence.seconds_since_newest(rows)
        if age is None:
            return False
        if age <= presence.stale_seconds():  # reconnected meanwhile
            rearm(age)
            return False
        rows.delete()
        _game_went_offline(game, pr, user_id)
        return True


def make_idempotent_callback(
    game_id: Any,
    expected_phase: str,
    action: Callable[[Any], None],  # action receives Game instance
    *,
    reraise: bool = False,
) -> Callable[[], None]:
    """
    Wrap a phase-transition action so it is a no-op if the phase has already changed.

    Uses select_for_update() to serialise concurrent callbacks — if two timer threads
    race, only one proceeds. The other will find the phase already changed and return.

    Exceptions are always logged (with the game id and phase). A failed callback
    rolls its own transaction back, so the game is left exactly as it was and the
    host can still advance it. With ``reraise`` the exception then propagates (the
    timer jobs do this, so ``fire`` keeps the timer row for a retry); without it
    the callback swallows it (the original behaviour).
    """

    def _callback() -> None:
        # Import inside function to avoid circular imports at module load time.
        from django.db import transaction

        from apps.onuw.models import Game

        try:
            with transaction.atomic():
                try:
                    game = Game.objects.select_for_update().get(id=game_id)
                except Game.DoesNotExist:
                    return  # Game was deleted — nothing to do.
                if game.phase != expected_phase:
                    return  # Phase already advanced — stale callback, skip.
                action(game)
        except Exception:
            logger.exception(
                "Timer callback failed for game %s (expected phase %s)",
                game_id,
                expected_phase,
            )
            if reraise:
                raise

    return _callback


# ── Timer jobs ──────────────────────────────────────────────────────────────
#
# What a due timer runs (see timers.py): a named job with JSON parameters. Each
# handler locks the Game row and re-checks the phase (and, at night, the window
# number), so a stale, duplicate or late firing is harmless.


@timers.job("night_window")
def _job_night_window(game_id: str, wave: int, deferred: bool = False) -> None:
    make_idempotent_callback(
        game_id,
        Phase.NIGHT,
        functools.partial(_auto_advance_wave, wave_number=wave, deferred=deferred),
        reraise=True,
    )()


@timers.job("discussion_deadline")
def _job_discussion_deadline(game_id: str) -> None:
    make_idempotent_callback(
        game_id, Phase.DISCUSSION, _auto_transition_to_voting, reraise=True
    )()


@timers.job("voting_deadline")
def _job_voting_deadline(game_id: str) -> None:
    make_idempotent_callback(game_id, Phase.VOTING, _auto_reveal_votes, reraise=True)()


@timers.job("grace_expired")
def _job_grace_expired(game_id: str, user_id: int) -> None:
    _grace_expired(game_id, user_id)


# ── Restart recovery ────────────────────────────────────────────────────────
#
# Timers live in this process's memory; the stored deadlines are the source of
# truth. recover_timers() runs once at server start and ensure_timers() runs
# lazily whenever a player fetches their game state, so a game recovers even
# if start-up recovery missed it. Both are idempotent and safe in several
# worker processes at once: a timer that fires in two workers is harmless
# because every callback takes the Game row lock and re-checks the phase (and,
# at night, the window number) before doing anything.


def _grant_reconnect_allowance(game: Game) -> None:
    """Give a rebuilt timer room for phones to reconnect.

    If the game's deadline is overdue or closer than the allowance, move it to
    now + RECOVERY_RECONNECT_ALLOWANCE_SECONDS and persist it (so clients show
    the right countdown), updating ``game`` in place. The extension depends only
    on the clock and the stored deadline, never on what any player did, so it is
    the same for every game state (including the fixed Doppelganger window,
    whose length therefore still says nothing about her). Compare-and-set: if
    another worker already moved it, take its value.
    """
    deadline = game.phase_deadline
    if deadline is None:
        return
    now = timezone.now()
    floor = now + timedelta(seconds=RECOVERY_RECONNECT_ALLOWANCE_SECONDS)
    if deadline >= floor:
        return
    moved = Game.objects.filter(
        id=game.id,
        phase=game.phase,
        current_wave=game.current_wave,
        phase_deadline=deadline,
    ).update(phase_deadline=floor, updated_at=now)
    if moved:
        game.phase_deadline = floor
    else:
        game.phase_deadline = (
            Game.objects.filter(id=game.id)
            .values_list("phase_deadline", flat=True)
            .first()
        )


# A night still at window 0 after this long has not "just started": it is stuck.
NIGHT_START_STUCK_SECONDS = 15


def _night_start_is_stuck(game: Game) -> bool:
    """True if the game was created more than NIGHT_START_STUCK_SECONDS ago (by
    the database clock) and its night still has no window."""
    return Game.objects.filter(
        pk=game.pk,
        phase=Phase.NIGHT,
        current_wave=0,
        created_at__lt=Now() - timedelta(seconds=NIGHT_START_STUCK_SECONDS),
    ).exists()


def timer_prefixes(game: Game) -> tuple[str, ...]:
    """Key prefixes of every timer belonging to a game (for a scoped sweep)."""
    return (f"{game.id}:", f"presence:game:{game.id}:")


def _night_timer_plan(game: Game) -> tuple[float, dict[str, Any]] | None:
    """(delay, callback) for the open night window's one timer, or None.

    Normally the window's deadline. If everyone it waits for is done and the
    window may close, the close is due at its minimum length instead (that is
    what the lost "deferred close" timer was for; it re-checks when it fires);
    a window whose minimum has passed is due at once. A fixed-length window (Doppelganger) only ever has
    its deadline. A window with no deadline and nothing to close has no timer:
    only the host moves it.
    """
    window = game.current_wave
    deadline_delay: float | None = None
    if game.phase_deadline is not None:
        deadline_delay = max(
            0.0, (game.phase_deadline - timezone.now()).total_seconds()
        )
    ready_delay: float | None = None
    if _fixed_window_seconds(game, window) == 0 and _night_ready_to_close(
        game, ignore_recent_drops=True
    ):
        ready_delay = _min_close_delay(game)
    delays = [d for d in (deadline_delay, ready_delay) if d is not None]
    if not delays:
        return None
    delay = min(delays)
    # The early (minimum-length) close re-checks readiness when it fires; the
    # deadline timer closes unconditionally.
    closes_early = ready_delay is not None and (
        deadline_delay is None or ready_delay < deadline_delay
    )
    return delay, _window_job_params(game, window, deferred=closes_early)


def _phase_timer_plan(
    game: Game,
) -> tuple[str, float, str, dict[str, Any]] | None:
    """(key, delay, job, params) for the timer the game's stored state calls for.

    Only asked for when the timer is missing (after a restart, or lost), so an
    overdue / nearly due deadline is first given the reconnect allowance.
    """
    _grant_reconnect_allowance(game)
    if game.phase == Phase.NIGHT and game.current_wave in NIGHT_WINDOWS:
        key = _window_timer_key(game, game.current_wave)
        plan = _night_timer_plan(game)
        return None if plan is None else (key, plan[0], "night_window", plan[1])
    if game.phase_deadline is None:
        return None
    delay = max(0.0, (game.phase_deadline - timezone.now()).total_seconds())
    if game.phase == Phase.DISCUSSION:
        return (
            f"{game.id}:discussion",
            delay,
            "discussion_deadline",
            {"game_id": str(game.id)},
        )
    if game.phase == Phase.VOTING:
        return (
            f"{game.id}:voting",
            delay,
            "voting_deadline",
            {"game_id": str(game.id)},
        )
    return None


def ensure_timers(game: Game, player_roles: list[PlayerRole] | None = None) -> None:
    """Make sure the timers the game's stored state calls for are registered.

    Re-creates, if missing: the phase / night-window timer (an overdue deadline
    fires promptly, not never), the deferred "everyone has acted but the
    minimum length has not passed" close, and the grace timers of dropped
    players. Cheap when the timers are already registered: no database access
    beyond ``player_roles`` if given. (A night that never opened its first
    window is only repaired by recover_timers at start-up, never lazily.)
    """
    if game.phase not in TIMED_PHASES:
        return
    if game.phase == Phase.NIGHT and game.current_wave not in NIGHT_WINDOWS:
        # A committed night whose first window never opened (the instance died
        # between creating the game and opening it): open it, once the game has
        # had time to open on its own. start_night_phase is idempotent under
        # the Game lock, so a race with the starter is harmless.
        if game.current_wave == 0 and _night_start_is_stuck(game):
            start_night_phase(game)
        return

    plan_key = (
        _window_timer_key(game, game.current_wave)
        if game.phase == Phase.NIGHT
        else f"{game.id}:{game.phase}"
    )
    if not timers.is_scheduled(plan_key):
        plan = _phase_timer_plan(game)
        if plan is not None:
            key, delay, job, params = plan
            timers.schedule(key, delay, job, params)

    if game.phase in (Phase.NIGHT, Phase.VOTING):
        prs = (
            player_roles
            if player_roles is not None
            # pyrefly: ignore [missing-attribute]
            else _player_roles(game)
        )
        for user_id, delay in _grace_timer_plan(game, prs, include_expired=True):
            key = _grace_timer_key(game.id, user_id)
            if not timers.is_scheduled(key):
                timers.schedule(
                    key,
                    delay,
                    "grace_expired",
                    {"game_id": str(game.id), "user_id": user_id},
                )


def recover_timers() -> int:
    """Rebuild every running game's timers after a server start (memory backend
    only). Returns the number of games looked at.

    Presence is NOT reset: socket rows left by the dead process go stale (no
    heartbeat) and the presence checks re-armed from the table notice them, so
    a player whose phone reconnects within seconds is never marked gone. Each
    game in night / discussion / voting gets its timers back via ensure_timers
    (a night stuck before its first window is opened), then whatever else is
    stored but not armed in this process is re-armed from the table.
    """
    logger.info(
        "Start-up recovery (memory timer backend): re-arming timers from the "
        "database. Presence is not reset; socket rows that went stale are noticed "
        "by their presence checks. Only ONE server process is supported with this "
        "backend: its timers live in this process (use ONUW_TIMER_BACKEND="
        "vercel_queue for several instances)."
    )
    from apps.core import host

    host.ensure_timers_after_restart()
    count = 0
    for game in Game.objects.filter(phase__in=TIMED_PHASES):
        count += 1
        try:
            if game.phase == Phase.NIGHT and game.current_wave == 0:
                # Crashed between creating the game and opening its first
                # window: open it now (a no-op if another worker already did).
                start_night_phase(game)
            else:
                ensure_timers(game)
        except Exception:
            logger.exception("Could not recover timers for game %s", game.id)
    # Whatever else is stored but not armed in this process (presence checks,
    # timers of games that are no longer running: their jobs are no-ops).
    timers.rearm_from_table()
    return count


def run_startup_recovery() -> None:
    """Recover timers once, at real server start (called from the ASGI module).

    Skipped when ONUW_RECOVER_TIMERS_ON_START is False (the test settings), and
    never allowed to stop the server from starting: an unmigrated or
    unreachable database just means there is nothing to recover yet.

    The work runs in a short-lived thread that is joined here. An ASGI server
    may import the application inside a running event loop, where Django
    refuses synchronous database access (SynchronousOnlyOperation); a plain
    thread has no running loop, so this works the same either way. The thread's
    own database connections are closed when it ends.
    """
    if not getattr(django_settings, "ONUW_RECOVER_TIMERS_ON_START", True):
        return
    if timers.backend() == timers.BACKEND_QUEUE:
        # No process owns timers there: a queue message fires each one, and
        # any instance starting or stopping at any time must change nothing.
        return

    def _run() -> None:
        from django.db import connections

        try:
            recovered = recover_timers()
        except DatabaseError:
            logger.warning("Timer recovery skipped: database not ready.", exc_info=True)
        except Exception:
            logger.exception("Timer recovery failed.")
        else:
            logger.info("Timer recovery looked at %d running game(s).", recovered)
        finally:
            connections.close_all()

    thread = threading.Thread(target=_run, name="onuw-timer-recovery", daemon=True)
    thread.start()
    thread.join(timeout=60)
    if thread.is_alive():
        logger.warning("Timer recovery is still running after 60 seconds; carrying on.")


# ── The lobby's current game ──────────────────────────────────────────────


def latest_game(lobby: Lobby) -> Game | None:
    """The lobby's current game: its newest one."""
    # pyrefly: ignore [missing-attribute]
    return lobby.games.order_by("-created_at", "-id").first()


def report_game_presence(game_id: Any, user_id: int, connected: bool) -> None:
    """Tell the lobby (host handover) that a player's socket on this game opened
    (0 -> 1) or closed (1 -> 0). Call only after the game presence transaction
    has committed. Only the lobby's newest game counts."""
    from apps.core import host

    game = Game.objects.filter(id=game_id).only("lobby_id").first()
    if game is None:
        return
    newest = (
        Game.objects.filter(lobby_id=game.lobby_id)
        .order_by("-created_at", "-id")
        .first()
    )
    if newest is None or newest.id != game.id:
        return
    host.member_presence_changed(game.lobby_id, user_id, connected)
