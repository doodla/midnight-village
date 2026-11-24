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

**Accounts never pile up.** A table OWNS its practice accounts (``owned_account_ids``:
seated now, or holding a seat in one of its games, whose results keep them), and
every path that ends a table deletes them with it (``close_table``). A practice
player taken off a table goes at once unless its games keep it. Tables are never
swept on a clock (there is no cron), so the number is bounded instead: **a person
has practice players at one table at a time.** Switching them on, or starting a new
table, first clears that person's practice players from every other table they own
or act as host for that is not in a running game (``clear_elsewhere``). So the
accounts alive at any moment are at most one table's seats per person, plus the
ones finished games' results hold (which go with their table).

``settings.practice`` is written only here: the settings PATCH and a new table's
settings never set or clear it (``strip_setting``).

Names are a fixed list of village things, never a person's name, so even an app
that shows no "Practice" tag reads them as not people. No randomness here: the
next name is the first one not taken at the table. Each has its own seat token,
the thing it is named for (``token_for``: "teapot" for Teapot), drawn in the seat
tokens' style but outside the people's ten (``tokens.TOKENS``): a practice player
never takes a person's token, and an app that does not know the token draws a
plain disc.

Lock order: the caller holds the Lobby row (Lobby, then LobbyMember).
"""

from __future__ import annotations

import logging
import uuid
from typing import Any

from django.db.models import Q

from apps.core import asked as ask
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


def token_for(name: str) -> str:
    """A practice player's seat token: the thing it is named for."""
    return name.lower()


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
    member = lobbies.add_member(lobby, user.pk, token=token_for(name))
    taken_names.add(name)
    logger.info(
        "lobby %s: practice player %s (%s) sits down", lobby.code, user.pk, name
    )
    return member


def strip_setting(settings: Any) -> Any:
    """``settings`` without ``practice``: only ``set_practice`` writes that key (the
    settings PATCH and a new table's settings never set or clear it)."""
    if isinstance(settings, dict) and SETTING_KEY in settings:
        return {k: v for k, v in settings.items() if k != SETTING_KEY}
    return settings


def owned_account_ids(lobby: Lobby) -> set[int]:
    """The practice accounts this table owns: seated at it now, or holding a seat
    in one of its games. Every path that ends the table deletes them with it."""
    played = games.hooks_for(lobby).played_user_ids(lobby, USERNAME_PREFIX)
    return member_user_ids(lobby) | played


def _delete_accounts(ids: set[int]) -> None:
    if ids:
        User.objects.filter(pk__in=ids, username__startswith=USERNAME_PREFIX).delete()


def _unseat(lobby: Lobby, member: LobbyMember) -> None:
    """Take a practice player off the table; its account goes too unless it played
    a game here (whose results keep it until the table goes)."""
    user_id: int = member.user_id  # type: ignore[attr-defined]
    member.delete()
    if user_id not in games.hooks_for(lobby).played_user_ids(lobby, USERNAME_PREFIX):
        _delete_accounts({user_id})
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


def note_asked(lobby: Lobby, user_id: int, asked: int | None) -> None:
    """A practice request was applied: keep its ``asked`` as the newest under
    ``Lobby.asked["practice"]`` (``apps.core.asked``). The settings PATCH never
    writes that key (it strips ``practice``), so the two never shadow each other.
    The caller holds the Lobby row lock. Without ``asked`` nothing is written."""
    if asked is None:
        return
    lobby.asked = ask.noted(lobby.asked, [SETTING_KEY], user_id, asked)
    lobby.save(update_fields=["asked"])


def make_room(lobby: Lobby) -> bool:
    """A person is joining a full table: the newest practice player gives up its
    seat. False when there is none (the table is full of people). The caller
    holds the Lobby row lock."""
    seated = members(lobby)
    if not seated:
        return False
    _unseat(lobby, seated[-1])
    return True


def close_table(lobby: Lobby) -> None:
    """The table ends (the last person left): delete it, its games with it, and
    every practice account it owns (``owned_account_ids``), seated or not."""
    ids = owned_account_ids(lobby)
    lobby.delete()
    _delete_accounts(ids)
    if ids:
        logger.info("lobby %s closed with %d practice accounts", lobby.code, len(ids))


def _theirs(user_id: int) -> Q:
    """The tables ``user_id`` owns or acts as host for."""
    return Q(host_id=user_id) | Q(acting_host_id=user_id)


def lock_with_theirs(code: str, user_id: int) -> Lobby | None:
    """Lock the table ``code`` together with the other tables ``user_id`` owns or
    hosts, all in one statement in primary-key order (so two requests of one
    person at two tables never lock in opposite orders). Returns ``code``'s row,
    or None when there is no such table."""
    rows = list(
        Lobby.objects.select_for_update()
        .filter(Q(code=code) | _theirs(user_id))
        .order_by("pk")
    )
    return next((row for row in rows if row.code == code), None)


def clear_elsewhere(user_id: int, keep: Lobby | None = None) -> list[Lobby]:
    """The bound: a person has practice players at one table at a time. Take every
    practice player off the other tables ``user_id`` owns or hosts that are not in
    a running game, switch them off there, and delete the accounts nothing kept
    points at (a finished game's results keep theirs until that table goes).
    Returns the tables changed (the caller announces them after commit). Locks
    those tables (pk order); a caller that already holds them
    (``lock_with_theirs``) takes no new lock."""
    others = (
        Lobby.objects.select_for_update()
        .filter(_theirs(user_id))
        .exclude(status=Lobby.Status.IN_GAME)
        .order_by("pk")
    )
    if keep is not None:
        others = others.exclude(pk=keep.pk)
    changed = []
    for other in others:
        seated = members(other)
        if not seated and not switched_on(other):
            continue
        for member in reversed(seated):
            _unseat(other, member)
        other.settings = strip_setting(other.settings)
        other.save(update_fields=["settings", "updated_at"])
        logger.info(
            "lobby %s: practice players cleared (user %s is elsewhere)",
            other.code,
            user_id,
        )
        changed.append(other)
    return changed
