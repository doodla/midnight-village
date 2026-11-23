"""
Phones coming and going during a game.

Registering a socket, noticing one that left (cleanly or silently), the grace
period for a dropped player, and what the game does when someone is gone for good:
the night's window or the vote stops waiting for them.
"""

from __future__ import annotations

import logging
import uuid
from collections.abc import Callable
from typing import Any

from django.db import transaction
from django.db.models.functions import Now
from django.utils import timezone

from apps.core import timers
from apps.onuw import presence

from . import basics, night_flow, readiness, voting
from .models import Game, Phase, PlayerRole, SocketPresence
from .protocol import (
    NIGHT_WINDOWS,
    in_look_stage,
)

logger = logging.getLogger(__name__)


def _evaluate_presence(game: Game, *, announce: bool = True) -> None:
    """Re-check whether the look stage / the night window / the vote can now proceed.

    The caller holds the Game row lock. Called when a grace period ends, and when
    a phone comes back. If the stage stays open, ``announce`` tells the table the
    count again (``needed`` may have changed).
    """
    if game.phase == Phase.NIGHT and game.current_wave in NIGHT_WINDOWS:
        night_flow._advance_if_ready(game)
    elif in_look_stage(game):
        if not voting._advance_stage_if_ready(game) and announce:
            basics._send_after_commit(
                [
                    (
                        f"game_{game.id}",
                        {"type": "progress", **readiness.look_progress(game)},
                    )
                ]
            )
    elif game.phase == Phase.VOTING:
        if readiness._votes_ready(game):
            voting.reveal_votes(game)
        elif announce:
            basics._send_after_commit(
                [
                    (
                        f"game_{game.id}",
                        {"type": "progress", **readiness.vote_progress(game)},
                    )
                ]
            )


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
            away = readiness._seconds_disconnected(pr, timezone.now())
            if away is None:
                return  # Reconnected (or never dropped): keep waiting for them.
            remaining = readiness._grace_seconds(game) - away
            if remaining > 0:
                # Fired a hair early (timer and wall clocks differ): try again.
                basics._schedule_after_commit(
                    readiness._grace_timer_key(game_id, user_id),
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
        basics._after_commit(
            lambda: presence.ensure_check_timer("game", game_id, user_id)
        )
        if was_connected:
            return False

        grace = readiness._grace_seconds(game)
        was_gone = (
            pr.disconnected_at is not None
            and grace > 0
            and (timezone.now() - pr.disconnected_at).total_seconds() >= grace
        )
        if pr.disconnected_at is not None:
            pr.disconnected_at = None
            pr.save(update_fields=["disconnected_at"])
        basics._cancel_after_commit(readiness._grace_timer_key(game_id, user_id))
        basics._send_after_commit(
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
        if game.phase == Phase.DISCUSSION and was_gone:
            # The talk has no grace timers and never waits; a phone that was left
            # out of ``needed`` coming back only changes the count, which the table
            # is told. Ending the talk stays a tap's job.
            basics._send_after_commit(
                [
                    (
                        f"game_{game.id}",
                        {"type": "progress", **readiness.talk_progress(game)},
                    )
                ]
            )
        if game.phase in (Phase.NIGHT, Phase.VOTING):
            try:
                with transaction.atomic():  # a savepoint: never costs the connect
                    _evaluate_presence(game, announce=was_gone)
            except Exception:
                logger.exception("Presence check failed for game %s", game_id)
        return True


def _game_went_offline(game: Game, pr: PlayerRole, user_id: int) -> None:
    """The player has no fresh socket left: stamp it, tell the table, start the
    grace timer. The ONE code path for a clean last-socket disconnect and for a
    silent death noticed by the presence check. Caller holds the locks."""
    pr.disconnected_at = timezone.now()
    pr.save(update_fields=["disconnected_at"])
    basics._send_after_commit(
        [
            (
                f"game_{game.id}",
                {"type": "player.presence", "player_id": user_id, "connected": False},
            )
        ]
    )
    grace = readiness._grace_seconds(game)
    if game.phase in (Phase.NIGHT, Phase.VOTING) and grace > 0:
        basics._schedule_after_commit(
            readiness._grace_timer_key(game.id, user_id),
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
        basics._cancel_after_commit(presence.check_key("game", game.id, user_id))
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
        basics._schedule_after_commit(
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
