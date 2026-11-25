"""
What a player is shown of the night, after the fact.

Their own results for the windows that have closed (``night_results_for_player``,
what ``GET /me/`` carries and what the ack counts), and at the end the whole night's
timeline (``night_timeline_for``). Everything here READS the night's log; the one
write is the ack, a single statement that only ever raises a player's own count.
Nothing here moves the game on: that is ``night_flow.py`` and ``voting.py``.
"""

from __future__ import annotations

import logging
from typing import Any

from django.db.models import F
from django.db.models.functions import Greatest

from apps.core.wire import public_name

from .engine.roles import window_for_order_group
from .engine.state import ActionResult, NightAction
from .engine.timeline import TimelineError, build_night_timeline, recover_dealt_center
from .models import Game, Phase, PlayerRole
from .protocol import NIGHT_WINDOWS
from .turns import early_key

logger = logging.getLogger(__name__)


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
    """Transform engine revealed_info into the format the client reads.

    The engine returns raw data (player IDs, internal key names). The client gets
    display names and a consistent key schema per action type. Every role name is
    canonical (``"Werewolf"``). Two things are added to the viewer's own result (it
    was the viewer's own choice, so nothing leaks): ``center_indices`` on a
    ``peek_center`` (which two centre cards, in the order of ``roles``), and
    ``"nothing_chosen": true`` on a result that is the role's default because
    nothing the player picked meant anything (or they did not choose): a ``skip``,
    the Drunk's swap made by the server, a lone Werewolf who looked at no centre
    card.
    """
    raw = result.revealed_info
    action_type = action.action_type
    targets = action.targets

    # Insomniac sees their current role (may have changed via swap).
    if action.role_acting_as == "Insomniac":
        return {"current_role": raw.get("current_role", "")}

    if action_type == "peek_player":
        # Seer peek at a player, or Doppelganger copy.
        target_id = int(targets.get("player_id", 0))
        target_name = player_names.get(target_id, "Unknown")
        # Engine uses "peeked_role" for Seer, "copied_role" for Doppelganger.
        role = raw.get("peeked_role") or raw.get("copied_role", "")
        out: dict[str, Any] = {
            "target_name": target_name,
            "role": role,
        }
        # Preserve copied_role for Doppelganger follow-up logic.
        if "copied_role" in raw:
            out["copied_role"] = raw["copied_role"]
        return out

    if action_type == "peek_center":
        # Seer peek at 2 center cards.
        peeked = raw.get("peeked_center", [])
        roles = [
            entry["role"]
            for entry in peeked
            if isinstance(entry, dict) and "role" in entry
        ]
        return {
            "roles": roles,
            "center_indices": [
                int(index) for index in targets.get("center_indices", [])
            ],
        }

    if action_type == "swap_with_player":
        # Robber swaps with target, learns their role.
        target_id = int(targets.get("player_id", 0))
        target_name = player_names.get(target_id, "Unknown")
        new_role = raw.get("new_role", "")
        return {
            "target_name": target_name,
            "new_role": new_role,
        }

    if action_type == "swap_with_center":
        # Drunk swaps with a center card, learns nothing.
        center_index = targets.get("center_index")
        drunk_out: dict[str, Any] = {
            "card_index": int(center_index) if center_index is not None else 0
        }
        if action.made_by_server:
            drunk_out["nothing_chosen"] = True
        return drunk_out

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
                "role": cc.get("role", ""),
            }
        elif action.role_acting_as == "Werewolf" and raw.get("werewolves") == []:
            # A lone Werewolf whose picks held no centre card: alone, nothing seen.
            see_team_out["nothing_chosen"] = True
        return see_team_out

    if action_type == "skip":
        return {"nothing_chosen": True}

    # Unknown action — pass through as-is.
    return dict(raw)


def client_action_result(
    action: NightAction,
    revealed_info: dict[str, Any],
    player_names: dict[int, str],
) -> tuple[str, dict[str, Any]]:
    """The (action_type, revealed_info) pair a player is shown for one result: the
    single place that turns an engine result into an entry of ``GET /me/``'s
    ``night_results``."""
    result = ActionResult(
        player_id=action.player_id, revealed_info=revealed_info, state_mutations=[]
    )
    return (
        _client_action_type(action),
        _transform_revealed_info(action, result, player_names),
    )


def player_names(game: Game) -> dict[int, str]:
    """Every player's public name, by id (what results name players by)."""
    rows = PlayerRole.objects.filter(game=game).select_related("user")
    return {pr.user_id: public_name(pr.user) for pr in rows}


def _visible_result_entries(
    game: Game, user_id: int, own_data: dict[str, Any] | None = None
) -> list[tuple[int, dict[str, Any]]]:
    """The player's own night-log entries that show as a result now: ``(window,
    entry)`` in window order (stable: wake order within a window).

    Only this player's entries, a ``skip`` included (the phone is told that its
    choice did nothing: ``"nothing_chosen": true``). A closed window shows its log.
    The window still open shows what is already settled for this player: the
    Doppelganger's look, logged as soon as it is resolved (she needs it to choose
    her follow-up), and the settled result of their own choose, kept in their
    ``night_action_data`` (``own_data``, ``early_key``) until the close logs the
    same entry. It is theirs alone, like everything in this list.
    """
    if game.phase == Phase.NIGHT:
        closed_before = game.current_wave  # windows 1..current_wave-1 have closed
    elif game.phase in (Phase.DISCUSSION, Phase.VOTING, Phase.RESULTS):
        closed_before = NIGHT_WINDOWS[-1] + 1
    else:
        return []
    early_look = game.phase == Phase.NIGHT

    entries: list[tuple[int, dict[str, Any]]] = []
    for entry in game.night_actions_log:
        if entry.get("player_id") != user_id:
            continue
        try:
            window = window_for_order_group(entry["wave"])
        except (KeyError, ValueError):
            continue
        is_early_look = (
            early_look
            and window == game.current_wave == 1
            and entry.get("role_acting_as") == "Doppelganger"
        )
        if window < closed_before or is_early_look:
            entries.append((window, entry))
    if early_look and own_data is not None:
        settled = own_data.get(early_key(game.current_wave))
        if isinstance(settled, dict) and settled.get("player_id") == user_id:
            entries.append((game.current_wave, settled))
    entries.sort(key=lambda item: item[0])
    return entries


def night_results_for_player(
    game: Game,
    user_id: int,
    player_names: dict[int, str],
    own_data: dict[str, Any] | None = None,
) -> list[dict[str, Any]]:
    """The caller's own night results: every window that has closed, and at night
    what is already settled in the open one (the Doppelganger's look, a result
    settled at the choose: ``_visible_result_entries``).

    Rebuilt from the stored night log (``client_action_result``). One entry per
    result, in window order (a Doppelganger with a follow-up gets two in window 1:
    the copy, then the follow-up). Which entries count is decided by
    ``_visible_result_entries``.
    """
    results: list[dict[str, Any]] = []
    for window, entry in _visible_result_entries(game, user_id, own_data):
        action = NightAction(
            player_id=user_id,
            role_acting_as=entry.get("role_acting_as", ""),
            action_type=entry.get("action_type", ""),
            targets=entry.get("targets", {}),
            made_by_server=bool(entry.get("made_by_server", False)),
        )
        try:
            action_type, revealed = client_action_result(
                action, entry.get("result") or {}, player_names
            )
        except Exception:
            logger.exception("Could not rebuild a night result for player %s", user_id)
            continue
        results.append(
            {"wave": window, "action_type": action_type, "revealed_info": revealed}
        )
    return results


def night_timeline_for(game: Game, player_roles: list[PlayerRole]) -> dict | None:
    """The night as a timeline for the results screen, or None if it cannot be built.

    ``player_roles`` must be in seat order. Built forwards from the dealt cards
    (``original_role`` by seat and ``Game.dealt_center_cards``); a game dealt before
    the centre was stored recovers it by undoing the logged swaps, which only counts
    if that leads back to every player's dealt role.

    This is a presentation boundary: the rest of the results must show whatever the
    night log looks like, so ANY failure answers None. A log the timeline refuses in
    a game from before the centre was stored is expected (WARNING, once); anything
    else is a bug or a corrupt log (ERROR, with the traceback).
    """
    seats = [pr.user_id for pr in player_roles]
    original = {pr.user_id: pr.original_role for pr in player_roles}
    log = list(game.night_actions_log)
    legacy = not game.dealt_center_cards
    try:
        dealt_center = list(game.dealt_center_cards) or recover_dealt_center(
            original,
            {pr.user_id: pr.current_role for pr in player_roles},
            list(game.center_cards),
            log,
        )
        return build_night_timeline(seats, original, dealt_center, log)
    except TimelineError:
        if legacy:
            logger.warning("No night timeline for old game %s", game.id, exc_info=True)
        else:
            logger.error("No night timeline for game %s", game.id, exc_info=True)
    except Exception:
        logger.exception("Night timeline of game %s failed unexpectedly", game.id)
    return None


def acknowledge_night_results(game: Game, user_id: int, seen: int) -> int | None:
    """Record that the player has seen their first ``seen`` night results.

    Returns the stored count, or None if the user is not a player of the game.
    ``seen`` is clamped to the number of results the player can see now: the log
    entries ``night_results`` is built from, counted without rendering them. So an
    ack can never cover a result not shown to them yet. The update is ONE
    statement that
    only ever raises the count (``GREATEST``): it takes no Game lock, a late or
    repeated ack changes nothing, and two phones cannot lower each other's.
    """
    rows = PlayerRole.objects.filter(game=game, user_id=user_id)
    # At night a settled result of the open window counts too (one more read,
    # only then: the app acks in the talk).
    own = (
        rows.values_list("night_action_data", flat=True).first()
        if game.phase == Phase.NIGHT
        else None
    )
    visible = len(_visible_result_entries(game, user_id, own))
    updated = rows.update(
        night_results_seen=Greatest(F("night_results_seen"), min(seen, visible))
    )
    if not updated:
        return None
    return rows.values_list("night_results_seen", flat=True).get()
