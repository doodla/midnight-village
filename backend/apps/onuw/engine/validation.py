"""
Pure-Python settings validation for ONUW games.

NO Django imports allowed in this module. This is pure game logic.
"""

from __future__ import annotations

from .decks import DECK_CHIPS, MAX_AUTO_PLAYERS, MIN_AUTO_PLAYERS
from .roles import ROLE_REGISTRY

# Every timer setting the server reads, in seconds. 0 disables that timer
# (night_doppelganger_window_seconds: see night_window._fixed_window_seconds).
TIMER_SETTING_KEYS: tuple[str, ...] = (
    "night_wave_seconds",
    "night_min_window_seconds",
    "night_doppelganger_window_seconds",
    "discussion_seconds",
    "voting_seconds",
    "disconnect_grace_seconds",
    "host_handover_seconds",
    "card_look_seconds",
)
MAX_TIMER_SECONDS = 3600
# Per-setting ceilings that are lower than MAX_TIMER_SECONDS. The disconnect
# grace period is how long the game waits for a dropped phone; 0 turns it off.
# host_handover_seconds is how long the host's phone may be away before the
# host role passes on (0 turns it off).
TIMER_SETTING_MAX_SECONDS: dict[str, int] = {
    "disconnect_grace_seconds": 60,
    "host_handover_seconds": 600,
    # The look stage's backstop: how long the table may take to look at its cards
    # (0 = no look stage: the night opens at the deal).
    "card_look_seconds": 120,
}


def max_seconds_for(key: str) -> int:
    """Largest allowed value (seconds) of a timer setting."""
    return TIMER_SETTING_MAX_SECONDS.get(key, MAX_TIMER_SECONDS)


def is_valid_timer_value(value: object, maximum: int = MAX_TIMER_SECONDS) -> bool:
    """True if value is an integer number of seconds in [0, maximum]."""
    return (
        isinstance(value, int) and not isinstance(value, bool) and 0 <= value <= maximum
    )


def validate_timer_settings(settings: dict) -> list[str]:
    """The timer keys of a settings dict (absent keys are fine), by the rule
    table (``length_errors``, untimed nights allowed): each a whole number of
    seconds within its range, given the others."""
    return length_errors(settings, frozenset(settings), allow_untimed=True)


# A label for the pace preset the deck screen used; the server never reads it,
# it only refuses junk so a screen can re-select its preset.
PACE_LABELS: tuple[str, ...] = ("quick", "normal", "long", "custom")


def validate_pace(settings: dict) -> list[str]:
    """``pace`` (if present) must be one of the preset labels."""
    if "pace" in settings and settings["pace"] not in PACE_LABELS:
        return [f"'pace' must be one of: {', '.join(PACE_LABELS)}."]
    return []


DECK_MODES: tuple[str, ...] = ("auto", "custom")


def validate_deck_choice(settings: dict) -> list[str]:
    """``deck`` (``auto`` or ``custom``) and ``deck_chip`` (a chip of ``engine.decks``),
    if present. Under ``auto`` the server builds the deck at the deal; under
    ``custom`` (or no ``deck`` at all) the ``roles`` the host chose are the deck."""
    errors: list[str] = []
    if "deck" in settings and settings["deck"] not in DECK_MODES:
        errors.append(f"'deck' must be one of: {', '.join(DECK_MODES)}.")
    if "deck_chip" in settings and settings["deck_chip"] not in DECK_CHIPS:
        errors.append(f"'deck_chip' must be one of: {', '.join(DECK_CHIPS)}.")
    return errors


# How many players the game is for (``seats``): the host picks it before anyone joins
# and the table waits for that many. Absent or null: the table is "open" and deals to
# whoever is there (every table before this setting, and a new table until the host
# picks a number).
MIN_SEATS = MIN_AUTO_PLAYERS
MAX_SEATS = MAX_AUTO_PLAYERS


def seats_of(settings: object) -> int | None:
    """The number of players a table is set for, or None for an open table (no
    ``seats``, null, or a value this server would refuse)."""
    if not isinstance(settings, dict):
        return None
    seats = settings.get("seats")
    if type(seats) is int and MIN_SEATS <= seats <= MAX_SEATS:
        return seats
    return None


def seats_range(player_count: int, max_players: int | None) -> list[int]:
    """``[least, most]`` the number of players may be set to now: never fewer than
    the players here (nor 3), never more than the table holds (``max_players``) nor
    10. The lobby body sends it as ``seats_range``; ``validate_seats`` takes the
    same."""
    most = MAX_SEATS if max_players is None else min(MAX_SEATS, max_players)
    return [max(MIN_SEATS, player_count), most]


def validate_seats(
    settings: dict, player_count: int, max_players: int | None = None
) -> list[str]:
    """``seats`` (if given): null (open) or a whole number in ``seats_range``."""
    if "seats" not in settings or settings["seats"] is None:
        return []
    seats = settings["seats"]
    _, most = seats_range(player_count, max_players)
    if type(seats) is not int or not MIN_SEATS <= seats <= MAX_SEATS:
        return [
            f"'seats' must be a whole number from {MIN_SEATS} to {MAX_SEATS}, or null."
        ]
    if seats < player_count:
        return [f"{player_count} players are at the table already."]
    if seats > most:
        return [f"The table holds {most} players at most."]
    return []


# The close of a window must not depend on roles, so a window with no deadline (one
# idle phone could stall the table, and a window 1 with no length singles out the
# Doppelganger) and a minimum window shorter than this are refused, unless the server
# allows untimed nights (tests, development, the harness).
MIN_WINDOW_FLOOR_SECONDS = 5
TIMED_NIGHT_KEYS: tuple[str, ...] = (
    "night_wave_seconds",
    "night_doppelganger_window_seconds",
)


# THE rule table for the lengths: what each is when the table sets none, the most it
# may be, the least it may be now (``length_ranges``), the one check a settings change
# gets (``length_errors``) and the clamp a deal applies to what older code stored
# (``clamp_night_timing``). The ranges the lobby body sends are the ones the check
# takes, so a phone can never be offered what the server refuses.
#
# The game's defaults (seconds) when a table sets none (``services`` reads them from
# here; the host handover's is ``core.host``'s, a core setting with no rule here).
LENGTH_DEFAULTS: dict[str, int] = {
    "night_wave_seconds": 30,
    "night_min_window_seconds": 8,
    "night_doppelganger_window_seconds": 10,
    "discussion_seconds": 300,
    "voting_seconds": 120,
    "disconnect_grace_seconds": 25,
    "card_look_seconds": 0,
}

# A stage that ends on its own clock or when everyone present is done. With its
# clock at 0 it waits for everyone, so a phone that dies must be counted gone
# (``disconnect_grace_seconds`` > 0), or the game waits for good.
DEADLINE_KEYS: tuple[str, ...] = (
    "night_wave_seconds",
    "discussion_seconds",
    "voting_seconds",
)
GRACE_KEY = "disconnect_grace_seconds"


def declared_lengths(settings: object) -> dict[str, int]:
    """Each length the rules see: the stored value when it is one the server takes
    (a whole number in 0 to the key's most), else the default."""
    stored = settings if isinstance(settings, dict) else {}
    out: dict[str, int] = {}
    for key in TIMER_SETTING_KEYS:
        value = stored.get(key)
        if is_valid_timer_value(value, max_seconds_for(key)):
            out[key] = value  # type: ignore[assignment]
        elif key in LENGTH_DEFAULTS:
            out[key] = LENGTH_DEFAULTS[key]
    return out


def length_ranges(
    settings: object, *, allow_untimed: bool = True
) -> dict[str, list[int]]:
    """``{key: [least, most]}`` for every length, given the others as ``settings``
    has them (a key's range never depends on its own value):

    - 0 to the key's most (``TIMER_SETTING_MAX_SECONDS``, else an hour);
    - unless ``allow_untimed``: a night window at least 1 s, the minimum window at
      least 5 s;
    - the minimum window no longer than the window (when that is above 0);
    - unless ``allow_untimed``, no stage waits for good: with
      ``disconnect_grace_seconds`` at 0 every ``DEADLINE_KEYS`` clock is at
      least 1 s; with any of them at 0 the grace period is at least 1 s.
    """
    now = declared_lengths(settings)
    ranges = {key: [0, max_seconds_for(key)] for key in TIMER_SETTING_KEYS}

    def at_least(key: str, least: int) -> None:
        ranges[key][0] = max(ranges[key][0], least)

    if not allow_untimed:
        for key in TIMED_NIGHT_KEYS:
            at_least(key, 1)
        at_least("night_min_window_seconds", MIN_WINDOW_FLOOR_SECONDS)
    wave = now.get("night_wave_seconds", 0)
    if wave > 0:
        window_min = ranges["night_min_window_seconds"]
        window_min[1] = max(window_min[0], min(window_min[1], wave))
    if allow_untimed:
        # Development, tests, the harness: games driven by hand, any clock.
        return ranges
    if now.get(GRACE_KEY, 0) == 0:
        for key in DEADLINE_KEYS:
            at_least(key, 1)
    if any(now.get(key, 0) == 0 for key in DEADLINE_KEYS):
        at_least(GRACE_KEY, 1)
    return ranges


def length_errors(
    settings: dict, changed: set[str] | frozenset[str] | None, *, allow_untimed: bool
) -> list[str]:
    """The lengths a change gives (every length when ``changed`` is None, the deal)
    that are not whole numbers within ``length_ranges`` of ``settings`` (the stored
    ones with the change merged over them)."""
    keys = [
        key
        for key in TIMER_SETTING_KEYS
        if key in settings and (changed is None or key in changed)
    ]
    if not keys:
        return []
    ranges = length_ranges(settings, allow_untimed=allow_untimed)
    errors = []
    for key in keys:
        least, most = ranges[key]
        value = settings[key]
        if type(value) is not int or not least <= value <= most:
            errors.append(
                f"{key!r} must be a whole number of seconds from {least} to {most}."
            )
    return errors


def clamp_night_timing(settings: dict, *, allow_untimed: bool = True) -> dict:
    """``settings`` with every stored length the rules would refuse today replaced,
    so a table older code wrote is never stuck (the deal applies it): a value out of
    its key's range is dropped (the default applies); unless ``allow_untimed``, a
    night timer of 0 is dropped too, a minimum window under 5 s becomes 5, a
    stored window shorter than its stored minimum becomes the minimum, and a
    grace period of 0 beside a stage with no clock is dropped (its default counts
    a dead phone gone, so the game cannot wait for good). A new dict; the input is
    not changed."""
    out = dict(settings)
    for key in TIMER_SETTING_KEYS:
        if key in out and not is_valid_timer_value(out[key], max_seconds_for(key)):
            del out[key]
    if not allow_untimed:
        for key in TIMED_NIGHT_KEYS:
            if out.get(key) == 0:
                del out[key]
        window_min = out.get("night_min_window_seconds")
        if isinstance(window_min, int) and window_min < MIN_WINDOW_FLOOR_SECONDS:
            out["night_min_window_seconds"] = MIN_WINDOW_FLOOR_SECONDS
        # A stored window shorter than its stored minimum becomes the minimum.
        wave = out.get("night_wave_seconds")
        floor = out.get("night_min_window_seconds", 0)
        if isinstance(wave, int) and isinstance(floor, int) and 0 < wave < floor:
            out["night_wave_seconds"] = floor
        now = declared_lengths(out)
        if now.get(GRACE_KEY) == 0 and any(now.get(k) == 0 for k in DEADLINE_KEYS):
            del out[GRACE_KEY]
    return out


def running_lengths(settings: object) -> dict[str, int]:
    """The lengths a game dealt with ``settings`` (already clamped) runs with: the
    declared ones, the minimum window cut to the window as the night cuts it."""
    now = declared_lengths(settings)
    wave = now.get("night_wave_seconds", 0)
    if wave > 0 and now.get("night_min_window_seconds", 0) > wave:
        now["night_min_window_seconds"] = wave
    return now


def _changed_keys(settings: dict, changed: set[str] | frozenset[str]) -> dict:
    """The part of ``settings`` a change touched."""
    return {key: settings[key] for key in changed if key in settings}


def validate_onuw_settings(
    settings: dict,
    player_count: int,
    *,
    check_deck: bool = True,
    allow_untimed: bool = True,
    changed: set[str] | frozenset[str] | None = None,
    max_players: int | None = None,
) -> list[str]:
    """
    Validate ONUW settings: for a lobby PATCH (``changed`` given) only the keys it
    gives, and of a card list only each role's own limits (a deck being built is
    stored card by card; whether it fits is the deal's question, reported by the
    lobby body's ``deal``); for the deal (``changed`` None) everything, including
    that the table holds the players it is set for and the deck fits them.

    Args:
        settings: Game settings dict. Must contain a "roles" key mapping
                  role names to counts, e.g. {"Werewolf": 2, "Seer": 1, ...}.
        player_count: Number of players in the lobby.
        check_deck: Check the role deck against the player count. The deal always
                    does; a settings change that does not touch ``roles`` (a pace
                    label, a timer) skips it, because who joined meanwhile is not
                    that change's fault and the deal checks again.
        allow_untimed: Allow zero night timers and a short minimum window (the
                    server's ``ONUW_ALLOW_UNTIMED_NIGHT``).
        changed: The keys a settings change gives (a lobby PATCH); only those
                    are checked, so a value older code stored and nobody touches
                    never blocks a change (the deal clamps it:
                    ``clamp_night_timing``). None checks every key.

    Returns:
        List of error messages. Empty list means valid.
    """
    if not isinstance(settings, dict):
        return ["Settings must be an object."]

    scope = settings if changed is None else _changed_keys(settings, changed)
    errors: list[str] = [
        *length_errors(settings, changed, allow_untimed=allow_untimed),
        *validate_pace(scope),
        *validate_deck_choice(scope),
        *(
            validate_seats(scope, player_count, max_players)
            if changed is not None and "seats" in changed
            else []
        ),
    ]
    if not check_deck:
        return errors

    at_deal = changed is None
    seats = seats_of(settings)
    if at_deal:
        if seats is not None and player_count != seats:
            errors.append(
                f"The table is set for {seats} players, {player_count} are here."
            )
        if player_count < 3:
            errors.append(f"At least 3 players required, got {player_count}.")
        if player_count > 10:
            errors.append(f"At most 10 players allowed, got {player_count}.")

    if settings.get("deck") == "auto":
        # The server builds the deck at the deal for the players then at the table
        # (``engine.decks``): any card list lying around is ignored.
        return errors

    roles = settings.get("roles")
    if roles is None:
        errors.append("Settings must include a 'roles' key.")
        return errors

    if not isinstance(roles, dict):
        errors.append("'roles' must be a mapping of role name to count.")
        return errors

    total_roles = 0
    for role_name, count in roles.items():
        if not isinstance(count, int) or count < 0:
            errors.append(f"Count for {role_name!r} must be a non-negative integer.")
            continue

        if role_name not in ROLE_REGISTRY:
            errors.append(f"Unknown role: {role_name!r}.")
            continue

        role_def = ROLE_REGISTRY[role_name]
        if count < role_def.min_count:
            errors.append(
                f"{role_name!r} requires at least {role_def.min_count}, got {count}."
            )
        if count > role_def.max_count:
            errors.append(
                f"{role_name!r} allows at most {role_def.max_count}, got {count}."
            )

        total_roles += count

    # Masons must be used in pairs (0 or 2, never 1).
    mason_count = roles.get("Mason", 0)
    if mason_count == 1:
        errors.append(
            "Masons must be used in pairs — include 0 or 2 Mason cards, not 1."
        )

    if not at_deal:
        return errors

    expected = player_count + 3
    if total_roles != expected:
        errors.append(
            f"Total role count must be {expected} (players + 3 center cards), got {total_roles}."
        )

    return errors
