"""
ONUW game service layer.

Coordinates between HTTP/WS (views, consumers) and the pure-Python engine.
All game state transitions go through this module.
"""

from __future__ import annotations

import functools
from datetime import timedelta
from typing import Any

from django.db import transaction
from django.utils import timezone

from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer

from apps.onuw import timers

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
from .engine.voting import apply_hunter, count_votes, determine_elimination
from .engine.win_conditions import evaluate_winner
from .models import Game, Phase, PlayerRole


class AlreadyActedError(Exception):
    """Raised when a player tries to act again after already submitting."""


# Night windows: 1 = Doppelganger alone, 2 = everyone else at once.
NIGHT_WINDOWS = (1, 2)

# Default maximum length of a night window (seconds). 0 disables the timer.
DEFAULT_NIGHT_WAVE_SECONDS = 30
# Default minimum length of a night window (seconds). A window never closes
# sooner than this after it opened, so a fast window gives nothing away.
DEFAULT_NIGHT_MIN_WINDOW_SECONDS = 8


def get_timer_seconds(game: Game, key: str, default: int) -> int:
    """Read a timer duration from game settings, returning default if not set."""
    return game.settings.get(key, default)


def _window_timer_key(game: Game, window: int) -> str:
    return f"{game.id}:wave:{window}"


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
        _open_window(locked, first_window)
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

    # With nobody to wait for, the window still lasts its minimum length.
    if not get_wave_actors(game, window):
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


def _close_or_defer(game: Game) -> None:
    """Close the current window now, or at its minimum length if that is later.

    Called with the Game row locked once every actor in the window is done.
    Rescheduling replaces the window's maximum timer under the same key; the
    callback is idempotent per window.
    """
    window = game.current_wave
    delay = _min_close_delay(game)
    if delay > 0:
        callback = timers.make_idempotent_callback(
            game.id,
            Phase.NIGHT,
            functools.partial(_auto_advance_wave, wave_number=window),
        )
        timers.schedule(_window_timer_key(game, window), delay, callback)
        return
    advance_wave(game)


def _timeout_action_type(role_acting_as: str) -> str:
    """Determine the action type for a player who didn't submit before the timer.

    Automatic roles (Insomniac, see_team roles) are auto-resolved rather than
    skipped, because their actions require no player choice — the information
    is revealed automatically per the ONUW rules. Skipping these would lose
    information the player is entitled to (e.g., Insomniac not seeing their
    current card after swaps).

    Roles with meaningful player choices (Seer, Robber, Troublemaker, Drunk,
    Doppelganger) are skipped — the player forfeited their choice by not
    submitting.
    """
    role_def = get_role(role_acting_as)
    if role_def.action_types == (ActionType.NONE,):
        return "none"
    if role_def.action_types == (ActionType.SEE_TEAM,):
        return "see_team"
    return "skip"


def _auto_advance_wave(game: Game, wave_number: int) -> None:
    """Auto-advance a wave when its timer expires, marking non-actors as skipped."""
    if game.current_wave != wave_number:
        return  # Wave already advanced — stale callback.
    advance_wave(game)


def send_wave_prompts(game: Game, wave: int) -> None:
    """
    Open the timing of a night window and prompt every actor in it at once.

    ``wave`` is the window number. Records when the window opened (the minimum
    length is measured from here), schedules the maximum-length timer when
    night_wave_seconds > 0, broadcasts wave.start, sends each actor their
    action.prompt, and tells everyone else wave.waiting.
    """
    wave_seconds = get_timer_seconds(
        game, "night_wave_seconds", DEFAULT_NIGHT_WAVE_SECONDS
    )
    opened_at = timezone.now()
    game.night_window_opened_at = opened_at
    if wave_seconds > 0:
        game.phase_deadline = opened_at + timedelta(seconds=wave_seconds)
        callback = timers.make_idempotent_callback(
            game.id,
            Phase.NIGHT,
            functools.partial(_auto_advance_wave, wave_number=wave),
        )
        timers.schedule(_window_timer_key(game, wave), wave_seconds, callback)
    else:
        game.phase_deadline = None
    game.save(update_fields=["phase_deadline", "night_window_opened_at", "updated_at"])

    channel_layer = get_channel_layer()
    if channel_layer is None:
        return

    state = build_game_state(game)
    doppelganger_info = state.doppelganger_copied_role if wave > 1 else None
    prompts = get_required_actions_for_window(state, wave, doppelganger_info)
    acting_player_ids = {p["player_id"] for p in prompts}

    send = async_to_sync(channel_layer.group_send)

    # Broadcast wave_start to all players
    send(
        f"game_{game.id}",
        {
            "type": "wave.start",
            "wave": wave,
            "deadline": game.phase_deadline.isoformat()
            if game.phase_deadline
            else None,
        },
    )

    # Send action prompts to acting players (player-specific channels)
    for prompt in prompts:
        pid = prompt["player_id"]
        send(
            f"game_{game.id}_player_{pid}",
            {
                "type": "action.prompt",
                "wave": wave,
                "role_acting_as": prompt["role_acting_as"],
                "action_types": prompt["action_types"],
                "valid_targets": prompt["valid_targets"],
            },
        )

    # Send waiting messages to non-acting players
    for pid in state.player_roles:
        if pid not in acting_player_ids:
            send(
                f"game_{game.id}_player_{pid}",
                {
                    "type": "wave.waiting",
                    "wave": wave,
                },
            )


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


def _resolve_doppelganger_look(game: Game) -> bool:
    """Resolve the Doppelganger's look as soon as she submits it.

    The look is the one result delivered before its window closes: she needs
    it to choose her follow-up. It goes only to her. Returns True if the copied
    role calls for an immediate follow-up, in which case the follow-up prompt
    has been sent and the window stays open for it.
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

    # Prompt the follow-up (Seer, Robber, Troublemaker, Drunk, Minion) at once.
    with transaction.atomic():
        PlayerRole.objects.filter(game=game, user_id=pr.user_id).update(has_acted=False)
    prompt = build_role_prompt(build_game_state(game), pr.user_id, copied)

    channel_layer = get_channel_layer()
    if channel_layer is not None:
        async_to_sync(channel_layer.group_send)(
            f"game_{game.id}_player_{pr.user_id}",
            {
                "type": "action.prompt",
                "wave": 1,
                "role_acting_as": prompt["role_acting_as"],
                "action_types": prompt["action_types"],
                "valid_targets": prompt["valid_targets"],
            },
        )

    # Fresh maximum for the follow-up. phase_deadline is left alone on purpose:
    # changing it would show the whole table that a follow-up exists.
    wave_seconds = get_timer_seconds(
        game, "night_wave_seconds", DEFAULT_NIGHT_WAVE_SECONDS
    )
    if wave_seconds > 0:
        callback = timers.make_idempotent_callback(
            game.id, Phase.NIGHT, functools.partial(_auto_advance_wave, wave_number=1)
        )
        timers.schedule(_window_timer_key(game, 1), wave_seconds, callback)
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
            actions.append(
                NightAction(
                    player_id=pid,
                    role_acting_as=role_acting_as,
                    action_type=data["action_type"],
                    targets=data.get("targets", {}),
                )
            )
        else:
            actions.append(
                NightAction(
                    player_id=pid,
                    role_acting_as=role_acting_as,
                    action_type=_timeout_action_type(role_acting_as),
                    targets={},
                )
            )
    return actions


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
    timers.cancel(_window_timer_key(game, window))
    state = build_game_state(game)
    night_actions = _collect_window_actions(game, window)

    new_state, results = resolve_window(state, night_actions, window)

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


def send_action_results(
    game: Game,
    results: list[ActionResult],
    night_actions: list[NightAction],
    wave: int,
) -> None:
    """Send each player their own result via WebSocket (action.result only).

    Transforms the engine's raw revealed_info into the client-friendly
    format the frontend expects (display names, consistent keys, action_type).
    """
    channel_layer = get_channel_layer()
    if channel_layer is None:
        return

    send = async_to_sync(channel_layer.group_send)
    player_names = _get_player_names(game)
    action_map = {a.player_id: a for a in night_actions}

    # Send each player their own result only
    for result in results:
        action = action_map.get(result.player_id)
        if action is not None:
            client_info = _transform_revealed_info(action, result, player_names)
            action_type = _client_action_type(action)
        else:
            client_info = result.revealed_info
            action_type = "unknown"

        send(
            f"game_{game.id}_player_{result.player_id}",
            {
                "type": "action.result",
                "wave": wave,
                "action_type": action_type,
                "revealed_info": client_info,
            },
        )


def send_wave_results(
    game: Game,
    results: list[ActionResult],
    night_actions: list[NightAction],
    wave: int,
) -> None:
    """Window closed: send every player their result, then broadcast wave.complete."""
    channel_layer = get_channel_layer()
    if channel_layer is None:
        return
    send_action_results(game, results, night_actions, wave)
    async_to_sync(channel_layer.group_send)(
        f"game_{game.id}", {"type": "wave.complete", "wave": wave}
    )


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
        callback = timers.make_idempotent_callback(
            game.id, Phase.DISCUSSION, _auto_transition_to_voting
        )
        timers.schedule(f"{game.id}:discussion", discussion_seconds, callback)

    # Broadcast phase change to all players
    channel_layer = get_channel_layer()
    if channel_layer is not None:
        async_to_sync(channel_layer.group_send)(
            f"game_{game.id}",
            {
                "type": "phase.change",
                "phase": "discussion",
                "deadline": game.phase_deadline.isoformat()
                if game.phase_deadline
                else None,
            },
        )


def check_and_maybe_advance(game: Game) -> None:
    """
    After a submission, close the window if every actor in it has submitted.

    The window still lasts at least its minimum length: if everyone is done
    early, the close is scheduled for when the minimum is reached. The
    Doppelganger's look is the one step resolved at once (she needs it to
    choose her follow-up).

    Uses select_for_update on the Game row to prevent double-fire
    when two players submit simultaneously.
    """
    with transaction.atomic():
        game = Game.objects.select_for_update().get(id=game.id)
        if game.phase != Phase.NIGHT:
            # Already advanced by another concurrent request
            return

        window = game.current_wave
        if window == 1 and _doppelganger_look_submitted(game):
            if _resolve_doppelganger_look(game):
                return  # Window stays open for the follow-up.

        actor_ids = get_wave_actors(game, window)
        pending = PlayerRole.objects.filter(
            game=game, user_id__in=actor_ids, has_acted=False
        ).count()

        if pending == 0:
            _close_or_defer(game)


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

    # Get all player IDs in this game (for target validation)
    # pyrefly: ignore [missing-attribute]
    game_player_ids = set(game.player_roles.values_list("user_id", flat=True))

    # Validate targets based on action_type
    if action_type == "skip":
        # Explicit "do nothing": no targets allowed.
        if targets:
            errors.append("Invalid action.")

    elif action_type == "peek_player":
        target_id = targets.get("player_id")
        if target_id is None:
            errors.append("targets.player_id is required for peek_player.")
        else:
            target_id = int(target_id)
            # pyrefly: ignore [missing-attribute]
            if target_id == pr.user_id:
                errors.append("Cannot target yourself.")
            elif target_id not in game_player_ids:
                errors.append(f"Invalid target player: {target_id}.")

    elif action_type == "peek_center":
        indices = targets.get("center_indices")
        if not isinstance(indices, list) or len(indices) != 2:
            errors.append("targets.center_indices must be a list of exactly 2 indices.")
        else:
            for idx in indices:
                idx_int = int(idx)
                if idx_int < 0 or idx_int >= len(game.center_cards):
                    errors.append(
                        f"Invalid center card index: {idx_int}. "
                        f"Must be 0-{len(game.center_cards) - 1}."
                    )
            if len(indices) == 2 and int(indices[0]) == int(indices[1]):
                errors.append("Must peek at 2 different center cards.")

    elif action_type == "swap_with_player":
        target_id = targets.get("player_id")
        if target_id is None:
            errors.append("targets.player_id is required for swap_with_player.")
        else:
            target_id = int(target_id)
            # pyrefly: ignore [missing-attribute]
            if target_id == pr.user_id:
                errors.append("Cannot target yourself.")
            elif target_id not in game_player_ids:
                errors.append(f"Invalid target player: {target_id}.")

    elif action_type == "swap_with_center":
        center_index = targets.get("center_index")
        if center_index is None:
            errors.append("targets.center_index is required for swap_with_center.")
        else:
            idx = int(center_index)
            if idx < 0 or idx >= len(game.center_cards):
                errors.append(
                    f"Invalid center card index: {idx}. "
                    f"Must be 0-{len(game.center_cards) - 1}."
                )

    elif action_type == "swap_others":
        player_ids = targets.get("player_ids")
        if not isinstance(player_ids, list) or len(player_ids) != 2:
            errors.append("targets.player_ids must be a list of exactly 2 player IDs.")
        else:
            for pid in player_ids:
                pid_int = int(pid)
                # pyrefly: ignore [missing-attribute]
                if pid_int == pr.user_id:
                    errors.append("Cannot target yourself in swap_others.")
                elif pid_int not in game_player_ids:
                    errors.append(f"Invalid target player: {pid_int}.")
            if len(player_ids) == 2 and int(player_ids[0]) == int(player_ids[1]):
                errors.append("Must target 2 different players.")

    elif action_type == "see_team":
        # No targets required. Only a lone Werewolf may optionally peek center.
        if targets.get("center_index") is not None:
            # Verify the player is acting as Werewolf and is the only one.
            # Error messages MUST be generic — role-specific messages leak
            # hidden information through the API response.
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
            idx = int(targets["center_index"])
            if idx < 0 or idx >= len(game.center_cards):
                errors.append(
                    f"Invalid center card index: {idx}. "
                    f"Must be 0-{len(game.center_cards) - 1}."
                )

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
        callback = timers.make_idempotent_callback(
            game.id, Phase.VOTING, _auto_reveal_votes
        )
        timers.schedule(f"{game.id}:voting", voting_seconds, callback)

    # Broadcast phase change to all players
    channel_layer = get_channel_layer()
    if channel_layer is not None:
        async_to_sync(channel_layer.group_send)(
            f"game_{game.id}",
            {
                "type": "phase.change",
                "phase": "voting",
                "deadline": game.phase_deadline.isoformat()
                if game.phase_deadline
                else None,
            },
        )


def end_discussion(game: Game) -> None:
    """End discussion early (host action). Transitions to voting."""
    timers.cancel(f"{game.id}:discussion")
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
    channel_layer = get_channel_layer()
    if channel_layer is not None:
        async_to_sync(channel_layer.group_send)(
            f"game_{game.id}",
            {"type": "vote.submitted", "player_id": voter_id},
        )

    # Check if all players have voted -> auto-reveal.
    # Lock the Game row to prevent double-fire when two players
    # submit simultaneously and both see all votes in.
    with transaction.atomic():
        game = Game.objects.select_for_update().get(id=game.id)
        if game.phase != Phase.VOTING:
            # Already revealed by another concurrent request
            return errors
        # pyrefly: ignore [missing-attribute]
        total_players = game.player_roles.count()
        # pyrefly: ignore [missing-attribute]
        voted_count = game.player_roles.filter(has_acted=True).count()

        if voted_count >= total_players:
            timers.cancel(f"{game.id}:voting")
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
    # the all-voted path (double-cancel is safe).
    timers.cancel(f"{game.id}:voting")

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

    # Broadcast vote_reveal to all players
    channel_layer = get_channel_layer()
    if channel_layer is not None:
        async_to_sync(channel_layer.group_send)(
            f"game_{game.id}",
            {"type": "vote.reveal", "votes": votes_broadcast},
        )

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

        from apps.core.models import Lobby

        Lobby.objects.filter(id=game.lobby_id).update(status=Lobby.Status.FINISHED)

    # Clean up all remaining timers for this game (safety net — individual
    # timers are cancelled at each phase transition, but this catches any
    # that were missed due to unusual flow).
    timers.cancel_all_for_game(str(game.id))

    # Broadcast game results
    if channel_layer is not None:
        async_to_sync(channel_layer.group_send)(
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
