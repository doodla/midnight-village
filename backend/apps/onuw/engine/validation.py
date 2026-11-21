"""
Pure-Python settings validation for ONUW games.

NO Django imports allowed in this module. This is pure game logic.
"""

from __future__ import annotations

from .decks import DECK_CHIPS
from .roles import ROLE_REGISTRY

# Every timer setting the server reads, in seconds. 0 disables that timer
# (night_doppelganger_window_seconds: see services._fixed_window_seconds).
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
    """
    Validate the timer keys of a settings dict (absent keys are fine).

    Each must be an integer from 0 to MAX_TIMER_SECONDS (0 to 60 for
    disconnect_grace_seconds, 0 to 600 for host_handover_seconds), and
    night_min_window_seconds must not exceed night_wave_seconds when the
    latter is set above 0 (the minimum length of a window cannot be longer
    than its maximum). These are host-facing settings, so errors are explicit.
    """
    return timer_value_errors(settings) + window_order_errors(settings)


def timer_value_errors(settings: dict) -> list[str]:
    """Each timer key present is a whole number of seconds in its range."""
    errors: list[str] = []
    for key in TIMER_SETTING_KEYS:
        if key not in settings:
            continue
        maximum = max_seconds_for(key)
        if not is_valid_timer_value(settings[key], maximum):
            errors.append(
                f"{key!r} must be a whole number of seconds from 0 to {maximum}."
            )
    return errors


def window_order_errors(settings: dict) -> list[str]:
    """The minimum length of a night window cannot be longer than its maximum
    (when that is set above 0)."""
    errors: list[str] = []
    wave_max = settings.get("night_wave_seconds")
    window_min = settings.get("night_min_window_seconds")
    if (
        is_valid_timer_value(wave_max)
        and is_valid_timer_value(window_min)
        and wave_max > 0  # type: ignore[operator]
        and window_min > wave_max  # type: ignore[operator]
    ):
        errors.append(
            "'night_min_window_seconds' must not be longer than 'night_wave_seconds'."
        )
    return errors


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


# The close of a window must not depend on roles, so a window with no deadline (one
# idle phone could stall the table, and a window 1 with no length singles out the
# Doppelganger) and a minimum window shorter than this are refused, unless the server
# allows untimed nights (tests, development, the harness).
MIN_WINDOW_FLOOR_SECONDS = 5
TIMED_NIGHT_KEYS: tuple[str, ...] = (
    "night_wave_seconds",
    "night_doppelganger_window_seconds",
)


def clamp_night_timing(settings: dict, *, allow_untimed: bool = True) -> dict:
    """``settings`` with every stored timer value the server would refuse today
    replaced, so a table older code wrote is never stuck: a timer value out of
    range is dropped (the server's default applies, as ``get_timer_seconds``
    reads it anyway); unless ``allow_untimed``, a night timer of 0 is dropped
    too (its default is a real length) and a minimum window under 5 s becomes 5
    (and a night window shorter than that minimum becomes the minimum). A new
    dict; the input is not changed."""
    out = dict(settings)
    for key in TIMER_SETTING_KEYS:
        if key in out and not is_valid_timer_value(out[key], max_seconds_for(key)):
            del out[key]
    if allow_untimed:
        return out
    for key in TIMED_NIGHT_KEYS:
        if out.get(key) == 0:
            del out[key]
    window_min = out.get("night_min_window_seconds")
    if isinstance(window_min, int) and window_min < MIN_WINDOW_FLOOR_SECONDS:
        out["night_min_window_seconds"] = MIN_WINDOW_FLOOR_SECONDS
    wave = out.get("night_wave_seconds")
    floor = out.get("night_min_window_seconds", 0)
    if isinstance(wave, int) and isinstance(floor, int) and 0 < wave < floor:
        out["night_wave_seconds"] = floor
    return out


def validate_night_timing(settings: dict, *, allow_untimed: bool = True) -> list[str]:
    """Unless ``allow_untimed``: no zero night timers and a minimum window of at
    least 5 s. (Keys the server does not know, such as a protocol flag older
    tables carry, are ignored: every table plays the one night there is.)"""
    if allow_untimed:
        return []
    errors = [
        f"{key!r} cannot be 0 when phones choose at night."
        for key in TIMED_NIGHT_KEYS
        if type(settings.get(key)) is int and settings.get(key) == 0
    ]
    window_min = settings.get("night_min_window_seconds")
    if type(window_min) is int and window_min < MIN_WINDOW_FLOOR_SECONDS:
        errors.append(
            "'night_min_window_seconds' must be at least "
            f"{MIN_WINDOW_FLOOR_SECONDS} when phones choose at night."
        )
    return errors


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
) -> list[str]:
    """
    Validate ONUW role configuration.

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
    order = (
        window_order_errors(settings)
        if changed is None
        or changed & {"night_wave_seconds", "night_min_window_seconds"}
        else []
    )
    errors: list[str] = [
        *timer_value_errors(scope),
        *order,
        *validate_pace(scope),
        *validate_night_timing(scope, allow_untimed=allow_untimed),
        *validate_deck_choice(scope),
    ]
    if not check_deck:
        return errors

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

    expected = player_count + 3
    if total_roles != expected:
        errors.append(
            f"Total role count must be {expected} (players + 3 center cards), got {total_roles}."
        )

    return errors
