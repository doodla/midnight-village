"""
Practice players: computer-filled seats, so one person can try a whole game alone.

A practice player is an account the server makes for one table: a guest whose
username starts with ``practice-`` (guest sign-up only ever makes bare uuids, and
the account has no password), so no phone can sign in as one and nothing a host
sends can turn a person into one. That username is the one mark, read wherever it
matters: the lobby body marks the member (``players[].practice: true``), host
handover and the owner leaving skip them, and the game app plays them
(``apps/onuw/practice.py``).

The host switches the ability on for a table (``settings.practice``, set only by
``POST /lobbies/<code>/practice/``; the app hides the switch behind a long press),
then sets how many practice players sit at it. They take seats like anyone
(``lobbies.add_member``: tokens, ``seats``, ``max_players``), never host, are always
shown as here (they have no phone to drop), and never hold a table open alone: the
last person leaving closes the table as before and their accounts go with it. A
person joining a table whose every seat is taken takes a practice player's seat.

Names are a fixed list of village things, never a person's name, so even an app
that shows no "Practice" tag reads them as not people. No randomness here: the
next name is the first one not taken at the table.

Lock order: the caller holds the Lobby row (Lobby, then LobbyMember).
"""

from __future__ import annotations

import logging
import uuid
from typing import Any

from apps.core import games, lobbies, tokens
from apps.core.models import Lobby, LobbyMember, User

logger = logging.getLogger(__name__)

USERNAME_PREFIX = "practice-"
SETTING_KEY = "practice"

# Village things, in the order they sit down. Ten seats minus the one person.
NAMES: tuple[str, ...] = (
    "Scarecrow",
    "Teapot",
    "Broom",
    "Kettle",
    "Haystack",
    "Bucket",
    "Candle",
    "Weathervane",
    "Wheelbarrow",
)


class PracticeError(Exception):
    """A practice change refused: ``status`` and the body's ``detail`` and ``code``."""

    def __init__(self, status: int, detail: str, code: str) -> None:
        super().__init__(detail)
        self.status = status
        self.detail = detail
        self.code = code


def is_practice_username(username: str) -> bool:
    """True for the username of a practice player's account."""
    return username.startswith(USERNAME_PREFIX)


def is_practice(user: Any) -> bool:
    """True if ``user`` (a User) is a practice player."""
    return is_practice_username(getattr(user, "username", "") or "")


def members(lobby: Lobby) -> list[LobbyMember]:
    """The table's practice players, in join order (the newest last)."""
    return list(
        LobbyMember.objects.filter(
            lobby=lobby, user__username__startswith=USERNAME_PREFIX
        )
        .select_related("user")
        .order_by("joined_at", "id")
    )


def member_user_ids(lobby: Lobby) -> set[int]:
    """User ids of the table's practice players."""
    return set(
        LobbyMember.objects.filter(
            lobby=lobby, user__username__startswith=USERNAME_PREFIX
        ).values_list("user_id", flat=True)
    )


def switched_on(lobby: Lobby) -> bool:
    """The host has switched practice players on for this table."""
    return isinstance(lobby.settings, dict) and lobby.settings.get(SETTING_KEY) is True


def capacity(lobby: Lobby) -> int:
    """The most members the table takes now (the join's own rule)."""
    limit = games.hooks_for(lobby).seat_limit(lobby)
    most = min(lobby.max_players, tokens.MAX_TABLE_SIZE)
    return most if limit is None else min(most, limit)


def most(lobby: Lobby, present: int, practice: int) -> int:
    """How many practice players the table can hold now: the ones seated plus
    every free seat (``present`` members, ``practice`` of them practice)."""
    return max(practice, practice + capacity(lobby) - present)


def body_extras(lobby: Lobby, players: list[dict[str, Any]]) -> dict[str, Any]:
    """Mark the lobby body's practice players (``practice: true``, always
    ``connected``: they have no phone to drop) and, for a table that has switched
    them on or has some seated, add ``practice: {"most": n}`` (the stepper's top).
    A table that never used them is answered exactly as before."""
    seated = 0
    for entry in players:
        if is_practice_username(entry["user"].get("username") or ""):
            entry["practice"] = True
            entry["connected"] = True
            seated += 1
    if not games.hooks_for(lobby).practice_seats(lobby):
        return {}
    if not seated and not switched_on(lobby):
        return {}
    return {SETTING_KEY: {"most": most(lobby, len(players), seated)}}


def _next_name(taken: set[str]) -> str:
    for name in NAMES:
        if name not in taken:
            return name
    return NAMES[len(taken) % len(NAMES)]


def _seat_one(lobby: Lobby, taken_names: set[str]) -> LobbyMember:
    """Make a practice account and seat it (``lobbies.LobbyFullError`` if full)."""
    name = _next_name(taken_names)
    user = User.objects.create_user(
        username=f"{USERNAME_PREFIX}{uuid.uuid4()}",
        password=None,  # no password: nobody can sign in as it
        display_name=name,
        is_guest=True,
    )
    member = lobbies.add_member(lobby, user.pk)
    taken_names.add(name)
    logger.info(
        "lobby %s: practice player %s (%s) sits down", lobby.code, user.pk, name
    )
    return member


def _unseat(lobby: Lobby, member: LobbyMember) -> None:
    """Take a practice player off the table; its account goes too unless it played
    a game here (whose results keep it)."""
    user_id: int = member.user_id  # type: ignore[attr-defined]
    member.delete()
    if not games.hooks_for(lobby).has_played(lobby, user_id):
        User.objects.filter(pk=user_id, username__startswith=USERNAME_PREFIX).delete()
    logger.info("lobby %s: practice player %s leaves", lobby.code, user_id)


def set_practice(lobby: Lobby, *, on: bool | None, count: int | None) -> None:
    """Switch practice players on or off and set how many sit at the table.

    The caller holds the Lobby row lock and has checked the host and that the
    table is waiting. ``on`` False takes every practice player off; a ``count``
    above 0 switches them on. The count is a target, so a request sent twice
    leaves the table as once. Raises ``PracticeError`` (400 ``lobby_full``) for a
    count past the free seats, changing nothing.
    """
    if on is False:
        count = 0
    seated = members(lobby)
    if count is not None:
        present = lobby.players.count()  # type: ignore[attr-defined]
        if count > most(lobby, present, len(seated)):
            raise PracticeError(400, "Lobby is full.", "lobby_full")
        taken = {m.user.display_name for m in seated}
        for _ in range(count - len(seated)):
            try:
                _seat_one(lobby, taken)
            except lobbies.LobbyFullError:
                raise PracticeError(400, "Lobby is full.", "lobby_full") from None
        for member in reversed(seated[count:]):
            _unseat(lobby, member)
    settings: dict[str, Any] = (
        dict(lobby.settings) if isinstance(lobby.settings, dict) else {}
    )
    if on is False:
        settings.pop(SETTING_KEY, None)
    elif on or count:
        settings[SETTING_KEY] = True
    if settings != lobby.settings:
        lobby.settings = settings
        lobby.save(update_fields=["settings", "updated_at"])
    else:
        lobbies.touch(lobby.pk)


def make_room(lobby: Lobby) -> bool:
    """A person is joining a full table: the newest practice player gives up its
    seat. False when there is none (the table is full of people). The caller
    holds the Lobby row lock."""
    seated = members(lobby)
    if not seated:
        return False
    _unseat(lobby, seated[-1])
    return True


def humans(lobby: Lobby, user_ids: list[int]) -> list[int]:
    """``user_ids`` without the practice players, in the same order."""
    practice = member_user_ids(lobby)
    return [uid for uid in user_ids if uid not in practice]


def close_table(lobby: Lobby) -> None:
    """The last person left: delete the table (its games with it) and the
    practice accounts that sat at it."""
    ids = member_user_ids(lobby)
    lobby.delete()
    if ids:
        User.objects.filter(pk__in=ids, username__startswith=USERNAME_PREFIX).delete()
