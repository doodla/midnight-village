"""
DEBUG-gated developer-harness affordances for ONUW.

Everything in this module is inert unless ``settings.DEBUG`` is True. These
surfaces exist solely to let the integration harness (and a human debug toolbar)
drive the full game deterministically and read authoritative ground truth.

CRITICAL — hidden information: the debug-state oracle (``debug_state``) exposes
EVERY player's role and the full night-action log. It MUST be unreachable in
production. The single gate is ``settings.DEBUG``; the frontend const gate is a
second, independent layer (defense in depth), never the only barrier.
"""

from __future__ import annotations

from collections import Counter
from typing import Any

from django.conf import settings
from django.db.models import Q

from rest_framework import status
from rest_framework.response import Response

from apps.core import host, timers
from apps.core.models import ScheduledTimer
from apps.onuw import presence

from .engine.roles import ROLE_REGISTRY
from .engine.win_conditions import get_effective_team
from .models import Game, Phase


def debug_disabled_response() -> Response | None:
    """Return a 403 Response when DEBUG is off, else None.

    Every debug surface calls this first and returns the result if non-None,
    so the surface is provably inert in production (403, no side effects).
    """
    if settings.DEBUG:
        return None
    return Response(
        {"detail": "Not found."},
        status=status.HTTP_403_FORBIDDEN,
    )


class ForcedAssignmentError(ValueError):
    """Raised when a forced_assignment payload is malformed or inconsistent.

    The message is intentionally generic — it never names a role or player, so a
    validation error cannot leak hidden information even though this surface is
    DEBUG-only.
    """


def parse_forced_assignment(
    forced: Any,
    role_counts: dict[str, int],
    lobby_player_ids: list[int],
) -> tuple[dict[int, str], list[str]]:
    """Validate and coerce a ``forced_assignment`` payload.

    Args:
        forced: The raw ``debug.forced_assignment`` object from the request.
        role_counts: Configured role multiset from ``lobby.settings["roles"]``
            (canonical TitleCase role name -> count).
        lobby_player_ids: Every player's user id, exactly once.

    Returns:
        (player_id_to_role, center_cards) — player_id_to_role keyed by int user
        id, center_cards a list of exactly 3 role names.

    Raises:
        ForcedAssignmentError: on any structural or multiset mismatch. The
            caller maps this to a 400 and creates nothing.
    """
    if not isinstance(forced, dict):
        raise ForcedAssignmentError("Invalid forced_assignment.")

    raw_player_roles = forced.get("player_roles")
    center = forced.get("center")

    if not isinstance(raw_player_roles, dict):
        raise ForcedAssignmentError("Invalid forced_assignment.")
    if not isinstance(center, list):
        raise ForcedAssignmentError("Invalid forced_assignment.")
    if len(center) != 3:
        raise ForcedAssignmentError("center must contain exactly 3 cards.")

    # Coerce stringified user-id keys to ints. JSON object keys are always
    # strings; the frontend sends e.g. {"12": "Werewolf"}.
    player_id_to_role: dict[int, str] = {}
    for raw_id, role_name in raw_player_roles.items():
        try:
            user_id = int(raw_id)
        except (TypeError, ValueError) as exc:
            raise ForcedAssignmentError("Invalid player id.") from exc
        if not isinstance(role_name, str):
            raise ForcedAssignmentError("Invalid role.")
        player_id_to_role[user_id] = role_name

    # Every name (player + center) must be a known v1 role.
    all_names = list(player_id_to_role.values()) + list(center)
    for name in all_names:
        if not isinstance(name, str) or name not in ROLE_REGISTRY:
            raise ForcedAssignmentError("Unknown role.")

    # The multiset of assigned roles must equal the configured counts exactly.
    configured = Counter({name: c for name, c in role_counts.items() if c})
    assigned = Counter(all_names)
    if assigned != configured:
        raise ForcedAssignmentError("Role multiset does not match configuration.")

    # Every lobby player must appear exactly once.
    if set(player_id_to_role) != set(lobby_player_ids) or len(player_id_to_role) != len(
        lobby_player_ids
    ):
        raise ForcedAssignmentError("Player set does not match lobby.")

    return player_id_to_role, list(center)


def _team_token(
    user_id: int,
    current_roles: dict[int, str],
    doppelganger_copied: dict[int, str],
) -> str:
    """Resolve a player's effective team token: village|werewolf|neutral.

    Tanner resolves to "neutral" (its team), never "tanner".
    """
    return get_effective_team(user_id, current_roles, doppelganger_copied)


def build_debug_state(game: Game) -> dict[str, Any]:
    """Build the full authoritative oracle projection for ``game``.

    Read-only. Reuses the same effective-team and Doppelganger-copy resolution
    the production results path uses — no new game logic.
    """
    player_roles_qs = list(game.player_roles.select_related("user").all())

    current_roles: dict[int, str] = {}
    doppelganger_copied: dict[int, str] = {}
    for pr in player_roles_qs:
        current_roles[pr.user_id] = pr.current_role
        if pr.original_role == "Doppelganger" and pr.night_action_data.get(
            "copied_role"
        ):
            doppelganger_copied[pr.user_id] = pr.night_action_data["copied_role"]

    host_id = game.lobby.effective_host_id
    connected_ids = presence.connected_user_ids(game_id=game.id)

    players: list[dict[str, Any]] = []
    votes: dict[str, int | None] = {}
    vote_locked: dict[str, bool] = {}
    for pr in player_roles_qs:
        players.append(
            {
                "user_id": pr.user_id,
                "display_name": pr.user.display_name or pr.user.username,
                "is_host": pr.user_id == host_id,
                "token": pr.token,
                "seat": pr.seat,
                "original_role": pr.original_role,
                "current_role": pr.current_role,
                "doppelganger_copied_role": doppelganger_copied.get(pr.user_id),
                "team": _team_token(pr.user_id, current_roles, doppelganger_copied),
                # Real presence: any game socket open for this player right now.
                "connected": pr.user_id in connected_ids,
                # "Ready to vote" (talk) / "looked at my card" (look stage).
                "ready": bool(pr.phase_ready),
                # How many `choose` the server took from this phone in each
                # night window ("1", "2"): a phone with nothing to choose
                # sends none (the harness checks no sleeper was waited for).
                "chosen": {
                    str(window): _chose(pr.night_action_data, window)
                    for window in (1, 2)
                },
            }
        )
        # EVERY player is a key; null = has not voted / abstained.
        votes[str(pr.user_id)] = pr.vote_target_id
        vote_locked[str(pr.user_id)] = bool(pr.has_acted)

    night_actions_log = _build_night_actions_log(game)

    results = _build_results(game) if game.phase == Phase.RESULTS else None

    state: dict[str, Any] = {
        "game_id": str(game.id),
        "phase": game.phase,
        # INT: the night window (1 = Doppelganger, 2 = everyone else), 0
        # outside night. The model defaults current_wave to 0 and resets it to
        # 0 on the discussion transition, so this is never null.
        "current_wave": game.current_wave,
        "center_cards": list(game.center_cards),
        "dealt_center_cards": list(game.dealt_center_cards),
        "players": players,
        "night_actions_log": night_actions_log,
        "votes": votes,
        "vote_locked": vote_locked,
        "results": results,
        "pending_timers": _pending_timers(game),
    }
    return state


def _pending_timers(game: Game) -> list[str]:
    """Names of the timers pending for ``game``, sorted: the game's own keys
    without the ``<game id>:`` prefix (``wave:2``, ``discussion``, ``voting``,
    ``grace:<user id>``) plus ``host_handover`` while its lobby's handover timer
    is armed. Lets the harness assert that a timer was started or cancelled,
    which no player-facing response says.

    "Pending" means the ``ScheduledTimer`` row exists: a row that is overdue but
    not yet fired still shows, and under the queue backend a row is not proof
    that a message will arrive. The handover timer belongs to the LOBBY, so it
    also shows on a finished game of the same lobby.
    """
    prefix = f"{game.id}:"
    keys = ScheduledTimer.objects.filter(
        Q(key__startswith=prefix) | Q(key=host.timer_key(game.lobby))
    ).values_list("key", flat=True)
    return sorted(
        "host_handover" if key.startswith("lobby:") else key.removeprefix(prefix)
        for key in keys
    )


def _build_night_actions_log(game: Game) -> list[dict[str, Any]]:
    """Project the persisted night action log into the oracle's shape.

    ``role_acting_as`` is read straight from each persisted entry, where it was
    captured at ACTION time by ``persist_wave_results`` (Doppelganger-aware). It
    must NOT be recomputed from the player's current state: an actor whose own
    card was later swapped (e.g. a Robber who robbed) holds a different
    ``current_role`` by read time, so recomputation reports the wrong acting
    role. Legacy/synthetic entries written before the field existed yield
    ``None``.
    """
    projected: list[dict[str, Any]] = []
    for entry in game.night_actions_log:
        # "" is the dataclass default for synthetic/legacy entries; surface it
        # as null so a consumer never mistakes it for a real role.
        acting = entry.get("role_acting_as") or None
        projected.append(
            {
                "wave": entry.get("wave"),
                "player_id": entry.get("player_id"),
                "role_acting_as": acting,
                "action_type": entry.get("action_type"),
                "targets": entry.get("targets", {}),
                "result": entry.get("result", {}),
                "timestamp_order": entry.get("timestamp_order"),
                # True only for a move the server made for a player who timed
                # out or was gone past the grace period (the Drunk's swap).
                "made_by_server": bool(entry.get("made_by_server", False)),
            }
        )
    return projected


def _build_results(game: Game) -> dict[str, Any]:
    """Project the stored ``game.results`` into the oracle's results shape.

    ``winning_teams`` is a list of lowercase tokens ⊂ {village, werewolf,
    tanner}; the harness asserts it as a set.
    """
    results = game.results
    return {
        "winning_teams": list(results.get("winning_teams", [])),
        "reason": results.get("reason", ""),
        "eliminated_players": list(results.get("eliminated_players", [])),
        "elimination_reasons": dict(results.get("elimination_reasons", {})),
        "player_outcomes": dict(results.get("player_outcomes", {})),
    }


def fire_timer(game: Game, key_suffix: str) -> tuple[bool, str]:
    """Synchronously fire the pending timer for ``game`` keyed by ``key_suffix``.

    ``key_suffix`` is one of ``wave:{n}`` / ``discussion`` / ``voting`` /
    ``current``. ``wave:{n}`` is night window ``n`` (1 or 2); firing it closes
    that window now (the same close as the window's own timer, so it ignores
    ``night_min_window_seconds`` and, for window 1, the fixed length).
    ``current`` resolves to the single phase / window timer under the game's
    prefix (grace timers are ignored) and is rejected if there are zero or more
    than one. A window with no timer
    (its timer setting is 0) has nothing to fire: use the host's advance-wave.

    Timers live in the ``ScheduledTimer`` table. We claim the row (ignoring its
    due time, so a late-arriving thread or queue message for it becomes a
    no-op) and run its job synchronously on this thread. The job is
    phase-guarded, so firing a stale timer is a safe no-op rather than a
    double transition.

    Returns:
        (fired, resolved_key). ``fired`` is False for a missing key (safe
        no-op). ``resolved_key`` is the actual registry key acted on (or the
        requested key when nothing was found).

    Raises:
        ForcedAssignmentError: when ``current`` resolves ambiguously (0 or >1
            keys). Reused as the generic harness 4xx signal — the caller maps it
            to 400.
    """
    prefix = f"{game.id}:"

    if key_suffix == "current":
        # Grace timers (a dropped player's countdown) are not phase timers.
        matching = list(
            ScheduledTimer.objects.filter(key__startswith=prefix)
            .exclude(key__contains=":grace:")
            .values_list("key", flat=True)
        )
        if len(matching) != 1:
            raise ForcedAssignmentError(
                f"'current' requires exactly one pending timer, found {len(matching)}."
            )
        full_key = matching[0]
    else:
        full_key = f"{game.id}:{key_suffix}"

    # Claim and run it now. A missing row is a stale / already-fired /
    # never-scheduled timer: a safe no-op.
    result = timers.fire(full_key, None, force=True)
    return result.status == "ran", full_key


def _chose(data: dict[str, Any], window: int) -> int:
    """How many ``choose`` a phone sent in a night window (its stored count)."""
    count = data.get(f"chose_{window}", 0)
    return count if type(count) is int else 0
